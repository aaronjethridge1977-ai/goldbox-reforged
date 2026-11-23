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
## A player answered YES at "ATTACK ALLY:" (the game sets 0x6E33 = 1; chat 17).
signal ally_attacked

const VIEW_CELLS := 7
const CELL := 24
## RANDCOM's pictures 0x26 (ground 0x1E) and 0x27 (ground 0x1F, a fallen party member), P40.
const CLOUD_TILE := 38
const BODY_TILE := 39
const SCALE := 3

var _field: Battlefield
var _art: CombatArt
var _party: Array[PartyMember] = []
var _monsters: Array[PartyMember] = []
var _combatants: Array = []      # [{who: PartyMember, team: 0 party / 1 monsters, cell: Vector2i, icon: Image}]
var _selected := 0
var _last_dropped: Array[GameItem] = []
var _last_paid: Array = []       # Combat.paid of the fight just left (main's award; Combat Chat 53)
var _last_rounds := 0          # rounds() after _leave: main adds them to the clock (finished)
var _aiming := false          # AIM: choosing a target
var _aim_list: Array[int] = []
var _aim_index := 0
# CAST: "" (not casting), "choose" (the spell list) or "aim" (where it goes)
var _casting := ""
var _spell_list: Array[int] = []
var _spell_index := 0
var _spell_id := 0
var _spell_cell := Vector2i.ZERO
var _spell_picks: Array[int] = []
var _picks_left := 0          # the aim's picks still to make (GAME.OVR 0x14AD1's count)
var _view := Vector2i.ZERO       # top-left cell of the 7x7 window
var _facing := 0
var _morale_base := 99      # the encounter's morale (from the script)
## Set by the caller just before a scripted fight: ECL 0x6E70, 0x6E71, 0x6E72 (bytes, signed)
## (monsters' to-hit, the party's to-hit, the party's movement); see Combat.
var area_mods: Array[int] = [0, 0, 0]
## The area's ECL block (0x49F2, main sets it): the original's clutter skips bones and flowers
## in block 10 (GAME.OVR 0xC67B tests DS:0x84DC, its copy of the block).
var area_block := 0
## Set by main before a scripted fight in the wilderness bands (the original's view DS:0x49FA
## 2-4): [band 0-2, x, y, ECL 0x4AB3]; empty elsewhere. See Battlefield.make_wild.
var wild: Array = []
## Set by main before a scripted fight: ECL 0x49E6 is 0 (the wilderness view). COMBAT (GAME.OVR
## 0x253D) takes the lesser of the approach distance (ECL 0x6DC1) and 0x7955's open squares
## ahead, and 0x7955 with 0x49E6 at 0 sets 0x6DC1 to 2 and gives 2: the fight starts at 2
## whatever the event's own maximum and advances (8:27's kobolds, main's ready check).
var open_two := false
var anti_magic := false                  # set by main before a fight: ECL 0x49E5 above 0 (the shell)
var _surprise := 0          # the script's ambush flag
var _px := 0
var _py := 0
var _distance := 0
var _mon_file := 1
var _monster_teams: Array[int] = []
var _monster_morale: Array[int] = []   # a script's morale per loaded creature (EclVM.monster_morale), -1 none
## Dev shortcut (M6, PlayBot): the next scripted fight is won at once. Debug builds only.
var dev_auto_win := false
## Dev only (M6): asked at each new round with the round number; true ends the fight as won
## (the bot's stalemate rule: nobody has been hurt for many rounds).
var dev_round_check: Callable
var _dev_win_now := false
var dev_flee := false               # dev (chat 15): the next scripted fight is fled at once
var dev_win_if: Callable          # (rows) -> bool, asked as each scripted fight opens   # each loaded creature's 0x6C0C (0x80: fights for the party)
var _encounters: Array = []      # [{monsters: [[id, count, picture]], text}]
var _enc_index := 0
var _pictures: Array[int] = []   # icon id for each of _monsters
var _types: ItemTypes
var _game_path := ""

var _combat: Combat = null
var _messages := PackedStringArray()
## P16 (side chat 4): the original's pacing of a fight's messages (lab, 2026-11-14, the Slums orcs
## filmed at 30 frames a second at game speeds 0, 4 and 9). A blow's message appears about 0.2 s
## after the blow, stays game speed x 0.2 s (0.8 s at 4, 1.8 s at 9, a flash at 0) and is cleared
## before the next; "GOES DOWN ..." is added under the blow's lines, "YOUR TEAMMATE IS DYING" goes
## on row 24. The next figure acts only once its messages are shown. Display only: off in headless,
## --play, --keys and --fast runs (the lab's --anim turns it on there), so the bot, the coverage
## runs and the lab's replays are unchanged.
const MESSAGE_GAP := 0.2
const TURN_START := 0.05
var _panel_msgs := PackedStringArray()      # paced: the messages now on the right
var _pending_msgs := PackedStringArray()    # paced: still to be shown
var _pending_subj: Array[int] = []           # each one's Combat.fx_subject when it was said
var _row24_msg := ""
# A player's aimed spell (Combat Chat 23, DOSBox, save E's Bakshi, Sleep; GAME.OVR 0x27D60): "<NAME> CASTS A SPELL"
# first, rows 23-24 empty, for a message's time (_announcing), then the aim; after TARGET no second line: the
# spell's lines show under the aim's rows 23-24, left as they were (_aim_rows_kept) until the last one.
var _announcing := false
var _announced := false
var _aim_rows_kept := false
var _kept_prompt := ""
var _kept_items := []
var _kept_lit := 0
var _cast_announced := false
const CAST_MARK := "\u0001CAST"
var _draining := false
var _muted := false
## P16 step 3: computer turns step by step (lab: the view's corner read from the battlefield
## record, DS:[0x6716] bytes 2-3, through a whole fight). GAME.OVR 0x30F0E keeps a cell in view:
## if it is more than `margin` from the view's centre on an axis, the centre moves onto it on
## that axis (centre column 3-46, row 3-21). A turn starts with the actor at margin 2; a computer-run step
## keeps the new cell in the 7x7 view (margin 3; GAME.OVR 0x12F0D: if it was off the view, the
## walker's own cell comes within 2 first), a step the player makes keeps it within 1; a
## hand-to-hand blow brings its target within 2 (0xB9F5: the cell beside the attacker toward it). Steps come
## about 0.15 s apart; a monster's or QUICK member's first TURN_START after its turn starts (Combat
## Chat 12: the original's first step is in the frame after the panel's). "MOVE/ATTACK, MOVE
## LEFT = n" is on row 24 while a computer turn walks; the actor's grey box goes once it acts.
## P16 step 4: blows and missiles (lab, filmed): the attacker shows its attack pose (icon block
## + 128) from the blow until its messages are done. A missile flies from the attacker's square to
## the target's in 8-pixel steps (a dart ~720 px/s, Magic Missile ~240), once a volley, before
## the first message; a target off the view first brings the view's centre to the midpoint
## (rounded up). Darts, arrows and quarrels fly as the arrow for their direction, a sling's stone
## and other thrown weapons as COMSPR's two-frame stone and axe.
signal flight_done
var _posed := -1
var _message_count := 0   # every message so far (_messages keeps only the last six)
var _flying := false
var _flight := {}          # {img: Image, at: Vector2i} while a missile is drawn
var _spell_flight := {}
var _cast_sound := 0         # the sound of the spell whose CASTS / USES line is still to show
var _hold_seq: Array = []    # Hold Person's targets as taken, last aimed first: [name, cell, flown to before its line]
var _hold_from := Vector2i.ZERO
var _spell_hits: Array[int] = []   # figures the last spell reached, not yet shown
var _sparkle := -1                 # the figure showing a spell's sparkles
## The picture shown on a figure the spell reaches (COMSPR block and its second frame): the sparkles (picture 0x12)
## for most spells; the burst (0x13: GAME.OVR 0x298D4 the bolt's hit on a square, 0x2A1C6) for Fireball, Lightning
## Bolt and the Javelin of Lightning (P86, seen in DOSBox, Combat Chat 42).
var _hit_pic: Array = [9, 137]
## Lightning Bolt's and the Javelin's walk (P86): the squares still to crackle through (CombatSpells.bolt_path, taken
## at the first hit's line) and where the crackle is.
var _bolt_walk: Array[Vector2i] = []
var _bolt_on := false
var _bolt_started := false
var _crackle_at := Vector2i.ZERO
## A figure struck down stays standing through the blow's message; its fall shows COMSPR's
## skull (block 11) on its square while "GOES DOWN ..." is up, then the square is empty (lab:
## Bakshi and the orcs at speed 4, 0.8 s).
var _lingering: Array[int] = []
var _skulls: Array[int] = []    # a spell's missile, flown after its "CASTS A SPELL" (P16)
var _box_off := false
var _move_label := ""
var _turn_weapon_of := -1   # paced: the figure whose turn began, and its weapon line then
var _turn_weapon := ""
var _shown_by := {}      # paced: attackers whose blows were shown in this run of messages
signal messages_shown
static var _paced := -1
var _ai_timer: Timer
var _result := 0
var _event_fight := false

var _picture: TextureRect
var _info: Label
var _prompt: Label


## Starts a test battle at map square (px, py) facing `facing` (0..3 = N E S W) against
## the set battles in `script` (monsters from MON<mon_file>CHA).
func open_test(game_path: String, map: GeoMap, px: int, py: int, facing: int,
		party: Array[PartyMember], mon_file: int, script: EclScript, load_now: bool = true) -> void:
	_game_path = game_path
	_show_area = show_area_on()
	_field = Battlefield.build(map, px, py)
	_px = px
	_py = py
	_art = CombatArt.load_set(game_path)
	_party = party
	_morale_base = 99
	_surprise = 0
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
	_drain_notes = []
	_event_fight = false
	_messages.clear()
	if _picture == null:
		_build()
	if load_now:    # (an event fight loads its own monsters next: a record loaded here
		_load_monsters()   # would roll its colours a second time, see load_monster)
	visible = true


## A fight started by an event script: the real party against `rows` ([[id, count,
## picture], ...]) from MON<mon_file>, `max_distance` and `advances` from the script's
## SPRITE_START / SPRITE_ADVANCE. Emits `finished` when it is over.
func open_event(game_path: String, map: GeoMap, px: int, py: int, facing: int,
		party: Array[PartyMember], mon_file: int, rows: Array, max_distance: int, advances: int,
		morale_base: int = 99, surprise: int = 0, extra: Array[PartyMember] = [],
		teams: Array[int] = [], morale: Array[int] = []) -> void:
	open_test(game_path, map, px, py, facing, party, mon_file, null, false)
	_extra_monsters = extra
	_monster_teams = teams
	_monster_morale = morale
	_event_fight = true
	_morale_base = morale_base
	_surprise = surprise
	_encounters = [{"monsters": rows, "text": ""}]
	_enc_index = 0
	var open_ahead := Placement.encounter_distance(_field, px, py, facing, 2)
	_distance = 2 if open_two else maxi(mini(open_ahead, max_distance) - advances, 0)
	open_two = false
	_load_monsters()
	_start_fight(dev_seed, false)
	if dev_win_if.is_valid() and dev_win_if.call(rows):
		dev_auto_win = true
	if dev_flee and DevShortcuts.allowed():
		# Dev shortcut (M6 coverage runs, chat 15): the whole party gets away at once, so the
		# script's "fled" side (0x6DC7 = 129) plays.
		dev_auto_win = false
		for c in _combat.combatants:
			if c.team == 0:
				c.down = true
				c.fled = true
				(c.who as PartyMember).status = PartyMember.STATUS_RUNNING
	dev_flee = false
	if dev_auto_win and DevShortcuts.allowed():
		# Dev shortcut (M6): the enemies fall at once; experience and treasure as for a win.
		for c in _combat.combatants:
			if c.team == 1:
				c.down = true
		_combat.decided = true     # won now: no round played out, no CONTINUE BATTLE
	dev_auto_win = false
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
		print("%s %s %d %d  move %d morale 0x%02X int %d classes 0x%02X size 0x%02X att2 %d weapon %s" % ["party" if e.team == 0 else "monster",
			e.who.name, e.cell.x, e.cell.y, e.who.movement, e.who.morale,
			e.who.stats[1] if e.who.stats.size() > 1 else 0, e.who.class_flags, e.who.size, e.who.half_attacks_2,
			e.who.weapon.name if e.who.weapon else "-"])
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


## Thrown weapons left lying on the field (found with the treasure after a win).
func dropped_items() -> Array[GameItem]:
	return _combat.dropped if _combat != null else _last_dropped


## The party members a won fight's experience goes to: those still in it at its end (Combat.finish()).
func paid_members() -> Array:
	return _combat.paid if _combat != null else _last_paid


## Testing aid: the encounter's morale for the next fight.
func set_morale_base(value: int) -> void:
	_morale_base = value


## The monsters brought down in the fight just finished (for experience and treasure).
## Rounds fought (a minute of game time each: GAME.OVR 0xA093 calls the clock routine 0x241A1
## at each round's end). Kept past _leave, which runs before `finished` (main's request: the
## clock lost the fight's minutes, checks 3 and 10).
func rounds() -> int:
	return _combat.round_no if _combat != null else _last_rounds


## Party members who fought on the monsters' side (turned: record 0x10E = 1 or a script's 0x81).
func turned_members() -> Array:
	var out := []
	for c in _combatants:
		if c.team == 1 and c.who in _party:
			out.append(c.who)
	return out


func defeated() -> Array:
	var out := []
	for c in _combatants:
		if c.team == 1 and c.get("down", false) and not c.get("fled", false):
			out.append(c.who)
	return out


## Testing aid: fights the check battle to the end with the computer on both sides and the
## given dice seed, printing every roll and message (for the lab).
## `plan` "away" replays the lab's free-attack check: party members wait until a monster
## attacks them, then the attacked one steps straight back (away from the monsters).
func run_fight(seed_value: int, plan: String = "") -> void:
	_start_fight(seed_value)
	for c in _combat.combatants:
		c.quick = c.team == 1 or plan == ""
	var attacked := {}
	_combat.message.connect(func(t: String) -> void:
		for c in _combat.combatants:
			if c.team == 0 and t.contains(" ATTACKS %s" % c.who.name):
				attacked[c.who.name] = true)
	var guard := 0
	var stop := false
	while not stop and guard < 5000:
		guard += 1
		var t := _combat.next_turn()
		if t == Combat.ASK_CONTINUE:
			print("CONTINUE BATTLE: NO")
			_combat.continue_battle(false)
			continue
		if t < 0:
			break
		var c: Dictionary = _combatants[_combat.active]
		if plan == "use" and c.team == 0 and _combat.magic != null:
			# Lab check: each member with a readied item that casts uses it once, at the nearest
			# enemy (or itself, for a potion), then fights on Quick.
			var used := false
			for it in c.who.items:
				var id := CharacterSheet.item_spell(c.who, it) if it.readied else 0
				if id == 0 or c.has("used"):
					continue
				var best := -1
				for j in _combatants.size():
					if _combatants[j].team != 0 and not _combatants[j].down and (best < 0 or
							_combat.range_of(c, _combatants[j]) < _combat.range_of(c, _combatants[best])):
						best = j
				var picks: Array[int] = [best if _combat.magic.table.field(id, 14) != 0 else _combat.active]
				var at: Vector2i = _combatants[picks[0]].cell
				print("== %s uses %s (spell %d) at %s (%s)" % [c.who.name, it.name, id, at,
					_combat.magic.why_not(_combat.active, id, at)])
				if _combat.magic.aim_kind(id) == "self" or _combat.magic.why_not(_combat.active, id, at) == "":
					c["used"] = true
					_combat.magic.cast(_combat.active, id, at, picks, it)
					used = true
					break
			if used:
				continue
			if not c.has("used"):
				for it in c.who.items:
					if it.readied:
						print("   %s has %s (spell %d, class %d, slot %d)" % [c.who.name, it.name,
							CharacterSheet.item_spell(c.who, it), c.who.class_flags, CharacterSheet.types.slot(it.type)])
				c["used"] = true
			c.quick = true
		if plan == "cast" and c.team == 0 and _combat.magic != null:
			# Lab check: each caster casts its first combat spell at the nearest enemy (or
			# itself), then fights on Quick.
			var list := _combat.magic.castable(_combat.active)
			if not list.is_empty():
				var id: int = list[0]
				var best := -1
				for j in _combatants.size():
					if _combatants[j].team != 0 and not _combatants[j].down and (best < 0 or
							_combat.range_of(c, _combatants[j]) < _combat.range_of(c, _combatants[best])):
						best = j
				var picks: Array[int] = [best if _combat.magic.table.field(id, 14) != 0 else _combat.active]
				var at: Vector2i = _combatants[picks[0]].cell
				print("== %s casts %s at %s (%s)" % [c.who.name, _combat.magic.table.name_of(id), at,
					_combat.magic.why_not(_combat.active, id, at)])
				if _combat.magic.why_not(_combat.active, id, at) == "":
					_combat.magic.cast(_combat.active, id, at, picks)
					continue
			c.quick = true
		if c.quick:
			while _combat.ai_act():
				guard += 1
			continue
		if attacked.has(c.who.name):
			var back: int = (Placement.FACING_TO_DIR[_facing] + 4) % 8
			print("== ", c.who.name, " steps away")
			for k in 3:
				var what := _combat.step(back)
				print("step: ", what, " at ", c.cell)
				if what != "moved":
					for y in range(c.cell.y - 2, c.cell.y + 3):
						var row := ""
						for x in range(c.cell.x - 3, c.cell.x + 4):
							row += "%3d" % _field.tile(x, y)
						print(row)
					break
			stop = true
		else:
			_combat.done()
	for line in _combat.roll_log:
		print("roll ", line)
	print("result ", ["", "party won", "party lost"][_combat.outcome()], " after ", _combat.round_no, " rounds")
	_combat.finish()
	for m in _party:
		print("  %s %s HP %d" % [m.name, m.status_name(), m.hp])
	if _combat.outcome() == 1:
		var sp := Spoils.gather(defeated(), [], [])
		var standing := _combat.paid.duplicate()      # still in the fight (Combat.finish(); Combat Chat 53)
		var before := {}
		for m in _party:
			before[m.name] = m.experience
		var share := sp.award(standing)
		var names := PackedStringArray()
		for it in sp.items:
			names.append(it.name)
		print("spoils: experience %d, %d standing, %d each; money %s; items %s" % [
			sp.experience, standing.size(), share, sp.money, ", ".join(names)])
		for m in _party:
			print("  %s %d -> %d" % [m.name, before[m.name], m.experience])


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
	# The original's combat screen over all of it (F12 shows the developer layout).
	_scr = GameScreen.new()
	_scr.transparent_tiles = true
	add_child(_scr)
	_sheet = CharacterSheet.new()
	_sheet.visible = false
	_sheet.closed.connect(_after_sheet)
	_sheet.spell_chosen.connect(_on_spell_chosen)
	_sheet.item_used.connect(_on_item_used)
	add_child(_sheet)
	_flash_timer = Timer.new()
	_flash_timer.one_shot = true
	_flash_timer.timeout.connect(func() -> void:
		_flash = ""
		var then := _after_flash
		_after_flash = Callable()
		if then.is_valid():
			then.call()
		else:
			_refresh())
	add_child(_flash_timer)


var _scr: GameScreen
static var dev_view := false
## Lab only: a fixed dice seed for event fights (main's combatseed= key), so a fight can be
## replayed the way the original's capture went.
static var dev_seed := 0
## The original's controls (lab, chat 11): a menu, MOVE VIEW AIM USE [CAST] [TURN] QUICK DONE,
## the hot letter or Enter on the lit item (the chosen item's place carries over to the next
## menu); MOVE: "MOVE/ATTACK, MOVE LEFT = n" with the arrows and keypad stepping (Esc back);
## AIM: "RANGE = n" above "AIM:" NEXT PREV MANUAL [TARGET] CENTER EXIT, the figure aimed at
## shown on the right (TARGET only where the attack is allowed); MANUAL: "(USE CURSOR KEYS)"
## TARGET CENTER EXIT; DONE: [GUARD] DELAY QUIT [BANDAGE] SPEED EXIT (GUARD not with a
## missile weapon, BANDAGE only with someone dying; GUARD says GUARDING a moment).
## VIEW, USE and CAST open the character sheet (CharacterSheet.open_combat).
var _cmode := "menu"     # menu, move, done, aim, manual
var _pick := 0
var _flash := ""
var _flash_timer: Timer
var _after_flash := Callable()
var _sheet: CharacterSheet
const MAGENTA := 13


## A message in the original's pieces (lab): "HITTING FOR n" is followed by "POINT(S) OF
## DAMAGE" on its own line, and "AND IS DYING" starts a line of its own.
static func _message_pieces(msg: String) -> String:
	var re := RegEx.create_from_string("HITTING FOR (\\d+)$")
	var m := re.search(msg)
	if m != null:
		msg += "\n" + ("POINT OF DAMAGE" if m.get_string(1) == "1" else "POINTS OF DAMAGE")
	return msg.replace(" AND IS DYING", "\nAND IS DYING")


## The panel's status names for a figure out of the fight (START.EXE DS:0x1047, 13 bytes each).
const PANEL_STATUS := ["OKAY", "ANIMATED", "TEMPGONE", "RUNNING", "UNCONSCIOUS", "DYING", "DEAD", "STONED", "GONE"]


## The original's combat screen: rope frame (rows 0 and 22, columns 0, 22 and 39), the
## 7x7 field at (8, 8), the figure's name (yellow), HITPOINTS, AC and weapon at column 23
## rows 1-7, the fight's messages below them, and the prompt or menu on row 24.
func _draw_original(field: Image) -> void:
	_scr.visible = not dev_view
	if dev_view:
		return
	var g := _scr
	g.img.fill(GameScreen.EGA[8])   # the original's combat screen is dark grey throughout
	for c in 40:
		g.tile(c, 0, 22)
		g.tile(c, 22, 22)
	for r in range(1, 22):
		g.tile(0, r, 21)
		g.tile(22, r, 21)
		g.tile(39, r, 21)
	for p in [Vector2i(0, 0), Vector2i(22, 0), Vector2i(39, 0), Vector2i(0, 22), Vector2i(22, 22), Vector2i(39, 22)]:
		g.tile(p.x, p.y, 20)
	var f: Image = field.duplicate()
	f.convert(Image.FORMAT_RGBA8)
	g.img.blit_rect(f, Rect2i(0, 0, mini(f.get_width(), 168), mini(f.get_height(), 168)), Vector2i(8, 8))
	g.click_zone(Rect2i(8, 8, VIEW_CELLS * CELL, VIEW_CELLS * CELL), _field_click)
	if not _combatants.is_empty():
		var e: Dictionary = _combatants[_selected]
		var m: PartyMember = e.who
		g.text(23, 1, m.name.left(16), GameScreen.CYAN if e.team == 0 else GameScreen.YELLOW)
		# A figure that surrenders (GAME.OVR 0xBE31: 0xB0:0x57 makes it UNCONSCIOUS with 0 HP, off the field) is not
		# drawn again: its own turn's panel keeps the HP it began with and no status line under "SURRENDERS"
		# (Jeremy's P105; DOSBox prayer_kob5, Combat Chat 48).
		var gave_up: bool = e.get("surrendered", false) and _turn_weapon_of == _selected
		var hp_shown: int = int(e.get("surrender_hp", m.hp)) if gave_up else m.hp
		g.text(23, 3, "HITPOINTS", GameScreen.GREEN)
		g.text(33, 3, str(hp_shown), GameScreen.YELLOW if hp_shown < m.hp_max else GameScreen.GREEN)
		g.text(23, 5, "AC %d" % m.ac, GameScreen.GREEN)
		var wn := _weapon_text(m)
		if paced() and _turn_weapon_of == _selected and e.get("quick", false):
			# A computer-run turn's panel is drawn once as the turn starts: the original keeps
			# "5 DARTS" under a volley's lines and "2 DARTS" while the last two fly (main's
			# cold-open capture, rounds 2 and 3).
			wn = _turn_weapon
		var cut := wn.left(16).rfind(" ") if wn.length() > 15 else -1
		var last_row := 5
		if cut > 0:
			g.text(23, 7, wn.left(cut), GameScreen.GREEN)
			g.text(23, 8, wn.substr(cut + 1).left(16), GameScreen.GREEN)
			last_row = 8
		elif wn != "":
			g.text(23, 7, wn.left(16), GameScreen.GREEN)
			last_row = 7
		# START.EXE 0x16A0: a blank row under the weapon (or AC), then in white a figure out of the fight's status
		# (+0x10D clear: the table DS:0x1047) or, standing, "(Helpless)" under any of effects 0x33, 0x34, 0x35,
		# 0x1F (DS:0x286B: snake charm, hold, sleep, helpless). Jeremy's play (2026-11-21) and p41g1's video.
		var state := _kept_state if _panel_kept else _panel_state(e, gave_up)
		if state != "":
			g.text(23, last_row + 2, state, GameScreen.WHITE)
	# The last action, as the original prints it from row 10: each name on its own line
	# (party light cyan, monsters yellow), the rest green, 16 to a line.
	var names := {}
	for c in _combatants:
		names[(c.who as PartyMember).name.to_upper()] = GameScreen.CYAN if c.team == 0 else GameScreen.YELLOW
	var lines := []
	var shown := []
	if paced():
		shown = Array(_panel_msgs)
	elif not _messages.is_empty() and not String(_messages[-1]).begins_with("ROUND "):
		shown = [_messages[-1]]
	for m_text in shown:
		var rest := _message_pieces(String(m_text).to_upper())
		# A fall under a blow's lines: a blank line before it and the falling figure's name in
		# light red (main's cold-open capture of the original: "ORC" red over "GOES DOWN").
		var falls := not lines.is_empty() and _falls_line(rest)
		if falls:
			lines.append(["", GameScreen.GREEN])
		while rest != "":
			var hit := ""
			var at := rest.length()
			for n in names:
				var k := rest.find(n)
				if k >= 0 and (k < at or (k == at and n.length() > hit.length())):
					at = k
					hit = n
			if at > 0:
				for piece in rest.substr(0, at).split("\n"):
					for w in GameScreen.wrap(piece.strip_edges(), 16):
						if w != "":
							lines.append([w, GameScreen.GREEN])
			if hit == "":
				break
			lines.append([hit.left(16), GameScreen.RED if falls and at == 0 and lines[-1][0] == "" else names[hit]])
			rest = rest.substr(at + hit.length()).strip_edges()
	if _casting != "choose":
		for i in mini(lines.size(), 12):
			g.text(23, 10 + i, lines[i][0], lines[i][1])
	# Bottom lines.
	if _aim_rows_kept and _row24_msg == "":
		g.text(0, 23, "SPELL:" + _combat.magic.table.name_of(_spell_id), GameScreen.GREEN)
		if _kept_prompt != "":
			g.text(0, 24, _kept_prompt, MAGENTA)
			g.menu_line(24, _kept_items, _kept_prompt.length() + (0 if _kept_prompt == "AIM:" else 1), _kept_lit)
		g.forget_menu(24)
	elif _announcing:
		g.forget_menu(24)
	elif _row24_msg != "":
		g.text(0, 24, _row24_msg, GameScreen.GREEN)
	elif _flash != "":
		g.text(0, 24, _flash, GameScreen.GREEN)
	elif _asking_flee:
		# GAME.OVR 0xA41E: "Flee:" through the question 0x2D9A0 with colour 0xD, YES straight after the colon
		# (Combat Chat 41, DOSBox: magenta, the menu from column 5).
		g.text(0, 24, "FLEE:", MAGENTA)
		g.menu_line(24, ["YES", "NO"], 5)
	elif _asking_ally:
		if not _ally_from_move:
			g.text(0, 23, "RANGE = %d" % _aim_range(), GameScreen.GREEN)
		g.text(0, 24, "ATTACK ALLY:", MAGENTA)     # 0x151C5: "Attack Ally: " with 0x2D9A0's colour 0xD, as FLEE's
		g.menu_line(24, ["YES", "NO"], 13)
	elif _asking_abort:
		g.text(0, 23, "SPELL:" + _combat.magic.table.name_of(_spell_id), GameScreen.GREEN)
		g.text(0, 24, "ABORT SPELL?", GameScreen.YELLOW)     # 0x27EFD: colour 0xE through 0x2D9A0 (Combat Chat 41)
		g.menu_line(24, ["YES", "NO"], 13)
	elif _asking_continue:
		# Magenta, YES straight after the colon (main's cold-open capture of the original).
		g.text(0, 24, "CONTINUE BATTLE:", MAGENTA)
		g.menu_line(24, ["YES", "NO"], 16)
	elif _combat != null and _result != 0 and not _drain_notes.is_empty():
		g.text(0, 24, String(_drain_notes[0]), GameScreen.YELLOW)     # QoL DRAIN REMINDER
	elif _combat != null and _result != 0 and not (paced() and _event_fight and _result == 1):
		g.text(0, 24, ["", "THE PARTY WINS.", "THE PARTY HAS FALLEN.", "THE PARTY HAS FLED."][_result], GameScreen.WHITE)
	elif _combat != null and (_cmode == "aim" or _cmode == "manual"):
		# A spell's aim shows the spell on row 23, an attack's the range (lab, Combat Chat 4:
		# "SPELL:SLOW POISON" over AIM: and over (USE CURSOR KEYS)).
		if _aim_for == "spell" and _use_item != null:
			pass
		elif _aim_for == "spell":
			g.text(0, 23, "SPELL:" + _combat.magic.table.name_of(_spell_id), GameScreen.GREEN)
		else:
			g.text(0, 23, "RANGE = %d" % _aim_range(), GameScreen.GREEN)
		var prompt := "AIM:" if _cmode == "aim" else "(USE CURSOR KEYS)"
		g.text(0, 24, prompt, MAGENTA)
		var items := _bottom_menu()
		g.menu_line(24, items, prompt.length() + (0 if _cmode == "aim" else 1), _lit(items))
	elif paced() and _combat != null and _combat.active >= 0 and _combatants[_combat.active].get("quick", false):
		g.forget_menu(24)
		if _move_label != "":
			g.text(0, 24, _move_label, GameScreen.GREEN)
	elif _combat != null and _cmode == "speed":
		var prompt := "GAMESPEED (%d) :" % CampScreen.speed
		g.text(0, 24, prompt, MAGENTA)
		var items := _bottom_menu()
		g.menu_line(24, items, prompt.length() + 1, _lit(items))
	elif _combat != null and _combat.active >= 0 and not _combatants[_combat.active].get("quick", false):
		if _cmode == "move":
			g.forget_menu(24)      # main's chat 42: the menu's words stayed live, the hover drew AIM over the prompt
			g.text(0, 24, "MOVE/ATTACK, MOVE LEFT = %d" % (_combatants[_combat.active].moves / 2), GameScreen.GREEN)
		else:
			var items := _bottom_menu()
			g.menu_line(24, items, 0, _lit(items))
	g.update()


## Opponents that aren't monster records (the arena's copy of the duelist).
var _extra_monsters: Array[PartyMember] = []


func _load_monsters() -> void:
	_monsters.clear()
	_pictures.clear()
	if not _encounters.is_empty():
		for row in _encounters[_enc_index].monsters:
			var first := PartyMember.load_monster(_game_path, _mon_file, row[0])
			if first == null:
				continue
			first.recalculate(_types)
			var base_morale := first.morale
			for i in int(row[1]):
				if _monsters.size() >= 63:   # the original's limit
					break
				var m := first if i == 0 else first.clone()
				if i > 0:
					# The original's copy of a monster holds its items in reverse order (lab, Combat
					# Chat 7: 2:9's second AIDES held Long Sword, Chain Mail, Long Bow, 20 Arrows; the
					# first the file's order), which decides the pile's d10s (no more after 8 items).
					m.items.reverse()
					m.recalculate(_types)
				var k := _monsters.size()
				m.script_team = _monster_teams[k] if k < _monster_teams.size() else 0
				m.morale = _monster_morale[k] if k < _monster_morale.size() and _monster_morale[k] >= 0 else base_morale
				_monsters.append(m)
				_pictures.append(int(row[2]))
	for m in _extra_monsters:
		# The arena's double fights as combat picture 11 of the area's CPIC file, as
		# GAME.OVR loads it (lab: ROLF is a stock swordsman, not the duelist's icon).
		_monsters.append(m)
		_pictures.append(11)
	_place()
	_selected = 0
	_centre_on_selected()
	_refresh()


# --- Placement --------------------------------------------------------------------------

## The whole party in order while a fight starts (its members who are down are placed too).
var _place_order: Array = []


## Both sides placed by the original's rule (see Placement): the party around its own
## square, the monsters around the square `_distance` squares ahead, facing the party.
func _place() -> void:
	_combatants.clear()
	var placer := Placement.new(_field, _px, _py)
	# Monsters a script set to 0x80 (LOAD_CHAR past the party; Hassad's nomads) fight on the
	# party's side, computer-run, and stand with it.
	var allies: Array[PartyMember] = []
	var foes: Array[PartyMember] = []
	var foe_pictures: Array = []
	for i in _monsters.size():
		if _monsters[i].script_team == 0x80:
			allies.append(_monsters[i])
		else:
			foes.append(_monsters[i])
			foe_pictures.append(_pictures[i])
	# A member turned against the party (a script's 0x6C0C = 0x81, kept in the record as byte
	# 0x10E = 1 with 0x10F = 1, so it survives a save: GAME.OVR 0x80B2) is placed with the monsters,
	# before them, and the rest of the party in the formation for its own size (Combat Chat 6, the
	# Player's 6:1 run for the gate: DIRTEN, saved so, stood at the monsters' first place in the
	# original and was in LIRA's target list). The figure order stays the party's.
	var home: Array = []
	var turned: Array = []
	var down: Array = []        # places in `home` of members who are down (placed, but not fighting)
	for m in (_place_order if not _place_order.is_empty() else _party):
		if _turned(m):
			if m in _party:
				turned.append(m)
		else:
			if not m in _party:
				down.append(home.size())
			home.append(m)
	var side_list: Array = home + allies
	var party_sizes := side_list.map(func(m): return Combat.foot_size(m))
	var party_cells := placer.place_team(side_list.size(), _facing, Vector2i.ZERO, true, party_sizes, down)
	var party_dir: int = Placement.FACING_TO_DIR[_facing]
	var ahead: Vector2i = Placement.SQUARE_STEP[_facing] * _distance
	var mon_list: Array = turned + foes
	var mon_sizes := mon_list.map(func(m): return Combat.foot_size(m))
	var mon_cells := placer.place_team(mon_list.size(), (_facing + 2) % 4, ahead, false, mon_sizes)
	for m in _party:
		var t := turned.find(m)
		var cell: Vector2i = mon_cells[t] if t >= 0 else party_cells[home.find(m)]
		if cell.x < 0:
			continue
		_combatants.append({"who": m, "team": 1 if t >= 0 else 0, "cell": cell,
			"icon": _art.character_icon(m), "dir": (party_dir + 4) % 8 if t >= 0 else party_dir, "pic": -1})
	if TpDice.on:
		for i in down:
			TpDice.log.append("downcell %s %d,%d" % [home[i].name, party_cells[i].x, party_cells[i].y])
	# The creatures follow the party in the order they were loaded, whichever side each is on
	# (the original's figure list: Combat Chat 32, main's tavern brawl, 3:0 0xA696: LOAD_CHAR 41-53
	# sets the last 11 loaded to 0x80; its figures 6-25 are the drunks, 26-31 the patrons on the
	# party's row 11, the cells as ours). The order decides the initiative and target draws.
	var creatures: Array = []
	for i in range(home.size(), side_list.size()):
		if party_cells[i].x < 0:
			continue
		var k := _monsters.find(side_list[i])
		creatures.append({"who": side_list[i], "team": 0, "cell": party_cells[i],
			"icon": _art.monster_icon(_mon_file, _pictures[k]) if _pictures[k] >= 0 else _art.character_icon(side_list[i]),
			"dir": party_dir, "pic": _pictures[k]})
	for i in foes.size():
		var cell: Vector2i = mon_cells[turned.size() + i]
		if cell.x < 0:
			continue
		var icon: Variant = _art.character_icon(foes[i]) if foe_pictures[i] < 0 \
			else _art.monster_icon(_mon_file, foe_pictures[i])
		creatures.append({"who": foes[i], "team": 1, "cell": cell,
			"icon": icon, "dir": (party_dir + 4) % 8, "pic": foe_pictures[i]})
	creatures.sort_custom(func(a, b): return _monsters.find(a.who) < _monsters.find(b.who))
	_combatants.append_array(creatures)


## Is party member `m` on the monsters' side: a script's 0x81 this session, or the record's
## byte 0x10E (the original keeps the side there, so a save carries it).
static func _turned(m: PartyMember) -> bool:
	return m.script_team == 0x81 or (m.script_team == 0 and m.raw.size() > 0x10E and m.raw[0x10E] != 0)


# --- Fighting ---------------------------------------------------------------------------

## Set by main before open_event for a duel (CALL 0x8000 / 0x8001): the whole party, of whom only
## the duellist fights (Combat.aside).
var duel_party: Array[PartyMember] = []


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
	var everyone: Array[PartyMember] = _party.duplicate()
	var standing: Array[PartyMember] = []
	for m in _party:
		if m.can_fight():
			standing.append(m)
	_party = standing
	# Clutter on the floor (Battlefield.scatter), rolled as the original does: after the
	# monsters are loaded, before placement and initiative.
	var clutter_rng := RandomNumberGenerator.new()
	if seed_value != 0:
		clutter_rng.seed = seed_value
	else:
		clutter_rng.randomize()
	if not wild.is_empty():
		# The wilderness field (GAME.OVR 0xD785) comes first, with the clutter on top.
		_field.make_wild(_wild_terrain(), int(wild[3]), func(n: int) -> int:
			return TpDice.random(n, "wild field") + 1 if TpDice.on else clutter_rng.randi_range(1, n))
		_art = CombatArt.load_set(_game_path, true)
	_field.scatter(func(n: int) -> int:
		return TpDice.random(n, "clutter") + 1 if TpDice.on else clutter_rng.randi_range(1, n), area_block == 10)
	# The members who are down get places too (Placement.place_team's `down`), in party order.
	_place_order = everyone if duel_party.is_empty() else []
	_place()
	_place_order = []
	if TpDice.on:
		for c in _combatants:
			TpDice.log.append("cell %s %d,%d" % [c.who.name, c.cell.x, c.cell.y])
		for y in Battlefield.HEIGHT:
			var row := PackedStringArray()
			for x in Battlefield.WIDTH:
				row.append("%02d" % _field.tile(x, y))
			TpDice.log.append("field %02d %s" % [y, " ".join(row)])
	_combat = Combat.new(_field, _combatants, seed_value)
	# The members who don't fight (a duel's onlookers, anyone down, dying or dead) keep their places in the
	# original's figure list: GAME.OVR 0x9938 rolls "who acts next" for every figure in the party list, any
	# status (Combat Chat 16, Player 15's p15f6: DORN at 0 HP since the last fight, no initiative, a d100).
	if not duel_party.is_empty():
		everyone = duel_party
	for k in everyone.size():
		var m: PartyMember = everyone[k]
		var fights := false
		for p in _party:
			if p == m or p.name == m.name:
				fights = true
		if not fights:
			_combat.aside.append([k, m.name])
	duel_party = []
	_combat.quick_bandages = Combat.quick_bandages_on() and DisplayServer.get_name() != "headless" and not TpDice.on
	_combat.smart_quick = SmartQuick.on() and DisplayServer.get_name() != "headless" and not TpDice.on
	_combat.smart_monsters = SmartQuick.monsters_on() and DisplayServer.get_name() != "headless" and not TpDice.on
	# Lab: --smart-quick / --smart-monsters turn them on in headless test fights too.
	_combat.smart_quick = _combat.smart_quick or "--smart-quick" in OS.get_cmdline_user_args()
	_combat.smart_monsters = _combat.smart_monsters or "--smart-monsters" in OS.get_cmdline_user_args()
	_combat.types = _types
	var table := SpellTable.shared(_game_path)
	if table.is_loaded():
		_combat.magic = CombatSpells.new(_combat, table)
		_combat.magic.spell_cast.connect(_on_spell_cast)
	_combat.flee_dir = Placement.FACING_TO_DIR[_facing]
	_combat.morale_base = _morale_base
	# The script's modifiers for this fight (ECL 0x6E70-0x6E72), used once.
	_combat.monster_hit_mod = (area_mods[0] & 0xFF ^ 0x80) - 0x80
	_combat.party_hit_mod = (area_mods[1] & 0xFF ^ 0x80) - 0x80
	_combat.party_move_mod = (area_mods[2] & 0xFF ^ 0x80) - 0x80
	area_mods = [0, 0, 0]
	_combat.anti_magic = anti_magic
	CharacterSheet.anti_magic = anti_magic
	_combat.surprise_flags = _surprise
	_combat.message.connect(_on_combat_message)
	_messages.clear()
	_panel_msgs.clear()
	_pending_msgs.clear()
	_pending_subj.clear()
	_row24_msg = ""
	_result = 0
	_drain_notes = []


var _asking_continue := false
## Chat 17: "ATTACK ALLY: YES NO" (GAME.OVR 0x15193, checked in the original): TARGET on a figure
## of the attacker's own side asks first; NO goes back to the aim. YES sets 0x6E33 (and 0x6DE2,
## not done here: ours reads 0x6DE2 as the temple flag) and turns every computer-run ally with
## morale over 127 against the party (record +0x10C = 0, +0x84 > 0x7F; +0x10E = 1). The lab:
## the player characters stay the player's.
var _asking_ally := false
var _move_start := {}          # where MOVE began (Esc puts the figure back there)
var _asking_abort := false     # ABORT SPELL? (EXIT from a spell's aim)
var _ally_target := -1
var _asking_flee := false      # Combat Chat 40: "FLEE:" YES NO, a MOVE step off the field's edge (GAME.OVR 0xA413)
var _ally_from_move := false   # asked from MOVE (a step onto a teammate): NO stays in MOVE, YES strikes as a step does


## The terrain byte under the party's band square (0xD7A0: DS:0x3648[y * 44 + x + the band's
## edge], read from the player's START.EXE by OverlandMap); 0 when it can't be read.
func _wild_terrain() -> int:
	var om := OverlandMap.shared(_game_path)
	if om == null or wild.size() < 4:
		return 0
	var band: int = clampi(int(wild[0]), 0, om.band_left.size() - 1)
	var i: int = int(wild[2]) * OverlandMap.WIDTH + int(wild[1]) + om.band_left[band]
	return om.cells[i] if i >= 0 and i < om.cells.size() else 0


## A figure's attack pose (its icon's block + 128), kept with it.
func _attack_icon(e: Dictionary) -> Image:
	if not e.has("icon_attack"):
		var pic: int = e.get("pic", -1)
		e.icon_attack = _art.monster_icon(_mon_file, pic, true) if pic >= 0 else _art.character_icon(e.who, true)
	return e.icon_attack if e.icon_attack != null else e.icon


## The original's view rule (GAME.OVR 0x30F0E), see _box_off.
func _ensure_view(cell: Vector2i, margin: int) -> void:
	var cx := _view.x + 3
	var cy := _view.y + 3
	if cell.x < cx - margin:
		cx = maxi(cell.x, 3)
	elif cell.x > cx + margin:
		cx = mini(cell.x, Battlefield.WIDTH - 4)
	if cell.y < cy - margin:
		cy = maxi(cell.y, 3)
	elif cell.y > cy + margin:
		cy = mini(cell.y, Battlefield.HEIGHT - 4)
	if Vector2i(cx - 3, cy - 3) != _view:
		_view = Vector2i(cx - 3, cy - 3)
		print("   view %d,%d" % [_view.x, _view.y])     # lab: compared with viewlog.py


## Is the display paced like the original's (P16)? Not in the lab's runs, unless --anim.
static func paced() -> bool:
	if _paced < 0:
		var args := OS.get_cmdline_user_args()
		_paced = 1
		if DisplayServer.get_name() == "headless" or "--fast" in args:
			_paced = 0
		for a in args:
			if a.begins_with("--play=") or a.begins_with("--keys="):
				_paced = 0
		if "--anim" in args:
			_paced = 1
	return _paced == 1


## How long a spell's effect shows on a figure it reaches (P85): START.EXE 0x2B8B's 4 frames, 70 ms each,
## (game speed + 1) times.
static func sparkle_time() -> float:
	return (CampScreen.speed + 1) * 4 * 0.07


## How long a combat message stays: game speed x 0.2 s, as the original.
static func message_hold() -> float:
	return CampScreen.speed * 0.2


func _on_combat_message(text: String) -> void:
	_on_message(text)
	if paced() and not _muted and not text.begins_with("ROUND "):
		_pending_msgs.append(text)
		_pending_subj.append(_combat.fx_subject)
		if not _draining:
			# Start once the action has queued all its messages (a volley's later darts, the
			# missile's flight): shown at once, a dart's miss went up before its volley's hits
			# were known (Jeremy's P16 test, 2026-11-14).
			_draining = true
			_show_messages.call_deferred()


## The original's sound for a line as it shows (Speaker; GAME.OVR's attack routine 0x13C01):
## each hit's line has the hit's (id 7, 0x13EF1), "slays helpless" too (0x13C54), and the one
## miss line of an attack that hit nothing the miss's (id 9, 0x13F6F; ours shows that line
## once, as the original); a cast's at its CASTS A SPELL / USES line (0x27E05), played on
## through its flight. In the original each sound in a fight lasts 0.1 s (DS:0x5374).
func _sound_for(msg: String) -> void:
	if msg.contains(" HITTING FOR ") or msg.contains(" SLAYS HELPLESS "):
		Speaker.play(Speaker.HIT)
	elif msg.ends_with(" AND MISSES"):
		Speaker.play(Speaker.MISS)
	elif _cast_sound > 0 and (msg.ends_with(" CASTS A SPELL") or msg.contains(" USES ")):
		Speaker.play(_cast_sound, true)
		_cast_sound = 0
	elif msg.contains(" TAKES ") and msg.contains(" OF DAMAGE"):
		# START.EXE 0x2B8B shows a figure's line with its picture: magic damage (flag 0, from the
		# damage routine 0x2C3C7) plays id 3 (0.15 s, played out).
		Speaker.play(Speaker.DAMAGE, true)
	elif _effect_line(msg):
		# ... and an effect (flag 1: the add-effect routine's line 0x2C617, "is Paralyzed",
		# "is turned", "is Healed", "is affected"...) id 4, cut when the picture's loop ends
		# (DS:0x5374 set again): 0.75 s in DOSBox (Combat Chat 10's cap/audio0002.wav).
		Speaker.play(Speaker.EFFECT, true, 0.75)


## A figure's effect line that the original shows through START.EXE 0x2B8B with flag 1: the
## monster powers' and turning's (0x10294 "is Paralyzed", 0x13AA1 "is turned") and a spell's
## line on a figure it reached (not "is unaffected", which the original prints plainly).
func _effect_line(msg: String) -> bool:
	if msg.ends_with(" IS PARALYZED") or msg.ends_with(" IS TURNED"):
		return true
	if msg.ends_with(" IS UNAFFECTED") or msg.contains(" ATTACKS ") or msg.ends_with(" SAVES") \
			or msg.ends_with(" CASTS A SPELL") or msg.contains(" USES ") or _continues(msg):
		return false
	for k in _spell_hits:
		if msg.begins_with((_combatants[k].who as PartyMember).name.to_upper() + " "):
			return true
	return false


## A message that goes under the last one instead of replacing it.
func _continues(msg: String) -> bool:
	return not _panel_msgs.is_empty() and _falls_line(msg)


## A figure's fall (GOES DOWN, IS KILLED...).
func _falls_line(msg: String) -> bool:
	for w in ["GOES DOWN", "IS KILLED", "IS DYING", "FALLS DEAD", "IS DEAD FOREVER"]:
		if msg.contains(w):
			return true
	return false


## The figure a blow's message starts with ("" if none).
func _attacker(msg: String) -> String:
	var best := ""
	for c in _combatants:
		var n := (c.who as PartyMember).name.to_upper()
		if n.length() > best.length() and msg.begins_with(n + " "):
			best = n
	return best


## The original shows a volley's hits one by one and none of its misses; a miss shows only when
## the whole volley missed, once (lab: darts, three a round, at speeds 0 and 4).
func _skip_miss(msg: String, who: String) -> bool:
	if who == "" or not msg.ends_with(" AND MISSES"):
		return false
	if _shown_by.has(who):
		return true
	for m in _pending_msgs:
		if m.begins_with(who + " ") and (m.ends_with(" AND MISSES") or m.contains(" HITTING FOR ")):
			return true
	return false


## Shows the queued messages one at a time, the original's way (P16).
func _show_messages() -> void:
	_draining = true
	_shown_by.clear()
	while not _pending_msgs.is_empty() and is_inside_tree():
		var msg := _pending_msgs[0]
		_pending_msgs.remove_at(0)
		var subj: int = _pending_subj.pop_front() if not _pending_subj.is_empty() else -1
		var who := _attacker(msg)
		if _skip_miss(msg, who):
			continue
		if msg.ends_with(" IS GUARDING") or msg == "ESCAPE IS BLOCKED":
			# The original has no "<name> is guarding": a computer-run figure's guard prints "Guarding" (START.EXE
			# 0x32E2) on row 24 under its own panel, the panel's lines kept (DOSBox, Combat Chat 49, tu_spec5: a
			# turned SPECTRE's run counts MOVE LEFT down to 4, then GUARDING; none of the lab's original screen logs
			# has the panel line). Jeremy's P113 read ours' "GHOUL IS GUARDING" as turned ghouls not running.
			# A runner's "Escape is blocked" likewise: the getaway (0x68:0x39, called by the player's flee at
			# 0xA440 and by the computer's run at 0xB52D) prints it through the row-24 routine 0xBA:0x1693 (the
			# player's seen in DOSBox, Combat Chat 47's flee_k6).
			_row24_msg = "GUARDING" if msg.ends_with(" IS GUARDING") else msg
			_move_label = ""
			_refresh()
			await get_tree().create_timer(message_hold()).timeout
			_row24_msg = ""
			_refresh()
			continue
		if who != "":
			_shown_by[who] = true
		var dying := msg == "YOUR TEAMMATE IS DYING"
		if msg == CAST_MARK:
			# An announced cast (CASTS A SPELL shown before the aim): its sound (GAME.OVR 0x27E18, after the
			# aim) and its flight, the panel kept; the sound cut as at a CASTS A SPELL line's end (0x27E56;
			# 0.31 s in DOSBox when nothing flies).
			var snd := _cast_sound
			_cast_sound = 0
			if not _spell_flight.is_empty():
				if snd > 0:
					Speaker.play(snd, true)
				var sf := _spell_flight
				_spell_flight = {}
				_fly(sf.from, sf.to, [5, 133], 240.0)
				await flight_done
				Speaker.play(0xFF)
			elif snd > 0:
				# Nothing flies: the spell's first line follows at once (DOSBox: Sleep's ~0.2 s after TARGET,
				# Mirror Image's 0.06 s after its SPELL line), the sound cut on its own.
				Speaker.play(snd, true, 0.31)
			continue
		if msg.begins_with("SPELL: "):
			# A spell with no flight: its name on row 24 for a message's time, the panel kept.
			_row24_msg = "SPELL:" + msg.substr(7)
			_refresh()
			await get_tree().create_timer(message_hold()).timeout
			_row24_msg = ""
			_refresh()
			continue
		if not _continues(msg) and not dying:
			_panel_msgs.clear()
			_refresh()
			await get_tree().create_timer(MESSAGE_GAP).timeout
			if _flying:
				await flight_done
				await get_tree().create_timer(0.13).timeout
		if who != "" and not _hold_seq.is_empty() and _hold_seq[0][0] == who:
			var hs: Array = _hold_seq.pop_front()
			if hs[2]:
				_fly(_hold_from, hs[1], [5, 133], 240.0, Speaker.SPELL)
				await flight_done
		_sound_for(msg)
		if dying:
			_panel_msgs.clear()
			_row24_msg = msg
		else:
			_panel_msgs.append(msg)
			# The sparkles go on the figure whose line it is (Combat.fx_subject): exactly for the cloud's saves (Jeremy,
			# 2026-11-23: a Stinking Cloud's sparkles on the wrong troll), by name only inside a spell's own lines
			# (-2), never on a line outside a spell (a guard's, a turn's IS COUGHING; ours had paired those by name).
			var cands: Array[int] = []
			if subj >= 0:
				cands = [subj]
				if not _spell_hits.has(subj):
					_hit_pic = [9, 137]      # a cloud's save in a later round: the sparkles
					_bolt_on = false
					_spell_hits.append(subj)
			elif subj == -2:
				cands = _bolt_order(_spell_hits, who)
			for k in cands:
				if (_combatants[k].who as PartyMember).name.to_upper() == who and not msg.contains(" ATTACKS "):
					_spell_hits.erase(k)
					_sparkle = k
					if _bolt_on:
						# The walk reaches the square first, then its burst and line.
						_panel_msgs.erase(msg)
						_refresh()
						await _crackle_to(_combatants[k].cell)
						_panel_msgs.append(msg)
					break
			if msg.contains("GOES DOWN") or msg.contains("IS KILLED") or msg.contains("FALLS DEAD"):
				for k in _lingering:
					if (_combatants[k].who as PartyMember).name.to_upper() == who:
						_lingering.erase(k)
						_skulls.append(k)
						break
		_refresh()
		if _sparkle >= 0:
			# P85: START.EXE 0x2B8B shows the effect's 4 frames 70 ms apart (speed + 1) times with the message up
			# (GAME.OVR 0x2C617), and no hold after: 0.28 s at SPEED 0, 1.4 s at 4 (ours had at least 1.2 s).
			var until := Time.get_ticks_msec() + int(sparkle_time() * 1000.0)
			while Time.get_ticks_msec() < until and is_inside_tree():
				await get_tree().create_timer(0.066).timeout
				_refresh()
			_sparkle = -1
			if _bolt_on and _spell_hits.is_empty():
				# The last figure hit: the walk goes on to its end (GAME.OVR 0x29B02's loop).
				await _crackle_to(Vector2i(-1, -1))
				_bolt_on = false
		else:
			await get_tree().create_timer(message_hold()).timeout
		if not _spell_flight.is_empty() and (msg.ends_with(" CASTS A SPELL") or msg.contains(" USES ")):
			var sf := _spell_flight
			_spell_flight = {}
			_panel_msgs.clear()
			# The original names the spell on row 24 while it flies ("SPELL:MAGIC MISSILE",
			# main's cold-open capture, chat 38), not in the panel.
			if not _pending_msgs.is_empty() and _pending_msgs[0].begins_with("SPELL: "):
				_row24_msg = "SPELL:" + _pending_msgs[0].substr(7)
				_pending_msgs.remove_at(0)
				if not _pending_subj.is_empty():
					_pending_subj.pop_front()
			_refresh()
			_fly(sf.from, sf.to, [5, 133], 240.0)
			await flight_done
		if _cast_sound == 0 and (msg.ends_with(" CASTS A SPELL") or msg.contains(" USES ")):
			# The cast's sound plays while its line is drawn; then the wrapper's wait is set
			# again (0x27E56), which takes the driver off the timer: the sound stops there (in
			# DOSBox a cast's 1.0 s sound lasted 0.31 s).
			Speaker.play(0xFF)
		_row24_msg = ""
		if _pending_msgs.is_empty() or not _continues(_pending_msgs[0]):
			_panel_msgs.clear()
			_skulls.clear()
		_refresh()
	_draining = false
	_aim_rows_kept = false
	_spell_hits.clear()
	_skulls.clear()
	_lingering.clear()
	if _posed >= 0:
		_posed = -1
		_refresh()
	_panel_kept = false
	messages_shown.emit()


func _on_message(text: String) -> void:
	if text.begins_with("ROUND ") and dev_round_check.is_valid() and DevShortcuts.allowed() \
			and dev_round_check.call(int(text.substr(6))):
		_dev_win_now = true
	_messages.append(text)
	_message_count += 1
	if _messages.size() > 6:
		_messages = _messages.slice(_messages.size() - 6)
	print(text)


## The panel's weapon line: the original builds the name from the item's words and its count
## (8 DARTS, then 5), not the record's cached name, and wraps it onto row 8 at a space
## (TWO-HANDED / SWORD) (main's cold-open capture, chat 38).
func _weapon_text(m: PartyMember) -> String:
	if not m.weapon:
		return ""
	var wn := m.weapon.name
	if CharacterSheet.game_path != "":
		var names := ItemNames.shared(CharacterSheet.game_path)
		if names.is_loaded():
			wn = names.name_of(m.weapon)
	return wn.to_upper()


## QoL DRAIN REMINDER (Jeremy approved 2026-11-22 23:07, the coach's restart read: two wight drains
## in 4:2 went by as one scroll line each, he saved over them): at a won or fled fight's end, row 24
## tells each party member a drain took levels from, a key each, before the results. Only when
## paced (a person playing); the lab's runs don't stop. The original says it once, mid-fight.
const DRAIN_KEY := "drain_reminder"
## QoL FALLEN MONSTERS (P101; Jeremy said yes 2026-11-23 07:33, off by default): a monster that is down but will get up
## (a troll waiting to rise, Combat.revive_in) is drawn as a dim skull on its squares. The original shows a downed
## monster only while its GOES DOWN line is up (DOSBox, Combat Chat 47), then bare floor.
const FALLEN_KEY := "fallen_monsters"
static var _fallen_cache := -1


static func fallen_monsters_on() -> bool:
	if _fallen_cache < 0:
		var c := ConfigFile.new()
		_fallen_cache = 0
		if c.load(GameData.SETTINGS_PATH) == OK:
			_fallen_cache = 1 if bool(c.get_value("qol", FALLEN_KEY, false)) else 0
	return _fallen_cache == 1


static func save_fallen_monsters(value: bool) -> void:
	var c := ConfigFile.new()
	c.load(GameData.SETTINGS_PATH)
	c.set_value("qol", FALLEN_KEY, value)
	c.save(GameData.SETTINGS_PATH)
	_fallen_cache = 1 if value else 0
var _drain_notes: Array = []


static func drain_reminder_on() -> bool:
	var c := ConfigFile.new()
	if c.load(GameData.SETTINGS_PATH) != OK:
		return true
	return bool(c.get_value("qol", DRAIN_KEY, true))


static func save_drain_reminder(value: bool) -> void:
	var c := ConfigFile.new()
	c.load(GameData.SETTINGS_PATH)
	c.set_value("qol", DRAIN_KEY, value)
	c.save(GameData.SETTINGS_PATH)


## The notes for `drained` (Combat.drained: member -> levels), none when the party fell.
static func drain_notes(drained: Dictionary, result: int) -> Array:
	var out: Array = []
	if result == 2:
		return out
	for m in drained:
		var n := int(drained[m])
		out.append("%s LOST %s." % [String(m.name), "A LEVEL" if n == 1 else "%d LEVELS" % n])
	return out


## What follows THE PARTY WINS / HAS FLED (after any drain notes): an event fight won goes straight
## on to the results; the rest wait for Esc or Enter.
func _after_result() -> void:
	if _event_fight and _result == 1:
		# Straight on to the results (the original's "Continue Battle?" is skipped). Paced,
		# as the original: no line on row 24, the results ~0.1 s after the last line or the
		# NO (Combat Chat 12, main's cold-open capture).
		await get_tree().create_timer(0.1 if paced() else 1.0).timeout
		if visible and _event_fight and _result == 1:
			_leave()


## Moves on to whoever acts next; computer-controlled turns play out on a timer.
func _advance() -> void:
	if _dev_win_now:
		_dev_win_now = false
		for c in _combat.combatants:
			if c.team == 1:
				c.down = true
		_combat.decided = true
	var i := _combat.next_turn()
	if _draining:
		await messages_shown
		if _combat == null:
			return
	if i == Combat.ASK_CONTINUE:
		_asking_continue = true
		_on_message("CONTINUE BATTLE: YES NO")
		_refresh()
		return
	if i < 0:
		_result = _combat.outcome()
		_combat.finish()
		_on_message(["", "THE PARTY WINS.", "THE PARTY HAS FALLEN.", "THE PARTY HAS FLED."][_result])
		_drain_notes = drain_notes(_combat.drained, _result) if paced() and drain_reminder_on() else []
		for n in _drain_notes:
			print(n)
		_refresh()
		if _drain_notes.is_empty():
			_after_result()
		return
	_selected = i
	_panel_kept = false
	_cmode = "menu"
	_aiming = false
	_aim_rows_kept = false
	_announcing = false
	_turn_weapon_of = i
	_turn_weapon = _weapon_text(_combatants[i].who)
	if paced():
		_ensure_view(_combatants[i].cell, 2)
		_box_off = false
		_move_label = ""
	else:
		_centre_on_selected()
	_refresh()
	var going_off: Dictionary = _combat.magic.take_pending_aim(i) if _combat.magic else {}
	if not going_off.is_empty():
		# P80 (Combat Chat 22, DOSBox): at the turn a begun spell goes off the original shows no combat
		# menu: "CASTS A SPELL" with row 24 empty, then the aim. Ours aims it here, then casts it.
		_spell_resolving = true
		_cmode = "aim"
		_begin_spell(int(going_off.id), null)
		return
	if not _combatants[i].get("quick", false) and _combat.magic and _combat.magic.resolve_pending(i):
		# A player's spell begun last turn goes off at this turn, which it uses up.
		_refresh()
		await get_tree().create_timer(0.5 * CampScreen.delay_scale()).timeout
		if _draining:
			await messages_shown
		if _combat != null and _combat.active == i:
			_combat.done()
			_advance()
		return
	if _combatants[i].get("quick", false):
		if not paced():
			_ai_timer.start(0.35)
		else:
			# A QUICK member acts as a monster does: no menu, its panel then at once its first
			# step or blow (Combat Chat 12, main's cold-open capture, rounds 2-3: the panel ~0.03 s
			# after the last line clears, the blow's line 0.2 s later; the round-1 menus there were
			# the recorder's Q key, sent every 0.5 s).
			_ai_timer.start(TURN_START)


func _ai_step() -> void:
	if _combat == null or not visible:
		return
	var actor: Dictionary = _combatants[_combat.active] if _combat.active >= 0 else {}
	var before: Vector2i = actor.get("cell", Vector2i.ZERO)
	var moves_before: int = actor.get("moves", 0)
	var shown_before := _message_count
	var weapon_before: GameItem = (actor.who as PartyMember).weapon if not actor.is_empty() else null
	var up_before := _standing()
	var more := _combat.ai_act()
	_note_falls(up_before)
	if paced() and not actor.is_empty():
		_after_blow(_combat.active, shown_before, weapon_before)
	if paced() and not actor.is_empty():
		# The box goes at the figure's first step or blow; a guard with no step keeps it through GUARDING
		# (DOSBox, Combat Chat 49, tu_spec5 at speed 5: a cornered turned SPECTRE's box stayed up with GUARDING;
		# at a blow or a step it went within 0.1-0.2 s of the turn's start).
		var blow := false
		for k in range(maxi(0, _messages.size() - (_message_count - shown_before)), _messages.size()):
			if String(_messages[k]).contains(" ATTACKS "):
				blow = true
		var waiting: bool = actor.get("guarding", false) or (more and actor.get("fleeing", false))
		if actor.cell != before or blow or not waiting:
			_box_off = true
		if actor.cell != before:
			Speaker.play(Speaker.STEP)    # a square moved (GAME.OVR 0x13071)
			_move_label = "MOVE/ATTACK, MOVE LEFT = %d" % (moves_before / 2)
			# GAME.OVR 0x12F0D: a computer-run step whose square is off the view first brings
			# the walker's own square within 2, then keeps the new one in view.
			if not _on_screen(actor.cell):
				_ensure_view(before, 2)
			_ensure_view(actor.cell, 3)
		var t: int = actor.get("target", -1)
		if _draining and t >= 0 and t < _combatants.size() and _combat.touching(actor, _combatants[t]):
			_ensure_view(_combatants[t].cell, 2)   # a blow; missiles are framed as they fly (step 4)
	else:
		_centre_on_selected()
	_refresh()
	if _draining:
		await messages_shown
		if _combat == null or not visible:
			return
	if more:
		_ai_timer.start(0.15 if paced() else 0.3)
	else:
		# The next figure's panel follows the last line's clearing at once (~0.03 s, a frame).
		await get_tree().process_frame
		if _combat != null:
			_advance()


func _after_player_action(what: String) -> void:
	if _draining:
		await messages_shown
		if _combat == null:
			return
	if what == "blocked":
		# GAME.OVR 0xA478 -> START.EXE 0xBA:0x1693: "Blocked" on row 24 in green for the message pause, then the
		# MOVE line again (Combat Chat 40; was CAN'T GO THERE, not an original string).
		_say("BLOCKED")
	elif what == "no attacks":
		_on_message("CAN'T GO THERE")    # an enemy's square with no attacks left: not yet seen in the original
	elif what == "fell":
		if _combatants[_selected].team == 0:
			_on_message("YOUR TEAMMATE IS DOWN")
	var c: Dictionary = _combatants[_selected]
	if _combat.outcome() != 0 or what == "fled" or (c.moves <= 0 and c.attacks <= 0) \
			or (what == "attacked" and c.attacks <= 0):
		_advance()
	elif paced():
		_ensure_view(c.cell, 1)     # a step the player made: margin 1 (GAME.OVR 0x12F0D)
		_refresh()
	else:
		_centre_on_selected()
		_refresh()


# --- AIM ---------------------------------------------------------------------------------
# The original's AIM (lab, chat 11): the aim starts on the figure whose turn it is (RANGE = 0),
# NEXT / PREV step through the others nearest first, showing each one on the right with
# "RANGE = n"; TARGET (offered only where the attack is allowed) attacks it; MANUAL moves a
# cursor square with the arrows; CENTER brings the view to the aim; EXIT goes back. Spells
# aim the same way (_aim_for "spell": TARGET picks the square or figure).

var _aim_for := "attack"      # attack or spell
var _aim_cell := Vector2i.ZERO


func _start_aim(purpose: String = "attack") -> void:
	var me: int = _combat.active
	_aim_for = purpose
	_aim_list = [me]
	var others: Array[int] = []
	for j in _combatants.size():
		if j != me and not _combatants[j].get("down", false):
			others.append(j)
	var offensive := purpose == "attack" or _combat.magic.table.field(_spell_id, 14) != 0
	# The list NEXT walks is 0x3045B's from the aimer (GAME.OVR 0x15AE1, range 0xFF): the figures in sight,
	# nearest first in half-moves (a diagonal step 3, a straight one 2), ties by direction, the aimer sorted in
	# (Combat._by_distance). Ours sorted by range in steps, enemies first, and so walked a different figure
	# (Combat Chat 34: the spell lab's hand-cast Sleep, replayed in ours, aimed 12 deep at another kobold).
	others.assign(others.filter(func(j): return _combat.clear_line(_combatants[me], _combatants[j]).y == 1))
	_combat._by_distance(_combatants[me], others)
	_aim_list.append_array(others)
	_aiming = true
	_cmode = "aim"
	# Every aim starts on the first of the list, the caster or attacker himself (GAME.OVR 0x15D53: 0x15B84 takes
	# entry 0 and moves on only when 0x13880 refuses it; DOSBox, Combat Chat 23, lab save E: Bakshi's Sleep and
	# Magic Missile and Brother Sean's Magic Missile and Fireball opened on the caster, his panel up; ours started
	# a spell on the nearest other figure).
	_aim_index = 0
	if skip_party_on():
		# TARGETING SKIPS THE PARTY (QoL, C11-3): an attack or a harmful spell's NEXT / PREV
		# step through the enemies only, nearest first, starting on the nearest; a helpful
		# spell's through the party first (nearest first), then the enemies. MANUAL still
		# reaches any square. OFF: the original's cycle through every figure.
		var mine: int = _combatants[me].team
		var foes := others.filter(func(j): return _combatants[j].team != mine)
		var friends := others.filter(func(j): return _combatants[j].team == mine)
		if offensive and not foes.is_empty():
			_aim_list.assign(foes)
			_aim_index = 0
		elif not offensive:
			_aim_list.assign([me] + friends + foes)
	# (A spell from an item starts on the user, with no SPELL: line: lab, Combat Chat 5, a
	# Restoration scroll used in the Slums' orc fight.)
	_show_aim()


const SKIP_PARTY_KEY := "aim_skips_party"
static var lab_original_aim := false   # lab (handcast=): the original's aim cycle whatever SETTINGS says


## SETTINGS: TARGETING SKIPS PARTY, ON (an addition, on unless turned off) or OFF (the original).
static func skip_party_on() -> bool:
	if lab_original_aim:
		return false
	var cf := ConfigFile.new()
	if cf.load(GameData.SETTINGS_PATH) != OK:
		return true
	return bool(cf.get_value("qol", SKIP_PARTY_KEY, true))


static func save_skip_party(on: bool) -> void:
	var cf := ConfigFile.new()
	cf.load(GameData.SETTINGS_PATH)
	cf.set_value("qol", SKIP_PARTY_KEY, on)
	cf.save(GameData.SETTINGS_PATH)


func _show_aim() -> void:
	_selected = _aim_list[_aim_index]
	_aim_cell = _combatants[_selected].cell
	_spell_cell = _aim_cell
	if not _on_screen(_aim_cell):
		_centre_on(_aim_cell)
	_refresh()


func _on_screen(cell: Vector2i) -> bool:
	var d := cell - _view
	return d.x >= 0 and d.y >= 0 and d.x < VIEW_CELLS and d.y < VIEW_CELLS


func _centre_on(cell: Vector2i) -> void:
	_view = cell - Vector2i(3, 3)


func _aim_range() -> int:
	if _combat == null or _combat.active < 0:
		return 0
	return _combat.range_between(_combatants[_combat.active].cell, _aim_cell)


func _aim_why(j: int) -> String:
	var me: int = _combat.active
	if j == me or j < 0:
		return "NO TARGET"
	var m: PartyMember = _combatants[me].who
	if m.weapon_ranged:
		var why := _combat.why_not_shoot(me, j)
		if why == "" or (m.weapon_ranged_melee and _combat.touching(_combatants[me], _combatants[j])):
			return ""
		return why
	if not _combat.touching(_combatants[me], _combatants[j]):
		return "OUT OF RANGE"
	return "" if _combatants[me].attacks > 0 else "NO ATTACKS LEFT"


## Whether TARGET is offered at the aim.
func _can_target() -> bool:
	if _aim_for == "spell":
		return _combat.magic.why_not(_combat.active, _spell_id, _aim_cell) == ""
	var who := _combat.occupant(_aim_cell)
	return who >= 0 and _aim_why(who) == ""


func _bottom_menu() -> Array:
	match _cmode:
		"aim":
			return ["NEXT", "PREV", "MANUAL"] + (["TARGET"] if _can_target() else []) + ["CENTER", "EXIT"]
		"manual":
			return (["TARGET"] if _can_target() else []) + ["CENTER", "EXIT"]
		"speed":
			return ["SLOWER", "FASTER", "EXIT"]
		"done":
			var items := []
			if _combat.can_guard():
				items.append("GUARD")
			items.append_array(["DELAY", "QUIT"])
			if _combat.first_dying(_combatants[_combat.active].team) >= 0:
				items.append("BANDAGE")
			items.append("SPEED")
			if Combat.magic_menu_on():
				items.append(_magic_item())
			items.append("EXIT")
			return items
	var c: Dictionary = _combatants[_combat.active]
	var who: PartyMember = c.who
	# P36 (lab, Combat Chat 3: the original at 0 movement shows VIEW AIM USE QUICK DONE): MOVE
	# only with movement left (GAME.OVR 0x9E8E, fight record +6), USE only with items
	# (0x9EE8, the character's item count 0xC7).
	var items := []
	if int(c.get("moves", 0)) > 0:
		items.append("MOVE")
	items.append_array(["VIEW", "AIM"])
	if not who.items.is_empty():
		items.append("USE")
	# CAST: not once the figure has been wounded this round (GAME.OVR 0x9F46, record byte 1).
	# Nor inside the anti-magic shell (0x9F59).
	if _combat.magic != null and not c.get("no_spells", false) and not _combat.anti_magic and \
			not _combat.magic.castable(_combat.active).is_empty():
		items.append("CAST")
	# TURN: a cleric level (record +0x96) and no turn yet this fight (GAME.OVR 0x9F89: combat byte +0x11, set by
	# the turn 0x139A5, the block zeroed at each fight's setup 0xD909). Undead in sight or not (Player 32, p32a1:
	# ELWEN's menu lost TURN after her TURN; Combat Chat 33). The turn itself ends the turn (0x13B39).
	if Combat.turn_level(who) > 0 and not c.get("tried_turning", false):
		items.append("TURN")
	items.append_array(["QUICK", "DONE"])
	return items


func _lit(items: Array) -> int:
	return _pick if _pick < items.size() else 0


func _bevel(img: Image, at: Vector2i) -> void:
	# The original's cursor square (lab): light grey, white along the top and the left two
	# columns, black along the bottom and the right two columns.
	img.fill_rect(Rect2i(at, Vector2i(CELL, CELL)), Color8(170, 170, 170))
	img.fill_rect(Rect2i(at, Vector2i(CELL - 1, 1)), Color8(255, 255, 255))
	img.fill_rect(Rect2i(at, Vector2i(2, CELL - 1)), Color8(255, 255, 255))
	img.fill_rect(Rect2i(at + Vector2i(CELL - 2, 1), Vector2i(2, CELL - 1)), Color8(0, 0, 0))
	img.fill_rect(Rect2i(at + Vector2i(1, CELL - 1), Vector2i(CELL - 1, 1)), Color8(0, 0, 0))
	# Only inside the image (main chat 93): release builds don't check set_pixel's bounds (debug builds log an
	# error and skip it), so a box for a figure off the view (the caster after a cast moved the view) wrote outside
	# the image: Jeremy's crashes after TARGET in 0.1.7-test2 (a segfault on the release template).
	var inside := Rect2i(Vector2i.ZERO, img.get_size())
	if inside.has_point(at + Vector2i(CELL - 1, 0)):
		img.set_pixelv(at + Vector2i(CELL - 1, 0), Color8(0, 0, 0))
	if inside.has_point(at + Vector2i(0, CELL - 1)):
		img.set_pixelv(at + Vector2i(0, CELL - 1), Color8(255, 255, 255))


func _say(text: String, then: Callable = Callable()) -> void:
	_flash = text
	_after_flash = then
	_flash_timer.start(CharacterSheet.MESSAGE_TIME)
	print(text)
	_refresh()


func _aim_input(event: InputEvent, key: Key) -> void:
	var items := _bottom_menu()
	var choice := _menu_choice(event, key, items)
	if event.is_action("ui_cancel"):
		choice = "EXIT"
	if _cmode == "manual":
		var moves := {KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_LEFT: Vector2i(-1, 0),
			KEY_RIGHT: Vector2i(1, 0), KEY_HOME: Vector2i(-1, -1), KEY_PAGEUP: Vector2i(1, -1),
			KEY_END: Vector2i(-1, 1), KEY_PAGEDOWN: Vector2i(1, 1), KEY_KP_8: Vector2i(0, -1),
			KEY_KP_2: Vector2i(0, 1), KEY_KP_4: Vector2i(-1, 0), KEY_KP_6: Vector2i(1, 0),
			KEY_KP_7: Vector2i(-1, -1), KEY_KP_9: Vector2i(1, -1), KEY_KP_1: Vector2i(-1, 1), KEY_KP_3: Vector2i(1, 1)}
		if moves.has(key):
			_aim_cell += moves[key]
			_spell_cell = _aim_cell
			var who := _combat.occupant(_aim_cell)
			if who < 0 and _aim_for == "spell":
				who = _combat.body_at(_aim_cell)    # a fallen member's body (0x157B9)
			if who >= 0:
				_selected = who
			if not _on_screen(_aim_cell):
				_centre_on(_aim_cell)
			_refresh()
			return
	if choice == "":
		return
	_pick = items.find(choice)
	match choice:
		"NEXT":
			_aim_index = (_aim_index + 1) % _aim_list.size()
			_show_aim()
		"PREV":
			_aim_index = (_aim_index + _aim_list.size() - 1) % _aim_list.size()
			_show_aim()
		"MANUAL":
			_cmode = "manual"
			_refresh()
		"CENTER":
			_centre_on(_aim_cell)
			_refresh()
		"EXIT":
			if _cmode == "manual":      # lab: MANUAL's EXIT goes back to the AIM menu
				_cmode = "aim"
				_refresh()
				return
			if _aim_for == "spell":
				# EXIT uses up one pick (GAME.OVR 0x14BD1); with picks left the aim starts over, with none the spell
				# goes off on the figures picked, and with none picked the original asks (0x27EF2) "ABORT SPELL?".
				# The aim's answer, none, is the caster's target now (0x1465B; Combat Chat 34, hpo1: BAKSHI's
				# QUICK turn after two EXITs picked a new target with d4).
				_combatants[_combat.active].target = -1
				_picks_left -= 1
				if _picks_left > 0:
					_restart_pick_aim()
					return
				if not _spell_picks.is_empty():
					_finish_cast()
					return
				_picks_left = 1
				_asking_abort = true
				_refresh()
				return
			_aiming = false
			_cmode = "menu"
			_selected = _combat.active
			_centre_on_selected()
			_refresh()
		"TARGET":
			var me: int = _combat.active
			if Combat.field_log():     # the field log (Combat Chat 42): the aim taken
				var tj := _combat.occupant(_aim_cell)
				print("CHOICE R%d %s TARGET %s at %d,%d%s" % [_combat.round_no, (_combatants[me].who as PartyMember).name,
					_combat.magic.table.name_of(_spell_id) if _aim_for == "spell" else _aim_for, _aim_cell.x, _aim_cell.y,
					(" on %d %s" % [tj, (_combatants[tj].who as PartyMember).name]) if tj >= 0 else ""])
			if _aim_for == "spell":
				_spell_target()
				return
			var j := _combat.occupant(_aim_cell)
			if j >= 0 and _combatants[j].team == _combatants[me].team and not _asking_ally:
				_asking_ally = true
				_ally_target = j
				_refresh()
				return
			_attack_aimed(j)


## The active figure attacks figure j (TARGET in AIM, or YES at "ATTACK ALLY:").
func _attack_aimed(j: int) -> void:
	var me: int = _combat.active
	_aiming = false
	_cmode = "menu"
	_selected = me
	var shown_before := _message_count
	var weapon_before: GameItem = (_combatants[me].who as PartyMember).weapon
	var up_before := _standing()
	if _combat.sweep(me, j):
		pass                      # GAME.OVR 0xA5BD: the sweep comes first (Combat Chat 7)
	elif (_combatants[me].who as PartyMember).weapon_ranged and not _combat.touching(_combatants[me], _combatants[j]):
		_combat.shoot(me, j)
	else:
		_combat.attack(me, j)
	_note_falls(up_before)
	if paced():
		_after_blow(me, shown_before, weapon_before)
	_after_player_action("attacked")


func _standing() -> Array[int]:
	var out: Array[int] = []
	for i in _combatants.size():
		if not _combatants[i].get("down", false):
			out.append(i)
	return out


## Figures that were standing before and are down now linger until their fall is shown.
func _note_falls(up_before: Array[int]) -> void:
	if not paced():
		return
	for i in up_before:
		if _combatants[i].get("down", false) and not _lingering.has(i):
			_lingering.append(i)


## After figure i acted (P16, paced): if it struck at its target, its attack pose, and for a
## missile weapon the missile's flight.
func _after_blow(i: int, shown_before: int, weapon: GameItem) -> void:
	var c: Dictionary = _combatants[i]
	var t: int = c.get("target", -1)
	if t < 0 or t >= _combatants.size():
		return
	var name := (c.who as PartyMember).name.to_upper()
	var struck := false
	# The messages since the action began (counted, as _messages keeps only the last six:
	# with a plain index, every pose, missile and skull stopped after the sixth message,
	# Jeremy's P16 step 4 test).
	for k in range(maxi(0, _messages.size() - (_message_count - shown_before)), _messages.size()):
		var msg := String(_messages[k]).to_upper()
		if msg.begins_with(name + " ") and (msg.ends_with(" AND MISSES") or msg.contains(" HITTING FOR ")):
			struck = true
	if not struck:
		return
	_posed = i
	# QUICK may change weapons during its turn (Phineas: dagger to darts); the last dart thrown
	# can leave none readied: then the weapon from before the turn.
	var now: GameItem = (c.who as PartyMember).weapon
	if now != null and (c.who as PartyMember).weapon_ranged:
		weapon = now
	if _combat.touching(c, _combatants[t]) or weapon == null or _types == null:
		return
	var f := _types.flags(weapon.type)
	var frames: Array = []
	if weapon.type == 9 or f & (ItemTypes.FLAG_ARROWS | ItemTypes.FLAG_QUARRELS):
		frames = ["arrow"]
	elif f & ItemTypes.FLAG_LAUNCHER:
		frames = [8, 136]
	elif f & ItemTypes.FLAG_THROWN:
		frames = [3, 131]
	if not frames.is_empty():
		# GAME.OVR 0x14EAB: id 6 as the missile flies, played out; at its end id 12, and the wait
		# set again at once (0x15065), which silences the speaker: id 12 is never heard.
		_fly(c.cell, _combatants[t].cell, frames, 720.0, Speaker.MISSILE)


## A spell went off (paced): the caster's pose; for a spell aimed away from the caster, COMSPR's
## spark (5 / 133 by turns, ~240 px/s) flown to the aim after "CASTS A SPELL" (lab: Bakshi's
## Magic Missile and Sleep); each figure the spell reaches shows sparkles (9 / 137 by turns)
## while its message is up, (game speed + 1) x 0.28 s (sparkle_time; P85). Fireball and Lightning Bolt show the
## burst instead (P86); the bolt's crackle walking its squares (COMSPR 6 / 134) is not drawn yet.
func _on_spell_cast(i: int, id: int, cell: Vector2i, targets: Array) -> void:
	if not paced() or i < 0 or i >= _combatants.size():
		return
	_posed = i
	# The cast's sound (GAME.OVR 0x27E05, in a fight once the aim is taken): id 11 for
	# Fireball, 8 for Lightning Bolt, 2 for the rest.
	_cast_sound = 11 if id == CombatSpells.FIREBALL else (8 if id == CombatSpells.LIGHTNING else 2)
	var to := cell
	if _combat.magic.aim_kind(id) == "pick" and not targets.is_empty():
		to = _combatants[targets[0]].cell
		if id == 23 or id == 49:
			# Hold Person: the cast's spark goes to the last figure aimed, the first its loop takes (P108's film,
			# Combat Chat 50: DOSBox hpk15, three kobolds: the spark flew from BAKSHI to the third aimed, then its
			# line; the second and first aimed each got their own spark after).
			to = _combatants[targets[targets.size() - 1]].cell
	_hit_pic = [10, 138] if id in [CombatSpells.FIREBALL, CombatSpells.LIGHTNING, 60] else [9, 137]
	_bolt_on = id in [CombatSpells.LIGHTNING, 60]
	_bolt_started = false
	_bolt_walk = []
	# Fireball: no spark flies to the aim; the bursts follow TARGET at once (P86, DOSBox, Combat Chat 42: two hand
	# casts filmed; Lightning Bolt's spark does fly).
	if _combat.magic.aim_kind(id) != "self" and to != _combatants[i].cell and id != CombatSpells.FIREBALL:
		_spell_flight = {"from": _combatants[i].cell, "to": to}
	if _cast_announced and not _muted:
		# No line after the aim: the cast's sound and its flight go first, before the spell's lines.
		_pending_msgs.append(CAST_MARK)
		_pending_subj.append(-1)
		if not _draining:
			_draining = true
			_show_messages.call_deferred()
	_spell_hits = []
	for t in targets:
		_spell_hits.append(int(t))
	# Hold Person (GAME.OVR 0x286E9): the targets last to first; every one but the first taken
	# gets the cast's sound again (id 2, played out) and a spark flown from the caster to it
	# before its save and line. The lines are paired with their figures in that order, not by name
	# alone (Jeremy's P108: three ORCs aimed, ours sparked the first aimed under the last one's line).
	_hold_seq = []
	if (id == 23 or id == 49) and targets.size() > 1:
		_hold_from = _combatants[i].cell
		_spell_hits.reverse()
		for n in range(targets.size() - 1, -1, -1):
			var t: int = targets[n]
			_hold_seq.append([(_combatants[t].who as PartyMember).name.to_upper(), _combatants[t].cell,
					n < targets.size() - 1])


## Lightning Bolt's crackle (P86; DOSBox, Combat Chat 42's film lb1 at 30 fps): the bolt's walk is drawn by the
## flight routine (START.EXE 0xBA:0x1A29, from GAME.OVR 0x29B02 / 0x2A1E4: COMSPR 6 / 134) stop by stop, and each
## square's figure gets its burst and line (0x298D4) as the walk reaches it. The routine draws a step every third
## of a square and waits its [bp+6] in ms after each (0x2884): the spark passes 30 (0x27E4D), the bolt 50
## (0x29AFF), so the crackle goes at 30/50 of the spark's ~240 px/s (P86, Combat Chat 45: ours filmed at 1x beside
## the original's lb1, 30 fps: the original's walk from the aim to the bounce and back took ~0.7 s, ours' 0.3 s). Flies the crackle along the walk's squares up to `to` (the walk's end for (-1, -1)); squares off
## the view are passed over.
## The figures a spell reached, for matching its lines by name: during a bolt's walk the same-named ones in the
## order the walk reaches their squares (several kobolds hit: the line is the next one's on the walk).
func _bolt_order(hits: Array[int], who: String) -> Array[int]:
	if not _bolt_on:
		return hits
	var order: Array = _combat.magic.bolt_path if not _bolt_started else [_crackle_at] + _bolt_walk
	var out := hits.duplicate()
	out.sort_custom(func(a: int, b: int) -> bool:
		var ia := order.find(_combatants[a].cell)
		var ib := order.find(_combatants[b].cell)
		return (ia if ia >= 0 else 999) < (ib if ib >= 0 else 999))
	return out


func _crackle_to(to: Vector2i) -> void:
	if not _bolt_started:
		_bolt_started = true
		_bolt_walk = _combat.magic.bolt_path.duplicate()
		if _bolt_walk.is_empty():
			return
		_crackle_at = _bolt_walk.pop_front()     # the aim's square: the spark ended there
	var hit := _sparkle
	_sparkle = -1               # no burst while the crackle walks
	while _crackle_at != to and not _bolt_walk.is_empty():
		var p: Vector2i = _bolt_walk.pop_front()
		if _on_screen(_crackle_at) and _on_screen(p):
			_fly(_crackle_at, p, [6, 134], 240.0 * 30.0 / 50.0)
			await flight_done
		_crackle_at = p
	_sparkle = hit
	_refresh()


## The arrow sprite for a flight from a to b, mirrored for the left diagonals (lab: Darkstar's
## dart thrown down-left).
func _arrow(a: Vector2i, b: Vector2i) -> Image:
	var d := Vector2(b - a)
	var sector := int(round(atan2(d.x, -d.y) / (PI / 4.0))) % 8
	if sector < 0:
		sector += 8
	var block: int = [0, 1, 2, 129, 128, 129, 130, 1][sector]
	var img := _art.sprite(block)
	if img != null and sector in [5, 7]:
		img = img.duplicate() as Image
		img.flip_x()
	return img


## A missile's flight from cell a to cell b (P16); `sound` (if any) plays through it and stops
## as it lands.
func _fly(a: Vector2i, b: Vector2i, frames: Array, speed: float, sound := 0) -> void:
	_flying = true
	if sound > 0:
		Speaker.play(sound, true)
	if not _on_screen(b):
		_ensure_view(Vector2i((a.x + b.x + 1) / 2, (a.y + b.y + 1) / 2), 0)
	var p0 := Vector2((a - _view) * CELL)
	var p1 := Vector2((b - _view) * CELL)
	var length := maxf(absf(p1.x - p0.x), absf(p1.y - p0.y))
	var t := 0.0
	var started := Time.get_ticks_msec()
	while is_inside_tree():
		t = (Time.get_ticks_msec() - started) / 1000.0
		var gone := minf(t * speed, length)
		var at := p0.lerp(p1, gone / length if length > 0 else 1.0)
		var img: Image = _arrow(a, b) if frames[0] is String else _art.sprite(frames[int(t * 15.0) % frames.size()])
		_flight = {"img": img, "at": Vector2i(int(at.x) / 8 * 8, int(at.y) / 8 * 8)}
		_refresh()
		if gone >= length:
			break
		await get_tree().process_frame
	_flight = {}
	_flying = false
	if sound > 0:
		Speaker.play(0xFF)
	_refresh()
	flight_done.emit()


## The hot letter or Enter on the lit item ("" for neither).
func _menu_choice(event: InputEvent, key: Key, items: Array) -> String:
	if event.is_action("ui_accept") and not items.is_empty():
		return items[_lit(items)]
	for it in items:
		if key == OS.find_keycode_from_string(String(it).substr(0, 1)):
			return it
	return ""


# --- CAST ---------------------------------------------------------------------------------
# The original's CAST: the caster's memorized spells, then (for a spell that isn't on the
# caster alone) the aim, with "ABORT SPELL?" on leaving. QoL: the cells an area spell will
# cover are shaded while aiming. Modern controls: C casts, ↑/↓ choose the spell, Enter
# picks it; arrows move the aim, Tab jumps to the next figure, Enter casts (or picks a
# figure, D when done picking), Esc asks ABORT SPELL? (YES: the spell is lost, the turn ends).

var _use_items: Array[GameItem] = []    # kept for the developer layout (empty)


## USE: the items page on grey (READY lit); USE there on a readied item that casts a spell
## (potion, wand, scroll...) aims it as CAST does, spending the item's charge.
func _start_use() -> void:
	_sheet.open_combat(_party_view(), _active_index(), "use", 0)


## CAST: the spells page on grey, "CHOOSE SPELL:" CAST EXIT.
func _start_cast() -> void:
	if _combat.magic == null:
		return
	_sheet.open_combat(_party_view(), _active_index(), "cast", 0)


## The sheet's people: the active figure alone (its index 0).
func _party_view() -> Array[PartyMember]:
	var out: Array[PartyMember] = [_combatants[_combat.active].who]
	return out


func _active_index() -> int:
	return 0


func _after_sheet() -> void:
	_pick = _sheet.last_pick
	if _combat != null:
		for c in _combatants:
			(c.who as PartyMember).recalculate(_types)
	_refresh()


func _on_spell_chosen(id: int) -> void:
	if _combat == null or _combat.magic == null:
		return
	if not _combat.magic.castable(_combat.active).has(id):
		_say("CAN'T CAST THAT NOW")
		return
	_begin_spell(id, null)


func _on_item_used(it: GameItem) -> void:
	var m: PartyMember = _combatants[_combat.active].who
	var id := CharacterSheet.item_spell(m, it)
	if id > 0 and _combat.magic != null:
		_begin_spell(id, it)


var _spell_resolving := false        # aiming a begun spell at the turn it goes off (P80)


func _begin_spell(id: int, item: GameItem) -> void:
	if item == null and not _spell_resolving and _combat.magic.begin_cast(_combat.active, id):
		# A casting time: BEGINS CASTING, no aim yet; the turn ends.
		_casting = ""
		_aiming = false
		_cmode = "menu"
		_refresh()
		_advance()
		return
	_spell_id = id
	_use_item = item
	_combat.magic.item_in_use = item != null     # the aim's range at level 6 with an item (DS:0x6DBF)
	_spell_picks = []
	_picks_left = _combat.magic.max_picks(id) if _combat.magic.aim_kind(id) == "pick" else 1
	var self_spell := _combat.magic.aim_kind(_spell_id) == "self"
	if self_spell and item != null:
		_spell_cell = _combatants[_combat.active].cell
		_finish_cast()
		return
	if item == null:
		# CASTS A SPELL before the aim (GAME.OVR 0x27D60 prints it, then 0x2A332 aims; DOSBox, Combat Chat 23:
		# Bakshi's Sleep: the line with rows 23-24 empty for ~0.8 s, then SPELL:SLEEP and AIM:). An item's
		# USES line is not checked: it stays after the aim.
		var me: int = _combat.active
		_announced = true
		_announcing = true
		_casting = "announce"
		_cmode = "announce"
		_combat.message.emit("%s CASTS A SPELL" % (_combatants[me].who as PartyMember).name)
		_refresh()
		if paced():
			await get_tree().process_frame
			if _draining:
				await messages_shown
		_announcing = false
		if _combat == null or _combat.active != me:
			return
		if self_spell:
			# A spell on the caster: no aim; SPELL:<NAME> on row 23 under its lines (DOSBox, Combat Chat 23: Brother
			# Sean's Mirror Image, CASTS A SPELL, then SPELL:MIRROR IMAGE with IS DUPLICATED, row 24 empty).
			_spell_cell = _combatants[me].cell
			_finish_cast()
			return
	_casting = "aim"
	_start_aim("spell")


## TARGET while aiming a spell: an area spell goes off at the square; others pick figures
## (as many as the spell takes) and go off when the last is picked.
func _spell_target() -> void:
	var me: int = _combat.active
	var why := _combat.magic.why_not(me, _spell_id, _aim_cell)
	if why != "":
		_say(why)
		return
	# The figure aimed at becomes the caster's target (GAME.OVR 0x14611's own-hand branch: 0x15D53's pick written
	# to the combat block's +0xA), the one its next QUICK turn keeps (Combat Chat 34: the spell lab's hand-cast
	# Sleep replayed in ours; BAKSHI's QUICK kept the sleeping kobold he had aimed at, d6 for who to hit among
	# the six beside him, where ours picked a new target with d19).
	_combatants[me].target = _combat.occupant(_aim_cell)
	if _combat.magic.aim_kind(_spell_id) == "area":
		_finish_cast()
		return
	var who := _combat.occupant(_aim_cell)
	if who < 0:
		who = _combat.body_at(_aim_cell)     # a spell aimed at a body takes the fallen member
	if who < 0:
		_say("NO TARGET THERE")
	elif who in _spell_picks:
		# A figure picked again costs no pick (GAME.OVR 0x14B79, "Already been targeted"); the aim starts over.
		_say("ALREADY BEEN TARGETED")
		_restart_pick_aim()
	else:
		_spell_picks.append(who)
		_picks_left -= 1
		if _picks_left <= 0:
			_finish_cast(true)
		else:
			_restart_pick_aim()


## The next pick of a spell with several (GAME.OVR 0x14AD1 calls the aim 0x14611 -> 0x15D53 once a pick): the aim
## starts again on the first of the list, the caster (Combat Chat 34, the spell lab's Hold Person by hand on the
## Slums orcs: after each TARGET the panel showed BAKSHI again, NEXT the same orc; ours walked on from the pick).
func _restart_pick_aim() -> void:
	if _aim_list.is_empty():
		return
	_aim_index = 0
	_cmode = "aim"      # back to AIM:, not MANUAL (Player 48's p45i5 log: after a MANUAL pick's TARGET the original's
	_show_aim()         # next pick opened on AIM:NEXT PREV MANUAL TARGET CENTER EXIT; Combat Chat 52)


## YES at ABORT SPELL? (GAME.OVR 0x27F19): "SPELL ABORTED", the spell is forgotten as if
## cast (0xBA:0x148B; not for an item's), and the turn ends (lab, Combat Chat 4: Brother Sean
## aborted Slow Poison twice; both were gone, and the next figure acted).
func _abort_spell() -> void:
	var me: int = _combat.active
	_casting = ""
	_aiming = false
	_cmode = "menu"
	_selected = me
	if _use_item == null:
		(_combatants[me].who as PartyMember).forget(_spell_id)
	_use_item = null
	_combat.magic.item_in_use = false
	_spell_resolving = false
	_announced = false
	_spell_picks.clear()
	_on_message("SPELL ABORTED")
	_combat.done()
	_refresh()
	_advance()


## The last pick's panel kept through the cast's lines (see _finish_cast), with no box drawn and its status line as
## it was at TARGET (the original doesn't redraw it: no "(HELPLESS)" under a kobold just held, hpk15).
var _panel_kept := false
var _kept_state := ""


## The panel's status line for combatant `e` (START.EXE 0x16A0, see _draw_original).
func _panel_state(e: Dictionary, gave_up: bool) -> String:
	var m: PartyMember = e.who
	if gave_up:
		return ""
	if e.get("down", false):
		return PANEL_STATUS[clampi(m.status, 0, PANEL_STATUS.size() - 1)]
	if CombatSpells.held(m):
		return "(HELPLESS)"
	return ""


func _finish_cast(by_target := false) -> void:
	var me: int = _combat.active
	var announced := _announced
	_announced = false
	_aim_rows_kept = announced and paced() and _cmode in ["aim", "manual", "announce"]
	if _aim_rows_kept:
		_kept_prompt = {"aim": "AIM:", "manual": "(USE CURSOR KEYS)"}.get(_cmode, "")
		_kept_items = _bottom_menu() if _kept_prompt != "" else []
		_kept_lit = _lit(_kept_items) if _kept_prompt != "" else 0
	_casting = ""
	_aiming = false
	_cmode = "menu"
	_selected = me
	if by_target and paced() and not _spell_picks.is_empty():
		# The aim ends on the last figure picked and the panel stays on it, with no box, through the spell's
		# lines (P108's film, Combat Chat 50: DOSBox hpk15, Hold Person on three kobolds: KOBOLD HITPOINTS 3
		# from the third TARGET to the last line; after EXIT the aim has gone back to the caster, hp_orc1).
		_selected = int(_spell_picks[_spell_picks.size() - 1])
		_kept_state = _panel_state(_combatants[_selected], false)
		_panel_kept = true
	if _spell_resolving:
		_combatants[me].resolving = true
	_cast_announced = announced
	_combat.magic.cast(me, _spell_id, _spell_cell, _spell_picks, _use_item, announced)
	_cast_announced = false
	_combatants[me].resolving = false
	_spell_resolving = false
	_use_item = null
	_refresh()
	_advance()


var _use_item: GameItem = null


# --- Drawing ----------------------------------------------------------------------------

func _centre_on_selected() -> void:
	if _combatants.is_empty():
		return
	var c: Vector2i = _combatants[_selected].cell
	_view = c - Vector2i(3, 3)


## SHOW SPELL AREA (QoL 4, Jeremy's Q23, 2026-11-17: the 50% dither in the spell's colour): while an
## area spell is aimed, every other game pixel of a caught square's grey floor takes the spell's colour;
## figures, walls and the aim box are drawn as before. The original shows the aim box only. The colours
## are to be judged on testers' feedback: this table is all there is to change (EGA colours; a spell
## not named here takes AREA_OTHER).
const AREA_COLOURS := {
	"FIREBALL": Color8(255, 85, 85), "BURNING HANDS": Color8(255, 85, 85),
	"SLEEP": Color8(0, 0, 170), "HOLD PERSON": Color8(0, 0, 170),
	"STINKING CLOUD": Color8(0, 170, 0),
}
const AREA_OTHER := Color8(170, 0, 170)
const AREA_FLOOR := Color8(85, 85, 85)
const SHOW_AREA_KEY := "show_spell_area"


static func show_area_on() -> bool:
	var cf := ConfigFile.new()
	if cf.load(GameData.SETTINGS_PATH) != OK:
		return true
	return bool(cf.get_value("qol", SHOW_AREA_KEY, true))


static func save_show_area(on: bool) -> void:
	var cf := ConfigFile.new()
	cf.load(GameData.SETTINGS_PATH)
	cf.set_value("qol", SHOW_AREA_KEY, on)
	cf.save(GameData.SETTINGS_PATH)


static func area_colour(spell_name: String) -> Color:
	return AREA_COLOURS.get(spell_name.strip_edges().to_upper(), AREA_OTHER)


## The caught square's floor dithered: game pixels on a checkerboard, the grey ones only.
static func dither_floor(img: Image, at: Vector2i, colour: Color) -> void:
	# Only inside the image (Combat Chat 42, after main chat 93's _bevel crash: release builds don't check
	# get_pixel / set_pixel bounds).
	if at.x < 0 or at.y < 0 or at.x + CELL > img.get_width() or at.y + CELL > img.get_height():
		return
	for y in CELL:
		for x in CELL:
			if (x + y) & 1 == 0 and img.get_pixel(at.x + x, at.y + y) == AREA_FLOOR:
				img.set_pixel(at.x + x, at.y + y, colour)


var _show_area := true


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
	# P40: a fallen party member lies on its square: the original (GAME.OVR 0x3169B) puts it
	# in the fallen list with the ground it covered and makes that ground 0x1F (RANDCOM's
	# sixth picture, a body in its own colours; not when the ground is 0x1E), takes the figure
	# off the map, and puts the ground back when it gets up (0x3188C). Monsters leave nothing.
	# 0x1F is walkable and see-through (the ground table, DS:0x2744), so only the picture changes.
	var body := _art.tile(BODY_TILE)
	for i in _combatants.size():
		var e: Dictionary = _combatants[i]
		if body == null or not e.get("down", false) or e.get("fled", false) or not _party.has(e.who) \
				or _lingering.has(i) or _skulls.has(i) or _field.tile(e.cell.x, e.cell.y) == CLOUD_TILE:
			continue
		var at: Vector2i = (e.cell - _view) * CELL
		if at.x >= 0 and at.y >= 0 and at.x < size and at.y < size:
			img.blit_rect(body, Rect2i(0, 0, CELL, CELL), at)
	# Casting: the aim cursor and (QoL) the cells the spell will cover.
	if _casting == "aim":
		var cells: Array[Vector2i] = []
		if _show_area and _combat.magic.aim_kind(_spell_id) == "area":
			cells = _combat.magic.preview_cells(_combat.active, _spell_id, _spell_cell)
		var colour := area_colour(_combat.magic.table.name_of(_spell_id))
		for p in cells:
			var at := (p - _view) * CELL
			if at.x >= 0 and at.y >= 0 and at.x < size and at.y < size:
				dither_floor(img, at, colour)
		var cur := (_spell_cell - _view) * CELL
		if cur.x >= 0 and cur.y >= 0 and cur.x < size and cur.y < size:
			for k in CELL:
				for edge in [Vector2i(k, 0), Vector2i(k, CELL - 1), Vector2i(0, k), Vector2i(CELL - 1, k)]:
					if Rect2i(Vector2i.ZERO, img.get_size()).has_point(cur + edge):     # release builds: no bounds check
						img.set_pixelv(cur + edge, Color8(255, 255, 85))
	if _cmode == "manual":
		var mc := (_aim_cell - _view) * CELL
		if mc.x >= 0 and mc.y >= 0 and mc.x < size and mc.y < size:
			_bevel(img, mc)
	# P101 (FALLEN MONSTERS): the dim skulls first, under any figure standing there.
	for i in _combatants.size():
		var e: Dictionary = _combatants[i]
		if not e.get("down", false) or _skulls.has(i) or _lingering.has(i):
			continue
		if e.team == 1 and not e.get("fled", false) and int(e.get("revive_in", 0)) > 0 and fallen_monsters_on():
			var dim := _art.sprite(11)
			if dim != null:
				dim = dim.duplicate() as Image
				var bg := dim.get_pixel(0, 0)      # the sprite's ground: left out, the floor shows
				for y in dim.get_height():
					for x in dim.get_width():
						var px := dim.get_pixel(x, y)
						if px.is_equal_approx(bg):
							dim.set_pixel(x, y, Color(0, 0, 0, 0))
						else:
							dim.set_pixel(x, y, Color(px.r * 0.5, px.g * 0.5, px.b * 0.5, px.a * 0.7))
				for p in _combat.cells(e):
					var at2: Vector2i = (p - _view) * CELL
					if at2.x >= 0 and at2.y >= 0 and at2.x < size and at2.y < size:
						img.blend_rect(dim, Rect2i(Vector2i.ZERO, dim.get_size()), at2)
	# The art faces right; combatants facing a westward direction are drawn mirrored.
	for i in _combatants.size():
		var e: Dictionary = _combatants[i]
		if _skulls.has(i):
			var sk := _art.sprite(11)
			if sk != null:
				img.blend_rect(sk, Rect2i(Vector2i.ZERO, sk.get_size()), (e.cell - _view) * CELL)
			continue
		if e.get("down", false) and not _lingering.has(i):
			continue
		var icon: Image = e.icon
		var at: Vector2i = (e.cell - _view) * CELL
		if i == _selected and _cmode != "manual" and not (_box_off and e.get("quick", false)) and not _panel_kept:
			_bevel(img, at)
		if i == _posed:
			icon = _attack_icon(e)
		if icon:
			var src := icon
			if Placement.DX[e.dir] < 0:
				src = icon.duplicate() as Image
				src.flip_x()
			img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)
	if _sparkle >= 0 and _sparkle < _combatants.size():
		var sp := _art.sprite(_hit_pic[0] if (Time.get_ticks_msec() / 133) % 2 == 0 else _hit_pic[1])
		if sp != null:
			img.blend_rect(sp, Rect2i(Vector2i.ZERO, sp.get_size()), (_combatants[_sparkle].cell - _view) * CELL)
	if not _flight.is_empty() and _flight.img != null:
		var fi: Image = _flight.img
		img.blend_rect(fi, Rect2i(Vector2i.ZERO, fi.get_size()), _flight.at)
	_picture.texture = ImageTexture.create_from_image(img)
	_draw_original(img)
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
			_prompt.text = ["", "THE PARTY WINS.", "THE PARTY HAS FALLEN.", "THE PARTY HAS FLED."][_result] + "   Esc or Enter: leave"
		elif _casting == "choose":
			var names := PackedStringArray()
			for k in _spell_list.size():
				var label := _use_items[k].name if k < _use_items.size() else _combat.magic.table.name_of(_spell_list[k])
				names.append(("[%s]" if k == _spell_index else "%s") % label)
			_prompt.text = "CAST: %s\n↑/↓ choose   Enter cast   Esc back" % "  ".join(names)
		elif _casting == "aim":
			var why := _combat.magic.why_not(_combat.active, _spell_id, _spell_cell)
			var kind := _combat.magic.aim_kind(_spell_id)
			_prompt.text = "%s: %s   Arrows: aim   Tab: next figure   %s%sEsc: abort" % [
				_combat.magic.table.name_of(_spell_id), why if why != "" else "RANGE %d" % _combat.magic.spell_range(_combat.active, _spell_id),
				"Enter: cast   " if why == "" else "",
				("D: done (%d of %d picked)   " % [_spell_picks.size(), _combat.magic.max_picks(_spell_id)]) if kind == "pick" else ""]
		elif _aiming:
			var j: int = _aim_list[_aim_index]
			var why := _aim_why(j)
			_prompt.text = "AIM: RANGE = %d   %s   ←/→ next/prev   %sEsc: back" % [
				_combat.range_of(_combatants[_combat.active], _combatants[j]),
				why if why != "" else "", "Enter: target   " if why == "" else ""]
		else:
			_prompt.text = ("ROUND %d   Arrows / Home PgUp End PgDn: move or attack   Space: done   "
				+ "A: aim   C: cast   G: guard   B: bandage   Q: quick   Esc: leave") % _combat.round_no
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
	if _sheet != null and _sheet.visible:
		return
	if _flash != "":
		# A key ends the message at once.
		_flash_timer.stop()
		_flash_timer.timeout.emit()
		get_viewport().set_input_as_handled()
		return
	if not _drain_notes.is_empty():
		# QoL DRAIN REMINDER: any key takes the next note; after the last, the fight's end goes on.
		get_viewport().set_input_as_handled()
		_drain_notes.pop_front()
		_refresh()
		if _drain_notes.is_empty():
			_after_result()
		return
	if _asking_flee:
		if key == KEY_Y or key == KEY_N:
			get_viewport().set_input_as_handled()
			_asking_flee = false
			if key == KEY_N:
				_refresh()       # NO: back to the MOVE loop (0xA44D)
				return
			var me: int = _combat.active
			var up_before := _standing()
			var away := _combat.player_flees(me)
			_note_falls(up_before)
			_move_start = {}
			_cmode = "menu"
			if away:
				_after_player_action("fled")
			else:
				# "ESCAPE IS BLOCKED" on row 24 for the message pause, then the turn is over (Combat.player_flees).
				_say("ESCAPE IS BLOCKED", func() -> void: _after_player_action("escape blocked"))
		return
	if _asking_ally:
		if key == KEY_Y or key == KEY_N:
			get_viewport().set_input_as_handled()
			if key == KEY_N:
				_asking_ally = false
				_ally_from_move = false
				_refresh()
				return
			var me: int = _combat.active
			for c in _combatants:
				var w: PartyMember = c.who
				if c.team == _combatants[me].team and c.get("quick", false) and (w.npc >= 128 or w.script_team == 0x80) \
						and w.morale > 0x7F:
					c.team = 1 - int(c.team)
			ally_attacked.emit()
			_asking_ally = false
			if _ally_from_move:
				_ally_from_move = false
				var shown_before := _message_count
				var weapon_before: GameItem = (_combatants[me].who as PartyMember).weapon
				var up_before := _standing()
				if not _combat.sweep(me, _ally_target):
					_combat.attack(me, _ally_target)    # 0xA5BD: the sweep first, else the blow (0x1407F)
				_note_falls(up_before)
				if paced():
					_after_blow(me, shown_before, weapon_before)
				if _combatants[me].moves < 2:
					_combatants[me].moves = 0
				_after_player_action("attacked")
				return
			_attack_aimed(_ally_target)
		return
	if _announcing:
		get_viewport().set_input_as_handled()
		return
	if _asking_abort:
		get_viewport().set_input_as_handled()
		if key == KEY_N or event.is_action("ui_cancel"):
			_asking_abort = false
			_refresh()
		elif key == KEY_Y:
			_asking_abort = false
			_abort_spell()
		return
	if _aiming:
		_aim_input(event, key)
		get_viewport().set_input_as_handled()
		return
	if _asking_continue:
		if key == KEY_Y or key == KEY_N or key == KEY_ENTER or key == KEY_KP_ENTER:
			_asking_continue = false   # Enter takes the lit NO
			_combat.continue_battle(key == KEY_Y)
			_advance()
		get_viewport().set_input_as_handled()
		return
	if _combat != null and _result == 0 and _combat.active >= 0 and _combatants[_combat.active].get("quick", false):
		# The original reads keys while the computer runs a turn (GAME.OVR 0xBB80; lab):
		# Alt-M switches magic on or off for the party's QUICK members, Space hands every
		# QUICK party member back to the player (not the NPCs, who always fight on their own).
		if key == KEY_M and (event as InputEventKey).alt_pressed:
			get_viewport().set_input_as_handled()
			toggle_magic()
			return
		if key == KEY_SPACE:
			# Read at the next computer turn's opening, where the one whose turn it is goes back to the
			# order pick and takes it by hand (Combat.hand_back; Combat Chat 52).
			get_viewport().set_input_as_handled()
			_combat.control_pending = true
			return
	if (_event_fight or _cmode == "move") and _result == 0 and _combat != null:
		_fight_input(event, key)     # (a test fight's Esc leaves it, but not from inside MOVE)
		return
	if event.is_action("ui_cancel") or (_result != 0 and event.is_action("ui_accept")):
		_leave()
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


func _leave() -> void:
	_ai_timer.stop()
	var was_event := _event_fight
	var result := _result
	_last_dropped = _combat.dropped if _combat != null else ([] as Array[GameItem])
	_last_paid = _combat.paid if _combat != null else []
	_last_rounds = _combat.round_no if _combat != null else 0
	_combat = null
	_event_fight = false
	anti_magic = false
	CharacterSheet.anti_magic = false    # outside fights main sets it (the shell's USE, 0x21FD6)
	visible = false
	if was_event:
		finished.emit(result)
	else:
		closed.emit()


## Mouse step 2b (C11-1): a click on the battlefield's square `p` (pixels in the 7 x 7 window) as
## the keys would do it. At the menu or in MOVE, a square next to the figure whose turn it is steps
## there (MOVE first at the menu, when the figure can still move). In AIM a click aims there
## (MANUAL's cursor, moved square by square as the keys move it); a click on the square already
## aimed at is TARGET, when TARGET is offered.
const _DIR_KEYS := [KEY_UP, KEY_PAGEUP, KEY_RIGHT, KEY_PAGEDOWN, KEY_DOWN, KEY_END, KEY_LEFT, KEY_HOME]


func _field_click(p: Vector2i, _double: bool) -> void:
	if _combat == null or _combat.active < 0 or _result != 0 or _combatants[_combat.active].get("quick", false) \
			or _flash != "" or _asking_ally or _asking_flee or _asking_abort or _casting != "":
		return
	var cell := _view + Vector2i(p.x / CELL, p.y / CELL)
	var me: Dictionary = _combatants[_combat.active]
	if _cmode == "menu" or _cmode == "move":
		var d: Vector2i = cell - me.cell
		if d == Vector2i.ZERO or absi(d.x) > 1 or absi(d.y) > 1:
			return
		var dir := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
			Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)].find(d)
		if _cmode == "menu":
			if me.moves < 2 or not "MOVE" in _bottom_menu():
				return
			MouseInput.press(KEY_M)
		MouseInput.press(_DIR_KEYS[dir])
	elif _cmode == "aim" or _cmode == "manual":
		if cell == _aim_cell:
			if "TARGET" in _bottom_menu():
				MouseInput.press(KEY_T)
			return
		if _cmode == "aim":
			MouseInput.press(KEY_M)
		var at := _aim_cell
		while at != cell:
			var step := Vector2i(signi(cell.x - at.x), signi(cell.y - at.y))
			at += step
			MouseInput.press(_DIR_KEYS[[Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
				Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)].find(step)])


const _STEP_KEYS := {KEY_UP: 0, KEY_KP_8: 0, KEY_PAGEUP: 1, KEY_KP_9: 1, KEY_RIGHT: 2, KEY_KP_6: 2,
	KEY_PAGEDOWN: 3, KEY_KP_3: 3, KEY_DOWN: 4, KEY_KP_2: 4, KEY_END: 5, KEY_KP_1: 5,
	KEY_LEFT: 6, KEY_KP_4: 6, KEY_HOME: 7, KEY_KP_7: 7}


func _fight_input(event: InputEvent, key: Key) -> void:
	get_viewport().set_input_as_handled()
	if _draining or _result != 0 or _combat.active < 0 or _combatants[_combat.active].get("quick", false):
		return
	if _cmode == "move":
		if event.is_action("ui_cancel") or event.is_action("ui_accept"):
			# Leaving MOVE (GAME.OVR 0xA2D2, Combat Chat 4; lab: Brother Sean stepped SE, then Esc
			# put him back): Esc undoes the walk, the figure back on the square where MOVE began
			# with its movement and facing as they were; Enter keeps it.
			var mc: Dictionary = _combatants[_combat.active]
			if event.is_action("ui_cancel") and not _move_start.is_empty() \
					and (mc.cell == _move_start.cell or _combat.fits(_combat.active, _move_start.cell)[0]):
				mc.cell = _move_start.cell
				mc.moves = _move_start.moves
				mc.dir = _move_start.dir
			_move_start = {}
			_cmode = "menu"
			if mc.moves < 2:     # leaving the MOVE loop (0xA51D)
				mc.moves = 0
			_centre_on_selected()
			_refresh()
		elif _STEP_KEYS.has(key):
			# A step into an enemy is a blow: like AIM's, its target stays up through the message,
			# then the skull (Jeremy's P16 step 5 test: manual melee showed no skull, manual darts did).
			var me: int = _combat.active
			var shown_before := _message_count
			var weapon_before: GameItem = (_combatants[me].who as PartyMember).weapon
			var up_before := _standing()
			var what := _combat.step(_STEP_KEYS[key])
			if what == "edge":
				_asking_flee = true
				_refresh()
				return
			if what == "ally":
				_asking_ally = true          # Combat Chat 40: ATTACK ALLY: YES NO, from the MOVE loop
				_ally_from_move = true
				_ally_target = _combat.step_ally
				_refresh()
				return
			_note_falls(up_before)
			if what == "moved":
				Speaker.play(Speaker.STEP)    # a square moved (GAME.OVR 0x13071)
			if paced() and what != "moved":
				_after_blow(me, shown_before, weapon_before)
			# P36: the original's MOVE loop (GAME.OVR 0xA236) runs only while more than one
			# half-move is left, and on leaving it a last half-move is dropped (0xA51D): MOVE
			# ends and the menu comes back without MOVE (lab, Combat Chat 3: VIEW AIM USE QUICK
			# DONE after the step that left 1 of 3). Computer turns don't use this loop.
			if _combatants[me].moves < 2:
				_combatants[me].moves = 0
			_after_player_action(what)
			if _cmode == "move" and _combat.active == _selected and _combatants[_selected].moves <= 0:
				_cmode = "menu"
				_refresh()
		return
	# The original's reference card keys work at the combat menu too (lab, Combat Chat 1, the
	# kobold net trap; GAME.OVR 0x9CAE for Alt-M): Alt-M switches MAGIC ON / OFF, Alt-Q puts the
	# whole party on QUICK (this member's turn runs at once), Space takes every party member off
	# QUICK (nothing to see at the menu; the turn goes on). Space used to end the turn here.
	if _cmode == "menu" and event is InputEventKey and (event as InputEventKey).alt_pressed:
		if key == KEY_M:
			toggle_magic()
			return
		if key == KEY_Q:
			quick_all()
			return
	if _cmode == "menu" and key == KEY_SPACE:
		for c in _combatants:
			var w: PartyMember = c.who
			if c.team == 0 and not (w.npc >= 128 or w.script_team == 0x80):
				c.quick = false
				Combat.set_record_quick(w, false)   # GAME.OVR 0x9D16
		return
	var items := _bottom_menu()
	var choice := _menu_choice(event, key, items)
	if choice == "" and _cmode in ["done", "speed"] and event.is_action("ui_cancel"):
		choice = "EXIT"
	if choice == "":
		return
	_pick = items.find(choice)
	if Combat.field_log() and _combat.active >= 0:     # the field log (Combat Chat 42): the menu choice made
		print("CHOICE R%d %s %s %s" % [_combat.round_no, (_combatants[_combat.active].who as PartyMember).name, _cmode, choice])
	if _cmode == "speed":
		# The original's DONE -> SPEED (lab): "GAMESPEED (n) : SLOWER FASTER EXIT", 0 fastest
		# to 9 slowest, the same setting as ALTER's; EXIT goes back to DONE's menu.
		match choice:
			"SLOWER":
				CampScreen.speed = mini(CampScreen.speed + 1, 9)
			"FASTER":
				CampScreen.speed = maxi(CampScreen.speed - 1, 0)
			"EXIT":
				_cmode = "done"
				_pick = maxi(_bottom_menu().find("SPEED"), 0)
		_refresh()
		return
	if _cmode == "done":
		match choice:
			"GUARD":
				var shown := _messages.size()
				_muted = true
				_combat.guard(_combat.active, false)
				_muted = false
				# Lab: the original says only GUARDING on the bottom line, nothing on the right.
				_messages = _messages.slice(0, shown)
				_cmode = "menu"
				_say("GUARDING", _advance)
			"DELAY":
				_cmode = "menu"
				if _combat.delay():
					_advance()
				else:
					_refresh()
			"QUIT":
				_combat.done()
				_cmode = "menu"
				_advance()
			"BANDAGE":
				_cmode = "menu"
				if _combat.bandage():
					_refresh()
					_advance()
			"SPEED":
				_cmode = "speed"
				_pick = 0
				_refresh()
			"MAGIC:ON", "MAGIC:OFF":
				toggle_magic()
				_pick = maxi(_bottom_menu().find(_magic_item()), 0)
				_refresh()
			"EXIT":
				_cmode = "menu"
				_refresh()
		return
	match choice:
		"MOVE":
			if _combatants[_combat.active].moves < 2:       # the loop doesn't start (0xA23E)
				_combatants[_combat.active].moves = 0
			else:
				_cmode = "move"
				var mc: Dictionary = _combatants[_combat.active]
				_move_start = {"cell": mc.cell, "moves": mc.moves, "dir": mc.dir}
			_refresh()
		"VIEW":
			_sheet.open_combat(_party_view(), 0, "view", _pick)
		"AIM":
			_start_aim()
		"USE":
			_start_use()
		"CAST":
			_start_cast()
		"TURN":
			_combat.turn_undead(_combat.active)
			_refresh()
			_advance()
		"QUICK":
			_combatants[_combat.active].quick = true
			Combat.set_record_quick(_combatants[_combat.active].who, true)   # kept for the next fight (0xAA38)
			_ai_timer.start(0.2)
		"DONE":
			_cmode = "done"
			_refresh()


## Lab (--keys quickall): the whole party on QUICK, as pressing Q at each member's turn.
func quick_all() -> void:
	if _combat == null:
		return
	# Combat Chat 21: a member already on QUICK has its own chain of steps running (between steps the timer
	# is stopped while a line shows); a second chain made it act twice and skipped the next figure's turn.
	var was_quick: bool = _combat.active >= 0 and _combatants[_combat.active].get("quick", false)
	for c in _combatants:
		if c.team == 0:
			c.quick = true
			Combat.set_record_quick(c.who, true)
	if _combat.active >= 0 and not was_quick and _ai_timer.is_stopped():
		_ai_timer.start(0.2)


## DONE's MAGIC item (SETTINGS: MAGIC ON DONE): its text shows the setting, the original's Alt-M.
func _magic_item() -> String:
	return "MAGIC:ON" if _combat != null and _combat.magic_on else "MAGIC:OFF"


## Alt-M in a computer turn or at the combat menu (and --keys magic in the lab): the party's
## QUICK members cast spells or not ("MAGIC ON" / "MAGIC OFF" on the bottom line; off at the
## start of each fight, GAME.OVR 0xE457).
func toggle_magic() -> void:
	if _combat == null:
		return
	_combat.magic_on = not _combat.magic_on
	_say("MAGIC ON" if _combat.magic_on else "MAGIC OFF")
