class_name GameScreen
extends TextureRect
## The original's adventure screen, drawn as the original draws it: a 320x200 picture in
## the EGA palette with the game's own 1-bit font (8X8D1 block 201) and frame tiles
## (8X8D1 block 202: 20 the gold corner, 21 the rope upright, 22 the rope across), scaled
## up without smoothing.
##
## Layout (in 8x8 cells, from the lab's screenshots of the original):
##   frame: rows 0, 16 and 23 across, columns 0, 16 and 39 down to row 16, 0 and 39 below;
##   view: inner frame cells 2..14, the 88x88 3D view inside at (24, 24);
##   party: "NAME" at column 17 row 2, AC ending at column 34, HP at 38, members from row 4
##          (the selected one white, the others light cyan); place and time at row 15;
##   text box: rows 17..22, columns 1..38; menu: row 24 (hot letter white, the rest green).

const W := 320
const H := 200
const EGA := [
	Color8(0, 0, 0), Color8(0, 0, 170), Color8(0, 170, 0), Color8(0, 170, 170),
	Color8(170, 0, 0), Color8(170, 0, 170), Color8(170, 85, 0), Color8(170, 170, 170),
	Color8(85, 85, 85), Color8(85, 85, 255), Color8(85, 255, 85), Color8(85, 255, 255),
	Color8(255, 85, 85), Color8(255, 85, 255), Color8(255, 255, 85), Color8(255, 255, 255)]
const WHITE := 15
const CYAN := 11
const GREEN := 10
const YELLOW := 14
const RED := 12

static var _font := PackedByteArray()
static var _tiles: Array[Image] = []

var img: Image


static func load_art(game_path: String) -> void:
	if not _font.is_empty():
		return
	var dax := DaxFile.open(game_path.path_join("8X8D1.DAX"))
	if dax == null:
		return
	if dax.blocks.has(201):
		_font = dax.blocks[201]
	if dax.blocks.has(202):
		var pic := EgaPicture.decode_any(dax.blocks[202])
		if pic != null:
			for f in pic.frames:
				var t: Image = f.duplicate()
				t.convert(Image.FORMAT_RGBA8)
				_tiles.append(t)


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_anchors_preset(Control.PRESET_FULL_RECT)
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)


## Glyph index in the font for a character: '0'-'?' and space as they are, letters from 1.
static func glyph(c: int) -> int:
	if c >= 0x61 and c <= 0x7A:
		c -= 0x20
	if c >= 0x40 and c <= 0x5F:
		return c & 0x3F
	return c if c < 0x40 else 0x20


func clear() -> void:
	img.fill(EGA[0])


func text(col: int, row: int, s: String, color: int = WHITE) -> void:
	for i in s.length():
		put_glyph(col + i, row, glyph(s.unicode_at(i)), color)


func text_px(x: int, y: int, s: String, color: int = WHITE) -> void:
	for i in s.length():
		put_glyph_px(x + i * 8, y, glyph(s.unicode_at(i)), color)


func put_glyph(col: int, row: int, g: int, color: int) -> void:
	put_glyph_px(col * 8, row * 8, g, color)


func put_glyph_px(x0: int, y0: int, g: int, color: int) -> void:
	if g * 8 + 7 >= _font.size():
		return
	for y in 8:
		var bits := _font[g * 8 + y]
		for x in 8:
			if bits >> (7 - x) & 1:
				var px := x0 + x
				var py := y0 + y
				if px >= 0 and py >= 0 and px < W and py < H:
					img.set_pixel(px, py, EGA[color])


## The combat screens draw the frame tiles over their grey: black is left out (lab, chat 11).
var transparent_tiles := false


func tile(col: int, row: int, index: int) -> void:
	if index >= _tiles.size():
		return
	if not transparent_tiles:
		img.blit_rect(_tiles[index], Rect2i(0, 0, 8, 8), Vector2i(col * 8, row * 8))
		return
	var t: Image = _tiles[index]
	for y in 8:
		for x in 8:
			var c := t.get_pixel(x, y)
			if c.r8 != 0 or c.g8 != 0 or c.b8 != 0:
				img.set_pixel(col * 8 + x, row * 8 + y, c)


## A menu line: each item's first letter white, the rest green; the highlighted item
## (`selected`, the one Enter picks) all white, as the original shows it.
func menu_line(row: int, items: Array, col: int = 0, selected: int = -1) -> void:
	var c := col
	var i := 0
	for it in items:
		var s := String(it)
		if s == "":
			continue
		text(c, row, s.substr(0, 1), WHITE)
		text(c + 1, row, s.substr(1), WHITE if i == selected else GREEN)
		c += s.length() + 1
		i += 1


## Word-wraps `s` to `width` characters a line.
static func wrap(s: String, width: int) -> PackedStringArray:
	var out := PackedStringArray()
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" "):
			while word.length() > width:
				if line != "":
					out.append(line)
					line = ""
				out.append(word.substr(0, width))
				word = word.substr(width)
			if line == "":
				line = word
				if word == "":
					continue
			elif line.length() + 1 + word.length() <= width:
				line += " " + word
			else:
				out.append(line)
				line = word
		out.append(line)
	return out


func frame_main(view_frame: bool = true, overland: bool = false) -> void:
	for c in 40:
		tile(c, 0, 22)
		tile(c, 16, 22)
		tile(c, 23, 22)
	for r in range(1, 23):
		tile(0, r, 21)
		tile(39, r, 21)
		if r < 16:
			tile(16, r, 21)
	for p in [Vector2i(0, 0), Vector2i(16, 0), Vector2i(39, 0), Vector2i(0, 16), Vector2i(16, 16),
			Vector2i(39, 16), Vector2i(0, 23), Vector2i(39, 23)]:
		tile(p.x, p.y, 20)
	if overland:
		tile(16, 16, 22)   # the wilderness screens have rope across under the view
	if not view_frame:
		return
	# The view's own frame.
	for c in range(2, 15):
		tile(c, 2, 22)
		tile(c, 14, 22)
	for r in range(3, 14):
		tile(2, r, 21)
		tile(14, r, 21)
	for p in [Vector2i(2, 2), Vector2i(14, 2), Vector2i(2, 14), Vector2i(14, 14)]:
		tile(p.x, p.y, 20)


## The walking screen. `view` is the 88x88 3D view (or event picture); `lines` the text
## box's lines (the last six show); `menu` the bottom line's items. `overland`: the
## wilderness screen; `wild`: its map view, 120x120 from (8, 8) with no frame of its own
## (an event picture there sits in the usual framed view).
func draw_walk(view: Image, party: Array, selected: int, place: String, lines: PackedStringArray,
		menu: Array, wild: bool = false, overland: bool = false, menu_selected: int = 0,
		white_line: int = -1) -> void:
	clear()
	frame_main(not wild, overland or wild)
	if wild and view != null:
		var w: Image = view.duplicate()
		w.convert(Image.FORMAT_RGBA8)
		img.blit_rect(w, Rect2i(0, 0, mini(w.get_width(), 120), mini(w.get_height(), 120)), Vector2i(8, 8))
	elif view != null:
		var v: Image = view.duplicate()
		v.convert(Image.FORMAT_RGBA8)
		if v.get_width() != 88 or v.get_height() != 88:
			v.resize(88, 88, Image.INTERPOLATE_NEAREST)
		img.blit_rect(v, Rect2i(0, 0, 88, 88), Vector2i(24, 24))
	party_list(party, selected)
	text(17, 15, place, GREEN)
	text_box(lines, GREEN, white_line)
	if not menu.is_empty():
		menu_line(24, menu, 0, menu_selected)
	update()


func party_list(party: Array, selected: int) -> void:
	text(17, 2, "NAME", WHITE)
	text(33, 2, "AC", WHITE)
	text(37, 2, "HP", WHITE)
	for i in mini(party.size(), 8):
		var m: PartyMember = party[i]
		# The selected member white; one who can't act (unconscious, dying, dead) light red.
		var down := m.status >= PartyMember.STATUS_UNCONSCIOUS or m.hp <= 0
		var color := WHITE if i == selected else (RED if down else CYAN)
		text(17, 4 + i, m.name.left(15), color)
		# AC light green; HP light green at full strength, yellow below (as the original).
		var ac := str(m.ac)
		text(35 - ac.length(), 4 + i, ac, GREEN)
		var hp := str(m.hp)
		text(39 - hp.length(), 4 + i, hp, GREEN if m.hp >= m.hp_max else YELLOW)


## The text area (rows 17-22). white_line: one line drawn white (a vertical menu's choice).
func text_box(lines: PackedStringArray, color: int = GREEN, white_line: int = -1) -> void:
	var start := maxi(lines.size() - 6, 0)
	for i in range(start, lines.size()):
		text(1, 17 + i - start, lines[i], WHITE if i == white_line else color)


func update() -> void:
	texture = ImageTexture.create_from_image(img)
