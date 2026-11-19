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
var _by_new_ecl := false    # the area change under way comes from a script's NEW_ECL
var _event_image: Image     # picture shown in the view by an event (null = 3D view)
var _message: Label
var _dax_cache := {}

# Timed playback: script DELAYs and script-driven walks
const WALK_STEP_SECONDS := 0.22
var _timer: Timer
var _busy := false                  # a delay or walk is playing; input waits
var _walk_path: Array[Vector2i] = []
var _walk_final_dir := 0
var _held_message := ""
## The original's 0x49F9 (chat 54): whether the last walking menu was the wilderness's. Its walking
## input (GAME.OVR 0x17054) ends with 0x49F9 = 0x49FA (0x173E7); on the wilderness branch (0x17285) a
## previous mode under 2 (a 3D area; 1 at start-up, 0xE9BE) loads the ICONs and redraws the whole
## screen (START.EXE 0xBA:0x2B5E), so the first wilderness menu after leaving a 3D area or loading
## shows an empty box: the jump's arrival text in 6:25, IGNORE CAVE after 6:19's LEAVE (chat 53).
var _menu_was_wild := false
## The script blocks the original runs in its wilderness modes (0x49FA 2-4: GAME.OVR 0x3F4C, from the
## block number 0x84DC); every other block, 6:19's cave among them, is mode 1 (3D) though ours shows
## some of them over the band.
const WILD_MODE_BLOCKS := [25, 26, 27]
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
## Lab (chat 19): set by a coverage run. Every generator a screen seeds from the clock when it opens
## (fights, camp, shops, temples, the party menu and sheet, doors) is reseeded from this one, so a
## run's seed= replays everything, not only the script's dice.
var dev_rng: RandomNumberGenerator = null


func _dev_reseed(gens: Array) -> void:
	if dev_rng == null:
		return
	for r in gens:
		r.seed = dev_rng.randi()
const REST_PERIOD := 0x6DD2       # set by the area's "on rest" script: steps between checks
const REST_PERCENT := 0x6DD3      # ... and the chance (d100) that rest is interrupted
var _fight_treasure := []        # the event's TREASURE operands, kept for after the fight
var _fight_made: Array[GameItem] = []   # the items its list 128+ made at the TREASURE
var _combat: CombatScreen
var _types: ItemTypes

# The original's adventure screen (F12 switches to the developer view and back).
var _screen: GameScreen
var _dev_view := false
## The walking screen's test keys (Player 17's request, chat 50): N the clock, O the wall slots, B a test fight,
## Shift+M the monsters' sheet, F4 the script dump, F9 a capture, F12 the developer view, G go to (and "ending"),
## Tab the picture and map viewer. None is the original's; they answer only in a debug build (the editor: the lab,
## the checks) or with --lab, never in a release build. --player-keys turns them off in a debug build too (the
## lab's key sweep).
static var lab_keys := "--lab" in OS.get_cmdline_user_args() \
		or (OS.is_debug_build() and not "--player-keys" in OS.get_cmdline_user_args())
const LAB_KEYS := [KEY_N, KEY_O, KEY_B, KEY_F4, KEY_F9, KEY_F12, KEY_G]
var _view_img: Image
var _area_view := false            # AREA: the overhead map in the view window
var _automap: Automap               # QoL: mini-map (M) and full map (F) of visited squares


var _quest_log: QuestLog
var _quest_screen: QuestScreen       # combat lane: the quest log's screen (C11-4), made at the first Q


## The quest tracker's view of the game now (QuestLog.evaluate with the offers shown), for its
## screen (Combat's lane, after Q7's order).
func quest_view() -> Array[Dictionary]:
	if _quest_log == null:
		return []
	return _quest_log.evaluate(Callable(_vm, "read_byte"), _vm.shown_texts)


func _ready() -> void:
	DisplayMode.apply(get_tree())          # full screen if chosen (side lane, scripts/ui/display_mode.gd)
	# The quest tracker's offers that set no flag: the VM records them when shown (Q11, chat 39).
	_quest_log = QuestLog.load_file()
	for k in _quest_log.shown_keys():
		_vm.watch_texts[k] = true
	# The build's version in the window title (application/config/version), so a tester can tell builds apart.
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	if version != "":
		get_window().title = "%s %s" % [ProjectSettings.get_setting("application/config/name"), version]
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
	# The box itself sits under the game screen; what's typed is drawn on row 24 (P53).
	_typed.text_changed.connect(func(_t: String) -> void: _show())
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
	_vm.square_info = _script_square_info
	_vm.wall_info = _script_wall
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
	_camp.start_memorized.connect(_begin_adventure)
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
	# Chat 17: "ATTACK ALLY" answered YES: 0x6E33 = 1, which 7:17's nomads read after the fight
	# ("THE FILTHY TRAITORS!"). GAME.OVR 0x151F4.
	_combat.ally_attacked.connect(func(): _vm.write_byte(EclVM.ALLY_ATTACKED, 1))
	add_child(_combat)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer)
	add_child(_timer)
	_automap = Automap.new()
	_automap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_automap.gate = func() -> bool:
		_automap.party_rows = _party.size()     # Combat: the mini-map stays below the party list
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
	# The copy this game reads, in the log for reports (GameCopy; ABOUT shows it too): hashed on
	# a thread of its own, the line logged when it's done (Lead, 2026-11-17: not on the start's path).
	print("Game folder: ", _game_path)
	GameCopy.start(_game_path)
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
	_vm.treasure_maker = TreasureMaker.shared(_game_path)
	var battle_only := false
	for arg in OS.get_cmdline_user_args():
		battle_only = battle_only or arg.begins_with("--battle=")
		# --seed=<n>: the same dice every run (for the lab's step-by-step comparisons and the push gate's
		# differential checks). Chat 31: every generator that rolls, as the bot's _seed_all does (the script's
		# dice, the screens', the doors, Godot's global); it used to seed only the global one, so the script's
		# dice stayed on the clock (check 4's bugbear: the toll or "THEY ARE IMPOSTERS!" at random).
		if arg.begins_with("--seed="):
			var from := RandomNumberGenerator.new()
			from.seed = int(arg.get_slice("=", 1))
			_vm._rng.seed = from.randi()
			dev_rng = RandomNumberGenerator.new()
			dev_rng.seed = from.randi()
			_door_rng.seed = from.randi()
			seed(from.randi())
		# --fast: the lab's long tours run every pause and fight step 25 times faster.
		if arg == "--fast":
			Engine.time_scale = 25.0
			# Headless runs sleep 6.9 ms a frame (low-processor mode): about 145 frames a second,
			# which held every lab run to 10% of a core. --fast lifts it (chat 16).
			if not "--frame-sleep" in OS.get_cmdline_user_args():
				OS.low_processor_usage_mode = false
				OS.low_processor_usage_mode_sleep_usec = 0
		# --time-scale=<n> (lab, after --fast): game timers run n times faster still (chat 17:
		# the bot's quiet window is counted in game time, so 1000 makes it a few frames).
		if arg.begins_with("--time-scale=") and OS.is_debug_build():
			Engine.time_scale = float(arg.get_slice("=", 1))
		if arg == "--no-draw" and OS.is_debug_build():
			dev_no_draw = true
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
	# F3 from a screen or an event (P56): the scene was started afresh to load the quick save.
	if _reload_quick:
		_reload_quick = false
		_on_start_chosen("continue", "")
		if not _replay_left.is_empty():
			_replay_keys.call_deferred(_replay_left)   # lab: a --keys replay carries on
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
	SaveListScreen.quick_path = _save_path()     # the save/load list (Combat lane, QoL 5)
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
			_automap.from_save({})
			_new_game()
		"create":
			_automap.from_save({})
			# As the original starts: an empty party, the party menu's CREATE / ADD, then
			# BEGIN ADVENTURING starts the game with whoever was added.
			_party.clear()
			_open_starting_party_menu()
			return
	_show()


## The party menu before the adventure starts (PARTY CREATION, or a game saved there):
## BEGIN ADVENTURING starts a new game with the party in it.
func _open_starting_party_menu() -> void:
	_starting_party = true
	_vm.ecl = null
	_vm.write_byte(EclVM.TRAINING_MASK, 0)
	_party_menu.tables = ClassTables.shared(_game_path)
	_party_menu.spells = SpellTable.shared(_game_path)
	_party_menu.types = _types
	_party_menu.game_path = _game_path
	_party_menu.open(_party, 0)


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
	SaveListScreen.quick_path = _save_path()     # the save/load list (Combat lane, QoL 5)
	_start_menu.open(_game_path, FileAccess.file_exists(_save_path()))
var _who_open := false   # a WHO menu's highlight has been put on the selected member
var _menu_sel := 0   # the event menus' highlight, kept from one menu to the next


## A new game with the ready-made party: New Phlan at the start of the adventure.
func _new_game() -> void:
	_mode = Mode.WALK
	# A fresh start: no flags or places from an earlier game.
	_vm.mem.fill(0)
	_vm.hi.clear()
	_vm.shown_texts.clear()
	_wall_slots_reset()
	_vm.on_overland = false
	_vm.overland_band = 0
	_menu_was_wild = false
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
	for ki in names.size():
		var n := names[ki]
		_replay_left = names.slice(ki + 1)   # lab: what's left if F3 restarts the scene (P56)
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
			for o in [_combat, _combat._sheet, _party_menu, _camp, _temple, _treasure, _shop, _party_menu._sheet, _camp._sheet, _treasure._sheet, _sheet]:
				if o != null and o.visible and o.get("_scr") != null:
					scr = o._scr
			for sl in [_camp.get("_save_list"), _party_menu.get("_save_list")]:
				if sl != null and sl.visible:
					scr = sl._scr                # the save list over camp / party menu (QoL 5)
			if _ending != null and _ending.visible:
				scr = _ending._screen   # the closing pictures (PROGRAM 8)
			if scr != null and scr.img != null:
				scr.img.save_png(n.trim_prefix("screen="))
			continue
		elif n == "automap":                # automap: the squares the automap holds, per map (lab)
			for k in _automap.visited:
				print("   automap %s: %d squares" % [k, (_automap.visited[k] as PackedByteArray).count(1)])
			continue
		elif n.begins_with("tpseed="):      # tpseed=<hex>: the original's own dice from that seed (TpDice)
			TpDice.start(n.trim_prefix("tpseed=").hex_to_int())
		elif n == "quickall":               # quickall: the whole party on QUICK in the open fight (lab)
			while _battle_begins:           # chat 39: the fight opens after A BATTLE BEGINS... (--anim)
				await get_tree().process_frame
			_combat.quick_all()
		elif LabHooks.handles(n):          # the side lane's lab keys (scripts/combat/lab_hooks.gd)
			if await LabHooks.handle(self, n):
				continue
		elif n == "magic":                  # magic: Alt-M in the open fight (the party's QUICK members cast)
			while _battle_begins:
				await get_tree().process_frame
			_combat.toggle_magic()
		elif n == "tplog":                  # tplog prints the dice drawn since tpseed= (and clears)
			for l in TpDice.log:
				print("   ", l)
			TpDice.log.clear()
		elif n.begins_with("combatseed="):  # combatseed=<n>: event fights roll from seed n (lab)
			CombatScreen.dev_seed = int(n.trim_prefix("combatseed="))
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
		elif n.begins_with("peek="):        # peek=<hex address>:<count> prints ECL memory bytes (lab)
			var a := n.trim_prefix("peek=").split(":")
			var at := a[0].hex_to_int()
			var out := PackedStringArray()
			for k in (int(a[1]) if a.size() > 1 else 16):
				out.append(str(_vm.read_byte(at + k)))
			print("   peek %X: %s" % [at, " ".join(out)])
			continue
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
			var key_name: String = {"enter": "Enter", "esc": "Escape", "home": "Home", "end": "End", "pgup": "PageUp", "pgdn": "PageDown",
				"up": "Up", "down": "Down", "left": "Left", "right": "Right"}.get(n, n.to_upper())
			ev.keycode = OS.find_keycode_from_string(key_name)
			if n.length() == 1:
				ev.unicode = n.to_upper().unicode_at(0)   # so a typed answer's box takes it (P53)
			ev.pressed = true
			Input.parse_input_event(ev)
			var up := ev.duplicate()
			up.pressed = false
			Input.parse_input_event(up)
		# Chat 44: until the engine is idle (a script DELAY or a walk is over), at least 4 frames; the ceiling is
		# 300 frames and 5 s, whichever is later. 300 frames alone made a check hang on frame time: with fast
		# frames a chain of DELAYs outlasted them and the next key landed mid-text (checks 21 and 24 with
		# Combat Chat 15's automap).
		var t_end := Time.get_ticks_msec() + 5000
		var i := 0
		while i < 300 or Time.get_ticks_msec() < t_end:
			await get_tree().process_frame
			if i > 3 and not _busy:
				break
			i += 1
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


## Lab: up to 60 frames for a step to play out. Chat 17: over once nothing has been busy for
## 8 frames in a row (a fixed 60 frames were most of a coverage run's time).
func _step_wait() -> void:
	var quiet := 0
	for i in 60:
		await get_tree().process_frame
		quiet = quiet + 1 if not _busy and _timer.is_stopped() else 0
		if quiet >= 8:
			return


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
		var before := _pos
		var area_before := "%d:%d" % [_vm_file, _vm_block]
		if _vm.on_overland:
			# In the wilderness the arrows move the party that way; they don't turn it (chat 13:
			# turning right towards a square to the north walked the party east for an hour).
			await _press(["up", "right", "down", "left"][d])
		else:
			while int(_facing) != d and not _lost:
				await _press("right" if (d - int(_facing) + 4) % 4 != 3 else "left")
			await _press("up")
		await _step_wait()
		if _pos == before and _vm.state in [EclVM.State.IDLE, EclVM.State.DONE] and _door_options == "" \
				and not _combat.visible and _message.text.strip_edges() == "" and not _vm.on_overland:
			# A step the area's script refuses without a word may be a secret door not found
			# yet (Yarash's pyramid: the step script rolls for each member on arrival, better
			# when SEARCHing; 0x4A4F holds the doors found). Search, step off and back on, and
			# try again, a few times.
			var key := "%d:%d,%d,%d" % [_map_index, before.x, before.y, d]
			var tries := int(_secret_tries.get(key, 0))
			if tries < 6 and await _search_again(before, d):
				_secret_tries[key] = tries + 1
				continue
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


## Lab: steps off `at` (not towards `blocked`) and back on with SEARCH on, so the square's
## script looks for a secret door again; SEARCH goes back as it was. False if it can't.
func _search_again(at: Vector2i, blocked: int) -> bool:
	if _vm.on_overland:
		# The wilderness has no secret doors, and its arrows move rather than turn (chat 13:
		# the turning loop below walked a party east across 8:27 for an hour).
		return false
	var was := _searching
	_searching = true
	_vm.write_byte(SEARCH_FLAG, 1)
	var ok := false
	for k in 4:
		if k == blocked:
			continue
		var next: Vector2i = at + DungeonView.DELTA[k]
		var path := _find_path(at, next)
		if path.size() != 2:
			continue
		while int(_facing) != k and not _lost:
			await _press("right" if (k - int(_facing) + 4) % 4 != 3 else "left")
		await _press("up")
		await _step_wait()
		while await _auto_handle():
			await get_tree().process_frame
		if _pos != next:
			continue
		var back := (k + 2) % 4
		while int(_facing) != back and not _lost:
			await _press("right" if (back - int(_facing) + 4) % 4 != 3 else "left")
		await _press("up")
		await _step_wait()
		while await _auto_handle():
			await get_tree().process_frame
		ok = _pos == at
		break
	_searching = was
	_vm.write_byte(SEARCH_FLAG, 1 if was else 0)
	if ok:
		print("   searching for a secret door at %s" % at)
	return ok


var _said := ""
var _secret_tries := {}     # the tour's tries at each refused step ("map:x,y,dir")
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
## Dev (M6 coverage runs, chat 14): a harness records each step and the choices that follow it,
## and later puts the game back (dev_snapshot / dev_restore) to play another choice for real.
var dev_restores := 0       # dev_restore calls so far (the bot's repeated-question counts start again)
var dev_no_draw := false      # --no-draw (lab, dev builds): _show skips the drawing (chat 17)
var dev_step_hook: Callable = Callable()     # (direction) as a step starts in walk mode
var dev_choice_hook: Callable = Callable()   # (choice) as a script menu takes a choice
var dev_typed_hook: Callable = Callable()    # (text) as a script's question takes an answer


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
	if _ending != null and _ending.visible:
		# The closing pictures (PROGRAM 8 after Tyranthraxus): page through them.
		await _press("enter")
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
				var way_out := false
				for i in _vm.menu.size():
					if String(_vm.menu[i]).strip_edges().to_upper() in ["NO", "LEAVE", "EXIT", "QUIT", "DONE"]:
						k = str(i + 1)
						way_out = true
				if not way_out or int(_menu_seen[key]) > 5:
					# No way out offered (WHO WILL OPEN IT? asked again while the first member
					# can't: chat 13, Valjevo's trap door), or the way out only asks again (chat 15:
					# 7:23's "DO YOU REALLY MEAN NOKNOK?", where NO asks for the word again): the
					# next choice each time.
					k = str((int(_menu_seen[key]) - 1) % mini(_vm.menu.size(), 9) + 1)
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


## Alt+Enter / F11 switch full screen on any screen (side lane, DisplayMode).
func _input(event: InputEvent) -> void:
	if DisplayMode.handle_key(get_tree(), event):
		get_viewport().set_input_as_handled()
		return
	# P56 (Jeremy's exception, 2026-11-14): F3 quick-loads from any part of the game, fights,
	# camp, shops, sheets and events included. Off the plain walking screen the whole game
	# scene is started afresh and loads the quick save as it starts (every screen's timers and
	# waits go with it); on the walking screen the usual path below does it.
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F3 \
			and _game_path != "" and not (_start_menu != null and is_instance_valid(_start_menu) and _start_menu.visible) \
			and FileAccess.file_exists(_save_path()) and _quick_load_needs_reset():
		get_viewport().set_input_as_handled()
		_reload_quick = true
		get_tree().reload_current_scene()


## The quick load restarts the scene first when anything but the plain walking screen is up.
static var _reload_quick := false
static var _replay_left := PackedStringArray()


func _quick_load_needs_reset() -> bool:
	for o in [_shop, _sheet, _combat, _treasure, _camp, _temple, _party_menu]:
		if o != null and o.visible:
			return true
	if _ending != null and is_instance_valid(_ending):
		return true
	return _busy or _door_options != "" or _lost or not _vm.state in [EclVM.State.IDLE, EclVM.State.DONE, EclVM.State.ERROR]


func _unhandled_input(event: InputEvent) -> void:
	if _battle_begins:
		return
	if _game_path == "" or not event.is_pressed() or _shop.visible or _sheet.visible or _combat.visible \
			or _treasure.visible or _camp.visible or _temple.visible or _party_menu.visible:
		return
	if _lost and event is InputEventKey:
		get_viewport().set_input_as_handled()
		_back_to_start()
		return
	if _mode != Mode.WALK and event is InputEventKey and (event as InputEventKey).keycode == KEY_F3:
		_quick_load()
	elif lab_keys and event is InputEventKey and (event as InputEventKey).keycode == KEY_TAB:
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
			if _vm._menu_kind == "press":
				# PRESS <ENTER>/<RETURN> TO CONTINUE after DAMAGE: any key (GetKey), the text kept.
				if (key != KEY_NONE and key not in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]) \
						or (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
					_vm.choose(0)
					_after_vm()
				get_viewport().set_input_as_handled()
				_show()
				return
			if key >= KEY_1 and key <= KEY_9:
				choice = key - KEY_1
			elif _vm._menu_kind == "who":
				# WHO (lab, chat 22, New Phlan's inn): "WHO WILL PAY?" SELECT on row 24; Home/End
				# move the white member on the party list, Enter (or SELECT's S) takes them.
				# Up/Down too (P33, Jeremy 2026-11-14: both pairs in every list).
				if key in [KEY_HOME, KEY_END, KEY_KP_7, KEY_KP_1, KEY_UP, KEY_DOWN]:
					_menu_sel = posmod(clampi(_menu_sel, 0, _vm.menu.size() - 1) + (1 if key in [KEY_END, KEY_KP_1, KEY_DOWN] else -1), _vm.menu.size())
				elif event.is_action("ui_accept") or key == KEY_S:
					choice = clampi(_menu_sel, 0, _vm.menu.size() - 1)
			elif _vm.menu_vertical:
				# A vertical menu (lab, chat 13): Home and End move the highlight up and down,
				# wrapping round; Enter takes it. Letters and the left/right arrows do nothing.
				# Up/Down too (P33, Jeremy 2026-11-14: both pairs in every list).
				if key in [KEY_HOME, KEY_END, KEY_UP, KEY_DOWN]:
					_menu_sel = posmod(clampi(_menu_sel, 0, _vm.menu.size() - 1) + (1 if key in [KEY_END, KEY_DOWN] else -1), _vm.menu.size())
				elif event.is_action("ui_accept"):
					choice = clampi(_menu_sel, 0, _vm.menu.size() - 1)
			elif key >= KEY_A and key <= KEY_Z:
				var letter := OS.get_keycode_string(key).to_upper()
				var hits := []
				for i in _vm.menu.size():
					if String(_vm.menu[i]).strip_edges().to_upper().begins_with(letter):
						hits.append(i)
				if hits.size() == 1:
					choice = hits[0]
			elif _vm.menu.size() == 1 and event.is_action("ui_accept"):
				# A script's horizontal menu (MENU_HORIZONTAL, PARLAY, ENCOUNTER_MENU) takes Enter only
				# when it has one choice (PRESS <RETURN>), as the original (Jeremy, Q24, 2026-11-18):
				# GAME.OVR's menu routine 0x8B57 takes 0x0D only when its argument [bp+8] is set,
				# MENU_HORIZONTAL (0x1E5A) sets it for one choice, PARLAY (0x3311) and ENCOUNTER_MENU
				# (0x2F18) never. With two or more choices only the letters (and the mouse) choose;
				# Enter and the arrows do nothing.
				choice = 0
			if choice >= 0 and choice < _vm.menu.size():
				_menu_sel = choice   # the original keeps the highlight where the last choice was
				# A script's horizontal menu (YES / NO) leaves the box as it is: the script's next ops
				# decide (chat 51, DOSBox: NO at Kuto's Well, 8:29 0xAF71, then EXIT, keeps the question;
				# the rowboat's NO clears it with its own PRINT_CLEAR " ", 7:26 0xAD47). Only the menu's
				# options line goes. The other menus clear the box, as before.
				if _vm._menu_kind == "" and not _vm.menu_vertical:
					_message.text = _vm.text
				else:
					_message.text = ""
				if dev_choice_hook.is_valid():
					dev_choice_hook.call(choice)
				_vm.choose(choice)
				_after_vm()
			get_viewport().set_input_as_handled()
			_show()
			return
		# A key on the walking menu: the member selected now is the player's own (GAME.OVR 0x40E3 keeps it
		# in 0x4436; a script's LOAD_CHAR is undone from it at EXIT or PROGRAM: ecl_vm.gd, Combat Chat 18).
		_vm.walk_selected = _vm.selected
		if (key == KEY_HOME or key == KEY_END) and not _party.is_empty():
			# Home/End move the selected character up and down the party (lab, chat 11).
			_vm.selected = posmod(clampi(_vm.selected, 0, _party.size() - 1) + (1 if key == KEY_END else -1), _party.size())
			_vm.walk_selected = _vm.selected
			get_viewport().set_input_as_handled()
			_show()
			return
		if not lab_keys and key in LAB_KEYS:
			return    # a test key: nothing in a release build (lab_keys)
		if key == KEY_F2:
			_quick_save()
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_F3:
			_quick_load()
		elif key == KEY_V:
			for m in _party:
				m.recalculate(_types)
			_sync_shell()
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
		elif key == KEY_M and (event as InputEventKey).shift_pressed and lab_keys:
			_sheet.open(_all_monsters(), "MONSTERS")    # developer aid
			get_viewport().set_input_as_handled()
			return
		elif key == KEY_M and _automap.enabled and not (event as InputEventKey).alt_pressed:
			# Alt+M is the original's combat MAGIC key, never the map (Methods 3). Plain M is no
			# key on the original's adventure menu (lab, chat 22).
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
		elif key == KEY_Q and QuestScreen.on() and _vm.state in [EclVM.State.IDLE, EclVM.State.DONE, EclVM.State.ERROR]:
			# The quest log (combat lane, C11-4): Q is no key on the original's adventure menu.
			if _quest_screen == null:
				_quest_screen = QuestScreen.new()
				add_child(_quest_screen)
			_quest_screen.open(quest_view())
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
			# Lab (chat 22, save J): the place line says SEARCH at once, and loses it on the
			# second press; the clock doesn't move.
			_searching = not _searching
			_vm.write_byte(SEARCH_FLAG, 1 if _searching else 0)
			get_viewport().set_input_as_handled()
			_show()
			return
		elif key == KEY_C:
			# CAST: the selected member's spells in memory (camp's CAST page), or "<NAME> HAS NO
			# SPELLS MEMORIZED" for a moment (lab, chat 22).
			if _vm.state in [EclVM.State.IDLE, EclVM.State.DONE, EclVM.State.ERROR] and not _party.is_empty():
				for m in _party:
					m.recalculate(_types)
				var menu: Array = ["AREA", "CAST", "VIEW", "ENCAMP", "SEARCH", "LOOK"]
				if _vm.on_overland:
					menu.erase("AREA")
				_camp.spells = SpellTable.shared(_game_path)
				_sync_shell()
				_camp.open_cast(_party, clampi(_vm.selected, 0, _party.size() - 1), menu)
				_dev_reseed([_camp._rng2])
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
				# P67 (chat 35, DOSBox 7:17 6,14: L on a square with nothing shows nothing new
				# and the place line's clock moves 10 minutes at once): redraw it now, not at
				# the next step.
				if _vm.state in [EclVM.State.IDLE, EclVM.State.DONE]:
					_show()
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
			# Down turns the party round where it stands (GAME.OVR 0x17187: scan code 0x50, the facing
			# + 4 of 8, the wall ahead read again, no sound); chat 61 in DOSBox: 2:20 3,4 E, Down, 3,4 W.
			# Ours had stepped backwards.
			_facing = ((_facing + 2) % 4) as DungeonView.Dir
			_write_wall_ahead()
			_vm.sprite_id = -1
		elif event.is_action("ui_left") or event.is_action("ui_right"):
			# A turn redraws the view from the map, as a step does: a figure an encounter left
			# standing (THE MONSTERS FLEE, a parley's end) is gone (P38; the original draws a
			# figure only on the script's SPRITE commands).
			_facing = ((_facing + (3 if event.is_action("ui_left") else 1)) % 4) as DungeonView.Dir
			_write_wall_ahead()   # GAME.OVR 0x171AE / 0x171F5 (chat 61)
			_vm.sprite_id = -1
			Speaker.play(Speaker.STEP)    # GAME.OVR 0x171DF / 0x17224 (Combat's sound)
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
		if dev_typed_hook.is_valid():
			dev_typed_hook.call(text)
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


## The anti-magic shell (ECL 0x49E5 above 0) outside fights: no CAST in walking and camp CAST (GAME.OVR
## 0x17BB2), no USE in any item list (0x21FD6 tests it for the walking, camp and shop lists too).
## Set as each screen opens; the fight sets and clears the sheet's flag itself.
func _sync_shell() -> void:
	var on: bool = _vm.read_byte(0x49E5) > 0
	_camp.anti_magic = on
	CharacterSheet.anti_magic = on


func _quick_save() -> void:
	if _busy or _vm.state == EclVM.State.MENU or _vm.ecl == null:
		_status.text = "Can't save in the middle of an event; finish it first."
		_note_24("CAN'T SAVE NOW.")
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
	cfg.set_value("qol", "speed", CampScreen.speed)
	cfg.set_value("script", "memory_hi", _vm.hi)
	cfg.set_value("script", "overland", [_vm.on_overland, _vm.overland_band])
	cfg.set_value("qol", "visited", _automap.to_save())
	cfg.set_value("qol", "offers", PackedStringArray(_vm.shown_texts.keys()))
	cfg.set_value("qol", "rememorize", Rememorize.to_save(_party))   # combat lane (C11-2)
	var before := ConfigFile.new()       # the quick save's name stays too (Q22 (c), the combat lane)
	if before.load(_save_path()) == OK and String(before.get_value("qol", "label", "")) != "":
		cfg.set_value("qol", "label", before.get_value("qol", "label"))
	var members := []
	for m in _party:
		var items := []
		for it in m.items:
			items.append(it.to_record())
		members.append({"name": m.name, "record": m.to_record(), "money": m.money, "items": items, "hp": m.hp,
			"experience": m.experience, "status": m.status, "memorized": m.memorized,
			"spell_book": m.spell_book, "affects": m.affects, "npc": m.npc, "quick_order": m.quick_order})
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
	_note_24("GAME SAVED." if err == OK else "THE GAME COULDN'T BE SAVED.")


## P39 (QoL, an exception to the pause, Jeremy 2026-11-14): F2 / F3 say what happened on
## row 24 of the walking screen, in place of its menu, for a moment.
var _row24_note := ""
var _row24_until := 0


func _note_24(text: String) -> void:
	_row24_note = text
	_row24_until = Time.get_ticks_msec() + 1500
	_show()
	await get_tree().create_timer(1.6).timeout
	if Time.get_ticks_msec() >= _row24_until and _row24_note == text:
		_row24_note = ""
		_show()


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
## The game speed (ALTER's SPEED, DS:0x49E2) is part of a save: SAVE copies it into this cell
## (GAME.OVR 0x1FECE, the first array's +0x1F8) and LOAD puts it back (0x1F8F6); a new game starts
## at 1 (0xE999). Ours started every game at 4 and never saved it (Combat Chat 22).
const SPEED_CELL := 0x49FC


func _save_original(letter: String) -> bool:
	if _vm.ecl == null and _starting_party:
		# Before the adventure starts (lab, 2026-11-13): the original saves data set 3, an
		# empty script image and the party (its square bytes 15, 1, facing 6); loading that
		# save goes back to this party menu.
		var blank := PackedByteArray()
		blank.resize(_vm.mem.size())
		# The engine bytes the original has set at that point; without them it won't load
		# the save (lab: these three and the 0 at 0x3207 are enough).
		blank[SPEED_CELL] = CampScreen.speed
		blank[0x49FF] = 3
		blank[EclVM.FILE_SET] = 3
		var ok0 := OriginalSave.write(_game_path, letter, 3, blank, 15, 1, 3, _party, false)
		_party_menu.save_failed = not ok0
		print("   (saved game %s before the adventure%s)" % [letter.to_upper(), "" if ok0 else ": FAILED"])
		return ok0
	if _vm.ecl == null:
		_status.text = "Can't save here."
		_party_menu.save_failed = true
		return false
	if not _vm.on_overland:
		_sync_position_to_vm(_facing)
	# The engine values the original writes into the image only at save time (GAME.OVR
	# 0x1FE77-0x1FEFE) and reads back on load: the data set at 0x6E12 (its GEO and WALLDEF
	# files) and the three wall-set slots at 0x4AFA-0x4AFC with their numbers 1-3 at
	# 0x4AFD-0x4AFF. Lab (chat 22): a save ours made in Sokal Keep after the Slums kept the
	# Slums' 2 and 2, 4, 1 there, and the original stopped with "Unable to load geo in
	# Load3DMap" (then "...wallset in LoadWallSet"); with 4 and 1, 5, 9 it loads and plays.
	var mem := _vm.mem.duplicate()
	mem[EclVM.FILE_SET] = _vm_file
	# Ours keeps the door menu's flags in these cells; the original keeps them elsewhere (DS
	# 0x6DDE), so its saves have 0 here. _enter_script sets them again on a load.
	for a in [DOOR_TRY_BASH, DOOR_TRY_PICK, DOOR_TRY_KNOCK]:
		mem[a] = 0
	var hi := _vm.hi.duplicate()
	mem[SPEED_CELL] = CampScreen.speed
	hi.erase(SPEED_CELL)
	# In the wilderness the original keeps its slots as they stand (lab, chat 25: after a NEW_ECL into
	# 7:26 from the Slums its save still had the Slums' 2, 4, 1; after loading a game there, wall set
	# 0 in slot 1 and nothing in 2-3, 0 / 0xFFFF, the state a new game starts with): the cells hold
	# them (load_original_save puts the reset state there). In a dungeon, its own wall sets.
	var walls: Array = _vm.area_deco if _vm.area_deco.size() == 3 else _deco
	if walls.size() == 3 and int(walls[0]) == 127 and not _vm.on_overland:
		# LOAD_AREA_DECO 127 (the city's) loads wall set 0 into slot 1, which fills all three
		# (GAME.OVR 0x1A6B; WALLDEF3's block 0 is three slots long): the original's saves in New
		# Phlan (checks 1 and 5) hold the reset state.
		for i in 6:
			mem[0x4AFA + i] = WALL_SLOTS_RESET[i] & 0xFF
			hi[0x4AFA + i] = WALL_SLOTS_RESET[i] >> 8
	elif walls.size() == 3 and not _vm.on_overland:
		# Chat 27 (Player 2's request): a slot with no wall set of its own (255, or an id with no
		# WALLDEF block: the block before it fills it) is saved empty, id and number 0xFFFF; the
		# original stopped on "Unable to load wallset" for ours' 255 (8:13) and 25 (5:x). Lab: the
		# original's own save in 8:13 (LOAD_AREA_DECO 17, 18, 255) holds 17, 18, 0xFFFF / 1, 2, 0xFFFF.
		var wd := DaxFile.open(_game_path.path_join("WALLDEF%d.DAX" % _vm_file))
		for i in 3:
			var id := int(walls[i])
			if id == 255 or id == 127 or (wd != null and not wd.blocks.has(id)):
				mem[0x4AFA + i] = 0xFF
				mem[0x4AFD + i] = 0xFF
				hi[0x4AFA + i] = 0xFF
				hi[0x4AFD + i] = 0xFF
				continue
			mem[0x4AFA + i] = id & 255
			mem[0x4AFD + i] = i + 1
			hi.erase(0x4AFA + i)
			hi.erase(0x4AFD + i)
	# Saving over a named slot keeps its name (Jeremy, Q22 (c), 2026-11-17; the combat lane): read before
	# the save is written, while the slot's companion still belongs to it.
	var label := String(CompanionSave.read(_game_path, letter, true).get("label", ""))
	var ok := OriginalSave.write(_game_path, letter, _vm_file, mem, _vm.read_byte(EclVM.PARTY_X),
		_vm.read_byte(EclVM.PARTY_Y), _vm.read_byte(EclVM.PARTY_DIR), _party, true, hi,
		2 + _vm.overland_band if _vm.on_overland else 1, _vm.read_byte(EclVM.WALL_AHEAD),
		_vm.read_byte(EclVM.SQUARE_INFO))
	var qol := {"visited": _automap.to_save(), "offers": PackedStringArray(_vm.shown_texts.keys()),
		"rememorize": Rememorize.to_save(_party)}
	if label != "":
		qol["label"] = label
	if ok and not CompanionSave.write(_game_path, letter, qol):
		print("   (saved game %s: the automap's companion file couldn't be written)" % letter.to_upper())
	_status.text = ("Saved game %s." if ok else "Couldn't write saved game %s.") % letter.to_upper()
	_party_menu.save_failed = not ok
	print("   (saved game %s%s)" % [letter.to_upper(), "" if ok else ": FAILED"])
	return ok


## The original's wall-set slots as a new game starts them (GAME.OVR 0xE906-0xE963): wall set 0
## in slot 1, slots 2 and 3 empty (-1), in the cells 0x4AFA-0x4AFC (ids) and 0x4AFD-0x4AFF
## (numbers). A game loaded in the wilderness has them so too (lab, chat 25, 7:26).
const WALL_SLOTS_RESET := [0, 0xFFFF, 0xFFFF, 1, 0xFFFF, 0xFFFF]


func _wall_slots_reset() -> void:
	for i in 6:
		_vm.write_var(0x4AFA + i, WALL_SLOTS_RESET[i])


## Loads one of the original's own saved games (SAVGAM<letter>.DAT with its CHRDAT<letter>n
## character files) as found in the game folder. The save holds: byte 0 the data set
## (ECLn/GEOn), then the ECL memory cells as words (0x4900-0x4CFF the game's flags and clock, 0x6B00-0x6EFF,
## 0x9700-0x98FF: OriginalSave.cell_address), the
## area's script with its tables as they stood (from 0x1401, the block identifies the area),
## the party's square at 0x3201 (x, y, facing x2), and from 0x3209 the character file names
## (a length byte and 40 bytes each).
func load_original_save(letter: String) -> bool:
	var path := _game_path.path_join("SAVGAM%s.DAT" % letter.to_upper())
	var s := FileAccess.get_file_as_bytes(path)
	_menu_was_wild = false
	if s.size() < 0x3300:
		_status.text = "No saved game %s." % letter.to_upper()
		return false
	var set_no := s[0]
	var ecl := DaxFile.open(_game_path.path_join("ECL%d.DAX" % set_no))
	if ecl == null:
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
	# A game saved before the adventure started (an empty script image, as the original writes
	# it from the starting party menu) goes back to that menu with its party.
	var started := false
	for b in s.slice(0x1401, 0x1401 + 0x1E00):
		if b != 0:
			started = true
			break
	# Our additions from the companion file (CompanionSave): none, or a stale one, gives an
	# empty map.
	var extra := CompanionSave.read(_game_path, letter)
	_automap.from_save(extra.get("visited", {}))
	_shown_from_save(extra.get("offers", []))
	if not started:
		_party.assign(loaded)
		_vm.party = _party
		_open_starting_party_menu()
		_status.text = "Loaded saved game %s." % letter.to_upper()
		return true
	# The area is the block whose script the saved image matches best (SaveSlots.area_block).
	var block_id := SaveSlots.area_block(_game_path, s)
	if block_id < 0:
		_status.text = "Saved game %s: its area wasn't found." % letter.to_upper()
		return false
	_party.assign(loaded)
	_vm.party = _party
	Rememorize.from_save(_party, extra.get("rememorize", {}))   # combat lane (C11-2)
	_timer.stop()
	_busy = false
	_walk_path.clear()
	_held_message = ""
	_event_image = null
	_message.text = ""
	_mode = Mode.WALK
	# The three cell arrays, a word each (OriginalSave.cell_address), straight into memory (the
	# character window's cells too, not through its fields).
	_vm.hi.clear()
	for k in OriginalSave.CELLS:
		var a := OriginalSave.cell_address(k)
		_vm.mem[a] = s[1 + 2 * k]
		if s[2 + 2 * k] != 0:
			_vm.hi[a] = s[2 + 2 * k]
	# GAME.OVR 0x1F8F6: the load zeroes the party-size cell (ours counts the party).
	_vm.mem[EclVM.PARTY_SIZE] = 0
	CampScreen.speed = clampi(_vm.mem[SPEED_CELL], 0, 9)
	# The map the save names (GAME.OVR 0x1FBB3, in LOAD before the init): in a 3D area (view
	# byte 0x49FA below 2) the original loads GEO<data set> block [0x49C5], the map last loaded,
	# then the wall sets of 0x4AFA-0x4AFF. Inits that see 0x49F2 already naming their block skip
	# their LOAD_AREA_MAP (5:4 0x9B6D, 5:7 0x9A42), so without this the party stood on whatever
	# map was up before (chat 29, Player 3: New Phlan's).
	if s[0x3206] < 2:
		var geo := "GEO%d.DAX" % set_no
		for i in _maps.size():
			if _maps[i].file == geo and _maps[i].id == _vm.read_byte(EclVM.AREA_MAP_ID):
				_maps[i].map = GeoMap.decode(_maps[i].block)
				_map_index = i
				_vm_map = i
				_walls_for = -1
				break
	# The saved wall ahead (0x3204), as the original reads it back before the init (chat 61).
	_vm.write_byte(EclVM.WALL_AHEAD, s[0x3204])
	# The saved square, so the init sees it (_enter_script writes _pos and _facing to the VM).
	_pos = Vector2i(s[0x3201] & 15, s[0x3202] & 15)
	_facing = ((s[0x3203] / 2) & 3) as DungeonView.Dir
	# The area's init runs from the saved image with the saved flags, and what it writes stays
	# (the original: LOAD sets 0x49F8, the main loop skips the block load, runs the area entry
	# 0x7689 and the init, and puts nothing back; lab, chat 24: 7:26's init zeroes 0x4A1E and
	# the original's save after a load and two steps has 0). Only the square goes back.
	var code_len := EclScript.decode(ecl.blocks[block_id]).code.size()
	_enter_script(set_no, block_id, true, false, true, s.slice(0x1401, 0x1401 + code_len))
	# The rest of the image (0x1E00 bytes in all) as saved: what longer scripts left past this one's
	# end, which the original loads back and saves again (lab, chat 25: 7:26's save, 856 bytes).
	for i in range(code_len, OriginalSave.SCRIPT_BYTES):
		_vm.mem[EclScript.BASE + i] = s[0x1401 + i]
	if _vm.on_overland:
		_wall_slots_reset()
	_pos = Vector2i(s[0x3201] & 15, s[0x3202] & 15)
	_facing = ((s[0x3203] / 2) & 3) as DungeonView.Dir
	_sync_position_to_vm(_facing)
	_vm.state = EclVM.State.DONE
	_status.text = "Loaded saved game %s." % letter.to_upper()
	_show()
	return true


## The offer texts a save says were shown (CompanionSave / the quick save's [qol] offers); none for
## an original's save without a companion (the tracker then knows those offers by their first step).
func _shown_from_save(keys) -> void:
	_vm.shown_texts.clear()
	if keys is Array or keys is PackedStringArray:
		for k in keys:
			_vm.shown_texts[String(k)] = true


func _quick_load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_save_path()) != OK:
		_status.text = "No quick save yet (F2 in walk mode saves)."
		_note_24("NO QUICK SAVE YET.")
		return
	var map_file: String = cfg.get_value("place", "map_file", "")
	var map_id: int = cfg.get_value("place", "map_id", -1)
	var index := -1
	for i in _maps.size():
		if _maps[i].file == map_file and _maps[i].id == map_id:
			index = i
	if index < 0:
		_status.text = "Quick save names a map that isn't here."
		_note_24("THE QUICK SAVE DOESN'T FIT THIS GAME.")
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
	_shown_from_save(cfg.get_value("qol", "offers", []))
	_facing = int(cfg.get_value("place", "facing", 0)) as DungeonView.Dir
	_vm_file = cfg.get_value("script", "file", 0)
	_vm_block = cfg.get_value("script", "block", -1)
	var ecl := DaxFile.open(_game_path.path_join("ECL%d.DAX" % _vm_file))
	if ecl != null and ecl.blocks.has(_vm_block):
		_vm.load_script(ecl.blocks[_vm_block], "%d:%d" % [_vm_file, _vm_block])
	var memory: PackedByteArray = cfg.get_value("script", "memory", PackedByteArray())
	if memory.size() == _vm.mem.size():
		_vm.mem = memory
		_vm.hi = cfg.get_value("script", "memory_hi", {})
	if cfg.has_section_key("qol", "speed"):
		CampScreen.speed = clampi(int(cfg.get_value("qol", "speed")), 0, 9)
	var wild: Array = cfg.get_value("script", "overland", [false, 0])
	_vm.on_overland = wild[0]
	_vm.overland_band = wild[1]
	_menu_was_wild = false
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
			var m := PartyMember.from_bytes(saved.record, PackedByteArray())
			m.raise_highest()     # the original's recount as the party is loaded (0x1F55A)
			rebuilt.append(m)
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
		_party[i].quick_order = int(saved.get("quick_order", 0))
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
	Rememorize.from_save(_party, cfg.get_value("qol", "rememorize", {}))   # combat lane (C11-2)
	_status.text = "Loaded."
	_note_24("GAME LOADED.")
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
	if dev_step_hook.is_valid():
		dev_step_hook.call(direction)
	_event_image = null
	_vm.sprite_id = -1   # a step redraws the view: a figure left standing there is gone too
	_message.text = ""
	if _vm.on_overland:
		_overland_move(direction)
		return
	if _vm.ecl != null:
		var map: GeoMap = _maps[_map_index].map
		_sync_position_to_vm(direction)
		# A step ahead: the on-move sees the wall ahead as the last step or turn left it (an
		# arrival's stale value too, chat 61). A step another way (ours' Down) faces it first.
		if direction != _facing:
			_vm.write_byte(EclVM.WALL_AHEAD, map.wall(_pos.x, _pos.y, direction))
		_vm.write_byte(EclVM.MOVEMENT_BLOCK, 0)
		# A step that would leave the map (through an open side or a door on the edge): the
		# area's on-move script sees 0x6DD5 set and moves the party into the next area.
		var next := _pos + DungeonView.DELTA[direction]
		var open := map.wall(_pos.x, _pos.y, direction) == 0 or map.door(_pos.x, _pos.y, direction) != 0
		var off := next.x < 0 or next.y < 0 or next.x >= GeoMap.SIZE or next.y >= GeoMap.SIZE
		_vm.write_byte(EclVM.LEAVING_MAP, 1 if off and open else 0)
		# The original writes the square it stands on to 0x49F0/0x49F1 after the on-move script,
		# unless that left the area (GAME.OVR 0x4199 on-move, 0x41A1 NEW_ECL: the arrival; else
		# 0x41B9-0x41CE): a refused step leaves it the current square (5:3's gate, check 24;
		# 4:21's boat, NO: check 45); a step whose on-move leaves the area keeps the square
		# before (8:16's south edge into the wilderness: check 7; a jump save's step: check 54).
		# Written in _after_vm before _finish_move.
		_step_off_map = off
		_vm.clear_output()
		_step_from = _pos
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
		_event_after_refused_step()
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


## A door roll (BASH 0x1695F, PICK 0x16BAA): from the original's dice when a replay runs on them
## (tpseed), so a segment's draws stay in step past a locked door (Combat Chat 18: Player 15's
## p15c7, six d100 for PICK at 2:20 5,7); else the door's own generator, as before.
func _door_die(n: int) -> int:
	return TpDice.between(1, n, "door") if TpDice.on else _door_rng.randi_range(1, n)


func _door_d6(drawn: int) -> int:
	return TpDice.between(1, 6, "door") if TpDice.on else drawn


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
			# With the original's dice (tpseed) each roll is drawn where GAME.OVR 0x1695F draws it: a
			# member whose strength has no chance draws nothing (Combat Chat 18).
			for m in _party:
				var pm := m as PartyMember
				var st := pm.stats[0]
				var ex := pm.strength_exceptional
				var r6 := 0 if TpDice.on else _door_rng.randi_range(1, 6)
				if kind == 3:
					if st == 18 and ex >= 91 and ex <= 99:
						opened = _door_d6(r6) == 1
					elif st == 18 and ex == 100:
						opened = _door_d6(r6) <= 2
					elif st == 19 or st == 20:
						opened = _door_d6(r6) <= 3
					elif st == 21 or st == 22:
						opened = _door_d6(r6) <= 4
					elif st == 23:
						opened = _door_d6(r6) <= 5
					elif st == 24:
						opened = _door_die(8) <= 7
					elif st >= 25:
						opened = true
					else:
						_vm.write_byte(DOOR_TRY_BASH, 0)
				else:
					if st >= 3 and st <= 7:
						opened = _door_d6(r6) == 1
					elif st >= 8 and st <= 15:
						opened = _door_d6(r6) <= 2
					elif st >= 16 and st <= 17:
						opened = _door_d6(r6) <= 3
					elif st == 18 and ex <= 50:
						opened = _door_d6(r6) <= 3
					elif st == 18 and ex <= 99:
						opened = _door_d6(r6) <= 4
					elif st == 18:
						opened = _door_d6(r6) <= 5
				if opened:
					break
		"P":
			_vm.write_byte(DOOR_TRY_PICK, 0)
			if kind == 2:
				for m in _party:
					var pm := m as PartyMember
					if _door_die(100) <= pm.thief_skill(ClassTables.shared(_game_path), 1) and pm.status == 0:
						opened = true
						break
		"K":
			var caster := _knock_caster()
			if caster != null:
				caster.memorized.erase(KNOCK)
				opened = true
	if not opened:
		Speaker.play(Speaker.HIT)    # a door option that fails: GAME.OVR 0x17702 (Combat's sound)
		_show()
		_event_after_refused_step()
		return
	map.set_door(_pos.x, _pos.y, direction, 1)
	var next := _pos + DungeonView.DELTA[direction]
	next = Vector2i(posmod(next.x, GeoMap.SIZE), posmod(next.y, GeoMap.SIZE))
	map.set_door(next.x, next.y, (direction + 2) % 4, 1)
	_step_into(next)


## Completes a move once the on-move script has finished without refusing it.
var _step_from := Vector2i(-1, -1)   # where the party stood when the step's on-move script began
var _step_off_map := false           # ... and that step would leave the map
var _arrival_on_move := false        # an arrival's on-move script is paused (a menu) or running
var _arrival_pending := false        # an arrival's init stopped for the player: its square's event follows
var _arrival_after_init := false     # ... and the arrival was a step or NEW_ECL (the on-move script first)


func _finish_move(direction: int) -> void:
	_pending_move = -1
	if _vm.read_byte(EclVM.MOVEMENT_BLOCK) == 255:
		# A stopped step off the map leaves the party in the area: the square it stands on is
		# the previous square, as for any refused step (DOSBox, 4:21 8,15 S, the boat's NO: 15;
		# written in _after_vm).
		_step_off_map = false
		# The on-move script stopped the step. If it moved the party itself (Valjevo's tower
		# stairs: 3,6 south down to 3,8), the square it put them on runs its event, as in
		# the original (lab, chat 13: the audience hall's text comes at once).
		# (Chat 14: where a walking route joins the two squares, _adopt_position_from_vm had
		# started an animated walk there and _pos was still the old square, so the event never
		# ran; whether a route existed depended on the bot's closed steps, which is why the
		# bot's arrival in the audience hall sometimes didn't run it. The move is a jump.)
		var moved_to := Vector2i(_vm.read_byte(EclVM.PARTY_X) & 15, _vm.read_byte(EclVM.PARTY_Y) & 15)
		if _vm.ecl != null and _step_from.x >= 0 and moved_to != _step_from and not _vm.on_overland \
				and not _walk_path.is_empty():
			_walk_path.clear()
			_timer.stop()
			_busy = false
			_pos = moved_to
			_facing = (_vm.read_byte(EclVM.PARTY_DIR) & 3) as DungeonView.Dir
			if _held_message != "":
				_message.text = _held_message
				_held_message = ""
		# Chat 48: whether the script moved the party or not, the square it stands on then runs
		# its event: the original runs ECL entry [0x49E5] after every step attempt that loaded no
		# new script (GAME.OVR 0x41A1-0x422D); 8:29 5,8's on-move blocks the step north until the
		# door is found, and each such bump rolls the search's eight d6 again (DOSBox, Player 16).
		if _vm.ecl != null and _step_from.x >= 0 and not _vm.on_overland:
			_step_from = Vector2i(-1, -1)
			_sync_position_to_vm(_facing)
			var keep := _vm.text
			_vm.start(1)
			if _vm.text == "" and not _vm.text_changed:
				_vm.text = keep
			_after_vm()
		return
	if _vm.on_overland:
		_overland_step(direction)
		return
	var map: GeoMap = _maps[_map_index].map
	# A wall blocks unless it carries a door.
	if map.wall(_pos.x, _pos.y, direction) > 0 and map.door(_pos.x, _pos.y, direction) == 0:
		Speaker.play(Speaker.HIT)    # a step into a wall: GAME.OVR 0x176FE, heard in DOSBox (Combat's sound)
		_event_after_refused_step()
		return
	if map.wall(_pos.x, _pos.y, direction) > 0 and map.door(_pos.x, _pos.y, direction) >= 2:
		_locked_door(direction)
		return
	# A step off the edge that the area's on-move script didn't turn into a move elsewhere (0x6DD5)
	# comes in on the other side: the original's maps wrap (lab, chat 20: 6:25's cave, west from its
	# west entrance 0,2 the original puts the party at 15,2, in the cave's north half).
	var next := _pos + DungeonView.DELTA[direction]
	next = Vector2i(posmod(next.x, GeoMap.SIZE), posmod(next.y, GeoMap.SIZE))
	_step_into(next)


## The original runs the square's event after every step attempt, a refused one too (GAME.OVR
## 0x41D3-0x422D: the move routine 0x17438, a locked door's menu and its choice included, then ECL
## entry [0x49E5]); chat 48, DOSBox at 8:29 5,8: each bump into the secret door's wall rolls its
## eight d6 again (Player 16). The door menu's case is from the code, not yet seen in DOSBox.
func _event_after_refused_step() -> void:
	if _vm.ecl == null or _vm.on_overland:
		return
	_vm.clear_output()
	_vm.start(1)
	_after_vm()


## The step itself, once nothing stops it: time passes and the new square's event runs.
func _step_into(next: Vector2i) -> void:
	Speaker.play(Speaker.STEP)    # a step in the 3D view: GAME.OVR 0x16E06 (Combat's sound)
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
		_write_wall_ahead()   # GAME.OVR 0x16E71: the new square's wall
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
	# Chat 54 (Player 20's p19c2, 7:26 11,28): a refused step still runs the square's event, with
	# no time passing: GAME.OVR's band move (0x16EE3) leaves the party where it is, and the step
	# routine then runs ECL entry [0x49E5] whether it moved or not (0x4228), as in a 3D area.
	if OverlandMap.water(v) or (OverlandMap.river(v) and _vm.read_byte(0x4AA2) == 0):
		if _vm.ecl != null:
			_vm.clear_output()
			_vm.start(1)
			_after_vm()
		return
	_vm.write_byte(EclVM.OVERLAND_X, x)
	_vm.write_byte(EclVM.OVERLAND_Y, y)
	# A band step writes the square left behind as a dungeon step does: the map square, which
	# the band doesn't move (lab, chat 20: the original's save after a step in 6:25 held it).
	_vm.write_byte(EclVM.PREVIOUS_X, _vm.read_byte(EclVM.PARTY_X))
	_vm.write_byte(EclVM.PREVIOUS_Y, _vm.read_byte(EclVM.PARTY_Y))
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
	# Not the wall ahead (0xC04E, DS 0x6AB0): the original writes it only on a step, a turn, CALL
	# 0xC01E / 0xC018 and a load (chat 61, _write_wall_ahead); an arrival, a script's jump and a
	# fight leave the last step's value.
	_synced = Vector3i(_pos.x, _pos.y, direction)


## The wall ahead (ECL 0xC04E, DS 0x6AB0) from the square the party stands on, facing as it faces,
## on the map up now. Chat 61 (GAME.OVR): written only by a step (0x16E71: the new square's wall; at
## an edge the coordinates wrapped on the map being left), a turn (0x171AE, 0x171F5, 0x1723A), CALL
## 0xC01E (0x8F33) and CALL 0xC018 in a 3D area (0x3B12), and read back from a save; an arrival
## (NEW_ECL, 0x3EFA), a script's jump (0xC04B-0xC04D written) and a fight leave the last value (the
## original's saves: check 49's boat to New Phlan keeps the band's 1, 2:20's patrol (checks 71-73)
## the 0 of the step before the patrol moved the party). Readers: 3:0's night locked door (0x997E),
## 5:5's hedge, 6:1's pen (chat 16: the pen's wall after the step onto 6,9 N), 7:17's camp.
func _write_wall_ahead() -> void:
	if _vm.ecl == null or _vm.on_overland or _maps.is_empty():
		return
	var map: GeoMap = _maps[_map_index].map
	_vm.write_byte(EclVM.WALL_AHEAD, map.wall(_pos.x, _pos.y, _facing))


## For the VM's CALL 0xC01E / 0xC018: the wall at x, y facing d on the map the script has up (a
## LOAD_AREA_MAP takes effect at once, as for _script_square_info).
func _script_wall(x: int, y: int, d: int) -> int:
	if _maps.is_empty():
		return 0
	var i := _map_index
	if not _vm.on_overland and not _vm.area_map.is_empty() and int(_vm.area_map[0]) < 127 \
			and _vm.area_map != _area_map_seen:
		for k in _maps.size():
			if _maps[k].id == int(_vm.area_map[0]):
				i = k
				break
	return _maps[i].map.wall(x, y, d)


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


## The square's info byte for the VM's redraw (CALL 0x2C90). A LOAD_AREA_MAP takes effect at once in the original:
## Kuto's Well's climb up (8:29 0xA26A: LOAD_AREA_MAP 29, then 0x2C90, then the search entry on the square's event)
## reads the well's square on the street map and asks DO YOU WANT TO CLIMB DOWN (Player 17, p16d1). Ours follows the
## map only when the script stops, so it read the catacombs' square under it (event 16: "YOU ARE JUST EAST OF KUTO'S
## WELL." and no question).
func _script_square_info(x: int, y: int) -> int:
	if _maps.is_empty():
		return 0
	var i := _map_index
	if not _vm.on_overland and not _vm.area_map.is_empty() and int(_vm.area_map[0]) < 127 \
			and _vm.area_map != _area_map_seen:
		for k in _maps.size():
			if _maps[k].id == int(_vm.area_map[0]):
				i = k
				break
	return _maps[i].map.flag(x, y)


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
## Lab (PlayBot): event codes whose squares walks keep off unless they are the goal (explore's
## skipped events: Yarash's pyramid's teleporter beside the dial, chat 12).
var avoid_events := {}
## ... and the area ("file:block") they belong to: event numbers are the area's own, so another
## area's squares with those numbers are walked as usual (chat 32: a training trip from 2:9's
## explore found no way off New Phlan's dock, events 2, 3 and 6 round it).
var avoid_area := ""
## True while the bot travels between areas: with no way round the avoided squares, walk through.
var avoid_fallback := false
## Dev (the bot): squares of an area that move the party elsewhere in it when stepped on (the
## pyramid's teleports), "file:block" -> {square: where it lands}; the path finder walks through
## them. Empty in play.
var warps := {}


func _find_path(from: Vector2i, to: Vector2i, keep_off := true) -> Array[Vector2i]:
	var map: GeoMap = _maps[_map_index].map
	var avoiding := keep_off and not avoid_events.is_empty() and avoid_area == "%d:%d" % [_vm_file, _vm_block]
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	var warp: Dictionary = warps.get("%d:%d" % [_vm_file, _vm_block], {})
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == to:
			break
		if cur != from and warp.has(cur):
			# Stepping on it lands elsewhere: go on from there (the walk finds its path again).
			var dst: Vector2i = warp[cur]
			if not came.has(dst):
				came[dst] = cur
				queue.append(dst)
			continue
		for d in 4:
			if map.wall(cur.x, cur.y, d) > 0 and map.door(cur.x, cur.y, d) == 0:
				continue
			if _refused.has("%d:%d,%d,%d" % [_map_index, cur.x, cur.y, d]):
				continue
			var nxt: Vector2i = cur + DungeonView.DELTA[d]
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= GeoMap.SIZE or nxt.y >= GeoMap.SIZE or came.has(nxt):
				continue
			if nxt != to and avoiding and avoid_events.has(map.flag(nxt.x, nxt.y) & 127):
				continue
			came[nxt] = cur
			queue.append(nxt)
	var path: Array[Vector2i] = []
	if not came.has(to):
		# Travelling, with no way round the avoided squares: through them, not no way at all.
		return _find_path(from, to, false) if avoiding and avoid_fallback else path
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
				_timer.start(_script_delay())
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


## A script DELAY: the original waits game speed x 225 ms, no key (GAME.OVR 0x3465, opcode 0x3A,
## START.EXE 0x709:0xDBE). A Timer can't start at 0, hence the floor.
func _script_delay() -> float:
	return maxf(CampScreen.speed * 0.225, 0.001)


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
				_timer.start(_script_delay())
			return
		EclVM.State.MENU:
			if _vm._menu_kind == "press":
				return   # drawn on row 24 by _show
			if _vm.menu_vertical:
				# The original clears the text area for a vertical menu and shows its question.
				_menu_sel = 0
				if _held_message != "":
					_held_message = _vm.menu_question
				else:
					_message.text = _vm.menu_question
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
			_sync_shell()
			_temple.open(_party, _vm.selected)   # opens on the selected member (combat lane, Combat Chat 7)
			_dev_reseed([_temple._rng])
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
			_by_new_ecl = true
			_step_off_map = false
			_enter_script(set_no if set_no >= 1 and set_no <= 8 else _vm_file, _vm.new_ecl, true, true)
			return
		EclVM.State.ERROR:
			_message.text += "\n[script error: %s]" % _vm.error
	if _pending_move >= 0 and _vm.state == EclVM.State.DONE:
		# The step's on-move is done without leaving the area: the square of the attempt is
		# the previous square (GAME.OVR 0x41B9; see _try_move's note).
		if _step_from.x >= 0 and not (_step_off_map and _vm.on_overland):
			_vm.write_byte(EclVM.PREVIOUS_X, _step_from.x)
			_vm.write_byte(EclVM.PREVIOUS_Y, _step_from.y)
		_finish_move(_pending_move)
	elif _arrival_pending and _vm.state == EclVM.State.DONE:
		# The arrival's init has ended after stopping for the player (see _enter_script).
		_arrival_pending = false
		if not _arrival_event(_arrival_after_init):
			_after_vm()
	elif _arrival_on_move and _vm.state == EclVM.State.DONE:
		# The arrival's on-move script is done (see _enter_script): a stop with the party moved
		# runs the new square's event, as at the end of a step.
		_arrival_on_move = false
		if _vm.read_byte(EclVM.MOVEMENT_BLOCK) == 255:
			_finish_move(int(_facing))
		else:
			# Otherwise the square's event follows, as after an on-move that doesn't stop
			# (GAME.OVR 0x400E: the arrival runs [0x49E5] whatever the on-move showed; chat 55,
			# DOSBox: 1:18's PLAZA AHEAD menu, DISGUISE, then 12,8's d25 and the goblins).
			_arrival_square_event()
			_after_vm()


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
		# ADD_NPC (GAME.OVR 0x38C4) sets the side byte 0x10E: 0 (with the party) for every NPC but
		# monster 0x18, which joins turned (1). The monster record's own 0x10E stayed before chat 29,
		# so with Combat Chat 6's turned members (0x10E = 1 fights with the monsters) DIRTEN fought
		# the party from his first fight (full run c29a, 2:15).
		if m.raw.size() > 0x10F:
			m.raw[0x10E] = 1 if int(req[0]) == 0x18 else 0
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
			_sync_shell()
			# The hall opens on the selected member and leaves its own pick selected (Combat Chat 19, c18c7:
			# the original's training opened on BRAM, lit after the treasure, and DORN, trained last, paid at the inn).
			_party_menu._sel = clampi(_vm.selected, 0, maxi(_party.size() - 1, 0))
			_party_menu.open(_party, _vm.read_byte(EclVM.TRAINING_MASK))
			_dev_reseed([_party_menu._rng])
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
					# The original redraws the 3D view after the closing scene: "KNOWING THAT
					# TYRANTHRAXUS..." shows over the hall, not the dragon's portrait (lab, chat 24).
					_event_image = null
					_vm.sprite_id = -1
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
		# START MEMORIZED (QoL, SETTINGS): casters pick their spells first, memorized at once.
		# Not in the lab's bot or key-replay runs.
		var lab := Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--play=") or a.begins_with("--keys="))
		if CampScreen.start_memorized_on() and not lab \
				and _camp.open_start_memorize(_party, SpellTable.shared(_game_path)):
			return
		_begin_adventure()
		return
	_vm.write_byte(EclVM.TRAINING_MASK, 0)
	_message.text = ""
	# The member lit in the hall stays the selected one (Combat Chat 19, c18c7 s3a -> slums2: DORN, trained
	# last, paid at the inn in the original; ours went back to ARN).
	if not _party.is_empty():
		_vm.selected = clampi(_party_menu._sel, 0, _party.size() - 1)
		_vm.walk_selected = _vm.selected
	_vm.close_program()
	_after_vm()
	_show()


func _begin_adventure() -> void:
	_new_game()
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
	_sync_shell()
	_shop.open(stock, _party, "SHOP", _vm.selected)
	_dev_reseed([_shop._rng])


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
	# The camp opens on the member selected on the walking screen and hands its choice back
	# (one selection in the original; lab, chat 22: End x4, ENCAMP, MAGIC, SCRIBE answered for
	# DARKSTAR).
	_camp._sel = clampi(_vm.selected, 0, maxi(_party.size() - 1, 0))
	_sync_shell()
	_camp.open(_party, _vm.read_byte(REST_PERIOD), _vm.read_byte(REST_PERCENT))
	_dev_reseed([_camp._rng, _camp._rng2])


func _on_temple_closed() -> void:
	_message.text = ""
	if not _party.is_empty():
		_vm.selected = clampi(_temple.who(), 0, _party.size() - 1)
		_vm.selected_creature = -1
	_vm.close_temple()
	_after_vm()
	_show()


func _on_camp_closed() -> void:
	GameClock.add_minutes(_vm, _camp.minutes_passed)   # the camp has already run the effects
	if not _party.is_empty():
		_vm.selected = clampi(_camp._sel, 0, _party.size() - 1)
	# Leaving camp redraws the 3D view (P63, lab chat 29: the inn at New Phlan 6,12, PICTURE 24 then
	# PROGRAM 9; after EXIT the original shows the street at 6,13 N, not the innkeeper).
	_event_image = null
	_vm.sprite_id = -1
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
	_fight_made = _vm.treasure_items.duplicate()
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
	if dev_rng != null:
		CombatScreen.dev_seed = dev_rng.randi() | 1
	# The script's fight modifiers (ECL 0x6E70-0x6E72: the kobold caves' nets; side lane).
	_combat.area_mods = [_vm.read_byte(0x6E70), _vm.read_byte(0x6E71), _vm.read_byte(0x6E72)]
	_combat.anti_magic = _vm.read_byte(0x49E5) > 0   # the shell (combat lane, Combat Chat 2)
	_combat.area_block = _vm.read_byte(CURRENT_BLOCK)   # the clutter rule (combat lane, Combat Chat 5)
	if _duelist != null:
		_combat.duel_party = _party.duplicate()   # a duel's figure order (combat lane, Combat Chat 6)
	if CombatScreen.paced():
		# Combat's: the original's fight setup prints "A battle begins..." on row 24 (light green)
		# before the battlefield shows (GAME.OVR 0xE448; ~0.2 s in main's cold-open capture).
		_battle_begins = true
		_show()
		await get_tree().create_timer(0.2).timeout
		_battle_begins = false
	_combat.open_event(_game_path, map, _pos.x, _pos.y, int(_facing), fighters, maxi(_vm_file, 1),
		_vm.monsters, _vm.encounter_max, _vm.encounter_advances,
		_vm.read_byte(EclVM.MORALE_BASE), _vm.read_byte(EclVM.AMBUSH), opponents, _vm.monster_teams)
	# The original clears the surprise flag after every round's initiative (GAME.OVR 0x98F4: game
	# state +0x596 = 0), so it counts for this fight's first round only and a later fight without
	# its own SURPRISE starts even (Combat Chat 16, Player 11's p11t1 draw 3613; combat lane).
	_vm.write_byte(EclVM.AMBUSH, 0)


var _duelist: PartyMember = null
var _arena := false
var _battle_begins := false    # row 24 says A BATTLE BEGINS... for a moment before a fight (Combat)
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
	# The fight drew over the view: back on the walking screen the original shows the 3D view, not
	# the encounter's picture (chat 40, DOSBox: the Slums' orcs at 13,1 W, the corridor after the
	# treasure; the picture stays up only until the fight opens).
	_event_image = null
	_vm.sprite_id = -1
	# ECL 0x6DC8: how many monsters the fight put down (GAME.OVR 0x672A counts the combatants it
	# takes off the list). Lab, chat 18: 4:10's army of 105 skeletons, 63 on the field (the most a
	# fight holds), all destroyed: after the script's SUBTRACT [6DC8], [4A01] and ADD [6DC8], [4A39]
	# the original's save had 0x4A01 = 42 and 0x4A39 = 63. Ours had left it 0, so the graveyard's
	# kill counters (and 2:20's, 8:16's) never grew.
	_vm.write_byte(EclVM.DEFEATED, mini(_combat.defeated().size(), 255))
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
	var beaten := _combat.defeated()
	# Combat Chat 15 (Player 11's fallen NPC; DOSBox, p11t1): a party member who fought on the monsters'
	# side (record 0x10E = 1: DIRTEN, saved so) is a monster figure at the fight's end: his money and
	# items go to the pile with the monsters' (0x557E, already in defeated()) and he leaves the party
	# (0x672A removes every figure on side 1). Seen: the original's list after the fight has six members.
	for m in _combat.turned_members():
		_party.erase(m)
		_vm.party_changed = true
	_vm.selected = clampi(_vm.selected, 0, maxi(_party.size() - 1, 0))
	_after_fight(beaten, "THE PARTY HAS WON.", _combat.dropped_items())


## Experience and treasure: from the defeated monsters and the event's TREASURE, then the
## results and treasure screens; the script carries on when they close.
func _after_fight(defeated: Array, won_text: String, field_items: Array[GameItem] = []) -> void:
	var coins := []
	var list_id := 255
	if _fight_treasure.size() >= 8:
		coins = _fight_treasure.slice(0, 7)
		list_id = int(_fight_treasure[7])
	var found: Array[GameItem] = _fight_made.duplicate() if list_id >= 128 else _item_list(list_id)
	_fight_made = []
	for it in found:
		if it.name == "":
			it.name = ItemNames.shared(_game_path).name_of(it)
	found.append_array(field_items)
	var spoils := Spoils.gather(defeated, coins, found, _vm.read_byte(0x6DE3) != 1)
	var hidden := _hirelings_take_shares(spoils)
	if hidden != "":
		won_text += "\n" + hidden
	var standing: Array = []
	for m in _party:
		if m.can_fight():
			standing.append(m)
	var share := spoils.award(standing, _duelist)
	_duelist = null
	for m in _party:
		m.recalculate(_types)
	_treasure.picture = _event_picture(255, 1)     # the chest (lab: PIC block 1)
	_sync_shell()
	_treasure.open(spoils, _party, won_text, share)


func _on_treasure_closed() -> void:
	for m in _party:
		m.recalculate(_types)
	_fight_treasure = []
	_message.text = ""
	# The member lit on the treasure screen stays the selected one (Player 16's p16d1: ELWEN lit at its EXIT,
	# the next camp's Home lights CEDRIC; ours went back to the first).
	if _treasure._who >= 0 and _treasure._who < _party.size():
		_vm.selected = _treasure._who
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
	# The last buyer stays selected (Combat Chat 23: the shop moves the one selected member; Player 19's p13a1).
	if not _party.is_empty():
		_vm.selected = clampi(_shop.buyer(), 0, _party.size() - 1)
		_vm.selected_creature = -1
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
func _enter_script(file_no: int, block_id: int, follow_map: bool = true, arrive: bool = false, loading: bool = false, image := PackedByteArray()) -> void:
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
	if arrive and not loading:
		_menu_was_wild = _vm_block in WILD_MODE_BLOCKS   # 0x49F9 = 0x49FA, the area left (GAME.OVR 0x3F2B)
	_vm_file = file_no
	_vm_block = block_id
	_step_from = Vector2i(-1, -1)
	_arrival_on_move = false
	_arrival_pending = false
	# A step through the map's edge (the leaving script's CALL 0xC01E) ends on the new area's
	# edge square, as a jump straight to a square does (boats, gates; lab, chat 8): the step
	# doesn't carry on into the new area (chat 51, DOSBox and differential check 38: 8:29 15,11 E
	# arrives in the Slums at 0,11 and 2:20 0,4 W in Kuto's Well at 15,4, no minute passing;
	# Player 18's 54 crossings agree).
	# After a NEW_ECL the original (GAME.OVR 0x3EFA) runs the new block's init, then its on-move
	# (0x3FFF) and, unless that moves on again, the square's event (0x400E), whatever started it:
	# a step, a square's event (the closing scene into New Phlan: its on-move sets the sky,
	# 0x49FD/E, differential check 5) or a menu. A new game or a load goes through the main
	# loop (0x403E) instead: the init, then the adventure menu.
	var from_step := arrive and (_pending_move >= 0 or _by_new_ecl)
	_by_new_ecl = false
	if arrive:
		# The leaving script may have moved the party (CALL 0xC01E steps through the edge).
		_pos = Vector2i(_vm.read_byte(EclVM.PARTY_X) & 15, _vm.read_byte(EclVM.PARTY_Y) & 15)
		_facing = (_vm.read_byte(EclVM.PARTY_DIR) & 3) as DungeonView.Dir
	# A loaded game runs the script image it saved (tables as they stood), not the block as
	# shipped: the original's main loop skips its block load (GAME.OVR 0x7814) while 0x49F8,
	# set by LOAD at 0x19D91, is 1, and runs the init from the image in memory.
	_vm.load_script(image if not image.is_empty() else ecl.blocks[block_id], "%d:%d" % [file_no, block_id])
	# Entering an area zeroes ECL 0x4A00-0x4A1F, the scripts' per-visit bytes (the Slums'
	# greeting 0x4A00, Sokal Keep's dead elf, City Hall's "visited this time" 0x4A01 that
	# keeps the clerk from looking for rewards). 0x4A20-0x4AFF carries over from area to
	# area. Lab, chat 8: a save with 0x4A01-0x4A3F all 0x11, entering New Phlan from the
	# Slums, saved again: 0x4A00-0x4A1F were 0 (0x4A17 = 1, set by New Phlan's init) and
	# 0x4A20-0x4A3F still 0x11; leaving City Hall and coming back made the clerk check for
	# rewards again. Chat 6's evidence agrees (Kuto's Well's 0x4A23 survived trips away).
	# A loaded save keeps them for its init (lab, chat 16: a game saved down Kuto's Well, 0x4A10 = 1,
	# loads in the original down the well: 8:29's init loads map 32 when 0x4A10 is 1; zeroed, it
	# loaded the top, map 29).
	if not loading:
		for a in range(0x4A00, 0x4A20):
			_vm.write_byte(a, 0)
	# GAME.OVR 0x7792, the same routine (before the loading test): 0x49E6 = 1. The wilderness
	# bands' scripts set it to 0 while the wilderness view is up and back to 1 at their sites; the
	# encounter menu offers ADVANCE only while it is set (chat 18, EclVM._show_encounter_menu).
	_vm.write_byte(EclVM.VIEW_3D, 1)
	# The same routine (GAME.OVR 0x7689, no branch before 0x771B) clears 0x49E5 on every area
	# entry: the anti-magic flag the ruined castle's init sets ("YOU SENSE AN ANTI-MAGIC SHELL",
	# 8:16 0x9BEE; tested at 0x9F59, 0xAFF6, 0x17BB2, 0x21FD6). Differential check 7 (chat 22):
	# ours kept it after leaving the castle.
	_vm.write_byte(0x49E5, 0)
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
		if _arrival_event(from_step):
			return
	elif arrive and _vm.state != EclVM.State.NEW_ECL:
		# The init stopped for the player (a menu, a text to read: Rolf's tour, 3:0's init when
		# 0x4AC5 is 0). The original's arrival (GAME.OVR 0x3EFA) still goes on to the on-move
		# script and the square's event once the init ends, on the square the init left the
		# party on (lab, chat 36: after "OUR TOUR IS ENDED" DOSBox shows 0,4's gateway text,
		# 0xAAD8). _after_vm runs it when the init is done.
		_arrival_after_init = from_step
		_arrival_pending = true
	_after_vm()


## The arrival on a new area's square after its init (see _enter_script): the on-move script
## when a step or NEW_ECL brought the party, then the square's event. True when it has handed
## over (shown something or moved on): the caller returns.
func _arrival_event(from_step: bool) -> bool:
	# As in the original, the square arrived on runs its event (New Phlan's gateway
	# text when coming in from the Slums).
	_sync_position_to_vm(_facing)
	if from_step:
		# The step goes on in the new area, starting again with its on-move script (lab,
		# chat 13: a step that enters Podol Plaza shows its "HOW WILL YOU PROCEDE?" menu
		# at once, before the square's own event, which follows it: chat 55).
		var before := _vm.text
		_step_from = _pos
		_arrival_on_move = true
		_vm.start(0)
		var shown := _vm.text.strip_edges() != "" and _vm.text != before
		if not _vm.state in [EclVM.State.DONE, EclVM.State.IDLE]:
			_after_vm()     # the event follows when the on-move is done (_after_vm)
			return true
		_arrival_on_move = false
		if not shown:
			_vm.text = before
	_arrival_square_event()
	return false


## The arrival's last part: the square's event (GAME.OVR 0x400E), keeping the box's text when
## the event prints nothing.
func _arrival_square_event() -> void:
	_sync_position_to_vm(_facing)
	var keep := _vm.text
	_vm.start(1)
	if _vm.text == "" and not _vm.text_changed:
		_vm.text = keep


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
		if ecl == null:
			push_warning("no ECL%d.DAX for script %s" % [file_no, key])   # chat 18: was a crash
			return null
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
	if dev_no_draw:
		# Chat 17: the lab's headless runs (--no-draw) skip the drawing: about 9 ms a call, a
		# third of a coverage run's time. Only what the game needs from here is done.
		if not _vm.on_overland:
			_ensure_area_script()
			# The automap's visited squares still count (chat 37): the bot's checkpoints are quick
			# saves, and a checkpoint loaded for play or a recording should carry the map.
			_automap.place(e.map, "%s:%d" % [e.file, e.id], _pos, int(_facing), area.to_upper())
		return
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
		("night" if night else "day") + ("  SEARCH" if _searching else ""), script_name]
	if _screen.visible:
		_draw_screen()


## The adventure screen as the original shows it.
func _draw_screen() -> void:
	var body := _message.text
	var menu: Array = ["AREA", "CAST", "VIEW", "ENCAMP", "SEARCH", "LOOK"]
	var selected := 0
	var vertical: Array = []
	var who_label := ""
	var press24 := false
	if _vm._menu_kind != "who" or _vm.state != EclVM.State.MENU:
		_who_open = false
	if _door_options != "":
		var words := {"B": "BASH", "P": "PICK", "K": "KNOCK", "E": "EXIT"}
		menu = []
		for c in _door_options:
			menu.append(words[c])
		body = ""
		menu.push_front("LOCKED.")
	elif _vm.state == EclVM.State.MENU and not _vm.menu.is_empty() and _vm._menu_kind == "who":
		# WHO: the question on row 24 (magenta) with SELECT, the member picked on the party
		# list, the text box empty (lab, chat 22: the inn's WHO WILL PAY?).
		if not _who_open:
			_who_open = true
			_menu_sel = clampi(_vm.selected, 0, _vm.menu.size() - 1)
		body = ""
		menu = []
		who_label = _vm.text.strip_edges()
	elif _vm.state == EclVM.State.MENU and _vm._menu_kind == "press":
		menu = []
		press24 = true
	elif _vm.state == EclVM.State.MENU and not _vm.menu.is_empty():
		var cut := body.rfind("\n\n")
		if cut >= 0:
			body = body.substr(0, cut)
		menu = _vm.menu.duplicate()
		selected = clampi(_menu_sel, 0, menu.size() - 1)
		if _vm.menu_vertical:
			vertical = menu
			menu = []
	elif _vm.state == EclVM.State.INPUT:
		menu = []
	elif _busy:
		menu = []
	elif _vm.state in [EclVM.State.IDLE, EclVM.State.DONE]:
		# The walking menu (see _menu_was_wild).
		var wild_mode: bool = _vm_block in WILD_MODE_BLOCKS
		if wild_mode and _vm.on_overland and not _menu_was_wild:
			body = ""
			_message.text = ""
		_menu_was_wild = wild_mode
	var view := _view_img
	if _area_view and not _vm.on_overland:
		view = _area_picture()
	var place := _place_line()
	var wild := _vm.on_overland and _event_image == null and not _area_view
	if _vm.on_overland:
		menu.erase("AREA")
	if _searching:
		place += " SEARCH"
	# A DAMAGE page keeps its leading blank row (the original's cursor starts the first hit a row down).
	var lines := GameScreen.wrap(body.strip_edges(not press24, true), 38)
	var white := -1
	if not vertical.is_empty():
		white = lines.size() + selected
		for it in vertical:
			lines.append(String(it))
	OverlayLook.last_view = view
	OverlayLook.last_wild = wild
	OverlayLook.last_overland = _vm.on_overland
	OverlayLook.last_place = place
	var note24 := _row24_note != "" and Time.get_ticks_msec() < _row24_until
	if note24 or _battle_begins:
		menu = []
	var lit := clampi(_vm.selected, 0, maxi(_party.size() - 1, 0))
	if who_label != "":
		lit = clampi(_menu_sel, 0, maxi(_party.size() - 1, 0))
	_screen.draw_walk(view, _party, lit, place, lines, menu, wild, _vm.on_overland, selected if not _busy and _door_options == "" else -1, white)
	if who_label != "":
		_screen.party_clickable(_party.size(), lit)   # Combat Chat 13, mouse step 2: a WHO list's lines (Up / Down)
	if _battle_begins:   # over any row-24 note (Combat Chat 12: a load's GAME LOADED. hid it)
		_screen.text(0, 24, "A BATTLE BEGINS...", GameScreen.GREEN)   # GAME.OVR 0xE448 (Combat)
		_screen.update()
	elif note24:
		_screen.text(0, 24, _row24_note, GameScreen.WHITE)
		_screen.update()
	elif press24:
		_screen.text(0, 24, String(_vm.menu[0]) if not _vm.menu.is_empty() else EclVM.PRESS_TO_CONTINUE, GameScreen.WHITE)   # GAME.OVR 0x37CD, colour 15
		_screen.update()
	if _vm.state == EclVM.State.INPUT and _typed.visible:
		# What's typed, as the original shows it (lab, chat 23, the Slums' booth: "WHAT DO YOU
		# SAY?" then O, H: " OH" in white on row 24 from column 1, no box, no cursor seen). P53.
		_screen.text(1, 24, _typed.text.to_upper(), GameScreen.WHITE)
		_screen.update()
	if who_label != "":
		_screen.text(0, 24, who_label, 13)
		_screen.menu_line(24, ["SELECT"], who_label.length() + 1, 0)
		_screen.update()


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
	GameCopy.finish()
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


## Dev (M6 coverage runs): the game's state between steps, in memory: place, script (its
## memory, dice and any open menu), party. Debug builds only.
## Lab (chat 16): the game saved here and loaded again, as load_original_save does it: the
## area's init runs from the script image with the saved flags (0x4900-0x52FF, the per-visit bytes
## too) and keeps what it writes (chat 25, as the original); the square goes back as saved. Scripts test for it (0x49F2 already this block).
func dev_reload() -> bool:
	if _vm.ecl == null or _vm.on_overland or _busy or not _vm.state in [EclVM.State.IDLE, EclVM.State.DONE]:
		return false
	var at := _pos
	var facing := int(_facing)
	var image := _vm.mem.slice(EclScript.BASE, EclScript.BASE + _vm.ecl.code.size())
	_enter_script(_vm_file, _vm_block, true, false, true, image)
	_pos = at
	_facing = facing as DungeonView.Dir
	_sync_position_to_vm(_facing)
	_vm.state = EclVM.State.DONE
	_show()
	return true


func dev_snapshot() -> Dictionary:
	if not DevShortcuts.allowed():
		return {}
	var members: Array = []
	for m in _party:
		members.append(m.clone())
	return {"map_index": _map_index, "pos": _pos, "facing": int(_facing), "file": _vm_file,
		"block": _vm_block, "vm": _vm.fork(null), "party": members, "searching": _searching}


## Dev (M6 coverage runs): takes menu choice `i` as the keys would (any menu, any length).
func dev_choose(i: int) -> void:
	if _vm.state != EclVM.State.MENU or i < 0 or i >= _vm.menu.size():
		return
	_menu_sel = i
	_message.text = ""
	if dev_choice_hook.is_valid():
		dev_choice_hook.call(i)
	_vm.choose(i)
	_after_vm()
	_show()


## Puts the game back to a dev_snapshot (the snapshot stays as it was, for another use).
func dev_restore(s: Dictionary) -> bool:
	if not DevShortcuts.allowed() or s.is_empty():
		return false
	dev_restores += 1
	_timer.stop()
	_busy = false
	_walk_path.clear()
	_held_message = ""
	_pending_move = -1
	_event_image = null
	_message.text = ""
	_lost = false
	tour_stop = false
	for o in [_shop, _treasure, _camp, _temple, _party_menu, _sheet]:
		if o != null:
			o.visible = false
	_mode = Mode.WALK
	_map_index = int(s.map_index)
	_vm_map = _map_index
	_walls_for = -1
	_vm_file = int(s.file)
	_vm_block = int(s.block)
	_vm.copy_from(s.vm)
	var members: Array[PartyMember] = []
	for m in s.party:
		var c: PartyMember = (m as PartyMember).clone()
		c.recalculate(_types)
		members.append(c)
	_party.assign(members)
	_vm.party = _party
	_pos = s.pos
	_facing = int(s.facing) as DungeonView.Dir
	_searching = bool(s.searching)
	_step_from = Vector2i(-1, -1)
	_arrival_on_move = false
	_arrival_pending = false
	_synced = Vector3i(-1, -1, -1)
	_sync_position_to_vm(_facing)
	_show()
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
