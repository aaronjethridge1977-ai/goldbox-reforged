class_name CharacterCreator
extends Control
## CREATE NEW CHARACTER, as the original plays it (see CreationRules for the rules):
##   race, sex, class, alignment: framed lists from row 2, column 3 (the current line white,
##     the rest green), " EXIT" on row 24; Up/Down and Enter, Esc to go back;
##   the rolled character on the view page with its portrait, "KEEP THIS CHARACTER? YES NO"
##     (No rolls again);
##   "CHARACTER NAME:" (up to 15 letters), then the portrait: HEAD BODY KEEP.
##   then the combat icon (IconEditor).

signal created(member: PartyMember)
signal cancelled

var game_path := ""
var tables: ClassTables
var spells: SpellTable
var types: ItemTypes

var _rules: CreationRules
var _screen: GameScreen
var _rng := RandomNumberGenerator.new()
var _stage := "race"
var _items: Array = []        # [label, value] of the list on screen
var _sel := 0
var _race := 0
var _sex := 0
var _class := 0
var _record := PackedByteArray()
var _member: PartyMember
var _name := ""
var _head := 0
var _body := 0
static var _pictures := {}    # "path:HEAD:id" -> Image
var _icons: IconEditor


func open(path: String) -> void:
	game_path = path
	_rules = CreationRules.shared(path)
	_rng.randomize()
	ShopScreen._fill(self, 0)
	if _screen == null:
		var bg := ColorRect.new()
		bg.color = Color.BLACK
		ShopScreen._fill(bg, 0)
		add_child(bg)
		_screen = GameScreen.new()
		ShopScreen._fill(_screen, 0)
		add_child(_screen)
	visible = true
	_show_list("race")


func _show_list(stage: String) -> void:
	_stage = stage
	_items = []
	match stage:
		"race":
			for r in CreationRules.RACE_CHOICES:
				_items.append([_rules.race_name(r), r])
		"sex":
			_items = [["MALE", 0], ["FEMALE", 1]]
		"class":
			for c in _rules.classes_for(_race):
				_items.append([_rules.class_name_of(c), c])
		"align":
			for a in _rules.alignments_for(_class):
				_items.append([PartyMember.ALIGNMENTS[a], a])
	_sel = 0
	_draw()


func _choose(value: int) -> void:
	match _stage:
		"race":
			_race = value
			_show_list("sex")
		"sex":
			_sex = value
			_show_list("class")
		"class":
			_class = value
			_show_list("align")
		"align":
			_record = _rules.start_record(_race, _sex, _class, value, _rng)
			_reroll()


func _reroll() -> void:
	_rules.roll(_record, _rng)
	_member = _rules.member(_record, tables, spells, types)
	_stage = "keep"
	_draw()


func _back() -> void:
	match _stage:
		"race":
			visible = false
			cancelled.emit()
		"sex":
			_show_list("race")
		"class":
			_show_list("sex")
		"align":
			_show_list("class")


func _finish() -> void:
	var d := _member.to_record()
	d[0] = _name.length()
	for i in 15:
		d[1 + i] = _name.unicode_at(i) if i < _name.length() else 0
	d[0xBB] = _head + 1
	d[0xBC] = _body + 1
	var m := _rules.member(d, tables, spells, types)
	# Last, as in the original: the combat icon.
	if _icons == null:
		_icons = IconEditor.new()
		add_child(_icons)
	_icons.open(game_path, m)
	await _icons.finished
	m.recalculate(types)
	visible = false
	created.emit(m)


# ---------------------------------------------------------------- drawing

func _frame(g: GameScreen) -> void:
	for c in 40:
		g.tile(c, 0, 22)
		g.tile(c, 23, 22)
	for r in range(1, 23):
		g.tile(0, r, 21)
		g.tile(39, r, 21)
	for p in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 23), Vector2i(39, 23)]:
		g.tile(p.x, p.y, 20)


func _draw() -> void:
	var g := _screen
	g.clear()
	if _stage in ["race", "sex", "class", "align"]:
		_frame(g)
		for i in _items.size():
			g.text(3, 2 + i, String(_items[i][0]), GameScreen.WHITE if i == _sel else GameScreen.GREEN)
		g.text(1, 24, "EXIT", GameScreen.WHITE)
		g.update()
		return
	draw_sheet(g, _member, _portrait())
	match _stage:
		"keep":
			g.text(0, 24, "KEEP THIS CHARACTER?", MAGENTA)
			g.menu_line(24, ["YES", "NO"], 21)
		"name":
			g.text(0, 24, "CHARACTER NAME:", MAGENTA)
			g.text(16, 24, _name, GameScreen.WHITE)
		"portrait":
			# The original shows this menu with the colours turned round: hot letters green.
			var c := 0
			for w in ["HEAD", "BODY", "KEEP"]:
				g.text(c, 24, w.substr(0, 1), GameScreen.GREEN)
				g.text(c + 1, 24, w.substr(1), GameScreen.WHITE)
				c += w.length() + 1
	g.update()


const MAGENTA := 13


static func _picture(game_path: String, prefix: String, id: int) -> Image:
	var key := "%s:%s:%d" % [game_path, prefix, id]
	if _pictures.has(key):
		return _pictures[key]
	var img: Image = null
	for n in range(1, 9):
		var dax := DaxFile.open(game_path.path_join("%s%d.DAX" % [prefix, n]))
		if dax != null and dax.blocks.has(id):
			var pic := EgaPicture.decode_any(dax.blocks[id])
			if pic != null and not pic.frames.is_empty():
				img = pic.frames[0].duplicate()
				img.convert(Image.FORMAT_RGBA8)
				break
	_pictures[key] = img
	return img


func _portrait() -> Image:
	return portrait_for(game_path, _head, _body)


## A character's portrait: head choice (record 0xBB, 1-based) over body choice (0xBC).
static func portrait_for(game_path: String, head: int, body: int) -> Image:
	var rules := CreationRules.shared(game_path)
	var img := Image.create(88, 88, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	var h := _picture(game_path, "HEAD", rules.head_id(head))
	var b := _picture(game_path, "BODY", rules.body_id(body))
	if h != null:
		img.blit_rect(h, Rect2i(Vector2i.ZERO, h.get_size()), Vector2i(0, 0))
	if b != null:
		img.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(0, 40))
	return img


## The original's character page (as creation shows it): the frame with the portrait's
## own frame at the top right (columns 27-39, rows 0-12), labels white, values green.
static func draw_sheet(g: GameScreen, m: PartyMember, portrait: Image, highlight: int = -1) -> void:
	for c in 40:
		g.tile(c, 0, 22)
		g.tile(c, 23, 22)
	for c in range(27, 40):
		g.tile(c, 12, 22)
	for r in range(1, 23):
		g.tile(0, r, 21)
		g.tile(39, r, 21)
		if r < 12:
			g.tile(27, r, 21)
	for p in [Vector2i(0, 0), Vector2i(27, 0), Vector2i(39, 0), Vector2i(27, 12), Vector2i(39, 12),
			Vector2i(0, 23), Vector2i(39, 23)]:
		g.tile(p.x, p.y, 20)
	if portrait != null:
		g.img.blit_rect(portrait, Rect2i(0, 0, 88, 88), Vector2i(224, 8))
	var W := GameScreen.WHITE
	var G := GameScreen.GREEN
	if m.name != "":
		g.text(1, 1, m.name, GameScreen.CYAN)
	g.text(1, 3, "%s %s AGE %d" % [m.gender, m.race, m.age], W)
	g.text(1, 4, m.alignment, W)
	g.text(1, 5, m.char_class.replace("MAGE", "MAGIC-USER"), W)
	var names := ["STR", "INT", "WIS", "DEX", "CON", "CHA"]
	for i in 6:
		var v := str(m.stats[i])
		if i == 0 and m.stats[0] == 18 and m.strength_exceptional > 0:
			v += "(%02d)" % (m.strength_exceptional % 100)
		g.text(1, 7 + i, names[i], G)
		g.text(5, 7 + i, v, MAGENTA if highlight == i else G)
	g.text(16, 7, "GOLD %d" % m.money[3], G)
	var levels := PackedStringArray()
	for c in m.class_indices():
		levels.append(str(m.level_in(c)))
	g.text(1, 15, "LEVEL", W)
	g.text(7, 15, "/".join(levels), W)
	g.text(17, 15, "EXP", W)
	g.text(21, 15, str(m.experience), W)
	g.text(1, 17, "AC", W)
	g.text(4, 17, str(m.ac), G)
	g.text(9, 17, "THAC0", W)
	g.text(15, 17, str(m.thac0), G)
	g.text(22, 17, "ENCUMBRANCE", W)
	g.text(34, 17, str(m.encumbrance()), G)
	g.text(1, 18, "HP", W)
	g.text(4, 18, str(m.hp), MAGENTA if highlight == 6 else G)
	g.text(8, 18, "DAMAGE", W)
	g.text(15, 18, PartyMember.dice_text(m.damage), G)
	g.text(25, 18, "MOVEMENT", W)
	g.text(34, 18, str(m.movement), G)
	g.text(1, 22, "STATUS", W)
	g.text(8, 22, m.status_name(), G)


# ---------------------------------------------------------------- keys

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.is_pressed() or (_icons != null and _icons.visible):
		return
	get_viewport().set_input_as_handled()
	var k := (event as InputEventKey).keycode
	match _stage:
		"race", "sex", "class", "align":
			if k == KEY_UP:
				_sel = (_sel + _items.size() - 1) % _items.size()
			elif k == KEY_DOWN:
				_sel = (_sel + 1) % _items.size()
			elif k == KEY_ENTER or k == KEY_KP_ENTER:
				_choose(int(_items[_sel][1]))
				return
			elif k == KEY_ESCAPE or k == KEY_E:
				_back()
				return
		"keep":
			if k == KEY_Y:
				_stage = "name"
				_name = ""
			elif k == KEY_N:
				_reroll()
				return
		"name":
			if (k == KEY_ENTER or k == KEY_KP_ENTER) and _name.strip_edges() != "":
				_name = _name.strip_edges()
				_stage = "portrait"
			elif k == KEY_BACKSPACE:
				_name = _name.left(_name.length() - 1)
			elif _name.length() < 15:
				var u := (event as InputEventKey).unicode
				if u == 0:
					var ks := OS.get_keycode_string(k)
					u = ks.unicode_at(0) if ks.length() == 1 else (0x20 if k == KEY_SPACE else 0)
				if u >= 0x20 and u < 0x7F:
					_name += char(u).to_upper()
		"portrait":
			if k == KEY_H:
				_head = (_head + 1) % CreationRules.HEADS
			elif k == KEY_B:
				_body = (_body + 1) % CreationRules.BODIES
			elif k == KEY_K or k == KEY_ENTER:
				_finish()
				return
	_draw()
