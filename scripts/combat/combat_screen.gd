class_name CombatScreen
extends Control
## The combat screen: a 7 x 7 window onto the battlefield (as the original shows it), the
## selected combatant's details on the right, and the command line below.
##
## C2 (battlefield) only: the field is built, both sides are placed and drawn, and the view
## can be moved around. Nobody acts yet; that is C3.
##   Arrows: move the view    Tab: next combatant (the view centres on them)
##   PgUp/PgDn: previous/next set battle of this area    +/-: monsters nearer/further
##   Esc: leave
## The monsters come from the area's own set battles (LOAD_MON ... COMBAT in its event
## script: monster, count, icon); an area without any falls back to each monster in turn.

signal closed

const VIEW_CELLS := 7
const CELL := 24
const SCALE := 3

## Party formation in straightened (u, v) cells, for facing north; rotated for other
## facings. Front line of three across the facing, the rest one line behind. Taken from
## the two Slums fights (facing west and south); still to be checked against more fights.
const PARTY_SLOTS := [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-2, 0), Vector2i(2, 0)]
## Where the party's front line centre sits, relative to the party square's origin (u, v).
const PARTY_ANCHOR_UV := Vector2i(4, 3)

var _field: Battlefield
var _art: CombatArt
var _party: Array[PartyMember] = []
var _monsters: Array[PartyMember] = []
var _combatants: Array = []      # [{who: PartyMember, team: 0 party / 1 monsters, cell: Vector2i, icon: Image}]
var _selected := 0
var _view := Vector2i.ZERO       # top-left cell of the 7x7 window
var _facing := 0
var _distance := 0
var _mon_file := 1
var _encounters: Array = []      # [{monsters: [[id, count, picture]], text}]
var _enc_index := 0
var _pictures: Array[int] = []   # icon id for each of _monsters
var _types: ItemTypes
var _game_path := ""

var _picture: TextureRect
var _info: Label
var _prompt: Label


## Starts a test battle at map square (px, py) facing `facing` (0..3 = N E S W) against
## the set battles in `script` (monsters from MON<mon_file>CHA).
func open_test(game_path: String, map: GeoMap, px: int, py: int, facing: int,
		party: Array[PartyMember], mon_file: int, script: EclScript) -> void:
	_game_path = game_path
	_field = Battlefield.build(map, px, py)
	_art = CombatArt.load_set(game_path)
	_party = party
	_facing = facing
	_mon_file = mon_file
	if _types == null:
		_types = ItemTypes.load_file(game_path)
	_encounters.clear()
	if script:
		for e in script.encounters():
			var rows := []
			for row in e.monsters:
				if row[0] >= 0:
					rows.append([row[0], maxi(row[1], 1), row[2] if row[2] >= 0 else row[0]])
			if not rows.is_empty():
				_encounters.append({"monsters": rows, "text": e.text})
	if _encounters.is_empty():
		var cha := DaxFile.open(game_path.path_join("MON%dCHA.DAX" % mon_file))
		var ids: Array = cha.ids() if cha else []
		ids.sort()
		for id in ids:
			_encounters.append({"monsters": [[id, 6, id]], "text": ""})
	_enc_index = 0
	_distance = 1
	if _picture == null:
		_build()
	_load_monsters()
	visible = true


func _build() -> void:
	ShopScreen._fill(self, 0)
	var bg := ColorRect.new()
	bg.color = Color8(85, 85, 85)
	ShopScreen._fill(bg, 0)
	add_child(bg)
	_picture = TextureRect.new()
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.position = Vector2(24, 24)
	_picture.size = Vector2(VIEW_CELLS * CELL * SCALE, VIEW_CELLS * CELL * SCALE)
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_picture)
	_info = Label.new()
	_info.position = Vector2(VIEW_CELLS * CELL * SCALE + 64, 24)
	_info.size = Vector2(600, 500)
	_info.add_theme_font_size_override("font_size", 24)
	_info.add_theme_color_override("font_color", Color8(85, 255, 85))
	add_child(_info)
	_prompt = Label.new()
	_prompt.position = Vector2(24, VIEW_CELLS * CELL * SCALE + 40)
	_prompt.size = Vector2(1200, 120)
	_prompt.add_theme_font_size_override("font_size", 18)
	add_child(_prompt)


func _load_monsters() -> void:
	_monsters.clear()
	_pictures.clear()
	if not _encounters.is_empty():
		for row in _encounters[_enc_index].monsters:
			var first := PartyMember.load_monster(_game_path, _mon_file, row[0])
			if first == null:
				continue
			first.recalculate(_types)
			for i in int(row[1]):
				if _monsters.size() >= 63:   # the original's limit
					break
				var m := first if i == 0 else first.clone()
				if i > 0:
					m.recalculate(_types)
				_monsters.append(m)
				_pictures.append(int(row[2]))
	_place()
	_selected = 0
	_centre_on_selected()
	_refresh()


# --- Placement --------------------------------------------------------------------------

## Rotates a north-facing slot to the party's facing (in u, v: north is -v, east is +u).
static func _rotate(p: Vector2i, facing: int) -> Vector2i:
	match facing:
		1: return Vector2i(-p.y, p.x)      # east
		2: return Vector2i(-p.x, -p.y)     # south
		3: return Vector2i(p.y, -p.x)      # west
	return p


func _place() -> void:
	_combatants.clear()
	var occupied := {}
	var o := Battlefield.square_origin(0, 0)
	var anchor := Battlefield.to_uv(o) + PARTY_ANCHOR_UV
	var forward := _rotate(Vector2i(0, -1), _facing)
	for i in _party.size():
		var slot: Vector2i = PARTY_SLOTS[i] if i < PARTY_SLOTS.size() else Vector2i(i - 5, 2)
		var cell := _free_cell(anchor + _rotate(slot, _facing), occupied)
		_combatants.append({"who": _party[i], "team": 0, "cell": cell, "icon": _art.character_icon(_party[i])})
	# Monsters: in front, `_distance` squares away (6 cells east-west, 5 north-south),
	# facing the party, in lines of three.
	var step := 6 if _facing % 2 == 1 else 5
	var front := anchor + forward * (1 + _distance * step)
	for i in _monsters.size():
		var across: int = [0, -1, 1][i % 3]
		var depth: int = i / 3
		var p := front + _rotate(Vector2i(across, -depth), _facing)
		var cell := _free_cell(p, occupied)
		var icon := _art.monster_icon(_mon_file, _pictures[i])
		_combatants.append({"who": _monsters[i], "team": 1, "cell": cell, "icon": icon})


## The nearest floor cell to `uv` that nobody stands on.
func _free_cell(uv: Vector2i, occupied: Dictionary) -> Vector2i:
	for r in 4:
		for du in range(-r, r + 1):
			for dv in range(-r, r + 1):
				if maxi(absi(du), absi(dv)) != r:
					continue
				var c := Battlefield.to_cell(uv.x + du, uv.y + dv)
				if _field.tile(c.x, c.y) == Battlefield.FLOOR and not occupied.has(c):
					occupied[c] = true
					return c
	var fallback := Battlefield.to_cell(uv.x, uv.y)
	occupied[fallback] = true
	return fallback


# --- Drawing ----------------------------------------------------------------------------

func _centre_on_selected() -> void:
	if _combatants.is_empty():
		return
	var c: Vector2i = _combatants[_selected].cell
	_view = c - Vector2i(3, 3)


func _refresh() -> void:
	var size := VIEW_CELLS * CELL
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color8(85, 85, 85))
	for r in VIEW_CELLS:
		for c in VIEW_CELLS:
			var t := _field.tile(_view.x + c, _view.y + r)
			var ti := _art.tile(t)
			if ti:
				img.blit_rect(ti, Rect2i(0, 0, CELL, CELL), Vector2i(c * CELL, r * CELL))
	# The art faces right; a side whose enemies stand to its left is drawn mirrored.
	var mean_x := [0.0, 0.0]
	var count := [0, 0]
	for e in _combatants:
		mean_x[e.team] += e.cell.x
		count[e.team] += 1
	for t in 2:
		if count[t] > 0:
			mean_x[t] /= count[t]
	for i in _combatants.size():
		var e: Dictionary = _combatants[i]
		var icon: Image = e.icon
		var at: Vector2i = (e.cell - _view) * CELL
		if i == _selected:
			var box := Rect2i(at, Vector2i(CELL, CELL))
			img.fill_rect(box, Color8(170, 170, 170))
		if icon:
			var src := icon
			var enemy_x: float = mean_x[1 - e.team]
			if count[1 - e.team] > 0 and enemy_x < e.cell.x:
				src = icon.duplicate() as Image
				src.flip_x()
			img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)
	_picture.texture = ImageTexture.create_from_image(img)
	if _combatants.is_empty():
		_info.text = ""
	else:
		var m: PartyMember = _combatants[_selected].who
		var weapon := m.weapon.name if m.weapon else ""
		_info.text = "%s\n\nHITPOINTS %d\n\nAC %d\n\n%s" % [m.name, m.hp, m.ac, weapon]
	var summary := PackedStringArray()
	var text := ""
	if not _encounters.is_empty():
		var e: Dictionary = _encounters[_enc_index]
		text = e.text
		for row in e.monsters:
			var n := "?"
			for i in _monsters.size():
				if _pictures[i] == row[2]:
					n = _monsters[i].name
					break
			summary.append("%s x%d" % [n, row[1]])
	_prompt.text = ("Battle %d of %d: %s   (%d square(s) away)\n%s\n"
		+ "Arrows: move view   Tab: next combatant   PgUp/PgDn: battle   +/-: distance   Esc: leave") % [
		_enc_index + 1, _encounters.size(), ", ".join(summary), _distance, text]


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
	if event.is_action("ui_cancel"):
		visible = false
		closed.emit()
	elif event.is_action("ui_left"):
		_view.x -= 1
	elif event.is_action("ui_right"):
		_view.x += 1
	elif event.is_action("ui_up"):
		_view.y -= 1
	elif event.is_action("ui_down"):
		_view.y += 1
	elif key == KEY_TAB:
		if not _combatants.is_empty():
			_selected = (_selected + 1) % _combatants.size()
			_centre_on_selected()
	elif key == KEY_PAGEDOWN or key == KEY_PAGEUP:
		if not _encounters.is_empty():
			var step := 1 if key == KEY_PAGEDOWN else -1
			_enc_index = (_enc_index + step + _encounters.size()) % _encounters.size()
			_load_monsters()
	elif key == KEY_EQUAL or key == KEY_KP_ADD:
		_distance = mini(_distance + 1, 2)
		_load_monsters()
	elif key == KEY_MINUS or key == KEY_KP_SUBTRACT:
		_distance = maxi(_distance - 1, 0)
		_load_monsters()
	else:
		return
	get_viewport().set_input_as_handled()
	_refresh()
