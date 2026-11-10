class_name EgaPicture
extends RefCounted
## Decoder for Gold Box EGA picture blocks (inside .DAX files).
##
## Block layout:
##   u16 height        -- pixels
##   u16 width8        -- width in 8-pixel units
##   u16 x, u16 y      -- default screen position (in 8-pixel / pixel units; not yet confirmed)
##   u8  frame_count
##   u8  unknown[8]    -- purpose not yet known (possibly a colour or mask table)
##   frames: frame_count * (height * width8 * 4) bytes,
##           each 4 bits per pixel, high nibble first, rows top to bottom.
##
## Confirmed for TITLE, BODY, HEAD, CBODY, CHEAD, CPIC, COMSPR, ICON, 8X8D and
## the combat icon sets. PIC*, SPRIT*, WALLDEF* and some FINAL blocks use other formats.

const HEADER_SIZE := 17

## Standard 16-colour EGA palette, as R, G, B triplets.
const PALETTE_RGB := [
	0, 0, 0, 0, 0, 170, 0, 170, 0, 0, 170, 170,
	170, 0, 0, 170, 0, 170, 170, 85, 0, 170, 170, 170,
	85, 85, 85, 85, 85, 255, 85, 255, 85, 85, 255, 255,
	255, 85, 85, 255, 85, 255, 255, 255, 85, 255, 255, 255,
]

var width: int = 0
var height: int = 0
var x: int = 0
var y: int = 0
var frames: Array[Image] = []


## True if the block's size matches the picture layout exactly.
static func is_picture(block: PackedByteArray) -> bool:
	if block.size() < HEADER_SIZE:
		return false
	var h := block.decode_u16(0)
	var w8 := block.decode_u16(2)
	var n := block.decode_u8(8)
	return h > 0 and w8 > 0 and n > 0 and block.size() == HEADER_SIZE + n * h * w8 * 4


static func decode(block: PackedByteArray) -> EgaPicture:
	if not is_picture(block):
		return null
	var pic := EgaPicture.new()
	pic.height = block.decode_u16(0)
	pic.width = block.decode_u16(2) * 8
	pic.x = block.decode_u16(4)
	pic.y = block.decode_u16(6)
	var count := block.decode_u8(8)
	var frame_bytes := pic.width * pic.height / 2
	var rgb := _palette_bytes()
	for f in count:
		var start := HEADER_SIZE + f * frame_bytes
		var pixels := PackedByteArray()
		pixels.resize(pic.width * pic.height * 3)
		var o := 0
		for i in frame_bytes:
			var b := block[start + i]
			for nibble in [b >> 4, b & 15]:
				pixels[o] = rgb[nibble * 3]
				pixels[o + 1] = rgb[nibble * 3 + 1]
				pixels[o + 2] = rgb[nibble * 3 + 2]
				o += 3
		pic.frames.append(Image.create_from_data(pic.width, pic.height, false, Image.FORMAT_RGB8, pixels))
	return pic


## All frames laid out in a grid (columns wide), for viewing multi-frame sets.
func sheet(columns: int = 16) -> Image:
	var cols := mini(columns, frames.size())
	var rows := ceili(frames.size() / float(cols))
	var img := Image.create_empty(width * cols, height * rows, false, Image.FORMAT_RGB8)
	for i in frames.size():
		img.blit_rect(frames[i], Rect2i(0, 0, width, height), Vector2i((i % cols) * width, (i / cols) * height))
	return img


static func _palette_bytes() -> PackedByteArray:
	return PackedByteArray(PALETTE_RGB)
