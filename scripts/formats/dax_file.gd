class_name DaxFile
extends RefCounted
## Reader for Gold Box .DAX container files.
##
## Layout (all little-endian):
##   u16 header_len                  -- bytes of directory that follow (9 per entry)
##   entry[header_len / 9]:
##       u8  id                      -- block id, unique within the file
##       s32 offset                  -- from the start of the data area (2 + header_len)
##       u16 raw_size                -- size after decompression
##       u16 comp_size               -- size stored in the file
##   data area: the blocks, each RLE-compressed (see decompress()).
##
## Verified against every .DAX file in the DOS Pool of Radiance (GOG):
## all 1,245 blocks decompress to exactly raw_size.

## Block id -> decompressed bytes, in directory order.
var blocks: Dictionary = {}
var path: String = ""


static func open(file_path: String) -> DaxFile:
	var data := FileAccess.get_file_as_bytes(file_path)
	if data.is_empty():
		push_error("DaxFile: cannot read %s" % file_path)
		return null
	var dax := DaxFile.new()
	dax.path = file_path
	var header_len := data.decode_u16(0)
	var base := 2 + header_len
	for i in range(0, header_len, 9):
		var p := 2 + i
		var id := data.decode_u8(p)
		var offset := data.decode_s32(p + 1)
		var raw_size := data.decode_u16(p + 5)
		var comp_size := data.decode_u16(p + 7)
		var start := base + offset
		dax.blocks[id] = decompress(data.slice(start, start + comp_size), raw_size)
	return dax


## Gold Box RLE: a signed control byte n.
##   n >= 0: copy the next n + 1 bytes literally.
##   n <  0: repeat the next byte -n times.
static func decompress(src: PackedByteArray, raw_size: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(raw_size)
	var i := 0
	var o := 0
	while i < src.size() and o < raw_size:
		var n := src[i]
		i += 1
		if n < 128:
			for k in n + 1:
				if o < raw_size and i < src.size():
					out[o] = src[i]
					o += 1
				i += 1
		else:
			var count := 256 - n
			var value := src[i] if i < src.size() else 0
			i += 1
			for k in count:
				if o < raw_size:
					out[o] = value
					o += 1
	return out


func ids() -> Array:
	return blocks.keys()
