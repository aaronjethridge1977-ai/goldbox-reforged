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
var _view := Vector2i.ZERO       # top-left cell of the 7x7 window
var _facing := 0
var _morale_base := 99      # the encounter's morale (from the script)
## Set by the caller just before a scripted fight: ECL 0x6E70, 0x6E71, 0x6E72 (bytes, signed)
## (monsters' to-hit, the party's to-hit, the party's movement); see Combat.
var area_mods: Array[int] = [0, 0, 0]
var anti_magic := false                  # set by main before a fight: ECL 0x49E5 above 0 (the shell)
var _surprise := 0          # the script's ambush flag
var _px := 0
var _py := 0
var _distance := 0
var _mon_file := 1
var _monster_teams: Array[int] = []
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
var _panel_msgs := PackedStringArray()      # paced: the messages now on the right
var _pending_msgs := PackedStringArray()    # paced: still to be shown
var _row24_msg := ""
var _draining := false
var _muted := false
## P16 step 3: computer turns step by step (lab: the view's corner read from the battlefield
## record, DS:[0x6716] bytes 2-3, through a whole fight). GAME.OVR 0x30F0E keeps a cell in view:
## if it is more than `margin` from the view's centre on an axis, the centre moves onto it on
## that axis (centre column 3-46, row 3-21). A turn starts with the actor at margin 2; a computer-run step
## keeps the new cell in the 7x7 view (margin 3; GAME.OVR 0x12F0D: if it was off the view, the
## walker's own cell comes within 2 first), a step the player makes keeps it within 1; a
## hand-to-hand blow brings its target within 2 (0xB9F5: the cell beside the attacker toward it). Steps come
## about 0.15 s apart; a monster's first ~0.17 s after its turn starts, a QUICK member's after its
## menu has shown 0.4 s. "MOVE/ATTACK, MOVE LEFT = n" is on row 24 while a computer turn walks;
## the actor's grey box goes once it acts.
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
var _spell_hits: Array[int] = []   # figures the last spell reached, not yet shown
var _sparkle := -1                 # the figure showing a spell's sparkles
## A figure struck down stays standing through the blow's message; its fall shows COMSPR's
## skull (block 11) on its square while "GOES DOWN ..." is up, then the square is empty (lab:
## Bakshi and the orcs at speed 4, 0.8 s).
var _lingering: Array[int] = []
var _skulls: Array[int] = []    # a spell's missile, flown after its "CASTS A SPELL" (P16)
var _box_off := false
var _quick_menu := false
var _move_label := ""
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
		teams: Array[int] = []) -> void:
	open_test(game_path, map, px, py, facing, party, mon_file, null, false)
	_extra_monsters = extra
	_monster_teams = teams
	_event_fight = true
	_morale_base = morale_base
	_surprise = surprise
	_encounters = [{"monsters": rows, "text": ""}]
	_enc_index = 0
	var open_ahead := Placement.encounter_distance(_field, px, py, facing, 2)
	_distance = maxi(mini(open_ahead, max_distance) - advances, 0)
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


## Testing aid: the encounter's morale for the next fight.
func set_morale_base(value: int) -> void:
	_morale_base = value


## The monsters brought down in the fight just finished (for experience and treasure).
## Rounds fought (a minute of game time each).
func rounds() -> int:
	return _combat.round_no if _combat != null else 0


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
		var standing := []
		for m in _party:
			if m.can_fight():
				standing.append(m)
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
	if not _combatants.is_empty():
		var e: Dictionary = _combatants[_selected]
		var m: PartyMember = e.who
		g.text(23, 1, m.name.left(16), GameScreen.CYAN if e.team == 0 else GameScreen.YELLOW)
		g.text(23, 3, "HITPOINTS", GameScreen.GREEN)
		g.text(33, 3, str(m.hp), GameScreen.YELLOW if m.hp < m.hp_max else GameScreen.GREEN)
		g.text(23, 5, "AC %d" % m.ac, GameScreen.GREEN)
		if m.weapon:
			g.text(23, 7, m.weapon.name.to_upper().left(16), GameScreen.GREEN)
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
			lines.append([hit.left(16), names[hit]])
			rest = rest.substr(at + hit.length()).strip_edges()
	if _casting != "choose":
		for i in mini(lines.size(), 12):
			g.text(23, 10 + i, lines[i][0], lines[i][1])
	# Bottom lines.
	if _row24_msg != "":
		g.text(0, 24, _row24_msg, GameScreen.GREEN)
	elif _flash != "":
		g.text(0, 24, _flash, GameScreen.GREEN)
	elif _asking_ally:
		g.text(0, 23, "RANGE = %d" % _aim_range(), GameScreen.GREEN)
		g.text(0, 24, "ATTACK ALLY:", GameScreen.WHITE)
		g.menu_line(24, ["YES", "NO"], 13)
	elif _asking_continue:
		g.text(0, 24, "CONTINUE BATTLE:", GameScreen.WHITE)
		g.menu_line(24, ["YES", "NO"], 17)
	elif _combat != null and _result != 0:
		g.text(0, 24, ["", "THE PARTY WINS.", "THE PARTY HAS FALLEN.", "THE PARTY HAS FLED."][_result], GameScreen.WHITE)
	elif _combat != null and (_cmode == "aim" or _cmode == "manual"):
		g.text(0, 23, "RANGE = %d" % _aim_range(), GameScreen.GREEN)
		var prompt := "AIM:" if _cmode == "aim" else "(USE CURSOR KEYS)"
		g.text(0, 24, prompt, MAGENTA)
		var items := _bottom_menu()
		g.menu_line(24, items, prompt.length() + (0 if _cmode == "aim" else 1), _lit(items))
	elif paced() and _combat != null and _combat.active >= 0 and _combatants[_combat.active].get("quick", false):
		if _quick_menu:
			var items := _bottom_menu()
			g.menu_line(24, items, 0, _lit(items))
		elif _move_label != "":
			g.text(0, 24, _move_label, GameScreen.GREEN)
	elif _combat != null and _cmode == "speed":
		var prompt := "GAMESPEED (%d) :" % CampScreen.speed
		g.text(0, 24, prompt, MAGENTA)
		var items := _bottom_menu()
		g.menu_line(24, items, prompt.length() + 1, _lit(items))
	elif _combat != null and _combat.active >= 0 and not _combatants[_combat.active].get("quick", false):
		if _cmode == "move":
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
			for i in int(row[1]):
				if _monsters.size() >= 63:   # the original's limit
					break
				var m := first if i == 0 else first.clone()
				if i > 0:
					m.recalculate(_types)
				var k := _monsters.size()
				m.script_team = _monster_teams[k] if k < _monster_teams.size() else 0
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
	var side_list: Array = _party + allies
	var party_sizes := side_list.map(func(m): return Combat.foot_size(m))
	var party_cells := placer.place_team(side_list.size(), _facing, Vector2i.ZERO, true, party_sizes)
	var party_dir: int = Placement.FACING_TO_DIR[_facing]
	for i in _party.size():
		if party_cells[i].x < 0:
			continue
		# A member a script turned against the party (0x6C0C = 0x81) fights with the monsters.
		var side := 1 if _party[i].script_team == 0x81 else 0
		_combatants.append({"who": _party[i], "team": side, "cell": party_cells[i],
			"icon": _art.character_icon(_party[i]), "dir": party_dir, "pic": -1})
	for i in range(_party.size(), side_list.size()):
		if party_cells[i].x < 0:
			continue
		var k := _monsters.find(side_list[i])
		_combatants.append({"who": side_list[i], "team": 0, "cell": party_cells[i],
			"icon": _art.monster_icon(_mon_file, _pictures[k]) if _pictures[k] >= 0 else _art.character_icon(side_list[i]),
			"dir": party_dir, "pic": _pictures[k]})
	var ahead: Vector2i = Placement.SQUARE_STEP[_facing] * _distance
	var mon_sizes := foes.map(func(m): return Combat.foot_size(m))
	var mon_cells := placer.place_team(foes.size(), (_facing + 2) % 4, ahead, false, mon_sizes)
	for i in foes.size():
		if mon_cells[i].x < 0:
			continue
		var icon: Variant = _art.character_icon(foes[i]) if foe_pictures[i] < 0 \
			else _art.monster_icon(_mon_file, foe_pictures[i])
		_combatants.append({"who": foes[i], "team": 1, "cell": mon_cells[i],
			"icon": icon, "dir": (party_dir + 4) % 8, "pic": foe_pictures[i]})


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
	_field.scatter(func(n: int) -> int:
		return TpDice.random(n, "clutter") + 1 if TpDice.on else clutter_rng.randi_range(1, n))
	_place()
	if TpDice.on:
		for c in _combatants:
			TpDice.log.append("cell %s %d,%d" % [c.who.name, c.cell.x, c.cell.y])
		for y in Battlefield.HEIGHT:
			var row := PackedStringArray()
			for x in Battlefield.WIDTH:
				row.append("%02d" % _field.tile(x, y))
			TpDice.log.append("field %02d %s" % [y, " ".join(row)])
	_combat = Combat.new(_field, _combatants, seed_value)
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
	_row24_msg = ""
	_result = 0


var _asking_continue := false
## Chat 17: "ATTACK ALLY: YES NO" (GAME.OVR 0x15193, checked in the original): TARGET on a figure
## of the attacker's own side asks first; NO goes back to the aim. YES sets 0x6E33 (and 0x6DE2,
## not done here: ours reads 0x6DE2 as the temple flag) and turns every computer-run ally with
## morale over 127 against the party (record +0x10C = 0, +0x84 > 0x7F; +0x10E = 1). The lab:
## the player characters stay the player's.
var _asking_ally := false
var _ally_target := -1


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


## How long a combat message stays: game speed x 0.2 s, as the original.
static func message_hold() -> float:
	return CampScreen.speed * 0.2


func _on_combat_message(text: String) -> void:
	_on_message(text)
	if paced() and not _muted and not text.begins_with("ROUND "):
		_pending_msgs.append(text)
		if not _draining:
			# Start once the action has queued all its messages (a volley's later darts, the
			# missile's flight): shown at once, a dart's miss went up before its volley's hits
			# were known (Jeremy's P16 test, 2026-11-14).
			_draining = true
			_show_messages.call_deferred()


## A message that goes under the last one instead of replacing it.
func _continues(msg: String) -> bool:
	if _panel_msgs.is_empty():
		return false
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
		var who := _attacker(msg)
		if _skip_miss(msg, who):
			continue
		if who != "":
			_shown_by[who] = true
		var dying := msg == "YOUR TEAMMATE IS DYING"
		if not _continues(msg) and not dying:
			_panel_msgs.clear()
			_refresh()
			await get_tree().create_timer(MESSAGE_GAP).timeout
			if _flying:
				await flight_done
				await get_tree().create_timer(0.13).timeout
		if dying:
			_panel_msgs.clear()
			_row24_msg = msg
		else:
			_panel_msgs.append(msg)
			for k in _spell_hits:
				if (_combatants[k].who as PartyMember).name.to_upper() == who and not msg.contains(" ATTACKS "):
					_spell_hits.erase(k)
					_sparkle = k
					break
			if msg.contains("GOES DOWN") or msg.contains("IS KILLED") or msg.contains("FALLS DEAD"):
				for k in _lingering:
					if (_combatants[k].who as PartyMember).name.to_upper() == who:
						_lingering.erase(k)
						_skulls.append(k)
						break
		_refresh()
		if _sparkle >= 0:
			var until := Time.get_ticks_msec() + int(maxf(message_hold(), 1.2) * 1000.0)
			while Time.get_ticks_msec() < until and is_inside_tree():
				await get_tree().create_timer(0.066).timeout
				_refresh()
			_sparkle = -1
		else:
			await get_tree().create_timer(message_hold()).timeout
		if not _spell_flight.is_empty() and (msg.ends_with(" CASTS A SPELL") or msg.contains(" USES ")):
			var sf := _spell_flight
			_spell_flight = {}
			_panel_msgs.clear()
			_refresh()
			_fly(sf.from, sf.to, [5, 133], 240.0)
			await flight_done
		_row24_msg = ""
		if _pending_msgs.is_empty() or not _continues(_pending_msgs[0]):
			_panel_msgs.clear()
			_skulls.clear()
		_refresh()
	_draining = false
	_spell_hits.clear()
	_skulls.clear()
	_lingering.clear()
	if _posed >= 0:
		_posed = -1
		_refresh()
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
		_refresh()
		if _event_fight and _result == 1:
			# Straight on to the results (the original's "Continue Battle?" is skipped).
			await get_tree().create_timer(1.0).timeout
			if visible and _event_fight and _result == 1:
				_leave()
		return
	_selected = i
	_cmode = "menu"
	_aiming = false
	if paced():
		_ensure_view(_combatants[i].cell, 2)
		_box_off = false
		_move_label = ""
		_quick_menu = _combatants[i].get("quick", false) and _combatants[i].team == 0
	else:
		_centre_on_selected()
	_refresh()
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
		elif _quick_menu:
			# The original shows a QUICK member's menu a moment before it acts.
			await get_tree().create_timer(0.4).timeout
			_quick_menu = false
			if _combat != null and _combat.active == i:
				_refresh()
				_ai_timer.start(0.2)
		else:
			_ai_timer.start(0.17)


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
		_box_off = true
		if actor.cell != before:
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
		await get_tree().create_timer(0.2).timeout
		if _combat != null:
			_advance()


func _after_player_action(what: String) -> void:
	if _draining:
		await messages_shown
		if _combat == null:
			return
	if what == "blocked":
		_on_message("CAN'T GO THERE")
	elif what == "no moves":
		_on_message("NO MOVES LEFT")
	elif what == "fell":
		if _combatants[_selected].team == 0:
			_on_message("YOUR TEAMMATE IS DOWN")
	var c: Dictionary = _combatants[_selected]
	if _combat.outcome() != 0 or (c.moves <= 0 and c.attacks <= 0) or (what == "attacked" and c.attacks <= 0):
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
	others.sort_custom(func(a, b):
		var ra := _combat.range_of(_combatants[me], _combatants[a])
		var rb := _combat.range_of(_combatants[me], _combatants[b])
		if ra != rb:
			return ra < rb
		var fa: int = 0 if (_combatants[a].team != _combatants[me].team) == offensive else 1
		var fb: int = 0 if (_combatants[b].team != _combatants[me].team) == offensive else 1
		return fa < fb)
	_aim_list.append_array(others)
	_aiming = true
	_cmode = "aim"
	_aim_index = 0
	if purpose == "spell" and _aim_list.size() > 1:
		_aim_index = 1      # a spell aims at the nearest other figure first
	_show_aim()


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
	var items := ["MOVE", "VIEW", "AIM", "USE"]
	var c: Dictionary = _combatants[_combat.active]
	var who: PartyMember = c.who
	# CAST: not once the figure has been wounded this round (GAME.OVR 0x9F46, record byte 1).
	# Nor inside the anti-magic shell (0x9F59).
	if _combat.magic != null and not c.get("no_spells", false) and not _combat.anti_magic and \
			not _combat.magic.castable(_combat.active).is_empty():
		items.append("CAST")
	if Combat.turn_level(who) > 0:
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
	img.set_pixelv(at + Vector2i(CELL - 1, 0), Color8(0, 0, 0))
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
			_aiming = false
			_cmode = "menu"
			if _aim_for == "spell":
				_casting = ""
			_selected = _combat.active
			_centre_on_selected()
			_refresh()
		"TARGET":
			var me: int = _combat.active
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
	if (_combatants[me].who as PartyMember).weapon_ranged and not _combat.touching(_combatants[me], _combatants[j]):
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
		_fly(c.cell, _combatants[t].cell, frames, 720.0)


## A spell went off (paced): the caster's pose; for a spell aimed away from the caster, COMSPR's
## spark (5 / 133 by turns, ~240 px/s) flown to the aim after "CASTS A SPELL" (lab: Bakshi's
## Magic Missile and Sleep); each figure the spell reaches shows sparkles (9 / 137 by turns)
## while its message is up, at least 1.2 s (lab: Sleep, "FALLS ASLEEP"). Fireball's and
## Lightning's own pictures are not filmed yet.
func _on_spell_cast(i: int, id: int, cell: Vector2i, targets: Array) -> void:
	if not paced() or i < 0 or i >= _combatants.size():
		return
	_posed = i
	var to := cell
	if _combat.magic.aim_kind(id) == "pick" and not targets.is_empty():
		to = _combatants[targets[0]].cell
	if _combat.magic.aim_kind(id) != "self" and to != _combatants[i].cell:
		_spell_flight = {"from": _combatants[i].cell, "to": to}
	_spell_hits = []
	for t in targets:
		_spell_hits.append(int(t))


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


## A missile's flight from cell a to cell b (P16).
func _fly(a: Vector2i, b: Vector2i, frames: Array, speed: float) -> void:
	_flying = true
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
# figure, D when done picking), Esc aborts and the spell is kept.

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


func _begin_spell(id: int, item: GameItem) -> void:
	_spell_id = id
	_use_item = item
	_spell_picks = []
	if _combat.magic.aim_kind(_spell_id) == "self":
		_spell_cell = _combatants[_combat.active].cell
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
	if _combat.magic.aim_kind(_spell_id) == "area":
		_finish_cast()
		return
	var who := _combat.occupant(_aim_cell)
	if who < 0:
		_say("NO TARGET THERE")
	elif who in _spell_picks:
		_say("ALREADY BEEN TARGETED")
	else:
		_spell_picks.append(who)
		if _spell_picks.size() >= _combat.magic.max_picks(_spell_id):
			_finish_cast()


func _finish_cast() -> void:
	var me: int = _combat.active
	_casting = ""
	_aiming = false
	_cmode = "menu"
	_selected = me
	_combat.magic.cast(me, _spell_id, _spell_cell, _spell_picks, _use_item)
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


var _tint: Image = null


func _refresh() -> void:
	if _tint == null:
		_tint = Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
		_tint.fill(Color(1.0, 0.45, 0.1, 0.45))
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
		if _combat.magic.aim_kind(_spell_id) == "area":
			cells = _combat.magic.area_cells(_combat.active, _spell_id, _spell_cell)
		for p in cells:
			var at := (p - _view) * CELL
			if at.x >= 0 and at.y >= 0 and at.x < size and at.y < size:
				img.blend_rect(_tint, Rect2i(0, 0, CELL, CELL), at)
		var cur := (_spell_cell - _view) * CELL
		if cur.x >= 0 and cur.y >= 0 and cur.x < size and cur.y < size:
			for k in CELL:
				for edge in [Vector2i(k, 0), Vector2i(k, CELL - 1), Vector2i(0, k), Vector2i(CELL - 1, k)]:
					img.set_pixelv(cur + edge, Color8(255, 255, 85))
	if _cmode == "manual":
		var mc := (_aim_cell - _view) * CELL
		if mc.x >= 0 and mc.y >= 0 and mc.x < size and mc.y < size:
			_bevel(img, mc)
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
		if i == _selected and _cmode != "manual" and not (_box_off and e.get("quick", false)):
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
		var sp := _art.sprite(9 if (Time.get_ticks_msec() / 133) % 2 == 0 else 137)
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
	if _asking_ally:
		if key == KEY_Y or key == KEY_N:
			get_viewport().set_input_as_handled()
			if key == KEY_N:
				_asking_ally = false
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
			_attack_aimed(_ally_target)
		return
	if _aiming:
		_aim_input(event, key)
		get_viewport().set_input_as_handled()
		return
	if _asking_continue:
		if key == KEY_Y or key == KEY_N:
			_asking_continue = false
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
			get_viewport().set_input_as_handled()
			for c in _combatants:
				var w: PartyMember = c.who
				if c.team == 0 and not (w.npc >= 128 or w.script_team == 0x80):
					c.quick = false
			return
	if _event_fight and _result == 0 and _combat != null:
		_fight_input(event, key)
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
	_combat = null
	_event_fight = false
	anti_magic = false
	CharacterSheet.anti_magic = false    # outside fights main sets it (the shell's USE, 0x21FD6)
	visible = false
	if was_event:
		finished.emit(result)
	else:
		closed.emit()


const _STEP_KEYS := {KEY_UP: 0, KEY_KP_8: 0, KEY_PAGEUP: 1, KEY_KP_9: 1, KEY_RIGHT: 2, KEY_KP_6: 2,
	KEY_PAGEDOWN: 3, KEY_KP_3: 3, KEY_DOWN: 4, KEY_KP_2: 4, KEY_END: 5, KEY_KP_1: 5,
	KEY_LEFT: 6, KEY_KP_4: 6, KEY_HOME: 7, KEY_KP_7: 7}


func _fight_input(event: InputEvent, key: Key) -> void:
	get_viewport().set_input_as_handled()
	if _draining or _result != 0 or _combat.active < 0 or _combatants[_combat.active].get("quick", false):
		return
	if _cmode == "move":
		if event.is_action("ui_cancel"):
			_cmode = "menu"
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
			_note_falls(up_before)
			if paced() and what != "moved":
				_after_blow(me, shown_before, weapon_before)
			_after_player_action(what)
			if _cmode == "move" and _combat.active == _selected and _combatants[_selected].moves <= 0:
				_cmode = "menu"
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
		return
	var items := _bottom_menu()
	var choice := _menu_choice(event, key, items)
	if choice == "" and _cmode in ["done", "speed"] and event.is_action("ui_cancel"):
		choice = "EXIT"
	if choice == "":
		return
	_pick = items.find(choice)
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
			_cmode = "move"
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
			_ai_timer.start(0.2)
		"DONE":
			_cmode = "done"
			_refresh()


## Lab (--keys quickall): the whole party on QUICK, as pressing Q at each member's turn.
func quick_all() -> void:
	if _combat == null:
		return
	for c in _combatants:
		if c.team == 0:
			c.quick = true
	if _combat.active >= 0 and _ai_timer.is_stopped():
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
