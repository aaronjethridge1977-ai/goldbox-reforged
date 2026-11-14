class_name IconEditor
extends Control
## The combat icon editor (camp ALTER → ICON, and the last step of character creation), as
## the original shows it: a grey page with the OLD and NEW icons in their READY and ACTION
## poses, and the menu
##   PARTS COLOR-1 COLOR-2 SIZE EXIT
##   PARTS → HEAD WEAPON EXIT → NEXT PREV KEEP EXIT     (record 0xBD head, 0xBE body/weapon:
##                                                       the CHEAD / CBODY pictures)
##   COLOR-1 (key 1), COLOR-2 (key 2) → WEAPON BODY HAIR SHIELD ARM LEG EXIT
##                                    → NEXT PREV KEEP EXIT  (COLOR-1 steps the low nibble,
##                                       COLOR-2 the high one; lab: NEXT goes 7, 8, 9...).
##     The parts' record bytes (lab, 2026-11-13: each part stepped a different number of
##     times in the original, then the saved records compared): WEAPON 0xC6, BODY 0xC1,
##     HAIR 0xC4, SHIELD 0xC5, ARM 0xC2, LEG 0xC3.
##   SIZE: small (record 0xC0 = 1) or normal (2)
##   EXIT → IS THIS ICON OK? YES NO  (No goes back to the editor)
## KEEP keeps a change, EXIT drops it; both go back to the list the part was picked from
## (lab, 2026-11-13: the colour parts, or HEAD WEAPON).

signal finished(changed: bool)

var _screen: GameScreen
var _art: CombatArt
var _member: PartyMember
var _old := PackedByteArray()
var _new := PackedByteArray()
var _trial := PackedByteArray()      # the change being tried (NEXT/PREV) before KEEP
var _stage := "main"
var _field := 0                       # record offset being changed
var _nibble := 0                      # 0 low (COLOR-1), 4 high (COLOR-2)
var _back := "main"                   # the list NEXT PREV KEEP EXIT returns to
const PARTS := ["WEAPON", "BODY", "HAIR", "SHIELD", "ARM", "LEG"]
const PART_FIELDS := [0xC6, 0xC1, 0xC4, 0xC5, 0xC2, 0xC3]   # record byte of each part, in menu order


func open(game_path: String, m: PartyMember) -> void:
	_member = m
	_art = CombatArt.load_set(game_path)
	_old = m.raw.duplicate()
	_new = m.raw.duplicate()
	_trial = PackedByteArray()
	ShopScreen._fill(self, 0)
	if _screen == null:
		var bg := ColorRect.new()
		bg.color = Color.BLACK
		ShopScreen._fill(bg, 0)
		add_child(bg)
		_screen = GameScreen.new()
		ShopScreen._fill(_screen, 0)
		add_child(_screen)
	_stage = "main"
	visible = true
	_draw()


func _icon_box(x: int, y: int, d: PackedByteArray, attack: bool) -> void:
	var g := _screen
	g.img.fill_rect(Rect2i(x, y, 24, 24), GameScreen.EGA[7])
	g.img.fill_rect(Rect2i(x, y, 24, 1), GameScreen.EGA[15])
	g.img.fill_rect(Rect2i(x, y, 1, 24), GameScreen.EGA[15])
	g.img.fill_rect(Rect2i(x + 23, y, 1, 24), GameScreen.EGA[0])
	g.img.fill_rect(Rect2i(x, y + 23, 24, 1), GameScreen.EGA[0])
	var icon := _art.record_icon(d, attack)
	if icon != null:
		g.img.blend_rect(icon, Rect2i(0, 0, mini(icon.get_width(), 24), mini(icon.get_height(), 24)), Vector2i(x, y))


func _draw() -> void:
	var g := _screen
	g.img.fill(GameScreen.EGA[8])
	for c in 40:
		g.tile(c, 0, 22)
		g.tile(c, 23, 22)
	for r in range(1, 23):
		g.tile(0, r, 21)
		g.tile(39, r, 21)
	for p in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 23), Vector2i(39, 23)]:
		g.tile(p.x, p.y, 20)
	var shown := _trial if not _trial.is_empty() else _new
	g.text(8, 6, "OLD", GameScreen.WHITE)
	_icon_box(32, 56, _old, false)
	_icon_box(104, 56, _old, true)
	g.text(3, 10, "READY", GameScreen.WHITE)
	g.text(11, 10, "ACTION", GameScreen.WHITE)
	g.text(8, 12, "NEW", GameScreen.WHITE)
	_icon_box(32, 104, shown, false)
	_icon_box(104, 104, shown, true)
	g.text(3, 16, "READY", GameScreen.WHITE)
	g.text(11, 16, "ACTION", GameScreen.WHITE)
	match _stage:
		"main":
			g.menu_line(24, ["PARTS", "COLOR-1", "COLOR-2", "SIZE", "EXIT"])
		"parts":
			g.menu_line(24, ["HEAD", "WEAPON", "EXIT"])
		"colour":
			g.menu_line(24, PARTS + ["EXIT"])
		"step":
			g.menu_line(24, ["NEXT", "PREV", "KEEP", "EXIT"])
		"ok":
			g.text(0, 24, "IS THIS ICON OK?", 13)
			g.menu_line(24, ["YES", "NO"], 17)
	g.update()


func _step(d: int) -> void:
	if _trial.is_empty():
		_trial = _new.duplicate()
	if _field == 0xBD or _field == 0xBE:
		var ids := _art.part_ids("CHEAD.DAX" if _field == 0xBD else "CBODY.DAX")
		if ids.is_empty():
			return
		var at := maxi(ids.find(_trial[_field]), 0)
		_trial[_field] = ids[posmod(at + d, ids.size())]
	else:
		var v := _trial[_field]
		var n := posmod(((v >> _nibble) & 15) + d, 16)
		_trial[_field] = (v & ~(15 << _nibble) & 0xFF) | (n << _nibble)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	var k := (event as InputEventKey).keycode
	match _stage:
		"main":
			match k:
				KEY_P: _stage = "parts"
				KEY_1: _stage = "colour"; _nibble = 0
				KEY_2: _stage = "colour"; _nibble = 4
				KEY_S: _new[0xC0] = 1 if _new[0xC0] == 2 else 2
				KEY_E, KEY_ESCAPE: _stage = "ok"
		"parts":
			match k:
				KEY_H: _field = 0xBD; _stage = "step"; _back = "parts"
				KEY_W: _field = 0xBE; _stage = "step"; _back = "parts"
				KEY_E, KEY_ESCAPE: _stage = "main"
		"colour":
			var i := ["W", "B", "H", "S", "A", "L"].find(OS.get_keycode_string(k))
			if i >= 0:
				_field = PART_FIELDS[i]
				_stage = "step"
				_back = "colour"
			elif k == KEY_E or k == KEY_ESCAPE:
				_stage = "main"
		"step":
			match k:
				KEY_N: _step(1)
				KEY_P: _step(-1)
				KEY_K:
					if not _trial.is_empty():
						_new = _trial
					_trial = PackedByteArray()
					_stage = _back
				KEY_E, KEY_ESCAPE:
					_trial = PackedByteArray()
					_stage = _back
		"ok":
			if k == KEY_Y:
				var changed := _new != _old
				for off in [0xBD, 0xBE, 0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6]:
					_member.raw[off] = _new[off]
				visible = false
				finished.emit(changed)
				return
			elif k == KEY_N:
				_stage = "main"
	_draw()
