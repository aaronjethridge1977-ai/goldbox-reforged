class_name CombatScreen
extends Control
## The combat screen: a 7 x 7 window onto the battlefield (as the original shows it), the
## selected combatant's details on the right, and the command line below.
##
## Setting up (test battles):
##   Arrows: move the view    Tab: next combatant (the view centres on them)
##   PgUp/PgDn: previous/next set battle of this area    +/-: monsters nearer/further
##   F: fight    Esc: leave
## Fighting (rules in Combat; the party here is a copy, so test fights hurt nobody):
##   Arrows, Home/PgUp/End/PgDn (or the keypad): step, or attack the enemy in that direction
##   Space: done    Q: let the computer fight for this character    Esc: leave
## The monsters come from the area's own set battles (LOAD_MON ... COMBAT in its event
## script: monster, count, icon); an area without any falls back to each monster in turn.

signal closed
## After a real (event) fight: 1 = the party won, 2 = the party fell.
signal finished(result: int)

const VIEW_CELLS := 7
const CELL := 24
const SCALE := 3

var _field: Battlefield
var _art: CombatArt
var _party: Array[PartyMember] = []
var _monsters: Array[PartyMember] = []
var _combatants: Array = []      # [{who: PartyMember, team: 0 party / 1 monsters, cell: Vector2i, icon: Image}]
var _selected := 0
var _view := Vector2i.ZERO       # top-left cell of the 7x7 window
var _facing := 0
var _px := 0
var _py := 0
var _distance := 0
var _mon_file := 1
var _encounters: Array = []      # [{monsters: [[id, count, picture]], text}]
var _enc_index := 0
var _pictures: Array[int] = []   # icon id for each of _monsters
var _types: ItemTypes
var _game_path := ""

var _combat: Combat = null
var _messages := PackedStringArray()
var _ai_timer: Timer
var _result := 0
var _event_fight := false

var _picture: TextureRect
var _info: Label
var _prompt: Label


## Starts a test battle at map square (px, py) facing `facing` (0..3 = N E S W) against
## the set battles in `script` (monsters from MON<mon_file>CHA).
func open_test(game_path: String, map: GeoMap, px: int, py: int, facing: int,
		party: Array[PartyMember], mon_file: int, script: EclScript) -> void:
	_game_path = game_path
	_field = Battlefield.build(map, px, py)
	_px = px
	_py = py
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
	_distance = Placement.encounter_distance(_field, px, py, facing)
	_combat = null
	_result = 0
	_event_fight = false
	_messages.clear()
	if _picture == null:
		_build()
	_load_monsters()
	visible = true


## A fight started by an event script: the real party against `rows` ([[id, count,
## picture], ...]) from MON<mon_file>, `max_distance` and `advances` from the script's
## SPRITE_START / SPRITE_ADVANCE. Emits `finished` when it is over.
func open_event(game_path: String, map: GeoMap, px: int, py: int, facing: int,
		party: Array[PartyMember], mon_file: int, rows: Array, max_distance: int, advances: int) -> void:
	open_test(game_path, map, px, py, facing, party, mon_file, null)
	_event_fight = true
	_encounters = [{"monsters": rows, "text": ""}]
	_enc_index = 0
	var open_ahead := Placement.encounter_distance(_field, px, py, facing, 2)
	_distance = maxi(mini(open_ahead, max_distance) - advances, 0)
	_load_monsters()
	_start_fight(0, false)
	_advance()


## Testing aid: a battle with given monsters ([[id, count, picture], ...]) and distance;
## writes the whole battlefield with everyone on it to `image_path` and prints each
## combatant's cell. Used by the lab to compare with the original.
func run_check(game_path: String, map: GeoMap, px: int, py: int, facing: int,
		party: Array[PartyMember], mon_file: int, rows: Array, distance: int, image_path: String) -> void:
	open_test(game_path, map, px, py, facing, party, mon_file, null)
	_encounters = [{"monsters": rows, "text": ""}]
	_enc_index = 0
	_load_monsters()
	if distance >= 0:
		_distance = distance
		_load_monsters()
	for e in _combatants:
		print("%s %s %d %d" % ["party" if e.team == 0 else "monster", e.who.name, e.cell.x, e.cell.y])
	if image_path != "":
		var full := Image.create_empty(Battlefield.WIDTH * CELL, Battlefield.HEIGHT * CELL, false, Image.FORMAT_RGBA8)
		full.fill(Color8(85, 85, 85))
		for y in Battlefield.HEIGHT:
			for x in Battlefield.WIDTH:
				var ti := _art.tile(_field.tile(x, y))
				if ti:
					full.blit_rect(ti, Rect2i(0, 0, CELL, CELL), Vector2i(x * CELL, y * CELL))
		for e in _combatants:
			var icon: Image = e.icon
			if icon:
				var src := icon
				if Placement.DX[e.dir] < 0:
					src = icon.duplicate() as Image
					src.flip_x()
				full.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), e.cell * CELL)
		full.save_png(image_path)


## Testing aid: fights the check battle to the end with the computer on both sides and the
## given dice seed, printing every roll and message (for the lab).
func run_fight(seed_value: int) -> void:
	_start_fight(seed_value)
	for c in _combat.combatants:
		c.quick = true
	var guard := 0
	while _combat.next_turn() >= 0 and guard < 5000:
		guard += 1
		while _combat.ai_act():
			guard += 1
	for line in _combat.roll_log:
		print("roll ", line)
	print("result ", ["", "party won", "party lost"][_combat.outcome()], " after ", _combat.round_no, " rounds")


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
	_ai_timer = Timer.new()
	_ai_timer.one_shot = true
	_ai_timer.timeout.connect(_ai_step)
	add_child(_ai_timer)
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

## Both sides placed by the original's rule (see Placement): the party around its own
## square, the monsters around the square `_distance` squares ahead, facing the party.
func _place() -> void:
	_combatants.clear()
	var placer := Placement.new(_field, _px, _py)
	var party_cells := placer.place_team(_party.size(), _facing, Vector2i.ZERO, true)
	var party_dir: int = Placement.FACING_TO_DIR[_facing]
	for i in _party.size():
		if party_cells[i].x < 0:
			continue
		_combatants.append({"who": _party[i], "team": 0, "cell": party_cells[i],
			"icon": _art.character_icon(_party[i]), "dir": party_dir})
	var ahead: Vector2i = Placement.SQUARE_STEP[_facing] * _distance
	var mon_cells := placer.place_team(_monsters.size(), (_facing + 2) % 4, ahead, false)
	for i in _monsters.size():
		if mon_cells[i].x < 0:
			continue
		_combatants.append({"who": _monsters[i], "team": 1, "cell": mon_cells[i],
			"icon": _art.monster_icon(_mon_file, _pictures[i]), "dir": (party_dir + 4) % 8})


# --- Fighting ---------------------------------------------------------------------------

func _start_fight(seed_value: int = 0, copy_party: bool = true) -> void:
	if copy_party:
		# Test fights use copies of the party, so nobody gets hurt for real.
		var copies: Array[PartyMember] = []
		for m in _party:
			var c := m.clone()
			c.recalculate(_types)
			copies.append(c)
		_party = copies
	# Characters who are down don't take part.
	var standing: Array[PartyMember] = []
	for m in _party:
		if m.hp > 0:
			standing.append(m)
	_party = standing
	_place()
	_combat = Combat.new(_field, _combatants, seed_value)
	_combat.message.connect(_on_message)
	_messages.clear()
	_result = 0


func _on_message(text: String) -> void:
	_messages.append(text)
	if _messages.size() > 6:
		_messages = _messages.slice(_messages.size() - 6)
	print(text)


## Moves on to whoever acts next; computer-controlled turns play out on a timer.
func _advance() -> void:
	var i := _combat.next_turn()
	if i < 0:
		_result = _combat.outcome()
		_on_message("THE PARTY WINS." if _result == 1 else "THE PARTY HAS FALLEN.")
		_refresh()
		return
	_selected = i
	_centre_on_selected()
	_refresh()
	if _combatants[i].quick:
		_ai_timer.start(0.35)


func _ai_step() -> void:
	if _combat == null or not visible:
		return
	var more := _combat.ai_act()
	_centre_on_selected()
	_refresh()
	if more:
		_ai_timer.start(0.3)
	else:
		await get_tree().create_timer(0.2).timeout
		if _combat != null:
			_advance()


func _after_player_action(what: String) -> void:
	if what == "blocked":
		_on_message("CAN'T GO THERE")
	elif what == "no moves":
		_on_message("NO MOVES LEFT")
	var c: Dictionary = _combatants[_selected]
	if _combat.outcome() != 0 or (c.moves <= 0 and c.attacks <= 0) or (what == "attacked" and c.attacks <= 0):
		_advance()
	else:
		_centre_on_selected()
		_refresh()


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
	# The art faces right; combatants facing a westward direction are drawn mirrored.
	for i in _combatants.size():
		var e: Dictionary = _combatants[i]
		if e.get("down", false):
			continue
		var icon: Image = e.icon
		var at: Vector2i = (e.cell - _view) * CELL
		if i == _selected:
			var box := Rect2i(at, Vector2i(CELL, CELL))
			img.fill_rect(box, Color8(170, 170, 170))
		if icon:
			var src := icon
			if Placement.DX[e.dir] < 0:
				src = icon.duplicate() as Image
				src.flip_x()
			img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)
	_picture.texture = ImageTexture.create_from_image(img)
	if _combatants.is_empty():
		_info.text = ""
	else:
		var e: Dictionary = _combatants[_selected]
		var m: PartyMember = e.who
		var weapon := m.weapon.name if m.weapon else ""
		_info.text = "%s\n\nHITPOINTS %d\n\nAC %d\n\n%s" % [m.name, m.hp, m.ac, weapon]
		if _combat != null:
			_info.text += "\n\nMOVES %d  ATTACKS %d\n\n%s" % [e.moves / 2, e.attacks, "\n".join(_messages)]
	if _combat != null:
		if _result != 0:
			_prompt.text = ("THE PARTY WINS." if _result == 1 else "THE PARTY HAS FALLEN.") + "   Esc or Enter: leave"
		else:
			_prompt.text = ("ROUND %d   Arrows / Home PgUp End PgDn: move or attack   Space: done   "
				+ "Q: quick (computer fights)   Esc: leave") % _combat.round_no
		return
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
		+ "Arrows: move view   Tab: next combatant   PgUp/PgDn: battle   +/-: distance   F: fight   Esc: leave") % [
		_enc_index + 1, _encounters.size(), ", ".join(summary), _distance, text]


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
	if _event_fight and _result == 0 and _combat != null:
		_fight_input(event, key)
		return
	if event.is_action("ui_cancel") or (_result != 0 and event.is_action("ui_accept")):
		_ai_timer.stop()
		var was_event := _event_fight
		var result := _result
		_combat = null
		_event_fight = false
		visible = false
		if was_event:
			finished.emit(result)
		else:
			closed.emit()
	elif _combat != null:
		_fight_input(event, key)
		return
	elif key == KEY_F:
		_start_fight()
		_advance()
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


const _STEP_KEYS := {KEY_UP: 0, KEY_KP_8: 0, KEY_PAGEUP: 1, KEY_KP_9: 1, KEY_RIGHT: 2, KEY_KP_6: 2,
	KEY_PAGEDOWN: 3, KEY_KP_3: 3, KEY_DOWN: 4, KEY_KP_2: 4, KEY_END: 5, KEY_KP_1: 5,
	KEY_LEFT: 6, KEY_KP_4: 6, KEY_HOME: 7, KEY_KP_7: 7}


func _fight_input(event: InputEvent, key: Key) -> void:
	get_viewport().set_input_as_handled()
	if _result != 0 or _combat.active < 0 or _combatants[_combat.active].quick:
		return
	if _STEP_KEYS.has(key):
		_after_player_action(_combat.step(_STEP_KEYS[key]))
	elif key == KEY_SPACE or key == KEY_D:
		_combat.done()
		_advance()
	elif key == KEY_Q:
		_combatants[_combat.active].quick = true
		_ai_timer.start(0.2)
