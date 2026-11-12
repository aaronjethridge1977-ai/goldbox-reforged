extends Control
## M1/M2 data browser.
##   Tab          : pictures -> maps -> walk -> pictures
##   Pictures     : Left/Right picture, Up/Down file
##   Maps         : Left/Right map, Enter to walk the map
##   Walk         : Up forward, Down back, Left/Right turn,
##                  O slot outlines, C capture (PNG + slot report to captures/), G go to "x y dir",
##                  E encamp (rest), F4 write the area's event script listing to captures/, N day/night,
##                  1-9 choose a menu item, Enter continue,
##                  V party character sheets, M monster sheets (every MONnCHA block),
##                  B test battle here (battlefield and placement; the area's set battles, PgUp/PgDn)
## Starts on the title screen.

enum Mode { PICTURES, MAPS, WALK }

@onready var _picture: TextureRect = $Picture
@onready var _map_view: MapView = $MapView
@onready var _status: Label = $Status

var _game_path := ""
var _mode := Mode.PICTURES
var _pictures: Array = []   # [{file, id, pic}]
var _maps: Array = []       # [{file, id, map}]
var _area_text := {}        # block id -> first event text in that area's ECL block
var _pic_index := 0
var _map_index := 0

# Walk mode state
var _dungeon := DungeonView.new()
var _walls: WallSet
var _walls_for := -1        # map index the wall set was built for
var _pos := Vector2i(8, 8)
var _facing := DungeonView.Dir.NORTH
var _goto: LineEdit
var _typed: LineEdit         # INPUT_STRING / INPUT_NUMBER: what the player types
var _deco := []             # current area's wall set ids, from its event script

# Event scripts
var _vm := EclVM.new()      # one VM for the session, so game flags persist between areas
var _vm_map := -1           # map index whose script is loaded
var _vm_file := 0           # ECL file number of the loaded script
var _vm_block := -1         # ECL block id of the loaded script
var _pending_move := -1     # direction of a move waiting on an on-move menu
var _event_image: Image     # picture shown in the view by an event (null = 3D view)
var _message: Label
var _dax_cache := {}

# Timed playback: script DELAYs and script-driven walks
const DELAY_SECONDS := 0.45
const WALK_STEP_SECONDS := 0.22
var _timer: Timer
var _busy := false                  # a delay or walk is playing; input waits
var _walk_path: Array[Vector2i] = []
var _walk_final_dir := 0
var _held_message := ""
var _sprite_cache := {}             # "file:id" -> frames
var _jump_next := false             # the next script move is a placement, not a walk

# The party (the game's saved party A, CHRDATA1-6) and the shop overlay
var _party: Array[PartyMember] = []
var _shop: ShopScreen
var _sheet: CharacterSheet
var _treasure: TreasureScreen
var _camp: CampScreen
var _temple: TempleScreen
var _party_menu: PartyMenu
const SEARCH_FLAG := 0x6DCA       # 1 while searching (SEARCH, LOOK); the scripts test it
var _searching := false
var _door_options := ""            # the LOCKED. menu while it is open ("BPKE" letters offered)
var _door_side := -1
var _door_rng := RandomNumberGenerator.new()
const REST_PERIOD := 0x6DD2       # set by the area's "on rest" script: steps between checks
const REST_PERCENT := 0x6DD3      # ... and the chance (d100) that rest is interrupted
var _fight_treasure := []        # the event's TREASURE operands, kept for after the fight
var _combat: CombatScreen
var _types: ItemTypes

# The original's adventure screen (F12 switches to the developer view and back).
var _screen: GameScreen
var _dev_view := false
var _view_img: Image
var _area_view := false            # AREA: the overhead map in the view window
var _automap: Automap               # QoL: mini-map (M) and full map (F) of visited squares


func _ready() -> void:
	_goto = LineEdit.new()
	_goto.placeholder_text = "x y facing (e.g. 12 6 S), Enter to go, Esc to cancel"
	_goto.visible = false
	_goto.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_goto.offset_left = -210
	_goto.offset_right = 210
	_goto.offset_top = 8
	_goto.text_submitted.connect(_on_goto)
	_goto.focus_exited.connect(_on_goto_closed)
	_goto.gui_input.connect(_on_goto_input)
	add_child(_goto)
	_typed = LineEdit.new()
	_typed.visible = false
	_typed.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_typed.offset_left = -160
	_typed.offset_right = 160
	_typed.offset_top = -40
	_typed.offset_bottom = -8
	_typed.text_submitted.connect(_on_typed)
	add_child(_typed)
	_screen = GameScreen.new()
	_screen.visible = false
	add_child(_screen)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_message.add_theme_font_size_override("font_size", 18)
	_message.anchor_left = 0.0
	_message.anchor_right = 0.5
	_message.anchor_top = 1.0
	_message.anchor_bottom = 1.0
	_message.offset_left = 16
	_message.offset_right = -8
	_message.offset_top = -230
	_message.offset_bottom = -64
	_message.visible = false
	add_child(_message)
	GameClock.set_time(_vm, 0, 0)   # a new game starts at 00:00
	_shop = ShopScreen.new()
	_shop.visible = false
	_shop.closed.connect(_on_shop_closed)
	add_child(_shop)
	_sheet = CharacterSheet.new()
	_sheet.visible = false
	add_child(_sheet)
	_shop.sheet = _sheet
	_vm.square_info = func(x: int, y: int) -> int: return _maps[_map_index].map.flag(x, y) if not _maps.is_empty() else 0
	_treasure = TreasureScreen.new()
	_treasure.visible = false
	_treasure.closed.connect(_on_treasure_closed)
	add_child(_treasure)
	_camp = CampScreen.new()
	_camp.visible = false
	_camp.closed.connect(_on_camp_closed)
	_camp.save_requested.connect(_save_original)
	_camp.time_passed.connect(_on_camp_rested)
	_camp.interrupted.connect(_on_rest_interrupted)
	add_child(_camp)
	_party_menu = PartyMenu.new()
	_party_menu.visible = false
	_party_menu.closed.connect(_on_party_menu_closed)
	_party_menu.save_requested.connect(_save_original)
	add_child(_party_menu)
	_temple = TempleScreen.new()
	_temple.visible = false
	_temple.closed.connect(_on_temple_closed)
	add_child(_temple)
	_combat = CombatScreen.new()
	_combat.visible = false
	_combat.finished.connect(_on_event_fight_finished)
	add_child(_combat)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer)
	add_child(_timer)
	_automap = Automap.new()
	_automap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_automap.gate = func() -> bool:
		return _screen.visible and _mode == Mode.WALK and not _vm.on_overland and not (_shop.visible \
			or _sheet.visible or _combat.visible or _treasure.visible or _camp.visible \
			or _temple.visible or _party_menu.visible or (_start_menu != null and _start_menu.visible) \
			or (_ending != null and _ending.visible))
	add_child(_automap)
	_game_path = GameData.find_game_path()
	if _game_path == "":
		# Ask for the player's own copy (GameFolderScreen), then start over with it.
		_status.text = ""
		var ask := GameFolderScreen.new()
		ask.ready_to_start.connect(func(_p: String) -> void: get_tree().reload_current_scene())
		add_child(ask)
		return
	_types = ItemTypes.load_file(_game_path)
	GameScreen.load_art(_game_path)
	CharacterSheet.types = _types
	CharacterSheet.spells = SpellTable.shared(_game_path)
	CharacterSheet.game_path = _game_path
	for i in range(1, 7):
		var m := PartyMember.load_files(_game_path.path_join("CHRDATA%d.SAV" % i), _game_path.path_join("CHRDATA%d.ITM" % i))
		if m != null:
			m.recalculate(_types)
			_party.append(m)
	_vm.party = _party
	_vm.open_ahead = _open_ahead
	_vm.tables = ClassTables.shared(_game_path)
	_vm.overland = OverlandMap.shared(_game_path)
	var battle_only := false
	for arg in OS.get_cmdline_user_args():
		battle_only = battle_only or arg.begins_with("--battle=")
		# --seed=<n>: the same dice every run (for the lab's step-by-step comparisons).
		if arg.begins_with("--seed="):
			seed(int(arg.get_slice("=", 1)))
		# --fast: the lab's long tours run every pause and fight step 25 times faster.
		if arg == "--fast":
			Engine.time_scale = 25.0
		# --coverage=<file>: record which parts of the event scripts run (M6). Dev builds only.
		if arg.begins_with("--coverage=") and OS.is_debug_build():
			_vm.coverage = ScriptCoverage.new(arg.trim_prefix("--coverage="))
		# --branches=<file>: at each script menu, also try every choice in a copy of the VM (M6).
		if arg.begins_with("--branches=") and OS.is_debug_build():
			_shadow = ShadowExplorer.new(arg.trim_prefix("--branches="))
	for file_name in GameData.list_files(_game_path, "DAX"):
		if battle_only and not file_name.begins_with("GEO"):
			continue
		var dax := DaxFile.open(_game_path.path_join(file_name))
		if dax == null:
			continue
		for id in dax.ids():
			var block: PackedByteArray = dax.blocks[id]
			if file_name.begins_with("ECL"):
				var strings := GoldBoxText.find_strings(block)
				if not strings.is_empty():
					_area_text[id] = strings[0].text
				continue
			if file_name.begins_with("GEO"):
				var m := GeoMap.decode(block)
				if m != null:
					_maps.append({"file": file_name, "id": id, "map": m, "block": block})
				continue
			var animated := file_name.begins_with("PIC") or file_name.begins_with("SPRIT") or file_name.begins_with("FINAL")
			var pic := EgaPicture.decode_any(block) if animated else EgaPicture.decode(block)
			if pic != null:
				_pictures.append({"file": file_name, "id": id, "pic": pic})
	# Start on the main title screen (TITLE.DAX block 2).
	for i in _pictures.size():
		if _pictures[i].file == "TITLE.DAX" and _pictures[i].id == 2:
			_pic_index = i
	# Testing aid for the lab: --battle=GEO2.DAX:20:13:7:W:2:4:6:4:2 (map file, map id, x, y,
	# facing, monster file, monster id, count, picture, distance or -1, then optionally more
	# monster rows as id,count,picture) [--battle-image=path]
	# prints where everyone starts and saves the battlefield, then quits. With
	# --battle-fight=<seed> it also fights it out (computer on both sides), printing every roll;
	# --battle-fight=<seed>:away replays the free-attack check (see CombatScreen.run_fight);
	# --battle-morale=<n> sets the encounter's morale (the scripts use 99 or 60);
	# --battle-strong gives the party 200 HP, AC -10 and THAC0 1.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--battle="):
			_battle_check(arg.trim_prefix("--battle="))
			return
	# Lab: --play=<plan file> plays the game from a plan (PlayBot), from the start menu on.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--play="):
			var bot := PlayBot.new()
			bot.main = self
			add_child(bot)
			bot.run.call_deferred(arg.trim_prefix("--play="))
			return
	# Testing aid: with --keys=, start straight in the last quick save and replay.
	var keys_arg := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--keys="):
			keys_arg = arg.trim_prefix("--keys=")
	if keys_arg != "" and FileAccess.file_exists(_save_path()):
		_quick_load()
		_replay_keys.call_deferred(keys_arg.split(","))
		return
	# Otherwise the title and the start menu.
	_start_menu = StartMenu.new()
	add_child(_start_menu)
	_start_menu.chosen.connect(_on_start_chosen)
	_start_menu.open(_game_path, FileAccess.file_exists(_save_path()))


var _start_menu: StartMenu


func _on_start_chosen(what: String, letter: String) -> void:
	_automap.enabled = Automap.load_enabled()
	match what:
		"continue":
			_quick_load()
		"load":
			load_original_save(letter)
		"new":
			_new_game()
		"create":
			# As the original starts: an empty party, the party menu's CREATE / ADD, then
			# BEGIN ADVENTURING starts the game with whoever was added.
			_party.clear()
			_starting_party = true
			_vm.write_byte(EclVM.TRAINING_MASK, 0)
			_party_menu.tables = ClassTables.shared(_game_path)
			_party_menu.spells = SpellTable.shared(_game_path)
			_party_menu.types = _types
			_party_menu.game_path = _game_path
			_party_menu.open(_party, 0)
			return
	_show()


var _starting_party := false
var _lost := false     # the party has fallen: a key goes back to the start menu


## The whole party is down: the adventure ends here; any key goes back to the start menu
## (load a game or continue from the quick save). (The original's own screen for this is
## still to be compared in the lab.)
func _party_lost() -> void:
	_lost = true
	_vm.state = EclVM.State.DONE
	_message.text = "THE PARTY HAS FALLEN.\n\nPRESS A KEY."
	_show()


func _back_to_start() -> void:
	_lost = false
	_message.text = ""
	_start_menu = StartMenu.new() if _start_menu == null else _start_menu
	if _start_menu.get_parent() == null:
		add_child(_start_menu)
		_start_menu.chosen.connect(_on_start_chosen)
	_start_menu.visible = true
	_start_menu.open(_game_path, FileAccess.file_exists(_save_path()))
var _menu_sel := 0   # the event menus' highlight, kept from one menu to the next


## A new game with the ready-made party: New Phlan at the start of the adventure.
func _new_game() -> void:
	_mode = Mode.WALK
	# A fresh start: no flags or places from an earlier game.
	_vm.mem.fill(0)
	_vm.on_overland = false
	_vm.overland_band = 0
	GameClock.set_time(_vm, 0, 0)
	_vm.write_byte(EclVM.PARTY_X, NEW_GAME_PLACE.x)
	_vm.write_byte(EclVM.PARTY_Y, NEW_GAME_PLACE.y)
	_vm.write_byte(EclVM.PARTY_DIR, NEW_GAME_PLACE.z)
	_enter_script(3, 0, true, true)


const NEW_GAME_PLACE := Vector3i(11, 9, 2)
const CURRENT_BLOCK := 0x49F2    # the area's block, written after its init
const NO_COORDINATES := 0x49FB   # 1: no square on the place line, no AREA map (START.EXE 0x35A6)


## Testing aid for the lab: --keys=up,up,s,l,e,... presses each key (Godot key names, or
## "wait" for half a second), waits until the engine is idle and prints where the party is,
## the clock, what is on screen and the message, one line per key; then quits.
func _replay_keys(names: PackedStringArray) -> void:
	print("start  ", _state_line())
	for n in names:
		if n == "wait":
			await get_tree().create_timer(0.5).timeout
		elif n.begins_with("program="):     # program=0:120 runs PROGRAM 0 with hall mask 120
			var a := n.trim_prefix("program=").split(":")
			_vm.write_byte(EclVM.TRAINING_MASK, int(a[1]) if a.size() > 1 else 0)
			_vm.program = int(a[0])
			_vm.state = EclVM.State.PROGRAM
			_after_vm()
		elif n.begins_with("find="):        # find=<event>: squares with that event number
			var ev := int(n.trim_prefix("find="))
			var found := []
			var mp: GeoMap = _maps[_map_index].map
			for y in GeoMap.SIZE:
				for x in GeoMap.SIZE:
					if mp.flag(x, y) & 127 == ev:
						found.append("%d,%d" % [x, y])
			print("   event %d at %s" % [ev, " ".join(found)])
			continue
		elif n.begins_with("area="):        # area=<set>:<block> enters that area's script (init)
			var a := n.trim_prefix("area=").split(":")
			_mode = Mode.WALK
			_enter_script(int(a[0]), int(a[1]))
		elif n == "create":                 # create: the start menu's PARTY CREATION
			_on_start_chosen("create", "")
		elif n == "party":                  # party: opens the party menu (PROGRAM 0, no training)
			_vm.write_byte(EclVM.TRAINING_MASK, 0)
			_vm.program = 0
			_run_program()
		elif n == "ending":                 # ending: plays the end-of-game screens
			_vm.program = 8
			_run_program()
		elif n.begins_with("screen="):      # screen=<png>: the open overlay's 320x200 picture (headless)
			var scr: GameScreen = _screen
			for o in [_party_menu, _camp, _temple, _treasure, _shop, _party_menu._sheet, _camp._sheet, _treasure._sheet, _sheet]:
				if o != null and o.visible and o.get("_scr") != null:
					scr = o._scr
			if scr != null and scr.img != null:
				scr.img.save_png(n.trim_prefix("screen="))
			continue
		elif n == "autowin":                # autowin: the next scripted fight is won at once (dev)
			_combat.dev_auto_win = true
			continue
		elif n == "cells":                  # cells: where everyone stands in the fight on screen
			print("   distance %d, party square %d,%d facing %d" % [_combat._distance, _combat._px, _combat._py, _combat._facing])
			for k in 3:
				print("   side of %d,%d facing %d: %d" % [_combat._px + k * Placement.SQUARE_STEP[_combat._facing].x,
					_combat._py + k * Placement.SQUARE_STEP[_combat._facing].y, _combat._facing,
					_combat._field.side(_combat._px + k * Placement.SQUARE_STEP[_combat._facing].x, _combat._py + k * Placement.SQUARE_STEP[_combat._facing].y, _combat._facing)])
			for c in _combat._combatants:
				print("   %s %-16s %d,%d" % ["party  " if c.team == 0 else "monster", c.who.name, c.cell.x, c.cell.y])
			continue
		elif n.begins_with("shot="):        # shot=<png path> saves the window (not headless)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(n.trim_prefix("shot="))
		elif n.begins_with("tour="):        # tour=x;y walks there a step at a time, playing what comes
			var a := n.trim_prefix("tour=").split(";")
			await _tour(Vector2i(int(a[0]), int(a[1])))
			print("   at ", _state_line())
			continue
		elif n.begins_with("answers="):     # answers=a;b;c: letters the tour gives to script menus
			_tour_answers = Array(n.trim_prefix("answers=").split(";"))
			continue
		elif n.begins_with("load="):        # load=<letter> loads the original's SAVGAM<letter>.DAT
			load_original_save(n.trim_prefix("load="))
		elif n.begins_with("say="):         # say=<text> answers INPUT_STRING / INPUT_NUMBER
			_on_typed(n.trim_prefix("say="))
		elif n.begins_with("mem="):         # mem=<hex address>:<value> writes ECL memory
			var a := n.trim_prefix("mem=").split(":")
			_vm.write_byte(a[0].hex_to_int(), int(a[1]))
		elif n.begins_with("at="):          # at=x;y;dir places the party (dir 0..3 = N E S W)
			var a := n.trim_prefix("at=").split(";")
			_pos = Vector2i(int(a[0]), int(a[1]))
			_facing = (int(a[2]) if a.size() > 2 else 0) as DungeonView.Dir
			_sync_position_to_vm(_facing)
			_show()
		elif n.begins_with("scroll="):      # scroll=<index>:<spell name>: a magic-user scroll
			var a := n.trim_prefix("scroll=").split(":")
			var table := SpellTable.shared(_game_path)
			var rec := PackedByteArray()
			rec.resize(GameItem.SIZE)
			var label := "Scroll".to_ascii_buffer()
			rec[0] = label.size()
			for i in label.size():
				rec[1 + i] = label[i]
			rec[46] = 61
			rec.encode_u16(55, 1)
			for id in range(1, SpellTable.NAMED + 1):
				if table.name_of(id).strip_edges().to_upper() == a[1].replace("_", " ").to_upper():
					rec[60] = id
			_party[int(a[0])].items.append(GameItem.from_record(rec))
		elif n.begins_with("gold="):        # gold=<party index>:<platinum pieces>
			var a := n.trim_prefix("gold=").split(":")
			_party[int(a[0])].money[4] = int(a[1])
		elif n.begins_with("xp="):          # xp=<party index>:<experience>
			var a := n.trim_prefix("xp=").split(":")
			_party[int(a[0])].experience = int(a[1])
		elif n.begins_with("sheet="):       # sheet=<index>: what the character sheet shows
			for sh in [_sheet, _camp._sheet, _party_menu._sheet]:
				if sh != null and sh.visible:
					print(sh.screen_text())
			continue
		elif n == "party":
			for m in _party:
				print("   %-15s lv %s xp %d hp %d/%d rolled %d thac0 %d saves %s slots %s ha %d gp %d book %d items %d" % [m.name,
					str(m.raw.slice(0x96, 0x9E)), m.experience, m.hp, m.hp_max, m.hp_rolled, 60 - m.base_thac0_60,
					str(m.saves), str(m.spell_slots), m.half_attacks, m.wealth_copper() / 200, m.spell_book.count(1), m.items.size()])
			continue
		else:
			var ev := InputEventKey.new()
			var key_name: String = {"enter": "Enter", "esc": "Escape", "home": "Home", "end": "End",
				"up": "Up", "down": "Down", "left": "Left", "right": "Right"}.get(n, n.to_upper())
			ev.keycode = OS.find_keycode_from_string(key_name)
			ev.pressed = true
			Input.parse_input_event(ev)
			var up := ev.duplicate()
			up.pressed = false
			Input.parse_input_event(up)
		for i in 300:
			await get_tree().process_frame
			if i > 3 and not _busy:
				break
		print(n.rpad(6), " ", _state_line())
	get_tree().quit()


var _tour_answers := []


## Lab: one key press as the replay sends it.
func _press(n: String) -> void:
	var ev := InputEventKey.new()
	var key_name: String = {"enter": "Enter", "esc": "Escape", "up": "Up", "down": "Down",
		"left": "Left", "right": "Right"}.get(n, n.to_upper())
	ev.keycode = OS.find_keycode_from_string(key_name)
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	for i in 4:
		await get_tree().process_frame


## Lab: walks to a square one step at a time and plays out whatever happens with the same
## policy as the lab's tour.py for the original (Enter on prompts, COMBAT on encounters, quick
## fights, CONTINUE BATTLE no, leave the treasure, BASH locked doors, script menus from answers= or their
## first item), printing each new message and menu.
func _tour(goal: Vector2i) -> void:
	var steps := 0
	var deadline := Time.get_ticks_msec() + 600000
	_said = ""
	_door_tries.clear()     # a few tries at each locked door per walk
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if _lost:
			print("   the party has fallen")
			return
		if tour_stop and not _combat.visible and not _treasure.visible and _vm.state in [EclVM.State.IDLE, EclVM.State.DONE]:
			tour_stop = false
			print("   tour stopped short of %s" % goal)
			return
		if await _auto_handle():
			if _auto_gave_up:
				_auto_gave_up = false
				print("   LOCKED, BASH used up -> EXIT; gave up on %s" % goal)
				return
			continue
		if _pos == goal:
			return
		steps += 1
		if steps > 150:
			print("   gave up on %s" % goal)
			return
		var path := _find_path(_pos, goal)
		if path.size() < 2:
			print("   no route from %s" % _pos)
			return
		var d := DungeonView.DELTA.find(path[1] - _pos)
		while int(_facing) != d:
			await _press("right" if (d - int(_facing) + 4) % 4 != 3 else "left")
		var before := _pos
		var area_before := "%d:%d" % [_vm_file, _vm_block]
		await _press("up")
		for i in 60:
			await get_tree().process_frame
		if _pos == before and _vm.state in [EclVM.State.IDLE, EclVM.State.DONE] and _door_options == "" \
				and not _combat.visible and _message.text.strip_edges() == "":
			print("   blocked at %s" % _pos)
			return
		while await _auto_handle():
			await get_tree().process_frame
		if _pos == before and _door_retry:
			# A locked door that didn't open this time: try it again (the tries are counted).
			_door_retry = false
			continue
		if _pos == before and area_before == "%d:%d" % [_vm_file, _vm_block]:
			# The square ahead turned the party back (a guarded door, a refusal): go round it.
			_refused["%d:%d,%d,%d" % [_map_index, before.x, before.y, d]] = true
			if path[1] == goal:
				print("   %s refuses entry; gave up" % goal)
				return


var _said := ""
var _refused := {}     # the tour's steps the game turned back ("map:x,y,dir")
var _auto_gave_up := false
## Lab (PlayBot): set to end the current tour at the next quiet moment (a hurt party stops
## to rest instead of walking on into the next wandering monster).
var tour_stop := false
var _menu_seen := {}
## Called before a fight's or screen's default handling; a playthrough bot sets it to take
## over (return true when it handled the moment itself).
var auto_hook: Callable = Callable()
var _shadow: ShadowExplorer = null     # dev: tries the choices not taken (--branches=)


## Lab: plays whatever is on screen with the tour's policy (Enter on prompts, quick fights,
## the first menu choice or the next answer, leave shops). Returns true if something was
## open or running (the caller should keep waiting), false when the party is free to move.
func _auto_handle() -> bool:
	if _lost:
		return false
	if _busy:
		if _timer.is_stopped():
			# Busy with nothing to end it (seen on the wilderness, lizard men at 8:27 34,20:
			# a bot run sat here 40 minutes). Say so, and go on as the timer would.
			print("!! busy with no timer running: ", _state_line())
			if _vm.state == EclVM.State.WAIT or not _walk_path.is_empty():
				_on_timer()
			else:
				_busy = false
		return true
	var text := _message.text.strip_edges()
	if _vm.state == EclVM.State.MENU:
		text += "  [" + " ".join(_vm.menu) + "]"
	if text != "" and text != _said:
		print("   ", text.replace("\n", " / "))
		_said = text
		if _shadow != null and _vm.state == EclVM.State.MENU:
			_shadow.explore(_vm)
	if auto_hook.is_valid() and await auto_hook.call():
		return true
	if _combat.visible:
		if _combat._asking_continue:
			print("   CONTINUE BATTLE -> N")
			await _press("n")
		elif _combat._result != 0:
			print("   (fight over: result %d)" % _combat._result)
			await _press("enter")
		elif _combat._combat != null and _combat._combat.active >= 0 \
				and not _combat._combatants[_combat._combat.active].quick:
			await _press("q")
		return true
	if _treasure.visible:
		if _treasure._amount_open:
			await _press("esc")
		elif _treasure._page == 0:
			await _press("enter")
		elif _treasure._asking_exit:
			await _press("n")
		else:
			print("   (treasure: %s)" % _treasure._spoils.describe() if _treasure._spoils.has_method("describe") else "   (treasure)")
			await _press("e")
		return true
	if _shop.visible or _temple.visible or _camp.visible or _party_menu.visible or _sheet.visible:
		if _shop.visible:
			print("   (shop: %s)" % ", ".join(_shop._items.map(func(it): return "%s %d" % [it.name, it.price])))
			_shop._exit()
			return true
		print("   (screen open: leaving %s)" % ", ".join([[_temple, "temple"], [_camp, "camp"],
			[_party_menu, "party menu"], [_sheet, "sheet"]].filter(func(p): return p[0].visible).map(func(p): return p[1])))
		if _party_menu.visible and not _sheet.visible:
			await _press("b")          # BEGIN ADVENTURING
			return true
		await _press("esc")
		if _temple.visible or _camp.visible or _party_menu.visible or _sheet.visible:
			await _press("e")
		return true
	if _door_options != "":
		# A player sends the thief first, then Knock, then bashes; each can be tried again,
		# as in the original (a few tries a door, then gives up).
		var key := "%d,%d,%d,%d" % [_map_index, _pos.x, _pos.y, _door_side]
		var tries: int = _door_tries.get(key, 0)
		_door_tries[key] = tries + 1
		if tries < 6:
			for c in ["P", "K", "B"]:
				if c in _door_options and (c != "K" or _knock_caster() != null):
					print("   LOCKED -> %s (try %d)" % [c, tries + 1])
					_door_retry = true
					await _press(c.to_lower())
					return true
		await _press("e")
		_auto_gave_up = true
		return true
	if _vm.state == EclVM.State.INPUT:
		var said_text: String = _tour_answers.pop_front() if not _tour_answers.is_empty() else "x"
		print("   >> typed ", said_text)
		_on_typed(said_text)
		return true
	if _vm.state == EclVM.State.MENU:
		var one: bool = _vm.menu.size() == 1
		var k: String = "1" if one or _tour_answers.is_empty() else String(_tour_answers.pop_front())
		# A menu answered the same way twice already (a loop such as "WILL YOU GO AGAIN?"):
		# take its last choice this time.
		var body := _message.text.strip_edges()
		var cut := body.rfind("\n\n")
		var key := " ".join(_vm.menu) + "|" + (body.substr(0, cut) if cut > 0 else body).right(50) + "|%s" % _pos
		if not one and _tour_answers.is_empty():
			_menu_seen[key] = int(_menu_seen.get(key, 0)) + 1
			if int(_menu_seen[key]) > 2:
				for i in _vm.menu.size():
					if String(_vm.menu[i]).strip_edges().to_upper() in ["NO", "LEAVE", "EXIT", "QUIT", "DONE"]:
						k = str(i + 1)
		if not one:
			print("   >> ", k)
		await _press(k)
		return true
	if _vm.state in [EclVM.State.RUNNING, EclVM.State.WAIT]:
		return true
	return false


func _state_line() -> String:
	var screen := "walk"
	for pair in [[_shop, "shop"], [_sheet, "sheet"], [_combat, "combat"], [_treasure, "treasure"],
			[_camp, "camp"], [_temple, "temple"], [_party_menu, "party"]]:
		if pair[0].visible:
			screen = pair[1]
	var effects := []
	for m in _party:
		for a in m.affects:
			effects.append("%s:%d/%d" % [m.name.substr(0, 6), int(a.effect), int(a.minutes)])
	var text := _message.text
	if _party_menu.visible:
		text = _party_menu.screen_text()
	elif _camp.visible:
		text = _camp.state_text()
	var place := "%d,%d %s %s" % [_pos.x, _pos.y, "NESW"[_facing], GameClock.text(_vm)]
	if _vm.on_overland:
		place = "wild " + _overland_place()
	return "%s %s ecl%d:%d vm=%d | %s | %s" % [place,
		screen, _vm_file, _vm_block, _vm.state, " ".join(effects), text.replace("\n", " / ").left(160)]


func _unhandled_input(event: InputEvent) -> void:
	if _game_path == "" or not event.is_pressed() or _shop.visible or _sheet.visible or _combat.visible \
			or _treasure.visible or _camp.visible or _temple.visible or _party_menu.visible:
		return
	if _lost and event is InputEventKey:
		get_viewport().set_input_as_handled()
		_back_to_start()
		return
	if _mode != Mode.WALK and event is InputEventKey and (event as InputEventKey).keycode == KEY_F3:
		_quick_load()
	elif event is InputEventKey and (event as InputEventKey).keycode == KEY_TAB:
		_mode = ((_mode + 1) % 3) as Mode
	elif _mode == Mode.WALK:
		var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
		if _busy:
			get_viewport().set_input_as_handled()
			return
		if _door_options != "":
			var letter := OS.get_keycode_string(key).to_upper()
			if letter.length() == 1:
				_door_choice(letter)
			get_viewport().set_input_as_handled()
			_show()
			return
		if _vm.state == EclVM.State.MENU:
			# A menu is open: only its choices count (digits, or an item's first letter
			# as in the original when that letter is unique).
			var choice := -1
			if key >= KEY_1 and key <= KEY_9:
				choice = key - KEY_1
			elif key >= KEY_A and key <= KEY_Z:
				var letter := OS.get_keycode_string(key).to_upper()
				var hits := []
				for i in _vm.menu.size():
					if String(_vm.menu[i]).strip_edges().to_upper().begins_with(letter):
						hits.append(i)
				if hits.size() == 1:
					choice = hits[0]
			elif event.is_action("ui_left") or event.is_action("ui_right"):
				# The highlight moves along the menu (the original's way to choose).
				_menu_sel = posmod(clampi(_menu_sel, 0, _vm.menu.size() - 1) + (1 if event.is_action("ui_right") else -1), _vm.menu.size())
			elif event.is_action("ui_accept"):
				choice = clampi(_menu_sel, 0, _vm.menu.size() - 1)
			if choice >= 0 and choice < _vm.menu.size():
				_menu_sel = choice   # the original keeps the highlight where the last choice was
				_message.text = ""
				_vm.choose(choice)
				_after_vm()
			get_viewport().set_input_as_handled()
			_show()
			return
		if (key == KEY_HOME or key == KEY_END) and not _party.is_empty():
			# Home/End move the selected character up and down the party (lab, chat 11).
			_vm.selected = posmod(clampi(_vm.selected, 0, _party.size() - 1) + (1 if key == KEY_END else -1), _party.size())
			get_viewport().set_input_as_handled()
			_show()
			return
		if key == KEY_F2:
			_quick_save()
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_F3:
			_quick_load()
		elif key == KEY_V:
			for m in _party:
				m.recalculate(_types)
			_sheet.open(_party, "PARTY", clampi(_vm.selected, 0, maxi(_party.size() - 1, 0)), false, 2)
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_B:
			for m in _party:
				m.recalculate(_types)
			var map: GeoMap = _maps[_map_index].map
			var script: EclScript = null
			var ecl := DaxFile.open(_game_path.path_join("ECL%d.DAX" % maxi(_vm_file, 1)))
			if ecl and ecl.blocks.has(_vm_block):
				script = EclScript.decode(ecl.blocks[_vm_block])
			_combat.open_test(_game_path, map, _pos.x, _pos.y, int(_facing), _party, maxi(_vm_file, 1), script)
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_M and (event as InputEventKey).shift_pressed:
			_sheet.open(_all_monsters(), "MONSTERS")    # developer aid
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_M and _automap.enabled:
			_automap.mini_open = not _automap.mini_open
			_automap.full_open = false
			_automap.queue_redraw()
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_ESCAPE and _automap.full_open:
			_automap.full_open = false
			_automap.queue_redraw()
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_F and _automap.enabled and not _vm.on_overland:
			_automap.full_open = not _automap.full_open
			_automap.queue_redraw()
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_N:
			var night := GameClock.hour(_vm) >= 14
			GameClock.set_time(_vm, 8 if night else 20, 0)
		elif key == KEY_O:
			_dungeon.show_slots = not _dungeon.show_slots
		elif key == KEY_F9:
			_capture()
			return
		elif key == KEY_F12:
			_dev_view = not _dev_view
			CombatScreen.dev_view = _dev_view
		elif key == KEY_A:
			_area_view = not _area_view
		elif key == KEY_E:
			_make_camp()
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_F4:
			_dump_script()
			return
		elif key == KEY_S:
			# SEARCH: the original's search mode, which the scripts read (more random
			# encounters, hidden things found).
			_searching = not _searching
			_vm.write_byte(SEARCH_FLAG, 1 if _searching else 0)
			_status.text = "SEARCHING" if _searching else "Search off."
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_L:
			# LOOK: searches the square you stand on once.
			if _vm.ecl != null and _vm.state in [EclVM.State.IDLE, EclVM.State.DONE, EclVM.State.ERROR]:
				_pass_time(GameClock.TEN_MINUTES, 1)
				_vm.write_byte(SEARCH_FLAG, 1)
				_sync_position_to_vm(_facing)
				_vm.clear_output()
				_vm.start(1)
				if not _searching:
					_vm.write_byte(SEARCH_FLAG, 0)
				_after_vm()
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_G:
			_goto.text = ""
			_goto.visible = true
			_goto.grab_focus()
			get_viewport().set_input_as_handled()
			return
		elif _vm.on_overland and (event.is_action("ui_up") or event.is_action("ui_right") \
				or event.is_action("ui_down") or event.is_action("ui_left")):
			# The wilderness: each arrow steps that way (the original has no turning here).
			var dirs := ["ui_up", "ui_right", "ui_down", "ui_left"]
			for d in 4:
				if event.is_action(dirs[d]):
					_try_move(d)
					break
		elif event.is_action("ui_up"):
			_try_move(_facing)
		elif event.is_action("ui_down"):
			_try_move((_facing + 2) % 4)
		elif event.is_action("ui_left"):
			_facing = ((_facing + 3) % 4) as DungeonView.Dir
		elif event.is_action("ui_right"):
			_facing = ((_facing + 1) % 4) as DungeonView.Dir
		else:
			return
	elif _mode == Mode.MAPS and event.is_action("ui_accept"):
		_mode = Mode.WALK
	elif event.is_action("ui_right"):
		_step(1)
	elif event.is_action("ui_left"):
		_step(-1)
	elif event.is_action("ui_down") and _mode == Mode.PICTURES:
		_jump_file(1)
	elif event.is_action("ui_up") and _mode == Mode.PICTURES:
		_jump_file(-1)
	else:
		return
	get_viewport().set_input_as_handled()
	_show()


func _step(delta: int) -> void:
	if _mode == Mode.PICTURES and not _pictures.is_empty():
		_pic_index = (_pic_index + delta + _pictures.size()) % _pictures.size()
	elif _mode == Mode.MAPS and not _maps.is_empty():
		_map_index = (_map_index + delta + _maps.size()) % _maps.size()


func _jump_file(step: int) -> void:
	if _pictures.is_empty():
		return
	# Indices where each file's pictures begin.
	var starts: Array[int] = []
	for i in _pictures.size():
		if i == 0 or _pictures[i].file != _pictures[i - 1].file:
			starts.append(i)
	var current := 0
	for k in starts.size():
		if starts[k] <= _pic_index:
			current = k
	_pic_index = starts[(current + step + starts.size()) % starts.size()]


var _font_glyphs := PackedByteArray()


## The view as a page of runes (PRINT_RUNES): white glyphs of the game's own 1-bit font
## (8X8D1 block 201, 8 bytes a glyph, indexed by character code) on black.
func _rune_page() -> Image:
	if _font_glyphs.is_empty():
		var dax := DaxFile.open(_game_path.path_join("8X8D1.DAX"))
		if dax != null and dax.blocks.has(201):
			_font_glyphs = dax.blocks[201]
	var view := DungeonView.to_image(_dungeon.render(_maps[_map_index].map, _walls, _pos.x, _pos.y, _facing))
	var img := Image.create(view.get_width(), view.get_height(), false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	for row in _vm.rune_lines.size():
		var line: String = _vm.rune_lines[row]
		for col in line.length():
			var g := line.unicode_at(col)
			for y in 8:
				var bits := _font_glyphs[g * 8 + y] if g * 8 + y < _font_glyphs.size() else 0
				for x in 8:
					var px := 8 + col * 8 + x
					var py := 8 + row * 12 + y
					if bits >> (7 - x) & 1 and px < img.get_width() and py < img.get_height():
						img.set_pixel(px, py, Color.WHITE)
	return img


func _on_typed(text: String) -> void:
	_typed.visible = false
	_typed.release_focus()
	if _vm.state == EclVM.State.INPUT:
		_vm.answer_input(text)
		_after_vm()
		_show()


func _on_goto_closed() -> void:
	_goto.visible = false


func _on_goto_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):
		_goto.release_focus()


func _on_goto(text: String) -> void:
	_goto.visible = false
	if text.strip_edges().to_lower() == "ending":
		# For testing: the end-of-game screens without playing to the end.
		_vm.program = 8
		_run_program()
		return
	var parts := text.strip_edges().split(" ", false)
	if parts.size() >= 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		_pos = Vector2i(clampi(parts[0].to_int(), 0, 15), clampi(parts[1].to_int(), 0, 15))
		if parts.size() >= 3:
			var d := "NESW".find(parts[2].substr(0, 1).to_upper())
			if d >= 0:
				_facing = d as DungeonView.Dir
	_show()


## Writes the area's event script, disassembled, to <project>/captures/.
func _dump_script() -> void:
	var e: Dictionary = _maps[_map_index]
	var file_no := int(String(e.file).trim_prefix("GEO").trim_suffix(".DAX"))
	var ecl := DaxFile.open(_game_path.path_join("ECL%d.DAX" % file_no))
	if ecl == null or not ecl.blocks.has(e.id):
		_status.text = "No event script with this map's id in ECL%d.DAX" % file_no
		return
	var dir := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("ECL%d_%d.txt" % [file_no, e.id])
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(_script(file_no, e.id, ecl).disassemble() + "\n")
	_status.text = "Wrote %s" % path.get_file()


## Saves the current view (4x, PNG) and its slot report to <project>/captures/.
func _capture() -> void:
	if _walls == null:
		return
	var e: Dictionary = _maps[_map_index]
	var dir := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var base := dir.path_join("%s_%d-%d-%s_%s" % [
		String(e.file).get_basename(), _pos.x, _pos.y, DungeonView.DIR_NAMES[_facing], stamp])
	var img := DungeonView.to_image(_dungeon.render(e.map, _walls, _pos.x, _pos.y, _facing))
	img.resize(DungeonView.SIZE * 4, DungeonView.SIZE * 4, Image.INTERPOLATE_NEAREST)
	img.save_png(base + ".png")
	var f := FileAccess.open(base + ".txt", FileAccess.WRITE)
	if f:
		f.store_string("%s block %d (%s)\n" % [e.file, e.id, GeoMap.AREA_NAMES.get(e.id, "unnamed area")])
		f.store_string(_dungeon.report(e.map, _walls, _pos.x, _pos.y, _facing) + "\n")
	_status.text = "Captured %s.png / .txt" % base.get_file()


## Quick save (F2) / quick load (F3): the whole game state in one file, so a test can
## start exactly where it's needed. Saved in the project's saves/ folder when run from the
## editor (git-ignored), otherwise in Godot's user folder.
func _save_path() -> String:
	# Testing aid for the lab: --save=<path> uses that quick save file instead.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="):
			return arg.trim_prefix("--save=")
	if OS.has_feature("editor"):
		var dir := ProjectSettings.globalize_path("res://saves")
		DirAccess.make_dir_recursive_absolute(dir)
		return dir.path_join("quicksave.cfg")
	return "user://quicksave.cfg"


func _quick_save() -> void:
	if _busy or _vm.state == EclVM.State.MENU or _vm.ecl == null:
		_status.text = "Can't save in the middle of an event; finish it first."
		return
	var cfg := ConfigFile.new()
	cfg.set_value("place", "map_file", String(_maps[_map_index].file))
	cfg.set_value("place", "map_id", int(_maps[_map_index].id))
	cfg.set_value("place", "x", _pos.x)
	cfg.set_value("place", "y", _pos.y)
	cfg.set_value("place", "facing", int(_facing))
	cfg.set_value("script", "file", _vm_file)
	cfg.set_value("script", "block", _vm_block)
	cfg.set_value("script", "memory", _vm.mem)
	cfg.set_value("script", "overland", [_vm.on_overland, _vm.overland_band])
	cfg.set_value("qol", "visited", _automap.to_save())
	var members := []
	for m in _party:
		var items := []
		for it in m.items:
			items.append(it.to_record())
		members.append({"name": m.name, "record": m.to_record(), "money": m.money, "items": items, "hp": m.hp,
			"experience": m.experience, "status": m.status, "memorized": m.memorized,
			"spell_book": m.spell_book, "affects": m.affects, "npc": m.npc})
	cfg.set_value("party", "members", members)
	var roster := []
	for m in _party_menu.roster:
		var items := []
		for it in m.items:
			items.append(it.to_record())
		roster.append({"record": m.to_record(), "items": items, "affects": m.affects})
	cfg.set_value("party", "roster", roster)
	var err := cfg.save(_save_path())
	_status.text = "Saved." if err == OK else "Save failed (error %d)." % err


## Lab aid: the first item in the game's treasure and monster lists whose full name starts
## with `name` (identified).
func _find_listed_item(name: String) -> GameItem:
	var words := ItemNames.shared(_game_path)
	for file in ["ITEM1", "ITEM2", "ITEM3", "ITEM4", "ITEM5", "ITEM6", "ITEM7", "ITEM8",
			"MON2ITM", "MON3ITM", "MON5ITM", "MON6ITM", "MON7ITM", "MON8ITM"]:
		var dax := DaxFile.open(_game_path.path_join(file + ".DAX"))
		if dax == null:
			continue
		for id in dax.ids():
			var b: PackedByteArray = dax.blocks[id]
			for o in range(0, b.size() - 62, 63):
				var it := GameItem.from_record(b.slice(o, o + 63))
				it.raw[53] = 0
				var n := words.name_of(it)
				if n.to_upper().begins_with(name.to_upper()):
					it.name = n
					return it
	return null


func _battle_check(spec: String) -> void:
	var a := spec.split(":")
	var image_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--battle-image="):
			image_path = arg.trim_prefix("--battle-image=")
	for i in _maps.size():
		if _maps[i].file == a[0] and _maps[i].id == int(a[1]):
			var facing := "NESW".find(a[4])
			if "--battle-strong" in OS.get_cmdline_user_args():
				# Lab aid, as mksave.py's "strong": 200 HP, AC -10, THAC0 1.
				for m in _party:
					m.raw[0x2D] = 59        # THAC0 1 (60-based)
					m.raw[0xA9] = 70        # AC -10
					m.raw[0x32] = 200
					m.raw[0x11B] = 200
					m.base_thac0_60 = 59
					m.base_ac_60 = 70
					m.hp_max = 200
					m.hp = 200
					m.recalculate(_types)
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--battle-give="):     # --battle-give=<member>:<item name start>
					var g := arg.trim_prefix("--battle-give=").split(":")
					var it := _find_listed_item(g[1])
					if it != null and int(g[0]) < _party.size():
						it.readied = true
						_party[int(g[0])].items.append(it)
						print("gave %s to %s" % [it.name, _party[int(g[0])].name])
			var rows := [[int(a[6]), int(a[7]), int(a[8])]]
			for k in range(10, a.size()):     # more monster rows: id,count,picture
				var r := a[k].split(",")
				rows.append([int(r[0]), int(r[1]), int(r[2])])
			_combat.run_check(_game_path, _maps[i].map, int(a[2]), int(a[3]), facing, _party,
				int(a[5]), rows, int(a[9]), image_path)
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--battle-morale="):
					_combat.set_morale_base(int(arg.trim_prefix("--battle-morale=")))
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--battle-fight="):
					var f := arg.trim_prefix("--battle-fight=").split(":")
					_combat.run_fight(int(f[0]), f[1] if f.size() > 1 else "")
	get_tree().quit()


## Saves the game in the original's own format as SAVGAM<letter>.DAT with its CHRDAT files in
## the game folder (OriginalSave), as the original's SAVE does: it loads in the original too.
func _save_original(letter: String) -> bool:
	if _vm.ecl == null:
		_status.text = "Can't save here."
		return false
	if not _vm.on_overland:
		_sync_position_to_vm(_facing)
	var ok := OriginalSave.write(_game_path, letter, _vm_file, _vm.mem, _vm.read_byte(EclVM.PARTY_X),
		_vm.read_byte(EclVM.PARTY_Y), _vm.read_byte(EclVM.PARTY_DIR), _party)
	_status.text = ("Saved game %s." if ok else "Couldn't write saved game %s.") % letter.to_upper()
	print("   (saved game %s%s)" % [letter.to_upper(), "" if ok else ": FAILED"])
	return ok


## Loads one of the original's own saved games (SAVGAM<letter>.DAT with its CHRDAT<letter>n
## character files) as found in the game folder. The save holds: byte 0 the data set
## (ECLn/GEOn), then ECL memory 0x4900-0x52FF as words (the game's flags, clock and the engine's own data), the
## area's script with its tables as they stood (from 0x1401, the block identifies the area),
## the party's square at 0x3201 (x, y, facing x2), and from 0x3209 the character file names
## (a length byte and 40 bytes each).
func load_original_save(letter: String) -> bool:
	var path := _game_path.path_join("SAVGAM%s.DAT" % letter.to_upper())
	var s := FileAccess.get_file_as_bytes(path)
	if s.size() < 0x3300:
		_status.text = "No saved game %s." % letter.to_upper()
		return false
	var set_no := s[0]
	var ecl := DaxFile.open(_game_path.path_join("ECL%d.DAX" % set_no))
	if ecl == null:
		return false
	# The area is the block whose script the saved image matches best (the image holds the
	# script's tables as they stood, so a few bytes differ).
	var block_id := -1
	var best := 0
	for id in ecl.ids():
		var code := EclScript.decode(ecl.blocks[id]).code
		var same := 0
		for i in mini(code.size(), 512):
			if s[0x1401 + i] == code[i]:
				same += 1
		if code.size() > 64 and same > best and same * 4 > mini(code.size(), 512) * 3:
			best = same
			block_id = id
	if block_id < 0:
		_status.text = "Saved game %s: its area wasn't found." % letter.to_upper()
		return false
	# The party.
	var loaded: Array[PartyMember] = []
	for k in 8:
		var o := 0x3209 + k * 41
		var n := s[o]
		if n <= 0 or n > 12:
			continue
		var stem := s.slice(o + 1, o + 1 + n).get_string_from_ascii()
		var m := PartyMember.load_files(_game_path.path_join(stem + ".SAV"), _game_path.path_join(stem + ".ITM"))
		if m != null:
			m.recalculate(_types)
			loaded.append(m)
	if loaded.is_empty():
		return false
	_party.assign(loaded)
	_vm.party = _party
	_timer.stop()
	_busy = false
	_walk_path.clear()
	_held_message = ""
	_event_image = null
	_message.text = ""
	_mode = Mode.WALK
	var flags := func() -> void:
		for a in range(0x4900, 0x5300):
			_vm.write_byte(a, s[1 + 2 * (a - 0x4900)])
	flags.call()
	_vm.write_byte(EclVM.PARTY_X, s[0x3201])
	_vm.write_byte(EclVM.PARTY_Y, s[0x3202])
	_vm.write_byte(EclVM.PARTY_DIR, s[0x3203] / 2)
	_enter_script(set_no, block_id, true, false)
	# Back to the saved state after the area's init: flags, the script's tables, the square.
	flags.call()
	var code_len := EclScript.decode(ecl.blocks[block_id]).code.size()
	for i in code_len:
		_vm.mem[EclScript.BASE + i] = s[0x1401 + i]
	# The original runs the saved image, so run that rather than the block as shipped.
	_vm.ecl = EclScript.decode(s.slice(0x1401, 0x1401 + code_len))
	_pos = Vector2i(s[0x3201] & 15, s[0x3202] & 15)
	_facing = ((s[0x3203] / 2) & 3) as DungeonView.Dir
	_sync_position_to_vm(_facing)
	_vm.state = EclVM.State.DONE
	_status.text = "Loaded saved game %s." % letter.to_upper()
	_show()
	return true


func _quick_load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_save_path()) != OK:
		_status.text = "No quick save yet (F2 in walk mode saves)."
		return
	var map_file: String = cfg.get_value("place", "map_file", "")
	var map_id: int = cfg.get_value("place", "map_id", -1)
	var index := -1
	for i in _maps.size():
		if _maps[i].file == map_file and _maps[i].id == map_id:
			index = i
	if index < 0:
		_status.text = "Quick save names a map that isn't here."
		return
	# Stop anything in progress.
	_timer.stop()
	_busy = false
	_walk_path.clear()
	_held_message = ""
	_pending_move = -1
	_event_image = null
	_message.text = ""
	if _shop.visible:
		_shop.visible = false
	# Place and script.
	_mode = Mode.WALK
	_map_index = index
	_walls_for = -1
	_pos = Vector2i(cfg.get_value("place", "x", 8), cfg.get_value("place", "y", 8))
	_automap.from_save(cfg.get_value("qol", "visited", {}))
	_facing = int(cfg.get_value("place", "facing", 0)) as DungeonView.Dir
	_vm_file = cfg.get_value("script", "file", 0)
	_vm_block = cfg.get_value("script", "block", -1)
	var ecl := DaxFile.open(_game_path.path_join("ECL%d.DAX" % _vm_file))
	if ecl != null and ecl.blocks.has(_vm_block):
		_vm.load_script(ecl.blocks[_vm_block], "%d:%d" % [_vm_file, _vm_block])
	var memory: PackedByteArray = cfg.get_value("script", "memory", PackedByteArray())
	if memory.size() == _vm.mem.size():
		_vm.mem = memory
	var wild: Array = cfg.get_value("script", "overland", [false, 0])
	_vm.on_overland = wild[0]
	_vm.overland_band = wild[1]
	_vm.state = EclVM.State.DONE
	_vm.clear_output()
	_vm.sprite_id = -1
	_vm_map = _map_index
	_sync_position_to_vm(_facing)
	# Party: whole records where the save has them (levels, trained values, party changes),
	# then money and items as saved.
	var members: Array = cfg.get_value("party", "members", [])
	if not members.is_empty() and (members[0] as Dictionary).has("record"):
		var rebuilt: Array[PartyMember] = []
		for saved in members:
			rebuilt.append(PartyMember.from_bytes(saved.record, PackedByteArray()))
		_party.assign(rebuilt)
	_party_menu.roster.clear()
	for saved in cfg.get_value("party", "roster", []):
		var r := PartyMember.from_bytes(saved.record, PackedByteArray())
		r.items = _items_from(saved.get("items", []))
		r.affects = saved.get("affects", [])
		SpecialAffects.add(r, SpecialAffects.RACIAL.get(r.race_id, []))
		r.recalculate(_types)
		_party_menu.roster.append(r)
	for i in mini(members.size(), _party.size()):
		var saved: Dictionary = members[i]
		_party[i].money = saved.get("money", _party[i].money)
		_party[i].hp = saved.get("hp", _party[i].hp)
		_party[i].experience = saved.get("experience", _party[i].experience)
		_party[i].status = saved.get("status", _party[i].status)
		_party[i].npc = saved.get("npc", 0)
		if saved.has("memorized"):
			var mem: Array[int] = []
			for v in saved.memorized:
				mem.append(int(v))
			_party[i].memorized = mem
			_party[i].spell_book = saved.get("spell_book", _party[i].spell_book)
			_party[i].affects = saved.get("affects", [])
			SpecialAffects.add(_party[i], SpecialAffects.RACIAL.get(_party[i].race_id, []))
		_party[i].items = _items_from(saved.get("items", []))
		_party[i].recalculate(_types)
	_status.text = "Loaded."
	_show()


func _items_from(records: Array) -> Array[GameItem]:
	var items: Array[GameItem] = []
	var names := ItemNames.shared(_game_path)
	for rec in records:
		var it := GameItem.from_record(rec)
		if it.name == "":
			it.name = names.name_of(it)
		items.append(it)
	return items


## A step: the area's on-move script runs first (it can refuse the move, e.g. a locked
## door), then the party moves and the on-step script runs for the new square.
func _try_move(direction: int) -> void:
	_event_image = null
	_message.text = ""
	if _vm.on_overland:
		_overland_move(direction)
		return
	if _vm.ecl != null:
		var map: GeoMap = _maps[_map_index].map
		_sync_position_to_vm(direction)
		_vm.write_byte(EclVM.WALL_AHEAD, map.wall(_pos.x, _pos.y, direction))
		_vm.write_byte(EclVM.MOVEMENT_BLOCK, 0)
		# A step that would leave the map (through an open side or a door on the edge): the
		# area's on-move script sees 0x6DD5 set and moves the party into the next area.
		var next := _pos + DungeonView.DELTA[direction]
		var open := map.wall(_pos.x, _pos.y, direction) == 0 or map.door(_pos.x, _pos.y, direction) != 0
		var off := next.x < 0 or next.y < 0 or next.x >= GeoMap.SIZE or next.y >= GeoMap.SIZE
		_vm.write_byte(EclVM.LEAVING_MAP, 1 if off and open else 0)
		_vm.clear_output()
		_vm.start(0)
		_pending_move = direction
		_after_vm()
		return
	_finish_move(direction)


## The original's locked doors (door type 2 locked, 3 wizard-locked): a menu of what the
## party can try. 0x6DDE-0x6DE0 hold whether BASH, PICK and KNOCK may still be tried here;
## a step resets them. One try per choice; success opens the door (both sides) and steps
## through it. A door where nothing is left to try turns into a plain wall.
const DOOR_TRY_BASH := 0x6DDE
const DOOR_TRY_PICK := 0x6DDF
const DOOR_TRY_KNOCK := 0x6DE0
const KNOCK := 31


func _locked_door(direction: int) -> void:
	var map: GeoMap = _maps[_map_index].map
	var kind := map.door(_pos.x, _pos.y, direction)
	var any_class := func(c: int) -> bool:
		for m in _party:
			if (m as PartyMember).level_in(c) > 0:
				return true
		return false
	var options := ""
	if _vm.read_byte(DOOR_TRY_BASH) != 0:
		options += "B"
	if _vm.read_byte(DOOR_TRY_PICK) != 0 and any_class.call(6):
		options += "P"
	if _vm.read_byte(DOOR_TRY_KNOCK) != 0 and (any_class.call(5) if kind == 3 else _knock_caster() != null):
		options += "K"
	if options == "":
		map.set_door(_pos.x, _pos.y, direction, 0)
		return
	_door_options = options + "E"
	_door_side = direction
	var words := {"B": "BASH", "P": "PICK", "K": "KNOCK", "E": "EXIT"}
	var line := "LOCKED."
	for c in _door_options:
		line += " " + words[c]
	_message.text = line


var _door_retry := false
var _door_tries := {}   # the tour's tries at each locked door (map,x,y,side)


func _knock_caster() -> PartyMember:
	for m in _party:
		if (m as PartyMember).memorized.has(KNOCK):
			return m
	return null


func _door_choice(c: String) -> void:
	if not _door_options.contains(c):
		return
	var map: GeoMap = _maps[_map_index].map
	var kind := map.door(_pos.x, _pos.y, _door_side)
	var direction := _door_side
	_door_options = ""
	_message.text = ""
	var opened := false
	match c:
		"B":
			# Every member in turn tries (strength, as the open-doors roll), until one does it.
			for m in _party:
				var pm := m as PartyMember
				var st := pm.stats[0]
				var ex := pm.strength_exceptional
				var r6 := _door_rng.randi_range(1, 6)
				if kind == 3:
					if st == 18 and ex >= 91 and ex <= 99:
						opened = r6 == 1
					elif st == 18 and ex == 100:
						opened = r6 <= 2
					elif st == 19 or st == 20:
						opened = r6 <= 3
					elif st == 21 or st == 22:
						opened = r6 <= 4
					elif st == 23:
						opened = r6 <= 5
					elif st == 24:
						opened = _door_rng.randi_range(1, 8) <= 7
					elif st >= 25:
						opened = true
					else:
						_vm.write_byte(DOOR_TRY_BASH, 0)
				else:
					if st >= 3 and st <= 7:
						opened = r6 == 1
					elif st >= 8 and st <= 15:
						opened = r6 <= 2
					elif st >= 16 and st <= 17:
						opened = r6 <= 3
					elif st == 18 and ex <= 50:
						opened = r6 <= 3
					elif st == 18 and ex <= 99:
						opened = r6 <= 4
					elif st == 18:
						opened = r6 <= 5
				if opened:
					break
		"P":
			_vm.write_byte(DOOR_TRY_PICK, 0)
			if kind == 2:
				for m in _party:
					var pm := m as PartyMember
					if _door_rng.randi_range(1, 100) <= pm.thief_skill(ClassTables.shared(_game_path), 1) and pm.status == 0:
						opened = true
						break
		"K":
			var caster := _knock_caster()
			if caster != null:
				caster.memorized.erase(KNOCK)
				opened = true
	if not opened:
		_show()
		return
	map.set_door(_pos.x, _pos.y, direction, 1)
	var next := _pos + DungeonView.DELTA[direction]
	next = Vector2i(posmod(next.x, GeoMap.SIZE), posmod(next.y, GeoMap.SIZE))
	map.set_door(next.x, next.y, (direction + 2) % 4, 1)
	_step_into(next)


## Completes a move once the on-move script has finished without refusing it.
func _finish_move(direction: int) -> void:
	_pending_move = -1
	if _vm.read_byte(EclVM.MOVEMENT_BLOCK) == 255:
		return
	if _vm.on_overland:
		_overland_step(direction)
		return
	var map: GeoMap = _maps[_map_index].map
	# A wall blocks unless it carries a door.
	if map.wall(_pos.x, _pos.y, direction) > 0 and map.door(_pos.x, _pos.y, direction) == 0:
		return
	if map.wall(_pos.x, _pos.y, direction) > 0 and map.door(_pos.x, _pos.y, direction) >= 2:
		_locked_door(direction)
		return
	var next := _pos + DungeonView.DELTA[direction]
	if next.x < 0 or next.y < 0 or next.x >= GeoMap.SIZE or next.y >= GeoMap.SIZE:
		return
	_step_into(next)


## The step itself, once nothing stops it: time passes and the new square's event runs.
func _step_into(next: Vector2i) -> void:
	_vm.write_byte(DOOR_TRY_BASH, 1)
	_vm.write_byte(DOOR_TRY_PICK, 1)
	_vm.write_byte(DOOR_TRY_KNOCK, 1)
	# The original keeps the square left behind at 0x49F0/0x49F1 (lab, chat 10: saves F and
	# G after steps 13,9 -> 13,8 and 13,8 -> 13,9); scripts move the party back to it.
	_vm.write_byte(EclVM.PREVIOUS_X, _pos.x)
	_vm.write_byte(EclVM.PREVIOUS_Y, _pos.y)
	_pos = next
	_pass_time(GameClock.TEN_MINUTES if _searching else GameClock.MINUTE, 1)
	if _vm.ecl != null:
		_sync_position_to_vm(_facing)
		_vm.clear_output()
		_vm.start(1)
		_after_vm()


var _synced := Vector3i(-1, -1, -1)   # x, y, direction last written to the VM


## A step in the wilderness (see OverlandMap): the band's on-move script may refuse it or
## take the party into the next band; then the map itself decides.
func _overland_move(direction: int) -> void:
	_facing = direction as DungeonView.Dir
	_vm.write_byte(EclVM.PARTY_DIR, direction)
	_vm.write_byte(EclVM.OVERLAND_HEADING, direction * 2)
	_vm.write_byte(EclVM.MOVEMENT_BLOCK, 0)
	if _vm.ecl == null:
		_overland_step(direction)
		return
	_vm.clear_output()
	_vm.start(0)
	_pending_move = direction
	_after_vm()


func _overland_step(direction: int) -> void:
	var ov := _vm.overland
	var x := clampi(_vm.read_byte(EclVM.OVERLAND_X) + DungeonView.DELTA[direction].x, 0, 15)
	var y := clampi(_vm.read_byte(EclVM.OVERLAND_Y) + DungeonView.DELTA[direction].y, 0, OverlandMap.HEIGHT - 1)
	var v := ov.value(x + ov.band_x(_vm.overland_band), y)
	# Water stops the party; so does the poisoned river until 0x4AA2 is set. The original
	# has a line for the river ("The river's stench drives you back.") but the lab shows
	# no text on screen, so none here either.
	if OverlandMap.water(v) or (OverlandMap.river(v) and _vm.read_byte(0x4AA2) == 0):
		return
	_vm.write_byte(EclVM.OVERLAND_X, x)
	_vm.write_byte(EclVM.OVERLAND_Y, y)
	_pass_time(GameClock.HOUR, 12)
	if _vm.ecl != null:
		_vm.clear_output()
		_vm.start(1)
		_after_vm()


## The wilderness screen's view: the 5x5 squares around the party and the party's mark.
func _overland_view() -> Image:
	var ov := _vm.overland
	var x := _vm.read_byte(EclVM.OVERLAND_X) + ov.band_x(_vm.overland_band)
	var img := ov.view(x, _vm.read_byte(EclVM.OVERLAND_Y), _vm.read_byte)
	# The party's mark. The original draws a mounted party here; where it keeps that
	# picture is not found yet, so a plain marker stands in.
	for k in range(4, 20):
		for p in [Vector2i(48 + k, 52), Vector2i(48 + k, 67), Vector2i(52, 48 + k), Vector2i(67, 48 + k)]:
			if p.x >= 52 and p.x <= 67 and p.y >= 52 and p.y <= 67:
				img.set_pixelv(p, GameScreen.EGA[15])
	return img


func _overland_place() -> String:
	var x := _vm.read_byte(EclVM.OVERLAND_X) + _vm.overland.band_x(_vm.overland_band)
	return "%d,%d %s %s" % [x, _vm.read_byte(EclVM.OVERLAND_Y), "NESW"[_facing], GameClock.text(_vm)]


func _sync_position_to_vm(direction: int) -> void:
	var map: GeoMap = _maps[_map_index].map
	_vm.write_byte(EclVM.PARTY_X, _pos.x)
	_vm.write_byte(EclVM.PARTY_Y, _pos.y)
	_vm.write_byte(EclVM.PARTY_DIR, direction)
	_vm.write_byte(EclVM.SQUARE_INFO, map.flag(_pos.x, _pos.y))
	_synced = Vector3i(_pos.x, _pos.y, direction)


## Scripts can move the party (a guided tour, a trap door): adopt what they wrote.
## A target reachable on foot is walked to step by step, as the original does; anything
## else is a jump.
## A script that loads another map of the area part way through (Kuto's Well: down the rungs
## to the catacombs, LOAD_AREA_MAP 32; up again, 29) moves the party onto that map, as an
## area's init does (_enter_script).
func _follow_area_map() -> void:
	if _vm.on_overland or _vm.area_map.is_empty() or _vm.area_map == _area_map_seen:
		return
	_area_map_seen = _vm.area_map.duplicate()
	if int(_vm.area_map[0]) >= 127:
		return
	for i in _maps.size():
		if _maps[i].id == int(_vm.area_map[0]):
			if i != _map_index:
				_map_index = i
				_vm_map = i
				_walls_for = -1
				_jump_next = true
			return


var _area_map_seen := []


func _adopt_position_from_vm() -> void:
	var now := Vector3i(_vm.read_byte(EclVM.PARTY_X), _vm.read_byte(EclVM.PARTY_Y), _vm.read_byte(EclVM.PARTY_DIR))
	if now == _synced or _vm.state == EclVM.State.NEW_ECL:
		return
	var moved := now.x != _synced.x or now.y != _synced.y
	var turned := now.z != _synced.z and now.z < 4
	_synced = now
	if now.x >= GeoMap.SIZE or now.y >= GeoMap.SIZE:
		return
	var target := Vector2i(now.x, now.y)
	var walk := moved and not _jump_next and _mode == Mode.WALK and _vm_map == _map_index
	_jump_next = false
	if walk:
		var path := _find_path(_pos, target)
		if path.size() > 1:
			_walk_path = path.slice(1)
			_walk_final_dir = now.z if turned else _facing
			_busy = true
			_timer.start(WALK_STEP_SECONDS)
			return
	if moved:
		_pos = target
	if turned:
		_facing = now.z as DungeonView.Dir


## Shortest walk between two squares (walls stop you unless they carry a door).
func _find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var map: GeoMap = _maps[_map_index].map
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == to:
			break
		for d in 4:
			if map.wall(cur.x, cur.y, d) > 0 and map.door(cur.x, cur.y, d) == 0:
				continue
			if _refused.has("%d:%d,%d,%d" % [_map_index, cur.x, cur.y, d]):
				continue
			var nxt: Vector2i = cur + DungeonView.DELTA[d]
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= GeoMap.SIZE or nxt.y >= GeoMap.SIZE or came.has(nxt):
				continue
			came[nxt] = cur
			queue.append(nxt)
	var path: Array[Vector2i] = []
	if not came.has(to):
		return path
	var p := to
	while p != from:
		path.push_front(p)
		p = came[p]
	path.push_front(from)
	return path


func _on_timer() -> void:
	if not _walk_path.is_empty():
		# One step of a script-driven walk: face the way you go, then step.
		var next: Vector2i = _walk_path.pop_front()
		var delta := next - _pos
		var d := DungeonView.DELTA.find(delta)
		if d >= 0:
			_facing = d as DungeonView.Dir
		_pos = next
		if _walk_path.is_empty():
			_facing = _walk_final_dir as DungeonView.Dir
			_sync_position_to_vm(_facing)
			_busy = false
			if _held_message != "":
				_message.text = _held_message
				_held_message = ""
			if _vm.state == EclVM.State.WAIT:
				_busy = true
				_timer.start(DELAY_SECONDS * CampScreen.delay_scale())
		else:
			_timer.start(WALK_STEP_SECONDS)
		_show()
		return
	# End of a script DELAY: an approaching figure that has arrived becomes its portrait.
	_busy = false
	if _vm.sprite_id >= 0 and _vm.sprite_distance == 0:
		_event_image = _event_picture(_vm.sprite_head, _vm.sprite_picture)
		_vm.sprite_id = -1
	_vm.resume()
	_after_vm()
	_show()


## Shows what a script run produced and carries on with whatever it was waiting for.
func _after_vm() -> void:
	_follow_area_map()
	if not _vm.npc_requests.is_empty():
		_add_npcs()
	if _vm.party_changed:
		_vm.party_changed = false
		for m in _party:
			m.recalculate(_types)
	if _vm.minutes_passed > 0:
		_show_time_news(SpellCaster.pass_time(_party, _vm.minutes_passed))
		_vm.minutes_passed = 0
	if _vm.text_changed:
		# PRINT_CLEAR "" clears the box, as between the stops of Rolf's tour.
		_message.text = _vm.text
		_vm.text_changed = false
	if _vm.picture >= 0:
		_event_image = null if _vm.picture == 255 else _event_picture(_vm.picture_head, _vm.picture)
		if _vm.picture_head != 255 and not CampScreen.show_portraits:
			_event_image = null   # ALTER PICS: PORTRAITS OFF
		_vm.picture = -1
	if not _vm.notes.is_empty():
		_message.text += "\n[not built yet: %s]" % ", ".join(_vm.notes)
		_vm.notes = []
	_adopt_position_from_vm()
	if not _walk_path.is_empty() and _held_message == "":
		# Show the text once the walk arrives.
		_held_message = _message.text
		_message.text = ""
	match _vm.state:
		EclVM.State.WAIT:
			if not _busy:
				_busy = true
				_timer.start(DELAY_SECONDS * CampScreen.delay_scale())
			return
		EclVM.State.MENU:
			var lines := PackedStringArray()
			for i in _vm.menu.size():
				lines.append(("%d) %s" % [i + 1, _vm.menu[i]]) if _vm.menu.size() > 1 else "Enter) %s" % _vm.menu[i])
			var options := "\n\n" + "    ".join(lines)
			if _held_message != "":
				_held_message += options
			else:
				_message.text += options
			return
		EclVM.State.SHOP:
			_open_shop()
			return
		EclVM.State.TEMPLE:
			for m in _party:
				m.recalculate(_types)
			_temple.open(_party)
			return
		EclVM.State.COMBAT:
			_start_event_fight()
			return
		EclVM.State.PROGRAM:
			_run_program()
			return
		EclVM.State.INPUT:
			_typed.text = ""
			_typed.max_length = _vm.input_max
			_typed.placeholder_text = "a number, then Enter" if _vm.input_numeric else "type, then Enter"
			_typed.visible = true
			_typed.grab_focus()
			return
		EclVM.State.NEW_ECL:
			# 0x6E12 names the data set (ECLn/GEOn...) the next block lives in.
			var set_no := _vm.read_byte(EclVM.FILE_SET)
			_enter_script(set_no if set_no >= 1 and set_no <= 8 else _vm_file, _vm.new_ecl, true, true)
			return
		EclVM.State.ERROR:
			_message.text += "\n[script error: %s]" % _vm.error
	if _pending_move >= 0 and _vm.state == EclVM.State.DONE:
		_finish_move(_pending_move)


## NPC_ADD: the monster record joins the party as an NPC (the computer runs them in
## fights; control 128 + morale / 2). The original takes up to 8 in the party.
func _add_npcs() -> void:
	for req in _vm.npc_requests:
		if _party.size() >= 8:
			break
		var m := PartyMember.load_monster(_game_path, maxi(_vm_file, 1), int(req[0]))
		if m == null:
			continue
		m.is_monster = false
		m.npc = 128 + int(req[1]) / 2
		m.recalculate(_types)
		_party.append(m)
		_vm.selected = _party.size() - 1
	_vm.npc_requests = []


## PROGRAM n from a script: 0 the party menu (training halls), 9 camp (the inns; the
## script ends there, as in the original), 8 the end of the game, 3 the party is lost.
func _run_program() -> void:
	match _vm.program:
		0:
			for m in _party:
				m.recalculate(_types)
			_party_menu.tables = ClassTables.shared(_game_path)
			_party_menu.spells = SpellTable.shared(_game_path)
			_party_menu.types = _types
			_party_menu.game_path = _game_path
			_party_menu.open(_party, _vm.read_byte(EclVM.TRAINING_MASK))
		9:
			_vm.close_program()
			_make_camp()
		3:
			_vm.close_program()
			_party_lost()
		8:
			# Tyranthraxus is beaten: the closing pictures and words, then the script goes on.
			if _ending == null:
				_ending = EndingScreen.new()
				add_child(_ending)
				_ending.finished.connect(func() -> void:
					_vm.close_program()
					_after_vm()
					_show())
			_ending.open(_game_path)
		_:
			_vm.close_program()
			_after_vm()


func _on_party_menu_closed() -> void:
	for m in _party:
		m.recalculate(_types)
	if _starting_party:
		_starting_party = false
		_new_game()
		_show()
		return
	_vm.write_byte(EclVM.TRAINING_MASK, 0)
	_message.text = ""
	_vm.close_program()
	_after_vm()
	_show()


## Opens the shop for the script's TREASURE item list.
func _open_shop() -> void:
	var list_id: int = _vm.treasure[_vm.treasure.size() - 1] if not _vm.treasure.is_empty() else 255
	var stock := _item_list(list_id)
	# As the original's shop lists them (lab, chat 10, New Phlan's arms shop): names built
	# from the name words, plural with the count ("4 DARTS", the record says "4 Dart"), and
	# a price of 0 shown as 1 ("10 ARROWS 1", "4 DARTS 1").
	var names := ItemNames.shared(_game_path)
	for it in stock:
		it.name = names.name_of(it)
		if it.price == 0:
			it.price = 1
	_shop.open(stock, _party)


## A TREASURE item list: an ITEM<n>.DAX block (this area's file first), in reverse of
## stored order, as the original lists it. 255 = none.
func _item_list(list_id: int) -> Array[GameItem]:
	var items: Array[GameItem] = []
	if list_id == 255:
		return items
	var order := [_vm_file]
	for n in range(1, 9):
		if n != _vm_file:
			order.append(n)
	for n in order:
		var name := "ITEM%d.DAX" % n
		if not _dax_cache.has(name):
			_dax_cache[name] = DaxFile.open(_game_path.path_join(name))
		var dax: DaxFile = _dax_cache[name]
		if dax != null and dax.blocks.has(list_id):
			items = GameItem.list_from(dax.blocks[list_id])
			items.reverse()
			break
	var names := ItemNames.shared(_game_path)
	for it in items:
		if it.name == "":
			it.name = names.name_of(it)
	return items


## Encamp: the area's "on rest" script sets how often resting may be interrupted.
func _make_camp() -> void:
	if not _vm.state in [EclVM.State.IDLE, EclVM.State.DONE, EclVM.State.ERROR]:
		_status.text = "Can't make camp in the middle of an event; finish it first."
		return
	_vm.write_byte(REST_PERIOD, 0)
	_vm.write_byte(REST_PERCENT, 0)
	if _vm.ecl != null:
		_sync_position_to_vm(_facing)
		_vm.clear_output()
		_vm.start(2)
	for m in _party:
		m.recalculate(_types)
	_camp.spells = SpellTable.shared(_game_path)
	_camp.place = _place_line()
	_camp.open(_party, _vm.read_byte(REST_PERIOD), _vm.read_byte(REST_PERCENT))


func _on_temple_closed() -> void:
	_message.text = ""
	_vm.close_temple()
	_after_vm()
	_show()


func _on_camp_closed() -> void:
	GameClock.add_minutes(_vm, _camp.minutes_passed)   # the camp has already run the effects
	_show()


## Rest was interrupted: the area's "rest interrupted" script runs (usually an encounter).
func _on_rest_interrupted() -> void:
	GameClock.add_minutes(_vm, _camp.minutes_passed)
	_camp.minutes_passed = 0
	if _vm.ecl != null:
		_vm.clear_output()
		_vm.start(3)
		_after_vm()
	_show()


## Open squares ahead of the party (0..2), as the encounter menu measures distance.
func _open_ahead() -> int:
	var map: GeoMap = _maps[_map_index].map
	var field := Battlefield.build(map, _pos.x, _pos.y)
	return Placement.encounter_distance(field, _pos.x, _pos.y, int(_facing), 2)


## Game time passes outside camp and combat: the clock moves and everyone's spell effects
## run down with it.
func _pass_time(slot: int, amount: int) -> void:
	var minutes := GameClock.advance(_vm, slot, amount)
	_show_time_news(SpellCaster.pass_time(_party, minutes))


## Lines from effects that ran their course as time passed ("ROTS...").
func _show_time_news(news: PackedStringArray) -> void:
	if not news.is_empty():
		_message.text = "\n".join(news)


## Runs the fight an event script asked for, then lets the script carry on. A COMBAT with
## treasure but no monsters is a treasure find: straight to the treasure.
func _start_event_fight() -> void:
	_fight_treasure = _vm.treasure.duplicate()
	# CALL 0x8000 (the arena): the opponent is a copy of the duelist, as GAME.OVR builds it
	# (overlay at file 0x74D3, routine +0x1A6F): the whole record and its items copied,
	# named ROLF, no money, morale 0xB2, drawn as combat picture 11. Lab 2026-11-11: ROLF
	# shows the duelist's HP, AC and weapon (14, 1, FLAIL for Thrender Grone).
	var opponents: Array[PartyMember] = []
	_arena = false
	if _vm.duel == 1 and _vm.selected >= 0 and _vm.selected < _party.size():
		_arena = true
		var copy := _party[_vm.selected].clone()
		copy.name = "ROLF"
		copy.is_monster = true
		copy.set_meta("arena_double", true)
		for k in copy.money.size():
			copy.money[k] = 0
		if copy.raw.size() > 0x84:
			copy.raw[0x84] = 0xB2
			copy.morale = 0xB2
		copy.recalculate(_types)
		opponents.append(copy)
	if _vm.monsters.is_empty() and opponents.is_empty():
		_after_fight([], "THE PARTY HAS FOUND TREASURE!")
		return
	for m in _party:
		m.recalculate(_types)
	var map: GeoMap = _maps[_map_index].map
	# CALL 0x8000 / 0x8001: a duel; only the member WHO picked fights.
	var fighters: Array[PartyMember] = _party
	_duelist = null
	if _vm.duel != 0 and _vm.selected >= 0 and _vm.selected < _party.size():
		_duelist = _party[_vm.selected]
		fighters = [_duelist]
	_vm.duel = 0
	_combat.open_event(_game_path, map, _pos.x, _pos.y, int(_facing), fighters, maxi(_vm_file, 1),
		_vm.monsters, _vm.encounter_max, _vm.encounter_advances,
		_vm.read_byte(EclVM.MORALE_BASE), _vm.read_byte(EclVM.AMBUSH), opponents, _vm.monster_teams)


var _duelist: PartyMember = null
var _arena := false
var _ending: EndingScreen


## Hirelings take their cut of the coins before the party sees them, as the original does
## (GAME.OVR, before the treasure screen): every conscious member whose record byte 0x84
## has bit 7 set (a hired NPC) counts (0x85 & 7) shares, everyone else one; from each kind
## of coin each hireling's shares of (pool / total shares) leave with them. Returns the
## original's lines ("<NAME> takes and hides his share.").
func _hirelings_take_shares(spoils: Spoils) -> String:
	var shares := 0
	var total := 0
	var who := PackedStringArray()
	for m in _party:
		var r: PackedByteArray = m.raw
		if r.size() > 0x85 and r[0x84] > 0x7F and m.status == 0:
			shares += r[0x85] & 7
			total += r[0x85] & 7
			if r[0x85] > 0:
				who.append("%s takes and hides his share." % m.name)
		else:
			total += 1
	if shares == 0 or total == 0:
		return ""
	var took := false
	for k in spoils.money.size():
		if spoils.money[k] > 0:
			spoils.money[k] -= (spoils.money[k] / total) * shares
			took = true
	return "\n".join(who).to_upper() if took else ""


func _on_event_fight_finished(result: int) -> void:
	GameClock.add_minutes(_vm, _combat.rounds())   # a minute a round; effects ran in the fight
	if result == 3 or (result == 2 and _duelist != null):
		# The party ran (or the duelist lost): the script goes on with 0x6DC7 = 129.
		_duelist = null
		_fight_treasure = []
		_vm.end_combat(129)
		_after_vm()
		_show()
		return
	if result == 2:
		_party_lost()
		return
	if _arena and _duelist != null:
		# The arena (lab 2026-11-11): no experience for the double and none of its gear;
		# the duelist gets 100 experience per level (Thrender Grone, a 2nd-level fighter,
		# 200; Bakshi, 1st level in three classes, 100).
		_arena = false
		var top := 1
		for c in 8:
			top = maxi(top, _duelist.level_in(c))
		_duelist.experience += 100 * top
		_after_fight([], "YOU HAVE WON THE DUEL.\n\nTHE DUELIST RECEIVES %d\n\nEXPERIENCE POINTS." % (100 * top))
		return
	_after_fight(_combat.defeated(), "THE PARTY HAS WON.", _combat.dropped_items())


## Experience and treasure: from the defeated monsters and the event's TREASURE, then the
## results and treasure screens; the script carries on when they close.
func _after_fight(defeated: Array, won_text: String, field_items: Array[GameItem] = []) -> void:
	var coins := []
	var list_id := 255
	if _fight_treasure.size() >= 8:
		coins = _fight_treasure.slice(0, 7)
		list_id = int(_fight_treasure[7])
	var found := _item_list(list_id)
	found.append_array(field_items)
	var spoils := Spoils.gather(defeated, coins, found)
	var hidden := _hirelings_take_shares(spoils)
	if hidden != "":
		won_text += "\n" + hidden
	var standing: Array = []
	for m in _party:
		if m.can_fight() and (_duelist == null or m == _duelist):
			standing.append(m)
	_duelist = null
	var share := spoils.award(standing)
	for m in _party:
		m.recalculate(_types)
	_treasure.picture = _event_picture(255, 1)     # the chest (lab: PIC block 1)
	_treasure.open(spoils, _party, won_text, share)


func _on_treasure_closed() -> void:
	for m in _party:
		m.recalculate(_types)
	_fight_treasure = []
	_message.text = ""
	_vm.end_combat(0)
	_after_vm()
	_show()


## Every monster record in MON1CHA..MON8CHA, for the monster sheets.
func _all_monsters() -> Array[PartyMember]:
	var out: Array[PartyMember] = []
	for n in range(1, 9):
		var path := _game_path.path_join("MON%dCHA.DAX" % n)
		if not FileAccess.file_exists(path):
			continue
		var dax := DaxFile.open(path)
		for id in dax.ids():
			var m := PartyMember.load_monster(_game_path, n, id)
			if m != null:
				m.name = "%s  (MON%d block %d)" % [m.name, n, id]
				m.recalculate(_types)
				out.append(m)
	return out


func _on_shop_closed() -> void:
	for m in _party:
		m.recalculate(_types)
	_message.text = ""
	_vm.close_shop()
	_after_vm()
	_show()


## Loads the event script for the current map (when it changes) and runs its init.
func _ensure_area_script() -> void:
	if _vm_map == _map_index:
		return
	_vm_map = _map_index
	var e: Dictionary = _maps[_map_index]
	var file_no := int(String(e.file).trim_prefix("GEO").trim_suffix(".DAX"))
	var ecl := DaxFile.open(_game_path.path_join("ECL%d.DAX" % file_no))
	var block_id := -1
	if ecl != null:
		if ecl.blocks.has(e.id):
			block_id = e.id
		else:
			for id in ecl.ids():
				if _script(file_no, id, ecl).loads_map(e.id):
					block_id = id
					break
	if block_id < 0:
		_vm.ecl = null
		return
	_enter_script(file_no, block_id, false)


## Switches to another ECL block (NEW_ECL or area change) and runs its init.
func _enter_script(file_no: int, block_id: int, follow_map: bool = true, arrive: bool = false) -> void:
	var ecl := DaxFile.open(_game_path.path_join("ECL%d.DAX" % file_no))
	if ecl == null or not ecl.blocks.has(block_id):
		# Look in the other script files.
		ecl = null
		for n in range(1, 9):
			var other := DaxFile.open(_game_path.path_join("ECL%d.DAX" % n))
			if other != null and other.blocks.has(block_id):
				ecl = other
				file_no = n
				break
	if ecl == null:
		_message.text += "\n[script %d not found]" % block_id
		_vm.ecl = null
		return
	_vm_file = file_no
	_vm_block = block_id
	# Only a step through the map's edge (the leaving script's CALL 0xC01E) carries on; a
	# jump straight to a square (boats, gates, the lab's saves) lands on it (lab, chat 8: a
	# save jumping to New Phlan 13,9 N lands there in the original, no minute passing).
	var carry := _pending_move if arrive and _vm.stepped_through else -1
	_vm.stepped_through = false
	if arrive:
		# The leaving script may have moved the party (CALL 0xC01E steps through the edge).
		_pos = Vector2i(_vm.read_byte(EclVM.PARTY_X) & 15, _vm.read_byte(EclVM.PARTY_Y) & 15)
		_facing = (_vm.read_byte(EclVM.PARTY_DIR) & 3) as DungeonView.Dir
	_vm.load_script(ecl.blocks[block_id], "%d:%d" % [file_no, block_id])
	# Entering an area zeroes ECL 0x4A00-0x4A1F, the scripts' per-visit bytes (the Slums'
	# greeting 0x4A00, Sokal Keep's dead elf, City Hall's "visited this time" 0x4A01 that
	# keeps the clerk from looking for rewards). 0x4A20-0x4AFF carries over from area to
	# area. Lab, chat 8: a save with 0x4A01-0x4A3F all 0x11, entering New Phlan from the
	# Slums, saved again: 0x4A00-0x4A1F were 0 (0x4A17 = 1, set by New Phlan's init) and
	# 0x4A20-0x4A3F still 0x11; leaving City Hall and coming back made the clerk check for
	# rewards again. Chat 6's evidence agrees (Kuto's Well's 0x4A23 survived trips away).
	# A loaded save writes its own values back.
	for a in range(0x4A00, 0x4A20):
		_vm.write_byte(a, 0)
	if arrive:
		_vm.write_byte(EclVM.MOVEMENT_BLOCK, 0)     # the leaving script's stop doesn't carry over
	_sync_position_to_vm(_facing)
	_jump_next = true
	_vm.clear_output()
	_vm.area_map = []
	_vm.start(4)
	# The original writes the area's block number to 0x49F2 once its init has run (GAME.OVR
	# 0x192F, 0x40D6); many inits test it ("already here": a loaded game) and then skip
	# placing the party, resetting the clock and the like.
	_vm.write_byte(CURRENT_BLOCK, block_id)
	# The init script may load a different map and place the party.
	if follow_map and not _vm.on_overland and not _vm.area_map.is_empty() and _vm.area_map[0] < 127:
		for i in _maps.size():
			if _maps[i].id == _vm.area_map[0]:
				_map_index = i
				# Loading the area again brings back its doors as the data has them (a bashed
				# door stays open only until then, as in the original).
				_maps[i].map = GeoMap.decode(_maps[i].block)
				_vm_map = i
				break
	_area_map_seen = _vm.area_map.duplicate()
	_pos = Vector2i(_vm.read_byte(EclVM.PARTY_X) & 15, _vm.read_byte(EclVM.PARTY_Y) & 15)
	_facing = (_vm.read_byte(EclVM.PARTY_DIR) & 3) as DungeonView.Dir
	_synced = Vector3i(_pos.x, _pos.y, int(_facing))
	_walls_for = -1
	_pending_move = -1
	_vm.write_byte(EclVM.LEAVING_MAP, 0)
	for a in [DOOR_TRY_BASH, DOOR_TRY_PICK, DOOR_TRY_KNOCK]:
		_vm.write_byte(a, 1)
	if arrive and _vm.state in [EclVM.State.DONE, EclVM.State.IDLE]:
		# As in the original, the square arrived on runs its event (New Phlan's gateway
		# text when coming in from the Slums).
		_sync_position_to_vm(_facing)
		var keep := _vm.text
		_vm.start(1)
		if _vm.text == "" and not _vm.text_changed:
			_vm.text = keep
		# The step that crossed the edge carries on into the new area when nothing there
		# stops it: the original lands one square further in, a minute later (lab, chat 6:
		# Slums 0,4 west arrives in Kuto's Well at 14,4, not 15,4), but stays on the edge
		# square when the arrival shows something (the Slums' greeting).
		if carry >= 0 and _vm.state in [EclVM.State.DONE, EclVM.State.IDLE] \
				and _vm.text.strip_edges() == "" and not _vm.on_overland:
			var was := _pos
			_finish_move(carry)
			if _pos != was:
				return
	_after_vm()


## Frames of sprite `id` (SPRIT files, preferring the current script's file number).
func _sprite_frames(id: int) -> Array:
	var key := "%d:%d" % [_vm_file, id]
	if _sprite_cache.has(key):
		return _sprite_cache[key]
	var frames := []
	var order := [_vm_file]
	for n in range(1, 9):
		if n != _vm_file:
			order.append(n)
	for n in order:
		var name := "SPRIT%d.DAX" % n
		if not _dax_cache.has(name):
			_dax_cache[name] = DaxFile.open(_game_path.path_join(name))
		var dax: DaxFile = _dax_cache[name]
		if dax != null and dax.blocks.has(id):
			frames = EgaPicture.frame_indices(dax.blocks[id])
			break
	_sprite_cache[key] = frames
	return frames


## An event picture: a head and body portrait when a head is set, else a PIC picture.
func _event_picture(head: int, id: int) -> Image:
	var img := Image.create_empty(DungeonView.SIZE, DungeonView.SIZE, false, Image.FORMAT_RGB8)
	if head != 255:
		var h := _find_picture("HEAD", head)
		var b := _find_picture("BODY", id)
		if h != null:
			img.blit_rect(h, Rect2i(Vector2i.ZERO, h.get_size()), Vector2i.ZERO)
		if b != null:
			img.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(0, 40))
		return img
	var p := _find_picture("PIC", id)
	if p == null:
		return img
	_start_picture_animation(id)
	return _anim_frames[0] if _anim_frames.size() > 1 else p


# --- Animated event pictures ----------------------------------------------------------------
# An event's PIC block with several frames animates in the view as in the original: the first
# frame, then each later one laid over it by XOR (EgaPicture.xor_frames; lab, chat 10: the
# camp's fire), each shown for its delay (units of about 0.11 s, as the camp fire measured).

var _anim_frames: Array[Image] = []
var _anim_delays: Array[int] = []
var _anim_i := 0
var _anim_timer: Timer


func _start_picture_animation(id: int) -> void:
	_anim_frames = []
	_anim_delays = []
	_anim_i = 0
	if Engine.time_scale > 1.0:
		return        # the lab's fast runs: no animation
	var order := [_vm_file]
	for n in range(1, 9):
		if n != _vm_file:
			order.append(n)
	for n in order:
		var name := "PIC%d.DAX" % n
		if not _dax_cache.has(name):
			_dax_cache[name] = DaxFile.open(_game_path.path_join(name))
		var dax: DaxFile = _dax_cache[name]
		if dax != null and dax.blocks.has(id):
			var pic := EgaPicture.decode_animated(dax.blocks[id])
			if pic == null or pic.frames.size() < 2:
				return
			_anim_frames = EgaPicture.xor_frames(dax.blocks[id])
			_anim_delays = pic.delays
			break
	if _anim_frames.size() < 2:
		return
	if _anim_timer == null:
		_anim_timer = Timer.new()
		_anim_timer.one_shot = true
		_anim_timer.timeout.connect(_next_picture_frame)
		add_child(_anim_timer)
	_anim_timer.start(_frame_seconds(0))


func _frame_seconds(i: int) -> float:
	return maxf(_anim_delays[i] if i < _anim_delays.size() else 2, 1) * CampScreen.ANIM_UNIT


func _next_picture_frame() -> void:
	if _anim_frames.size() < 2 or not _event_image in _anim_frames:
		_anim_frames = []
		return
	_anim_i = (_anim_i + 1) % _anim_frames.size()
	_event_image = _anim_frames[_anim_i]
	_anim_timer.start(_frame_seconds(_anim_i))
	_show()


## First frame of picture block `id` from PREFIX<n>.DAX, preferring the current script's file.
func _find_picture(prefix: String, id: int) -> Image:
	var order := [_vm_file]
	for n in range(1, 9):
		if n != _vm_file:
			order.append(n)
	for n in order:
		var name := "%s%d.DAX" % [prefix, n]
		if not _dax_cache.has(name):
			_dax_cache[name] = DaxFile.open(_game_path.path_join(name))
		var dax: DaxFile = _dax_cache[name]
		if dax != null and dax.blocks.has(id):
			var pic := EgaPicture.decode_any(dax.blocks[id])
			if pic != null and not pic.frames.is_empty():
				return pic.frames[0]
	return null


## The area's LOAD_AREA_DECO operands, from its event script: the ECL block with the
## map's id in the same-numbered file, else any block there that loads the map, else the
## first wall setting in that file.
func _area_deco(file_no: int, area_id: int) -> Array:
	var ecl := DaxFile.open(_game_path.path_join("ECL%d.DAX" % file_no))
	if ecl == null:
		return []
	if ecl.blocks.has(area_id):
		var own := _script(file_no, area_id, ecl)
		var deco := own.wall_ids_for_map(area_id)
		if not deco.is_empty():
			return deco
	for id in ecl.ids():
		var other := _script(file_no, id, ecl)
		if other.loads_map(area_id):
			var deco := other.wall_ids_for_map(area_id)
			if not deco.is_empty():
				return deco
	for id in ecl.ids():
		var deco := _script(file_no, id, ecl).wall_ids_for_map(-1)
		if not deco.is_empty():
			return deco
	return []


var _scripts := {}   # "file:id" -> EclScript


func _script(file_no: int, id: int, ecl: DaxFile = null) -> EclScript:
	var key := "%d:%d" % [file_no, id]
	if not _scripts.has(key):
		if ecl == null:
			ecl = DaxFile.open(_game_path.path_join("ECL%d.DAX" % file_no))
		_scripts[key] = EclScript.decode(ecl.blocks.get(id, PackedByteArray()))
	return _scripts[key]


func _layout() -> void:
	# Walk mode: view on the left, map on the right. Otherwise one panel fills the screen.
	var walk := _mode == Mode.WALK
	_picture.anchor_right = 0.5 if walk else 1.0
	_map_view.anchor_left = 0.5 if walk else 0.0
	_picture.visible = _mode != Mode.MAPS
	_map_view.visible = _mode != Mode.PICTURES
	_message.visible = walk
	var original := walk and not _dev_view
	_screen.visible = original
	if original:
		_picture.visible = false
		_map_view.visible = false
		_message.visible = false
		_status.visible = false
	else:
		_status.visible = true
	# Leave room under the view for event text.
	_picture.offset_bottom = -236.0 if walk else -60.0
	if not walk:
		_map_view.set_marker(Vector2i(-1, -1), 0)


func _show() -> void:
	_layout()
	if _mode == Mode.PICTURES:
		if _pictures.is_empty():
			_status.text = "No pictures decoded."
			return
		var e: Dictionary = _pictures[_pic_index]
		var pic: EgaPicture = e.pic
		_picture.texture = ImageTexture.create_from_image(pic.sheet())
		_status.text = "PICTURES  %s block %d   %dx%d   %d frame(s)   [%d/%d]\n←/→ picture   ↑/↓ file   Tab maps" % [
			e.file, e.id, pic.width, pic.height, pic.frames.size(), _pic_index + 1, _pictures.size()]
		return
	if _maps.is_empty():
		_status.text = "No maps decoded."
		return
	var e: Dictionary = _maps[_map_index]
	_map_view.map = e.map
	var area: String = GeoMap.AREA_NAMES.get(e.id, "unnamed area")
	if _mode == Mode.MAPS:
		var hint: String = _area_text.get(e.id, "")
		if hint.length() > 70:
			hint = hint.substr(0, 70) + "..."
		_status.text = "MAPS  %s — %s block %d  [%d/%d]   %s\nwalls coloured by type, doors gold, shaded = flag bit 7 (unknown)    ←/→ map   Enter walk   Tab walk" % [
			area, e.file, e.id, _map_index + 1, _maps.size(), hint]
		return
	# Walk mode
	if _vm.on_overland and _vm.overland != null:
		_view_img = _event_image if _event_image != null else _overland_view()
		_picture.texture = ImageTexture.create_from_image(_view_img)
		_status.text = "WILDERNESS  %s   ECL%d block %d\n←↑→↓ move   E encamp  S search  L look  V view  F2 save  F3 load" % [
			_overland_place(), _vm_file, _vm_block]
		if _screen.visible:
			_draw_screen()
		return
	if _walls_for != _map_index:
		var file_no := int(String(e.file).trim_prefix("GEO").trim_suffix(".DAX"))
		_deco = _area_deco(file_no, e.id)
		_walls = WallSet.build_for_area(_game_path, file_no, _deco)
		_walls_for = _map_index
	if _walls == null or _walls.walls.is_empty():
		_status.text = "WALK  %s — no wall graphics found" % area
		return
	_ensure_area_script()
	e = _maps[_map_index]
	var sky := _vm.read_byte(EclVM.SKY_OUTDOORS)
	_dungeon.sky_color = sky if sky > 0 and sky < 16 else 11
	if _vm.runes_shown and not _vm.rune_lines.is_empty():
		_view_img = _rune_page()
		_picture.texture = ImageTexture.create_from_image(_view_img)
	elif _event_image != null:
		_view_img = _event_image
		_picture.texture = ImageTexture.create_from_image(_view_img)
	else:
		var view := _dungeon.render(e.map, _walls, _pos.x, _pos.y, _facing)
		if _vm.sprite_id >= 0 and CampScreen.show_monsters:
			var frames := _sprite_frames(_vm.sprite_id)
			if not frames.is_empty():
				# A figure can't stand beyond a wall right in front of you.
				var distance := _vm.sprite_distance
				var map0: GeoMap = e.map
				var ahead := _pos + DungeonView.DELTA[_facing]
				if map0.wall(_pos.x, _pos.y, _facing) > 0:
					distance = 0
				elif distance > 1 and ahead.x >= 0 and ahead.y >= 0 and ahead.x < GeoMap.SIZE \
						and ahead.y < GeoMap.SIZE and map0.wall(ahead.x, ahead.y, _facing) > 0:
					distance = 1
				DungeonView.draw_sprite(view, frames[mini(distance, frames.size() - 1)])
		_view_img = DungeonView.to_image(view)
		_picture.texture = ImageTexture.create_from_image(_view_img)
	_map_view.set_marker(_pos, _facing)
	_automap.place(e.map, "%s:%d" % [e.file, e.id], _pos, int(_facing), area.to_upper())
	var facing_name: String = ["North", "East", "South", "West"][_facing]
	var map: GeoMap = e.map
	var night := GameClock.hour(_vm) >= 14
	var script_name := "ECL%d block %d" % [_vm_file, _vm_block] if _vm.ecl != null else "no script"
	_status.text = "WALK  %s   %d,%d facing %s  %s   event %d   %s   %s\n↑ forward  ↓ back  ←/→ turn   E encamp  S search  L look  V view  F2 save  F3 load   N day/night  O outlines  C capture  G go to  F4 script   Tab pictures" % [
		area, _pos.x, _pos.y, facing_name, GameClock.text(_vm), map.flag(_pos.x, _pos.y) & 127,
		("night" if night else "day") + ("  SEARCHING" if _searching else ""), script_name]
	if _screen.visible:
		_draw_screen()


## The adventure screen as the original shows it.
func _draw_screen() -> void:
	var body := _message.text
	var menu: Array = ["AREA", "CAST", "VIEW", "ENCAMP", "SEARCH", "LOOK"]
	var selected := 0
	if _door_options != "":
		var words := {"B": "BASH", "P": "PICK", "K": "KNOCK", "E": "EXIT"}
		menu = []
		for c in _door_options:
			menu.append(words[c])
		body = ""
		menu.push_front("LOCKED.")
	elif _vm.state == EclVM.State.MENU and not _vm.menu.is_empty():
		var cut := body.rfind("\n\n")
		if cut >= 0:
			body = body.substr(0, cut)
		menu = _vm.menu.duplicate()
		selected = clampi(_menu_sel, 0, menu.size() - 1)
	elif _vm.state == EclVM.State.INPUT:
		menu = []
	elif _busy:
		menu = []
	var view := _view_img
	if _area_view and not _vm.on_overland:
		view = _area_picture()
	var place := _place_line()
	var wild := _vm.on_overland and _event_image == null and not _area_view
	if _vm.on_overland:
		menu.erase("AREA")
	if _searching:
		place += " SEARCHING"
	var lines := GameScreen.wrap(body.strip_edges(), 38)
	OverlayLook.last_view = view
	OverlayLook.last_wild = wild
	OverlayLook.last_overland = _vm.on_overland
	OverlayLook.last_place = place
	_screen.draw_walk(view, _party, clampi(_vm.selected, 0, maxi(_party.size() - 1, 0)), place, lines, menu, wild, _vm.on_overland, selected if not _busy and _door_options == "" else -1)


## AREA: the overhead map of the block in the view window, walls as lines, the party as an
## arrow (the original's AREA view; our automap shows only what has been seen... for now all).
func _area_picture() -> Image:
	var im := Image.create(88, 88, false, Image.FORMAT_RGBA8)
	im.fill(Color.BLACK)
	var map: GeoMap = _maps[_map_index].map
	var wall_c := GameScreen.EGA[7]
	var door_c := GameScreen.EGA[14]
	for y in GeoMap.SIZE:
		for x in GeoMap.SIZE:
			var ox := 4 + x * 5
			var oy := 4 + y * 5
			for side in 4:
				if map.wall(x, y, side) == 0:
					continue
				var c: Color = door_c if map.door(x, y, side) != 0 else wall_c
				for k in 6:
					match side:
						0: im.set_pixel(ox + k, oy, c)
						1: im.set_pixel(ox + 5, oy + k, c)
						2: im.set_pixel(ox + k, oy + 5, c)
						3: im.set_pixel(ox, oy + k, c)
	var px := 4 + _pos.x * 5 + 2
	var py := 4 + _pos.y * 5 + 2
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		im.set_pixel(px + d.x, py + d.y, GameScreen.EGA[12])
	var tip := DungeonView.DELTA[_facing]
	im.set_pixel(clampi(px + tip.x * 2, 0, 87), clampi(py + tip.y * 2, 0, 87), GameScreen.EGA[15])
	return im


func _exit_tree() -> void:
	if _vm != null and _vm.coverage != null:
		_vm.coverage.save()
	if _shadow != null:
		_shadow.coverage.save()


## Dev shortcut (M6, PlayBot): moves the party to `pos` facing `facing` in script block
## `block` of ECL<file> (entering it, with its init, when it isn't the current one), or in
## the current area when `block` < 0; pos.x < 0 keeps where the init put the party. Debug
## builds only. Returns false if refused.
func dev_teleport(file_no: int, block: int, pos: Vector2i, facing: int) -> bool:
	if not DevShortcuts.allowed():
		return false
	if _vm.on_overland and block < 0:
		return false     # a square of the wilderness band: not supported
	if block >= 0 and (block != _vm_block or file_no != _vm_file):
		_enter_script(file_no, block)
		if _vm.state == EclVM.State.MENU:
			return false
	if pos.x < 0:
		return true        # where the area's init placed the party
	_pos = pos
	_facing = (facing & 3) as DungeonView.Dir
	_sync_position_to_vm(_facing)
	_walls_for = -1
	_pending_move = -1
	_after_vm()
	return true


## The place line under the view: square, facing and time ("14,5 S 10:56").
func _place_line() -> String:
	if _vm.on_overland:
		return _overland_place()
	if _vm.read_byte(NO_COORDINATES) != 0:
		# Where an area's script sets 0x49FB (Valjevo's castle, the pyramid, the graveyard,
		# Sokal Keep...) the original shows no square (START.EXE 0x35A6, lab chat 6).
		return "%s %s" % ["NESW"[_facing], GameClock.text(_vm)]
	return "%d,%d %s %s" % [_pos.x, _pos.y, "NESW"[_facing], GameClock.text(_vm)]


## A rest in camp is done: the clock moves on (the camp has already run the effects).
func _on_camp_rested(minutes: int) -> void:
	GameClock.add_minutes(_vm, minutes)
	_camp.place = _place_line()
