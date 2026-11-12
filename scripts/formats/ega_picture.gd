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
## the combat icon sets.
##
## Animated blocks (PIC*, SPRIT*, three FINAL blocks) wrap one picture per frame:
##   u8 frame_count
##   frame_count * { u32 delay, picture header (17 bytes, frame count 1), pixel data }
## Frames may differ in size (SPRIT holds the same sprite at several distances).
## See decode_animated(). Every PIC and SPRIT block in the DOS game matches this exactly.

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
## Per-frame delay for animated blocks (units not yet known); empty for plain pictures.
var delays: Array[int] = []


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
	for f in count:
		pic.frames.append(_pixels_to_image(block, HEADER_SIZE + f * frame_bytes, pic.width, pic.height))
	return pic


## True if the block is a frame list (u8 count, then {u32 delay, picture}) that fills it exactly.
static func is_animated(block: PackedByteArray) -> bool:
	if block.is_empty():
		return false
	var count := block.decode_u8(0)
	var p := 1
	for f in count:
		if p + 4 + HEADER_SIZE > block.size():
			return false
		var h := block.decode_u16(p + 4)
		var w8 := block.decode_u16(p + 6)
		if h == 0 or w8 == 0:
			return false
		p += 4 + HEADER_SIZE + h * w8 * 4
	return count > 0 and p == block.size()


static func decode_animated(block: PackedByteArray) -> EgaPicture:
	if not is_animated(block):
		return null
	var pic := EgaPicture.new()
	var count := block.decode_u8(0)
	var p := 1
	for f in count:
		var delay := block.decode_u32(p)
		var h := block.decode_u16(p + 4)
		var w := block.decode_u16(p + 6) * 8
		if f == 0:
			pic.x = block.decode_u16(p + 8)
			pic.y = block.decode_u16(p + 10)
		pic.width = maxi(pic.width, w)
		pic.height = maxi(pic.height, h)
		pic.delays.append(delay)
		pic.frames.append(_pixels_to_image(block, p + 4 + HEADER_SIZE, w, h))
		p += 4 + HEADER_SIZE + h * w / 2
	return pic


## Decodes either layout.
static func decode_any(block: PackedByteArray) -> EgaPicture:
	var pic := decode(block)
	if pic == null:
		pic = decode_animated(block)
	return pic


static func _pixels_to_image(block: PackedByteArray, start: int, w: int, h: int) -> Image:
	var rgb := _palette_bytes()
	var pixels := PackedByteArray()
	pixels.resize(w * h * 3)
	var o := 0
	for i in w * h / 2:
		var b := block[start + i]
		var hi := (b >> 4) * 3
		var lo := (b & 15) * 3
		pixels[o] = rgb[hi]
		pixels[o + 1] = rgb[hi + 1]
		pixels[o + 2] = rgb[hi + 2]
		pixels[o + 3] = rgb[lo]
		pixels[o + 4] = rgb[lo + 1]
		pixels[o + 5] = rgb[lo + 2]
		o += 6
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, pixels)


## All frames laid out in a grid (columns wide), for viewing multi-frame sets.
func sheet(columns: int = 16) -> Image:
	var cols := mini(columns, frames.size())
	var rows := ceili(frames.size() / float(cols))
	var img := Image.create_empty(width * cols, height * rows, false, Image.FORMAT_RGB8)
	for i in frames.size():
		var f := frames[i]
		img.blit_rect(f, Rect2i(0, 0, f.get_width(), f.get_height()), Vector2i((i % cols) * width, (i / cols) * height))
	return img


static func _palette_bytes() -> PackedByteArray:
	return PackedByteArray(PALETTE_RGB)


## The pictures an animated PIC block shows, in turn: the first frame, then each later
## frame laid over it by exclusive-or of the colour numbers (the later frames hold only
## what changes). Checked in the lab, chat 10: the camp's fire (PIC 29) as the original
## draws it is frame 0 XOR frame 1, pixel for pixel. Each later frame goes over the first, not
## over the one before (laid one on another, the boat's frames, PIC 41, turn to noise).
## Not for SPRIT blocks (whole frames).
static func xor_frames(block: PackedByteArray) -> Array[Image]:
	var out: Array[Image] = []
	var fr := frame_indices(block)
	if fr.is_empty():
		return out
	var base: Dictionary = fr[0]
	var rgb := _palette_bytes()
	for f in fr:
		var w: int = base.w
		var h: int = base.h
		var px := PackedByteArray()
		px.resize(w * h * 3)
		for i in w * h:
			var c: int = base.px[i]
			if f != base and i < f.px.size():
				c ^= f.px[i]
			px[i * 3] = rgb[c * 3]
			px[i * 3 + 1] = rgb[c * 3 + 1]
			px[i * 3 + 2] = rgb[c * 3 + 2]
		out.append(Image.create_from_data(w, h, false, Image.FORMAT_RGB8, px))
	return out


## Frames of an animated block as colour indices, for compositing over the 3D view:
## [{"w", "h", "x", "y", "px": PackedByteArray (w*h)}]; x and y are the header's
## position in 8-pixel tiles.
static func frame_indices(block: PackedByteArray) -> Array:
	var out := []
	if not is_animated(block):
		return out
	var count := block.decode_u8(0)
	var p := 1
	for f in count:
		var h := block.decode_u16(p + 4)
		var w := block.decode_u16(p + 6) * 8
		var px := PackedByteArray()
		px.resize(w * h)
		var start := p + 4 + HEADER_SIZE
		for i in w * h / 2:
			var b := block[start + i]
			px[i * 2] = b >> 4
			px[i * 2 + 1] = b & 15
		out.append({"w": w, "h": h, "x": block.decode_u16(p + 8), "y": block.decode_u16(p + 10), "px": px})
		p += 4 + HEADER_SIZE + h * w / 2
	return out
