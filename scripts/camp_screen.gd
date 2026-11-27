class_name CampScreen
extends Control
## Encamp, as the original shows it (Jeremy, 2026-11-12: every screen matches the original).
##
## Screens and keys from the lab (chat 10, save F, New Phlan 14,5):
##   CAMP: the adventure screen with the camp's fire (PIC 29, animated: frame 0, then frame 0
##     XOR frame 1, every 2 units of about 0.11 s), the party list (Home/End: who), the place
##     line ending "CAMPING", "THE PARTY MAKES CAMP..." (row 18), "CAMP:" (magenta) then
##     SAVE VIEW MAGIC REST ALTER EXIT. A chosen item's place carries over to the next menu.
##     Esc is EXIT in every menu.
##   SAVE: "SAVE WHICH GAME:" A to J, written in the original's own format (OriginalSave),
##     then "QUIT TO DOS" (yellow) YES NO with NO lit.
##   REST: "REST TIME: DD:HH:MM" (row 17, the field being set white), REST DAYS HOURS MINS
##     INC DEC EXIT at fixed columns (DAYS's hot key is Y). Y/H/M pick the field, Left/Right
##     too; INC/DEC add or take a day, an hour or 5 minutes (never below 0). While resting the
##     time counts down; when it's done the camp menu comes back with the clock moved on.
##     Interrupted: "THE PARTY IS RUDELY INTERRUPTED!" (white, row 19), then the area's
##     "rest interrupted" script (an encounter).
##   MAGIC: CAST MEMORIZE SCRIBE DISPLAY REST EXIT (no label). MEMORIZE and CAST open a page
##     (ropes at rows 0, 2, 23; "<NAME>'S" cyan and "SPELLS IN SPELL BOOK"/"SPELLS IN MEMORY"
##     green on row 1), the level in magenta at row 5, spells at column 3, the chosen one
##     white (Home/End), starting on the page's last spell; "CHOOSE SPELL:" then MEMORIZE
##     [NEXT] EXIT or CAST EXIT. MEMORIZE adds a rope at row 16 and "<NAME>" / "CAN MEMORIZE:"
##     / "    CLERIC SPELLS: n" / "MAGIC-USER SPELLS: n" below it. Leaving with spells chosen
##     shows "SPELLS TO BE MEMORIZED" ("*SLEEP" at column 2) with EXIT, then "MEMORIZE THESE
##     SPELLS?" (yellow) YES NO with NO lit. A character who can't memorize or cast: nothing
##     happens. CAST on a member: "CAST SPELL ON WHOM" SELECT EXIT on the adventure screen,
##     then "<NAME>" / "IS FULLY HEALED" there, and the spell list again.
##     CAST, more from the lab (chat 22, saves J and F at New Phlan 14,5), the same in camp and
##     from the adventure menu: a member with nothing memorized: "<NAME>" / "HAS NO SPELLS
##     MEMORIZED" (rows 18-19) for a moment, the menu unchanged. On the list page, with a
##     rope at row 16 and no spell lit: a combat-only spell: "<SPELL>" / "IS A COMBAT-ONLY
##     SPELL..." (green, rows 19-20), "LOSE IT?" (magenta) YES NO with YES lit, either answer
##     back to the list; a spell for the caster or the party: "<NAME>" (cyan) "CASTS" /
##     "<SPELL>" (rows 19-20), then each target's "<NAME>" / "IS SHIELDED" (rows 18-19) a
##     moment each, then the list without it. A member spell shows no CASTS line.
##     From the adventure menu (open_cast) the list opens at once; EXIT, or the last spell
##     cast, goes back to the adventure menu; the clock doesn't move.
##     DISPLAY: "DISPLAY" (white, column 16, row 1), each member (cyan) from row 5, three rows
##     apart, the spell effects under them (column 2), EXIT.
##   ALTER: ORDER DROP SPEED ICON PICS EXIT.
##     ORDER: "PARTY ORDER:" SELECT EXIT; SELECT: "<NAME>" / "HAS BEEN SELECTED", PLACE EXIT,
##       and Home/End carry the selected member up and down the party.
##     DROP: "<NAME>" / "WILL BE GONE", "DROP FROM PARTY?" (yellow) YES NO with NO lit; NO:
##       the message area cleared, nothing said (main chat 87, DOSBox).
##     SPEED: "GAME SPEED = n (0=FASTEST 9=SLOWEST)", "GAME SPEED:" FASTER SLOWER EXIT (4 at
##       the start).
##     ICON: the icon editor. PICS: "MONSTERS ON  PORTRAITS ON  EXIT", M and P switch them.
## Not yet seen in the original (drawn the same way as the rest, to check): the heal message
## while resting, SCRIBE's list, "CAN'T BE CAST HERE". The memorized messages are read from
## its code (P35, _show_held).
##
## Rules (as documented by Pilgrim's reconstruction, checked in the lab: save J rested 24
## hours in the Slums' "dirty room" and Bakshi and Phineas each went from 4 to 5 HP):
## - Resting runs in 5-minute steps. Every 288 steps (24 hours) spent in this camp, everyone
##   not dead gains 1 HP; an unconscious character wakes with it. The count starts again
##   each time the party makes camp.
## - The area's "on rest" script sets how often rest may be interrupted: every `period`
##   steps, a d100 roll of `percent` or less ends it.
## - REST offers the time the party needs to memorize the spells picked under MAGIC (see
##   PartyMember "Spells"); while resting they are memorized one by one, then scrolls marked
##   under SCRIBE are copied into the spell book, 15 minutes a level.
## The game clock runs while resting (GameClock); the caller adds the minutes rested.

signal closed
signal save_requested(letter: String)
signal interrupted          # the area's "rest interrupted" script should run now
signal time_passed(minutes: int)   # a rest is done: the caller moves the clock on
signal start_memorized             # START MEMORIZED: every caster has had the MEMORIZE page

const STEPS_PER_HEAL := 288
## Steps shown per timer tick (REST_TICK s): a day about 0.2 s, as the original's (main chat 127's request 4; Combat Chat 58,
## DOSBox at speed 4, 3 days: 02:07:20 0.05 s in, a day in about 0.2 s, then THE WHOLE PARTY IS HEALED's Delay; the
## step loop itself has no wait at any game speed). Ours took 1.2 s a day: a key typed 0.3 s in stopped 6 hours in.
const STEPS_PER_TICK := 24
const REST_TICK := 1.0 / 60.0
const ANIM_UNIT := 0.11     # seconds per unit of a picture frame's delay (lab: 2 units, 0.22 s)
const MAGENTA := 13
const PROMPT := 14          # yellow

const CAMP_MENU := ["SAVE", "VIEW", "MAGIC", "REST", "ALTER", "EXIT"]
const CAMP_MENU_FIX := ["SAVE", "VIEW", "MAGIC", "REST", "ALTER", "FIX", "EXIT"]
const MAGIC_MENU := ["CAST", "MEMORIZE", "SCRIBE", "DISPLAY", "REST", "EXIT"]
const ALTER_MENU := ["ORDER", "DROP", "SPEED", "ICON", "PICS", "EXIT"]
const SAVE_LETTERS := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
## The rest menu: [text, column, hot letter's place in the text].
const REST_MENU := [["REST", 0, 0], ["DAYS", 7, 2], ["HOURS", 12, 0], ["MINS", 18, 0],
	["INC", 25, 0], ["DEC", 29, 0], ["EXIT", 35, 0]]
const YES_NO := ["YES", "NO"]
const LEVEL_WORDS := ["1ST LEVEL", "2ND LEVEL", "3RD LEVEL", "4TH LEVEL", "5TH LEVEL"]
const LIST_TOP := 5
const DISPLAY_PAGE := 17              # DISPLAY's rows 5-21
## The effects DISPLAY names by their spell (GAME.OVR 0x1888D-0x188E6) and the ones it names itself (0x18979-0x18ACB).
const DISPLAY_SPELL_FX := [1, 2, 5, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 20, 21, 22, 23, 24, 25, 28, 29, 32, 33, 34,
	36, 37, 38, 39, 41, 42, 45, 46, 49, 51, 52, 53]
const DISPLAY_NAMES := {0x04: "STUDYING MANUAL OF BODILY HEALTH", 0x07: "TRAINING WITH MANUAL OF BODILY HEALTH",
	0x1B: "FEATHER FALL", 0x1F: "HELPLESS", 0x23: "PRAYER", 0x2C: "CAUSE DISEASE", 0x32: "DREADED MUMMY DISEASE",
	0x36: "REPULSED", 0x37: "POISONED", 0x3B: "REGENERATING", 0x3D: "FIRE RESISTANCE", 0x47: "INVISIBLE",
	0x48: "CAMOUFLAGED", 0x59: "DISPLACED"}

var _party: Array[PartyMember] = []
var _period := 0
var _percent := 0
var _rest_steps := 0        # 5-minute steps rested in this camp (for healing)
var _since_check := 0       # steps since the last interruption check
var _to_rest := 0           # 5-minute steps still to rest
var _field := 2             # 0 days, 1 hours, 2 minutes
var _resting := false
var _rng := RandomNumberGenerator.new()
var minutes_passed := 0     # minutes rested and not yet handed to the caller's clock
var place := ""             # the place line (the caller's), without "CAMPING"

var _scr: GameScreen
var _note := Label.new()    # what's said, for the bot's log
var _lines: Array = []      # the text box: [[text, colour], ...] from row 17
var _timer: Timer
var _anim: Timer
var _fire: Array[Image] = []
var _fire_delays: Array[int] = []
var _fire_frame := 0
var _sheet: CharacterSheet

var spells: SpellTable = null      # set by the game before opening
## The anti-magic shell (ECL 0x49E5 above 0, the ruined castle's): set by main before opening.
var anti_magic := false
var _sel := 0                      # selected character
var _mode := "camp"   # camp save rest magic list pending confirm whom display alter order drop speed pics ask
## The lit word: the highlight every horizontal menu shares (GAME.OVR 0x2CC8C's DS:0x6B2B, EclVM.menu_hl; main chat
## 122, Combat Chat 55): what a menu here leaves lit, the next menu anywhere lights, and the other way round.
var _pick: int:
	get:
		return EclVM.menu_hl
	set(v):
		EclVM.menu_hl = v
var _list_kind := ""               # memorize, cast, scribe
var _list: Array = []              # rows: [text, spell id or 0 for a heading]
var _cursor := 0
var _top := 0                      # the list's first row on the screen (a page, or the last page's overlap)
var _display_top := 0              # DISPLAY's first row on the screen
var _cast_id := 0
var _caster: PartyMember = null    # while choosing whom a spell is cast on
## CAST SPELL ON WHOM starts on the last target picked since MAGIC was opened (chat 83, DOSBox: LIRA's ENLARGE on
## CEDRIC, then REDUCE: the light starts on CEDRIC; the camp menu after EXIT has LIRA lit).
var _last_target: PartyMember = null
var _rng2 := RandomNumberGenerator.new()
var _hour_steps := 0
var _ordering := -1                # ORDER: the member being moved, or -1
## The original prints some messages (a member's name and what happened, the game speed) with
## a routine that redraws the rope under the view without its knot at column 16; the knot
## comes back when the whole screen is drawn again (lab: ORDER, DROP, SPEED, a cast's result;
## not "THE PARTY MAKES CAMP..." or "RUDELY INTERRUPTED").
var _plain_rope := false
## ALTER's SPEED: 0 fastest .. 9 slowest; scales the pause after each message. 1 when the program
## starts (GAME.OVR 0xE999); a loaded game brings its own (main.gd SPEED_CELL).
static var speed := 1
## ALTER's PICS.
static var show_monsters := true
static var show_portraits := true
var _icon_editor: IconEditor
var _scrolls: Array = []          # SCRIBE list: [item, record byte, spell id]
var _learn_timer := {}             # member -> steps until its next spell is memorized
## START MEMORIZED (QoL, Jeremy's P12): at BEGIN ADVENTURING each caster with free slots gets
## MEMORIZE's page; what's picked is memorized at once, with no rest and no time passing.
var _start_queue: Array = []       # members still to be offered the page
var _starting := false
var _walk := false                 # CAST from the adventure menu (open_cast): no camp
var _walk_menu: Array = []         # the adventure menu, shown under "HAS NO SPELLS MEMORIZED"


## The pause after a message, as a factor of the normal one (speed 4).
static func delay_scale() -> float:
	return (speed + 1) / 5.0


## P104 (Jeremy, QoL; Q39 on 2026-11-24: A): the screens' own text pauses (a camp spell's result lines, USES AN ITEM and
## a potion's or scroll's result lines, the ID answer, the hall's notes) run at the pace of the original's game speed 4
## whatever SETTINGS says, as a script's text does (main.gd TEXT_SPEED): text stays readable. No switch.
const TEXT_SPEED := 4


## P104 (Lead, 2026-11-24, after Q39: one rule everywhere, a line meant to be read is held at speed 4's pace): the
## rest's notes, the camp's refusals and HAS NO SPELLS MEMORIZED, the hall's and the shop's notes too. delay_scale's
## factor at TEXT_SPEED.
static func text_scale() -> float:
	return (TEXT_SPEED + 1) / 5.0


func _init() -> void:
	_note.visible = false
	add_child(_note)


func open(party: Array[PartyMember], period: int, percent: int) -> void:
	_party = party
	_last_target = null
	_period = period
	_percent = percent
	_rest_steps = 0
	_to_rest = 0                 # (_since_check carries over, as the original's 0x49FB)
	_resting = false
	_sel = clampi(_sel, 0, maxi(party.size() - 1, 0))
	_rng2.randomize()
	minutes_passed = 0
	_rng.randomize()
	if _scr == null:
		_build()
	_mode = "camp"
	_walk = false
	_plain_rope = false
	_pick = 3                    # carried over from ENCAMP (lab: REST lit)
	Rememorize.note_camp(party)
	_say_lines([["", GameScreen.GREEN], ["THE PARTY MAKES CAMP...", GameScreen.GREEN]])
	visible = true
	_anim.start(_fire_delay(0))
	_refresh()


## CAST from the adventure menu: the selected member's spells in memory at once, on the
## adventure screen (no fire, no CAMPING); `closed` when it's left.
func open_cast(party: Array[PartyMember], sel: int, walk_menu: Array) -> void:
	_party = party
	if _scr == null:
		_build()
	_sel = clampi(sel, 0, maxi(party.size() - 1, 0))
	_walk = true
	_walk_menu = walk_menu
	_last_target = null     # main chat 133 (DOSBox, check 499): the adventure menu's CAST lights the caster again
	_starting = false
	_plain_rope = false
	_lines = []
	_mode = "walk"
	_pick = 0
	minutes_passed = 0
	visible = true
	_open_list("cast")
	if _mode == "walk" and _lines.is_empty():
		_close_walk()          # someone who can't cast: nothing happens
	else:
		_refresh()


func _close_walk() -> void:
	_walk = false
	_lines = []
	visible = false
	closed.emit()


## START MEMORIZED: offers MEMORIZE's page to each caster in `party` with free slots. Returns
## false (and shows nothing) when nobody can memorize; otherwise `start_memorized` follows.
func open_start_memorize(party: Array[PartyMember], table: SpellTable) -> bool:
	_party = party
	spells = table
	_start_queue = []
	for m in party:
		if m.status == PartyMember.STATUS_OKAY and _can_learn(m):
			_start_queue.append(m)
	if _start_queue.is_empty():
		return false
	if _scr == null:
		_build()
	_starting = true
	_plain_rope = false
	visible = true
	_next_starter()
	return true


## Whether `m` has a free slot for a spell in its book (cleric and magic-user, levels 1-3).
func _can_learn(m: PartyMember) -> bool:
	for id in range(1, SpellTable.NAMED + 1):
		if m.knows(id) and spells.spell_class(id) <= 1 and spells.level(id) <= 3 \
				and m.slots_left(spells, spells.spell_class(id), spells.level(id)) > 0:
			return true
	return false


func _next_starter() -> void:
	while not _start_queue.is_empty():
		var m: PartyMember = _start_queue.pop_front()
		_sel = _party.find(m)
		_mode = ""
		_open_list("memorize")
		if _mode == "list":
			return
	_starting = false
	visible = false
	start_memorized.emit()


## The spells being memorized are memorized now (START MEMORIZED).
static func learn_at_once(m: PartyMember) -> void:
	for i in m.memorized.size():
		m.memorized[i] = m.memorized[i] % PartyMember.LEARNING
	m.learn_hours = 0


func _build() -> void:
	ShopScreen._fill(self, 0)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	ShopScreen._fill(bg, 0)
	add_child(bg)
	_scr = GameScreen.new()
	add_child(_scr)
	var dax := DaxFile.open(GameData.find_game_path().path_join("PIC1.DAX"))
	if dax != null and dax.blocks.has(29):
		_fire = EgaPicture.xor_frames(dax.blocks[29])
		var pic := EgaPicture.decode_animated(dax.blocks[29])
		if pic != null:
			_fire_delays = pic.delays
	_timer = Timer.new()
	_timer.wait_time = REST_TICK
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_anim = Timer.new()
	_anim.one_shot = true
	_anim.timeout.connect(_next_fire)
	add_child(_anim)
	_sheet = CharacterSheet.new()
	_sheet.visible = false
	_sheet.visibility_changed.connect(func() -> void:
		if not _sheet.visible and visible:
			_refresh())
	add_child(_sheet)


func _fire_delay(i: int) -> float:
	var d: int = _fire_delays[i] if i < _fire_delays.size() else 2
	return maxf(d, 1) * ANIM_UNIT


## The original turns the fire's frames only inside its menu routine (GAME.OVR 0x2CD72-0x2CDFC), and only for a
## menu whose caller asks for it (argument +0x0A: the camp's, MAGIC's, ALTER's and its ORDER, SPEED and PICS,
## SAVE WHICH GAME in camp, START.EXE's member picks in camp; not REST's 0x24535, the YES / NO questions' 0x2D9EA
## or the lists' 0x2D8AC) or while script cell 0x4AFF is not 0; then a frame per pass, its delay not waited. A SAVE
## writes slot 3's number, 0xFFFF, there (0x1FEC2) and the menu's return clears it (0x2CFAD): after a save QUIT TO
## DOS flickers the fire, after Esc at SAVE WHICH GAME it stands. Main chat 158, DOSBox at 3:0's camp (DS:0x6ABF
## watched): REST's menu, DROP FROM PARTY? and QUIT TO DOS stood; after a save 0.12 s a frame; elsewhere 0.22 s.
const FIRE_STILL := ["rest", "quit", "drop", "ask", "shown", "stop_ask"]
const FIRE_FAST := 0.12     # a pass of the menu loop (DOSBox) when 0x4AFF is set
var _fire_fast := false


func _next_fire() -> void:
	if not visible or _fire.is_empty():
		return
	if _mode == "quit" and _fire_fast:
		_fire_frame = (_fire_frame + 1) % _fire.size()
		_anim.start(FIRE_FAST)
	elif _mode in FIRE_STILL:
		_anim.start(_fire_delay(_fire_frame))
		return
	else:
		_fire_frame = (_fire_frame + 1) % _fire.size()
		_anim.start(_fire_delay(_fire_frame))
	if _mode in ["camp", "save", "quit", "magic", "whom", "alter", "order", "speed", "pics"]:
		_refresh()


## For the bot's log: what the camp shows.
func state_text() -> String:
	return "CAMP %s | %s | %s" % [_mode, " / ".join(_party.map(func(m): return "%s %d" % [m.name, m.hp])), _note.text]


# --- START MEMORIZED setting (QoL) --------------------------------------------------------------

const START_MEMORIZED_KEY := "start_memorized"


## SETTINGS: START MEMORIZED ON (an addition, on unless turned off) or OFF (as the original:
## nothing memorized at the start; rest in camp to memorize).
static func start_memorized_on() -> bool:
	var c := ConfigFile.new()
	if c.load(GameData.SETTINGS_PATH) != OK:
		return true
	return bool(c.get_value("qol", START_MEMORIZED_KEY, true))


# --- FIX (QoL, P42; Jeremy 2026-11-14: an exception to the QoL pause) -----------------------------
# The sequels' FIX (Curse of the Azure Bonds on): one press is one rest just long enough for the
# party's clerics to cast and memorize again their first-level spells as Cure Light Wounds, then
# everyone is healed by those cures. Rules as Pilgrim's reconstruction reads them (fix_menu,
# format documentation only) and checked in DOSBox with Jeremy's own Curse of the Azure Bonds
# (Combat Chat 2: two FIXes of 5:15 each, 315 minutes = 240 + 5 slots x 15; the cures' total
# went to the hurt in party order, the first one first):
# - nothing when no one is hurt;
# - the cures already memorized by living, conscious members roll now (1d8 each, kept);
# - the rest: for each living, conscious member with first-level cleric slots, 4 hours plus
#   15 minutes a slot; the longest one; shortened by the whole number of times 27 HP a
#   healer exceeds the HP missing; it is a normal rest (spells memorized, may be interrupted);
# - unless interrupted: every first-level slot of those healers rolls 1d8 more, and the total
#   goes to the hurt in party order, each up to their maximum (dying -> unconscious).
# Press FIX again for another round. Curse of the Azure Bonds' Cure Serious / Critical Wounds
# don't exist in Pool of Radiance (cleric spells stop at the third level).

const FIX_KEY := "fix"


static func fix_on() -> bool:
	var c := ConfigFile.new()
	if c.load(GameData.SETTINGS_PATH) != OK:
		return true
	return bool(c.get_value("qol", FIX_KEY, true))


static func save_fix(on: bool) -> void:
	var c := ConfigFile.new()
	c.load(GameData.SETTINGS_PATH)
	c.set_value("qol", FIX_KEY, on)
	c.save(GameData.SETTINGS_PATH)


## The camp menu: the original's, with FIX before EXIT when the setting is on (the sequels'
## menu, "CAMP:" then the items with no space: 40 columns).
func _camp_menu() -> Array:
	return CAMP_MENU_FIX if fix_on() else CAMP_MENU


var _fixing := false       # the rest under way is a FIX
var _fix_pool := 0         # the cures rolled so far
var _fix_slots := 0        # first-level cleric slots of the healers (rolled after the rest)


static func _hp_lost(party: Array) -> int:
	var n := 0
	for m in party:
		n += maxi(m.hp_max - m.hp, 0)
	return n


func _fix() -> void:
	var lost := _hp_lost(_party)
	if lost == 0:
		return
	_fix_pool = 0
	_fix_slots = 0
	var most := 0
	var can := 0
	for m in _party:
		if m.status != PartyMember.STATUS_OKAY:
			continue
		for s in m.memorized:
			if s == 3:          # Cure Light Wounds, memorized
				_fix_pool += _rng.randi_range(1, 8)
		var slots: int = m.spell_slots[0][0]
		_fix_slots += slots
		if slots > 0:
			most = maxi(most, 240 + slots * 15)
			can += 27
	if can > lost:
		most /= can / lost
	# P75 (Jeremy: after FIX he had to REST): with REST REMEMORIZES on, FIX's rest is a rest as the
	# sequels' is: the plan's spells cast since go back in, and the rest lasts as long as they take.
	if spells != null and Rememorize.refill(_party, spells) > 0:
		for m in _party:
			if m.status == PartyMember.STATUS_OKAY:
				most = maxi(most, m.learn_minutes(spells))
	if most < 5:
		_fix_heal()
		return
	_fixing = true
	_rest_back = "camp"
	_to_rest = (most + 4) / 5
	_start_rest()


func _fix_heal() -> void:
	for k in _fix_slots:
		_fix_pool += _rng.randi_range(1, 8)
	_fix_slots = 0
	for m in _party:
		if _fix_pool <= 0:
			break
		if not m.status in [PartyMember.STATUS_OKAY, PartyMember.STATUS_UNCONSCIOUS, PartyMember.STATUS_DYING]:
			continue
		var want := mini(m.hp_max - m.hp, _fix_pool)
		if want <= 0:
			continue
		# As a cure spell heals (SpellCaster._heal: GAME.OVR 0x2C647): a member back above 0 HP is up again
		# (P82, Jeremy: after FIX, full HP but the names still red), and the diseased aren't healed.
		if not SpellCaster._heal(m, want):
			continue
		_fix_pool -= want
	_fix_pool = 0


static func save_start_memorized(on: bool) -> void:
	var c := ConfigFile.new()
	c.load(GameData.SETTINGS_PATH)
	c.set_value("qol", START_MEMORIZED_KEY, on)
	c.save(GameData.SETTINGS_PATH)


# --- Drawing ------------------------------------------------------------------------------

func _say_lines(lines: Array) -> void:
	_lines = lines
	var t := PackedStringArray()
	for l in lines:
		if l[0] != "":
			t.append(l[0])
	_note.text = " ".join(t)


## "<NAME>" (cyan, row 18) and the message under it (green, row 19), as the original says
## what happened to someone.
func _say_name(name: String, message: String) -> void:
	_plain_rope = true
	_say_lines([["", GameScreen.GREEN], [name, GameScreen.CYAN], [message, GameScreen.GREEN]])


## A message line by line from row 18 (a member's name first, cyan, on its own line).
func _say(text: String) -> void:
	for m in _party:
		if text.begins_with(m.name + " "):
			_say_name(m.name, text.substr(m.name.length() + 1))
			return
	var lines: Array = [["", GameScreen.GREEN]]
	for w in PrintWrap.lines(text, 38):
		lines.append([w, GameScreen.GREEN])
	_say_lines(lines)


func _refresh() -> void:
	if _scr == null or not visible:
		return
	match _mode:
		"list", "pending", "confirm", "ask", "casting":
			_draw_list()
		"display":
			_draw_display()
		_:
			_draw_walk()
	_scr.update()


## The member lit in the party list: none while CAST SPELL ON WHOM has its light off (main chat 93).
func _lit_member() -> int:
	return -1 if _mode == "whom" and _whom_off != 0 else _sel


func _draw_walk() -> void:
	Automap.mini_shown = _walk and Automap.mini_shown     # no mini-map over the camp: its place line is whole
	if _walk:
		_scr.draw_walk(OverlayLook.last_view, _party, _lit_member(), OverlayLook.last_place, PackedStringArray(), [],
			OverlayLook.last_wild, OverlayLook.last_overland)
	else:
		var view: Image = _fire[_fire_frame] if not _fire.is_empty() else OverlayLook.last_view
		_scr.draw_walk(view, _party, _lit_member(), (place + " CAMPING").strip_edges(), PackedStringArray(), [])
		OverlayLook.camp_view = view
		OverlayLook.camp_place = (place + " CAMPING").strip_edges()
	if _plain_rope:
		_scr.tile(16, 16, 22)
	_draw_lines()
	match _mode:
		"walk":
			_scr.menu_line(24, _walk_menu, 0, EclVM.menu_lit(_walk_menu.size()))
		"camp":
			_labelled("CAMP:", _camp_menu(), 5 if fix_on() else 6)
		"save":
			_scr.text(0, 24, "SAVE WHICH GAME:", MAGENTA)
			_scr.menu_line(24, SAVE_LETTERS, 17, -1)
		"rest":
			_draw_rest()
		"stop_ask":
			# Row 24 cleared first: STOP RESTING? YES NO alone (main chat 127, DOSBox data/c127/rk_x.png; ours drew it
			# over the rest menu's words, whose glyphs a space doesn't erase).
			_draw_rest(false)
			_scr.text(0, 24, "STOP RESTING?", MAGENTA)
			_scr.menu_line(24, YES_NO, 14, EclVM.menu_lit(YES_NO.size()))
		"magic":
			_scr.menu_line(24, MAGIC_MENU, 0, EclVM.menu_lit(MAGIC_MENU.size()))
		"whom", "shown":
			_labelled("CAST SPELL ON WHOM", ["SELECT", "EXIT"], 19)
		"alter":
			_labelled("ALTER:", ALTER_MENU, 7)
		"order":
			_labelled("PARTY ORDER:", ["PLACE" if _ordering >= 0 else "SELECT", "EXIT"], 13)
		"drop":
			_scr.text(0, 24, "DROP FROM PARTY?", PROMPT)
			_scr.menu_line(24, YES_NO, 17, EclVM.menu_lit(YES_NO.size()))
		"speed":
			_labelled("GAME SPEED:", _speed_menu(), 12)
		"pics":
			var items := ["MONSTERS " + ("ON" if show_monsters else "OFF"),
				"PORTRAITS " + ("ON" if show_portraits else "OFF"), "EXIT"]
			var col := 0
			for i in items.size():
				_scr.menu_line(24, [items[i]], col, 0 if i == EclVM.menu_lit(items.size()) else -1)
				col += items[i].length() + 2
		"quit":
			_scr.text(0, 24, "QUIT TO DOS", PROMPT)
			_scr.menu_line(24, YES_NO, 12, EclVM.menu_lit(YES_NO.size()))



## The text box from row 17; a line "<NAME> CASTS" has the name cyan, as has a line with a
## third value (the length of a cyan name at its start; P35).
func _draw_lines() -> void:
	for i in mini(_lines.size(), 6):
		var t: String = _lines[i][0]
		_scr.text(1, 17 + i, t, _lines[i][1])
		if _lines[i].size() > 2:
			_scr.text(1, 17 + i, t.left(int(_lines[i][2])), GameScreen.CYAN)
		if t.ends_with(" CASTS"):
			_scr.text(1, 17 + i, t.trim_suffix(" CASTS"), GameScreen.CYAN)


func _labelled(label: String, items: Array, col: int) -> void:
	_scr.text(0, 24, label, MAGENTA)
	_scr.menu_line(24, items, col, EclVM.menu_lit(items.size()))


func _draw_rest(with_menu := true) -> void:
	var minutes := _to_rest * 5
	var parts := [minutes / 1440, (minutes / 60) % 24, minutes % 60]
	_scr.text(1, 17, "REST TIME:", GameScreen.GREEN)
	for i in 3:
		var lit := i == _field and not _resting
		_scr.text(12 + 3 * i, 17, "%02d" % parts[i], GameScreen.WHITE if lit else GameScreen.GREEN)
		if i < 2:
			_scr.text(14 + 3 * i, 17, ":", GameScreen.GREEN)
	for i in (REST_MENU.size() if with_menu else 0):
		var it: Array = REST_MENU[i]
		var s: String = it[0]
		var hot: int = it[2]
		for k in s.length():
			var white: bool = k >= hot if i == EclVM.menu_lit(REST_MENU.size()) else k == hot
			if _resting and k == 0:
				white = true     # lab: while resting DAYS shows its D lit as well as its Y
			_scr.text(it[1] + k, 24, s[k], GameScreen.WHITE if white else GameScreen.GREEN)


## The page of the spell lists (and DISPLAY): ropes across at rows 0, 2 (and 16), 23.
func _page_frame(ropes: Array) -> void:
	_scr.clear()
	for r in ropes:
		for c in 40:
			_scr.tile(c, r, 22)
	for r in range(1, 23):
		_scr.tile(0, r, 21)
		_scr.tile(39, r, 21)
	for r in ropes:
		_scr.tile(0, r, 20)
		_scr.tile(39, r, 20)


## Rows of the list on a page. CAST's list fills rows 5-22 (Combat Chat 18, DOSBox: ELWEN's 21 rows, NEXT
## shows the last 18).
func _page_rows() -> int:
	return 11 if _list_kind == "memorize" else (18 if _list_kind == "cast" else 17)


func _draw_list() -> void:
	_plain_rope = false
	var m := _who()
	var ropes := [0, 2, 23] if _list_kind != "memorize" or _mode != "list" else [0, 2, 16, 23]
	if not _lines.is_empty():
		ropes = [0, 2, 16, 23]
	_page_frame(ropes)
	var title: String = {"memorize": "SPELLS IN SPELL BOOK", "cast": "SPELLS IN MEMORY",
		"scribe": "SPELLS ON SCROLLS"}.get(_list_kind, "SPELLS IN SPELL BOOK")
	if _mode in ["pending", "confirm"]:
		title = "SPELLS TO BE SCRIBED" if _list_kind == "scribe" else "SPELLS TO BE MEMORIZED"
	var who := "%s'S" % m.name
	_scr.text(1, 1, who, GameScreen.CYAN)
	_scr.text(2 + who.length(), 1, title, GameScreen.GREEN)
	var rows := _page_rows()
	for i in range(_top, mini(_top + rows, _list.size())):
		var row: Array = _list[i]
		var r := LIST_TOP + i - _top
		if r >= 16 and not _lines.is_empty():
			# A message's box (the rope at row 16, rows 17-22) hides the list's rows there (Combat Chat 18,
			# DOSBox: ELWEN's 18 rows, HOLD PERSON / IS A COMBAT-ONLY SPELL..., ELWEN CASTS / BLESS; ours drew
			# both: main chat 45's "message box drawn over the camp's spell list").
			break
		if row[1] == 0:
			_scr.text(1, r, row[0], MAGENTA)
		else:
			var lit := i == _cursor and _mode in ["list", "pending"] and _lines.is_empty()
			_scr.text(2 if _mode in ["pending", "confirm"] else 3, r, row[0], GameScreen.WHITE if lit else GameScreen.GREEN)
			if _mode == "list" and _list_kind == "scribe" and row.size() > 2 and _marked(int(row[2])):
				_scr.text(2, r, "*", GameScreen.WHITE if lit else GameScreen.GREEN)
	if _mode == "list" and _list_kind == "memorize":
		_scr.text(1, 18, m.name, GameScreen.CYAN)
		_scr.text(1, 19, "CAN MEMORIZE:", GameScreen.GREEN)
		var r := 20
		for c in 2:
			var counts := PackedStringArray()
			var any := false
			for l in range(1, 4):
				if m.spell_slots[c][l - 1] > 0:
					any = true
					counts.append(str(m.slots_left(spells, c, l)))
				else:
					counts.append(" ")
			if any:
				_scr.text(1, r, "%s %s" % ["    CLERIC SPELLS:" if c == 0 else "MAGIC-USER SPELLS:", "  ".join(counts).strip_edges(false, true)], GameScreen.GREEN)
				r += 1
	_draw_lines()
	match _mode:
		"list", "casting":
			if _row24 != "":
				_scr.text(0, 24, _row24, GameScreen.WHITE)
			else:
				_labelled("CHOOSE SPELL:", _list_menu(), 14)
		"ask":
			_scr.text(0, 24, "LOSE IT?", MAGENTA)
			_scr.menu_line(24, YES_NO, 9, EclVM.menu_lit(YES_NO.size()))
		"pending":
			_scr.menu_line(24, ["EXIT"], 1, 0)
		"confirm":
			var ask := "SCRIBE THESE SPELLS?" if _list_kind == "scribe" else "MEMORIZE THESE SPELLS?"
			_scr.text(0, 24, ask, PROMPT)
			_scr.menu_line(24, YES_NO, ask.length() + 1, EclVM.menu_lit(YES_NO.size()))


func _list_menu() -> Array:
	var items: Array = [{"memorize": "MEMORIZE", "cast": "CAST", "scribe": "SCRIBE"}[_list_kind]]
	if _top + _page_rows() < _list.size():
		items.append("NEXT")
	# PREV only with a spell above the page (chat 83, DOSBox: ELWEN's list at top 1, only "1ST LEVEL" above:
	# MEMORIZE NEXT EXIT; CEDRIC's at top 5: PREV).
	for i in mini(_top, _list.size()):
		if _list[i][1] != 0:
			items.append("PREV")
			break
	items.append("EXIT")
	return items


func _draw_display() -> void:
	_plain_rope = false
	_page_frame([0, 23])
	_scr.text(16, 1, "DISPLAY", GameScreen.WHITE)
	# One list for the party, paged as the camp's lists: rows 5-21, NEXT / PREV, the last page showing the list's last
	# rows (main chat 156, DOSBox: p2c's seven members, NEXT shows BRAM to DIRTEN).
	var rows := _display_rows()
	_display_top = clampi(_display_top, 0, maxi(rows.size() - DISPLAY_PAGE, 0))
	for i in range(_display_top, mini(_display_top + DISPLAY_PAGE, rows.size())):
		var row: Array = rows[i]
		_scr.text(row[1], LIST_TOP + i - _display_top, row[0], row[2])
	_scr.menu_line(24, _display_menu(), 1, 0)


## DISPLAY's rows: each member's name, the effects the original names, or " <NO SPELL EFFECTS>"; a blank row between
## members ([text, column, colour]).
func _display_rows() -> Array:
	var rows: Array = []
	for m in _party:
		if not rows.is_empty():
			rows.append(["", 1, GameScreen.GREEN])
		rows.append([m.name, 1, GameScreen.CYAN])
		var any := false
		for a in m.affects:
			var n := display_effect_name(int(a.effect))
			if n != "":
				rows.append([n, 2, GameScreen.GREEN])
				any = true
		if not any:
			rows.append([" <NO SPELL EFFECTS>", 1, GameScreen.GREEN])
	return rows


func _display_menu() -> Array:
	var words: Array = []
	var n := _display_rows().size()
	if _display_top + DISPLAY_PAGE < n:
		words.append("NEXT")
	if _display_top > 0:
		words.append("PREV")
	words.append("EXIT")
	return words


## DISPLAY's name for an effect (GAME.OVR 0x1887D-0x18AE0): a spell's effect by the spell's name ("FUNKY--" when no
## spell has it), fourteen others by their own words, any other effect not listed (""; a fighter's racial records).
func display_effect_name(effect: int) -> String:
	if effect in DISPLAY_SPELL_FX:
		var n := spells.effect_name(effect)
		return "FUNKY--" if n.begins_with("EFFECT ") else n
	return DISPLAY_NAMES.get(effect, "")


# --- Menus ----------------------------------------------------------------------------------

## The light keeps the index of the word last chosen, in whatever menu comes next; past that menu's end it starts
## at the first word (main chat 91, DOSBox at 3:0's camp: ORDER's EXIT lights ALTER's DROP, PICS's EXIT SPEED, ICON's
## YES ORDER, ALTER's and MAGIC's EXIT the camp's EXIT, REST's EXIT (index 6) SAVE or CAST, DISPLAY's EXIT CAST,
## CAST's list EXIT MEMORIZE, MEMORIZE NEXT EXIT's EXIT SCRIBE).
func _to_menu(mode: String, items: Array) -> void:
	_mode = mode
	if _pick < 0 or _pick >= items.size():
		_pick = 0
	_refresh()


func _show_menu() -> void:
	_to_menu("camp", _camp_menu())


## QoL 5 (Q10): SAVE opens the saved games' list in place of the letter prompt; a letter still saves at once.
var _save_list: SaveListScreen


func _open_save_list() -> void:
	if _save_list == null:
		_save_list = SaveListScreen.new()
		add_child(_save_list)
		_save_list.picked.connect(func(slot: String) -> void:
			_mode = "save"
			_act(slot))
		_save_list.cancelled.connect(_show_menu)
	_save_list.open("save", GameData.find_game_path())


func _magic_menu() -> void:
	# The MAGIC menu forgets the last target (main chat 133, DOSBox, check 497: CEDRIC's SLOW POISON on DORN, EXIT
	# from the list, CAST CURE LIGHT WOUNDS: CAST SPELL ON WHOM lights CEDRIC again; cast straight from the list it
	# lights DORN, chat 83's case).
	_last_target = null
	_to_menu("magic", MAGIC_MENU)


func _alter_menu() -> void:
	_ordering = -1
	_to_menu("alter", ALTER_MENU)


var _rest_back := "camp"   # the menu REST was chosen from (lab: MAGIC's REST ends on MAGIC's menu)


func _rest_menu(from: String = "camp") -> void:
	_rest_back = from
	_mode = "rest"
	_resting = false
	_to_rest = 0
	if spells != null:
		var need := 0
		for m in _party:
			need = maxi(need, m.learn_minutes(spells))
		_to_rest = (need + 4) / 5
	_pick = clampi(_pick, 0, REST_MENU.size() - 1)
	# INC and DEC start on the minutes at every REST, whatever word is lit (GAME.OVR 0x244F7; main chat 159).
	_field = 2
	_lines = []
	_refresh()


## Back from REST's menu to the camp's or MAGIC's, the shared light where it is.
func _rest_leave() -> void:
	if _rest_back == "magic":
		_magic_menu()
	else:
		_show_menu()


func _change(sign: int) -> void:
	var step: int = [288, 12, 1][_field]
	_to_rest = clampi(_to_rest + sign * step, 0, 288 * 99)
	_refresh()


# --- Resting --------------------------------------------------------------------------------

func _start_rest() -> void:
	if _to_rest <= 0:
		return
	_mode = "rest"
	_pick = 0
	_resting = true
	_rest_key = false
	_heal_note = false
	_hour_steps = 0
	_learn_timer.clear()
	_held.clear()
	if spells != null:
		for m in _party:
			m.learn_hours = 0
			# The study hours; each spell's 15 minutes a level follow (_learn_step).
			m.learn_hours = m.learn_study_hours(spells)
	_lines = []
	SpellCaster.rest_begins(_party)    # the clock's member flags, set as a REST begins (GAME.OVR 0x24AB1)
	_rest_go()
	_refresh()


## Resting stopped (Esc) or done: back to the camp menu, the clock moved on.
func _stop_rest() -> void:
	_resting = false
	_timer.stop()
	if _fixing:
		_fixing = false
		if _to_rest <= 0:
			_fix_heal()
	if minutes_passed > 0:
		time_passed.emit(minutes_passed)
		minutes_passed = 0
	_back_from_rest()


## Back to the menu REST came from (lab, Combat Chat 3: a rest begun from MAGIC's menu ends
## on CAST MEMORIZE SCRIBE DISPLAY REST EXIT).
func _back_from_rest() -> void:
	if _rest_back == "magic":
		_pick = MAGIC_MENU.find("REST")
		_magic_menu()
	else:
		_show_menu()


## The rest's steps run on the clock: STEPS_PER_TICK each REST_TICK of real time, whatever the frame rate.
var _rest_from := 0


func _rest_go() -> void:
	_rest_from = Time.get_ticks_msec()
	_timer.start()


func _tick() -> void:
	var now := Time.get_ticks_msec()
	var n := clampi(int((now - _rest_from) / (REST_TICK * 1000.0) * STEPS_PER_TICK), 1, STEPS_PER_HEAL)
	_rest_from = now
	for i in n:
		if _to_rest <= 0:
			_stop_rest()
			return
		if _rest_key:
			# GAME.OVR 0x24B1D: with a key waiting, the rest stops before the next step and asks STOP RESTING? on row
			# 24 (magenta) with the shared Yes / No (0x2D9A0: NO lit, only Y or N answer) (main chat 126, DOSBox).
			_rest_key = false
			_timer.stop()
			_mode = "stop_ask"
			EclVM.menu_hl = 1
			_refresh()
			return
		_to_rest -= 1
		_rest_steps += 1
		minutes_passed += 5
		var news := SpellCaster.pass_time(_party, 5, true)
		if not news.is_empty():
			_say(news[news.size() - 1])
		if _rest_steps % STEPS_PER_HEAL == 0:
			_heal_day()
		_learn_step()
		var hit := _interrupt_check()
		var healed := _heal_note
		_heal_note = false
		if healed or not _held.is_empty():
			_notes_then(healed, hit)
			return
		if hit:
			_interrupt()
			return
	_refresh()


var _rest_key := false     # a key was typed during the rest (or its notes): the next step asks STOP RESTING?
var _heal_note := false    # this step printed THE WHOLE PARTY IS HEALED


## A step's notes, each a script DELAY with no key read (game speed x 225 ms): THE WHOLE PARTY IS HEALED (0x246D0),
## then the HAS MEMORIZED ones (_show_held); then an interruption if the step's roll called for it.
func _notes_then(healed: bool, hit: bool) -> void:
	_timer.stop()
	if healed and _resting and visible:
		_refresh()
		await get_tree().create_timer(TEXT_SPEED * 0.225 + 0.001).timeout     # P104: speed 4's pace
		_lines = []
		_refresh()
	if not _held.is_empty():
		await _show_held()
	elif _resting and visible and not hit:
		_rest_go()
	if hit and _resting and visible:
		_interrupt()


## The interruption check after each 5-minute step (GAME.OVR 0x24B9B, after the clock,
## effects, healing and memorizing): with the area's period above 0, a step counter (the
## original's word DS:0x49FB, cleared only at a new game 0xE980: it carries from one camp to
## the next) counts up to the period, goes back to 0 and the game's dice roll 1d100 (0x24BC4);
## <= the area's percent interrupts. Combat Chat 7 (Player 3's request): from the shared dice,
## so a lab run is the original's roll for roll; the check is made on a step that memorized a
## spell too (before, ours skipped it).
func _interrupt_check() -> bool:
	if _period <= 0:
		return false
	_since_check += 1
	if _since_check < _period:
		return false
	_since_check = 0
	var roll: int = (TpDice.random(100, "rest interrupted?") + 1) if TpDice.on else _rng.randi_range(1, 100)
	return roll <= _percent


func _held_then_interrupt() -> void:
	await _show_held()
	if _resting and visible:
		_interrupt()


## "THE PARTY IS RUDELY INTERRUPTED!" for a moment, then the area's script takes over.
## Still resting until then (the bot waits on _resting).
## The moment is a script DELAY (GAME.OVR 0x24C07: game speed x 225 ms, a plain Delay reading no keys): a key typed
## meanwhile stays in the buffer and the encounter's menu after takes the last one (main chat 125, DOSBox at 2:20,
## speed 4: F typed 0.45 s after R fled at COMBAT WAIT FLEE PARLAY). Main hands `typed_ahead` to its type-ahead:
## what the get-key reads from the keys typed meanwhile (KeyBurst, main chat 127).
var typed_ahead: InputEventKey = null
var _interrupting := false
var _interrupt_keys := KeyBurst.new()


func _interrupt() -> void:
	_timer.stop()
	_say_lines([["", GameScreen.GREEN], ["", GameScreen.GREEN], ["THE PARTY IS RUDELY INTERRUPTED!", GameScreen.WHITE]])
	_refresh()
	typed_ahead = null
	_interrupt_keys.clear()
	_interrupting = true
	await get_tree().create_timer(TEXT_SPEED * 0.225).timeout     # P104: speed 4's pace
	_interrupting = false
	typed_ahead = _interrupt_keys.take()
	_resting = false
	_to_rest = 0
	_fixing = false        # an interrupted FIX heals no one
	# Lab (chat 22, save J resting at 14,5, twice): spells picked and not yet memorized are
	# lost; the next camp's REST TIME is 00:00:00 and they must be picked again.
	for m in _party:
		m.cancel_learning()
	visible = false
	_anim.stop()
	interrupted.emit()


var _held: Array = []   # P35: this step's HAS MEMORIZED / HAS SCRIBED messages, [name, verb, spell]


## P35 (GAME.OVR 0x246F8 -> 0x2A332, Combat Chat 3): each spell learnt while resting prints
## "<NAME>" (cyan) "HAS MEMORIZED" (green) on row 19 and the spell (green) on row 20, the rest
## screen staying, waits the game speed x 225 ms (START.EXE 0x709:0xDBE, no key) and clears
## the box (0x17E3); then the rest goes on (lab, New Phlan, save F: BROTHER SEAN HAS MEMORIZED /
## RESIST COLD, then DARKSTAR HAS MEMORIZED / SLEEP, each for a moment, then the camp menu).
## Ours pauses the rest's clock for each one the same way, at speed 4's pace whatever SETTINGS says (P104).
func _show_held() -> void:
	_timer.stop()
	while not _held.is_empty() and _resting and visible:
		var h: Array = _held.pop_front()
		var line := "%s %s" % [h[0], h[1]]
		_say_lines([["", GameScreen.GREEN], ["", GameScreen.GREEN], [line, GameScreen.GREEN, String(h[0]).length()],
			[String(h[2]).to_upper(), GameScreen.GREEN]])
		_refresh()
		await get_tree().create_timer(TEXT_SPEED * 0.225 + 0.001).timeout     # P104: speed 4's pace
		_lines = []
		_refresh()
	_held.clear()
	if _resting and visible:
		_rest_go()


## One 5-minute step of memorizing (see PartyMember "Spells"): the hours of study count
## down every 12 steps; then each spell takes 3 steps per spell level.
func _learn_step() -> void:
	if spells == null:
		return
	for m in _party:
		var t: int = _learn_timer.get(m, 0)
		if t > 0:
			t -= 1
		if t == 0 and m.learn_hours == 0 and _learn_timer.has(m):
			# GAME.OVR 0x24911: the scroll walk (0x247B3) first, then the memory (0x246F1), one copy a time;
			# each walk returns the next spell's level for the countdown (level x 3 steps). A copy that uses
			# a scroll up (0x2A2A2 drops it) ends the walk with 0, so the countdown is 0 and wraps: 256 steps
			# (21:20) before the next copy, unless a spell still to memorize sets it (Combat Chat 38, Player
			# 37's p37b2: LIRA's nine marked spells took three rests, one used-up scroll each).
			var next := 0
			if not m.scribe_pending().is_empty():
				var n_items := m.items.size()
				var id := m.scribe_next()
				_held.append([m.name, "HAS SCRIBED", spells.name_of(id)])
				var pend := m.scribe_pending()
				if m.items.size() < n_items:
					pend.clear()
				if not pend.is_empty():
					next = spells.level(pend[0])
				elif not m.learning_spells().is_empty():
					next = spells.level(m.learning_spells()[0])
			else:
				var pending := m.learning_spells()
				if not pending.is_empty():
					var id: int = pending[0]
					var k := m.memorized.find(id + PartyMember.LEARNING)
					m.memorized[k] = id
					_held.append([m.name, "HAS MEMORIZED", spells.name_of(id)])
				pending = m.learning_spells()
				if not pending.is_empty():
					next = spells.level(pending[0])
			t = next * 3 if next > 0 else (256 if not (m.scribe_pending() + m.learning_spells()).is_empty() else 0)
		_learn_timer[m] = t
	_hour_steps += 1
	if _hour_steps >= 12:
		_hour_steps = 0
		for m in _party:
			if m.learn_hours > 0:
				m.learn_hours -= 1
				if m.learn_hours == 0:
					if _next_learn_steps(m) > 0:
						_learn_timer[m] = _next_learn_steps(m)


## 5-minute steps for the next spell to scribe, then to memorize (the study's end, GAME.OVR 0x249D3: the
## scroll walk asked first): 15 minutes a level.
func _next_learn_steps(m: PartyMember) -> int:
	var pending := m.scribe_pending()
	if pending.is_empty():
		pending = m.learning_spells()
	return spells.level(pending[0]) * 3 if not pending.is_empty() else 0


## A full day's rest: everyone alive gains 1 HP; the unconscious wake.
func _heal_day() -> void:
	for m in _party:
		if m.status in [PartyMember.STATUS_OKAY, PartyMember.STATUS_UNCONSCIOUS, PartyMember.STATUS_DYING] \
				and m.hp < m.hp_max and not SpecialAffects.diseased(m):
			m.hp += 1
			m.status = PartyMember.STATUS_OKAY
			if m.raw.size() > 0x10D:
				m.raw[0x10D] = 1     # (main chat 134, DOSBox: DIRTEN rested a day: OKAY, +0x10D set)
	# GAME.OVR 0x2463D: the line is printed (0x24699) before the any-healed test (0x246BD, which only redraws the
	# party list), so it shows every 24 hours rested (main chat 126, by the code), and waits (0x246D0).
	_say("THE WHOLE PARTY IS HEALED")
	_heal_note = true


# --- MAGIC ----------------------------------------------------------------------------------

func _who() -> PartyMember:
	return _party[_sel]


## Builds a spell list by level: rows [text, id] with headings as [text, 0].
func _build_list(ids: Array, mark: String = "") -> void:
	_list = []
	if _list_kind == "scribe" and mark == "":
		# SPELLS ON SCROLLS: the scrolls' record order (each scroll's bytes 60-62 in turn), a level heading
		# wherever the level changes, as CAST's (main chat 76, DOSBox: a scroll 20, 17 lists SHOCKING GRASP above
		# PROTECTION FROM GOOD; 17, 34, 20 shows 1ST / 2ND / 1ST; ours sorted by spell number). Each row keeps
		# its place in _scrolls (row[2]): two scrolls with one spell are two rows.
		var lv := -1
		for k in ids.size():
			var l := spells.level(ids[k])
			if l != lv:
				_list.append([LEVEL_WORDS[clampi(l - 1, 0, 4)], 0])
				lv = l
			_list.append([spells.name_of(ids[k]), ids[k], k])
		_top = 0
		_cursor = -1
		for i in mini(_list.size(), _page_rows()):
			if _list[i][1] != 0:
				_cursor = i
		return
	if _list_kind == "cast" and mark == "":
		# SPELLS IN MEMORY: in the record's own order, a level heading wherever the level changes (Combat
		# Chat 18, DOSBox: ELWEN's record CLW CLW BLESS SLEEP / KNOCK STINKING CLOUD / SLEEP MAGIC MISSILE /
		# HOLD PERSON x3 / BLESS BLESS / HOLD PERSON listed so, six headings; ours sorted them by level).
		# The record's bytes 0x17-0x2B upwards: ours' `memorized` holds them from 0x2B down, so backwards.
		var last := -1
		var up := ids.duplicate()
		up.reverse()
		for id in up:
			var l := spells.level(id)
			if l != last:
				_list.append([LEVEL_WORDS[clampi(l - 1, 0, 4)], 0])
				last = l
			_list.append([spells.name_of(id), id])
		_top = 0
		_cursor = -1
		for i in mini(_list.size(), _page_rows()):
			if _list[i][1] != 0:
				_cursor = i
		return
	var by_level := {}
	for id in ids:
		by_level.get_or_add(spells.level(id), []).append(id)
	var levels := by_level.keys()
	levels.sort()
	for l in levels:
		_list.append([LEVEL_WORDS[clampi(l - 1, 0, 4)], 0])
		by_level[l].sort()       # lab: the spells in memory by spell number, cleric first
		for id in by_level[l]:
			_list.append([mark + spells.name_of(id), id])
	# The original starts on the last spell of the first page.
	_top = 0
	_cursor = -1
	for i in mini(_list.size(), _page_rows()):
		if _list[i][1] != 0:
			_cursor = i


func _open_list(kind: String) -> void:
	var m := _who()
	var ids: Array = []
	# CAST inside the anti-magic shell (GAME.OVR 0x17BA8-0x17BCD, checked before the member's
	# condition, CAST only): "<NAME>" / "CANNOT CAST SPELLS IN THIS AREA", the same display.
	if kind == "cast" and anti_magic:
		_note_name(m.name, "CANNOT CAST SPELLS IN THIS AREA")
		return
	# Someone not fit to act (GAME.OVR 0x17B9D, the same check for all three): "<NAME>" / "IS IN
	# NO CONDITION TO CAST ANY SPELLS" (MEMORIZE SPELLS, SCRIBE ANY SCROLLS).
	if m.status != PartyMember.STATUS_OKAY:
		_note_name(m.name, "IS IN NO CONDITION TO " + {"cast": "CAST ANY SPELLS", "memorize": "MEMORIZE SPELLS",
			"scribe": "SCRIBE ANY SCROLLS"}.get(kind, "CAST ANY SPELLS"))
		return
	match kind:
		"memorize":
			# A character who can't memorize: nothing happens (lab: a fighter).
			if m.status != PartyMember.STATUS_OKAY or not m.has_slots():
				return
			for id in range(1, SpellTable.NAMED + 1):
				if m.knows(id) and spells.spell_class(id) <= 1 and spells.level(id) <= 3:
					ids.append(id)
		"cast":
			if m.status != PartyMember.STATUS_OKAY:
				return
			ids = m.ready_spells()
			if ids.is_empty():
				_note_name(m.name, "HAS NO SPELLS MEMORIZED")
				return
		"scribe":
			if m.status != PartyMember.STATUS_OKAY:
				return
			_scrolls = m.scribable(spells)
			for row in _scrolls:
				ids.append(row[2])
			if ids.is_empty():
				_note_name(m.name, "HAS NO COPYABLE SCROLLS")     # lab, chat 22 (GAME.OVR 0x18447)
				return
	if ids.is_empty():
		return        # lab: SCRIBE with no scrolls, nothing happens
	_list_kind = kind
	_build_list(ids)
	_lines = []
	_mode = "list"
	_pick = 0
	_refresh()


func _open_pending() -> void:
	_build_list(_who().scribe_pending() if _list_kind == "scribe" else _who().learning_spells(), "*")
	_mode = "pending"
	_refresh()


## NEXT / PREV as the shop's list (Combat Chat 15) and the original's (Combat Chat 16, Player 15's p13a1 at the
## inn: ELWEN with BLESS lit on row 1, NEXT, nine Ends light SLEEP): the last page shows the list's last rows
## (overlapping the one before) and the light keeps its screen row; on a level's heading NEXT goes on to the spell
## below it and PREV back to the spell above it (chat 83, DOSBox: ELWEN's ANIMATE DEAD, PREV: the light on SLEEP
## above "2ND LEVEL"; CEDRIC's CAUSE BLINDNESS, PREV: RESIST COLD above it; p36h1's 7:17 MEMORIZE).
func _turn_page(step: int) -> void:
	var rows := _page_rows()
	var row := _cursor - _top
	if step > 0:
		_top = mini(_top + rows, maxi(_list.size() - rows, 0))
	else:
		_top = maxi(_top - rows, 0)
	_cursor = clampi(_top + row, 0, maxi(_list.size() - 1, 0))
	if not _list.is_empty() and _list[_cursor][1] == 0:
		var i := _cursor
		while i >= 0 and i < _list.size() and _list[i][1] == 0:
			i += 1 if step > 0 else -1
		if i < 0 or i >= _list.size():
			i = _cursor
			while i < _list.size() - 1 and _list[i][1] == 0:
				i += 1
		_cursor = i
	_refresh()


func _move_cursor(d: int) -> void:
	if _list.is_empty():
		return
	# Home / End move the light on the page and wrap on it, never scrolling (the list routine 0x2D594; main chat 156,
	# DOSBox: CEDRIC's MEMORIZE, End on FIND TRAPS, the page's last line, lights BLESS, its first; Home there FIND
	# TRAPS again; the headings are skipped). Check 587.
	var lo := clampi(_top, 0, _list.size() - 1)
	var n := mini(_top + _page_rows(), _list.size()) - lo
	var i := clampi(_cursor, lo, lo + n - 1)
	for k in n:
		i = lo + posmod(i - lo + d, n)
		if _list[i][1] != 0:
			_cursor = i
			break
	_refresh()


func _choose() -> void:
	if _cursor < 0 or _cursor >= _list.size() or _list[_cursor][1] == 0:
		return
	var id: int = _list[_cursor][1]
	var m := _who()
	if _list_kind == "memorize":
		if m.slots_left(spells, spells.spell_class(id), spells.level(id)) > 0:
			m.memorized.append(id + PartyMember.LEARNING)
			m.sort_memorized()     # GAME.OVR 0x1827E
			Rememorize.note_pick(m, spells)
		_refresh()
	elif _list_kind == "scribe":
		# Marks the scroll spell to be scribed while resting ("*"), or says why not on row 24
		# for a moment (lab, chat 22; GAME.OVR 0x1838D): already known, already marked, or a
		# level the magic-user can't learn yet.
		var row: Array = _scrolls[_list[_cursor][2]]
		var it: GameItem = row[0]
		var why := m.scribe_refusal(spells, it, row[1])
		if why != "":
			_note_24(why)
		else:
			it.raw[row[1]] |= 0x80
			_note.text = "%s WILL BE SCRIBED" % spells.name_of(id).to_upper()
		_refresh()
	elif _list_kind == "cast":
		_cast_id = id
		_caster = m
		if not SpellCaster.castable_outside(spells, id):
			_mode = "ask"
			_pick = 0                # lab: YES lit
			_say_lines([["", GameScreen.GREEN], ["", GameScreen.GREEN], [spells.name_of(id), GameScreen.GREEN],
				["IS A COMBAT-ONLY SPELL...", GameScreen.GREEN]])
			_refresh()
		elif SpellCaster.needs_member(spells, id):
			_mode = "whom"
			_whom_off = 0
			_pick = 0
			if _last_target != null and _party.has(_last_target):
				_sel = _party.find(_last_target)
			_lines = []
			_refresh()
		else:
			_cast(null)


## CAST SPELL ON WHOM's light (main chat 93): 0 on _sel; -1 no one (after Esc); -2 past the party's end (bug 19).
var _whom_off := 0


func _cast(target: PartyMember) -> void:
	_held_key.clear()
	var on_member := _mode == "whom"
	if on_member:
		_last_target = target
	var lines := SpellCaster.cast_outside(spells, _caster, _cast_id, _party, target, _rng2)
	_sel = maxi(_party.find(_caster), 0)
	if on_member and lines.size() <= 1:
		# A spell that says nothing (Cure Disease on the healthy, CLW at full HP): no line, straight back to the
		# spell list (main chat 75, DOSBox: dumped 0.15 s after SELECT).
		_back_to_list()
		return
	if on_member:
		# The result on the adventure screen, under CAST SPELL ON WHOM.
		# Keys wait while it shows ("shown": no menu items), or a second SELECT casts again.
		if lines.size() > 0:
			_say(lines[lines.size() - 1])
		_mode = "shown"
		_refresh()
		await get_tree().create_timer(1.0 * (TEXT_SPEED + 1) / 5.0).timeout     # P104: speed 4's pace
		if not visible or _mode != "shown":
			return
	else:
		# On the list page: "<NAME> CASTS" / "<SPELL>", then each target's line in turn.
		_mode = "casting"
		for k in lines.size():
			if k == 0:
				_say_lines([["", GameScreen.GREEN], ["", GameScreen.GREEN], [_caster.name + " CASTS", GameScreen.GREEN],
					[spells.name_of(_cast_id), GameScreen.GREEN]])
			else:
				_say(lines[k])
			_refresh()
			await get_tree().create_timer(1.0 * (TEXT_SPEED + 1) / 5.0).timeout     # P104: speed 4's pace
			if not visible or _mode != "casting":
				return
	await _back_to_list()
	_hand_on()


var _held_key := KeyBurst.new()   # the keys typed during a spell's text (the get-key's burst rule: main chat 127)


## The key typed during a spell's text goes to the menu after it.
func _hand_on() -> void:
	var ev := _held_key.take()
	if ev != null and visible:
		_unhandled_input(ev)


## After a cast or LOSE IT?: the spell list again, or out of it when nothing is left.
func _back_to_list() -> void:
	_lines = []
	if _caster.ready_spells().is_empty():
		# The CAST loop (GAME.OVR 0x17CF7) builds the list again after every cast or LOSE IT?; with nothing left it
		# says "<NAME>" / "HAS NO SPELLS MEMORIZED" over the screen as it stands, row 24 kept, then the MAGIC menu or
		# the walking screen (Combat Chat 62, DOSBox: BAKSHI's last spell READ MAGIC on the list page, CURE LIGHT WOUNDS
		# under CAST SPELL ON WHOM, MAGIC MISSILE's LOSE IT? YES; the adventure menu's CAST the same). Ours went
		# straight on.
		_none_left = true
		_say_name(_caster.name, "HAS NO SPELLS MEMORIZED")
		_refresh()
		await get_tree().create_timer(1.0 * text_scale()).timeout     # P104
		_none_left = false
		if not visible:
			return
		_lines = []
		_plain_rope = false
		if _walk:
			_close_walk()
		else:
			_magic_menu()
		_hand_on()
	else:
		# The list is built again: the first page, its last spell lit (Combat Chat 18, DOSBox: after a cure
		# cast from the second row, after Bless, after LOSE IT? NO; ours kept the light where it was).
		_build_list(_caster.ready_spells())
		_mode = "list"
		_pick = 0
		_refresh()


var _none_left := false   # HAS NO SPELLS MEMORIZED after the last spell: keys wait (as during a spell's text)
var _row24 := ""     # a refusal shown on row 24 for a moment, in place of the menu


func _note_24(text: String) -> void:
	_row24 = text
	_refresh()
	await get_tree().create_timer(1.0 * text_scale()).timeout     # P104
	if _row24 == text:
		_row24 = ""
		_refresh()


## Whether the scroll spell at this place in _scrolls is marked for SCRIBE.
func _marked(k: int) -> bool:
	var row: Array = _scrolls[k]
	return (row[0] as GameItem).raw[row[1]] > 0x80


## "<NAME>" / message for a moment, the menu as it was (lab: HAS NO SPELLS MEMORIZED).
func _note_name(name: String, message: String) -> void:
	_say_name(name, message)
	_refresh()
	await get_tree().create_timer(1.0 * text_scale()).timeout     # P104
	if not visible or _lines.size() < 3 or _lines[2][0] != message:
		return
	_lines = []
	_plain_rope = false
	if _walk and _mode == "walk":
		_close_walk()
	else:
		_refresh()


func _leave_list() -> void:
	if _walk and _list_kind == "cast":
		_close_walk()
		return
	if _list_kind == "scribe" and not _who().scribe_pending().is_empty():
		_open_pending()
		return
	if _list_kind == "memorize" and not _who().learning_spells().is_empty():
		_open_pending()
		return
	if _starting:
		_next_starter()
		return
	_pick = _list_menu().size() - 1
	_magic_menu()


func _pick_member(d: int) -> void:
	if _party.is_empty():
		return
	if _mode == "order" and _ordering >= 0:
		# The selected member moves with the cursor.
		var to := clampi(_sel + d, 0, _party.size() - 1)
		if to != _sel:
			var m: PartyMember = _party[_sel]
			_party.remove_at(_sel)
			_party.insert(to, m)
			_sel = to
		_refresh()
		return
	_sel = (_sel + d + _party.size()) % _party.size()
	_refresh()


# --- Keys -----------------------------------------------------------------------------------

func _items() -> Array:
	match _mode:
		"camp": return _camp_menu()
		"save": return SAVE_LETTERS
		"rest": return REST_MENU.map(func(it): return it[0])
		"magic": return MAGIC_MENU
		"list": return _list_menu()
		"pending": return ["EXIT"]
		"display": return _display_menu()
		"confirm", "drop", "ask", "quit": return YES_NO
		"whom": return ["SELECT", "EXIT"]
		"alter": return ALTER_MENU
		"order": return ["PLACE" if _ordering >= 0 else "SELECT", "EXIT"]
		"speed": return _speed_menu()
		"pics": return ["MONSTERS", "PORTRAITS", "EXIT"]
	return []


func _hot(item: String) -> int:
	if _mode == "rest":
		for it in REST_MENU:
			if it[0] == item:
				return String(it[0]).unicode_at(it[2])
	return item.unicode_at(0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or not event is InputEventKey or _sheet.visible \
			or (_icon_editor != null and _icon_editor.visible):
		return
	if event is InputEventKey:
		var dk := KeyBurst.menu_key(event as InputEventKey)
		if dk == null:
			get_viewport().set_input_as_handled()
			return     # Ctrl / Alt and a letter: no menu letter (KeyBurst.menu_key; main chat 129, DOSBox)
		event = dk
	get_viewport().set_input_as_handled()
	var key := (event as InputEventKey).keycode
	if _interrupting:
		if not (event as InputEventKey).echo:
			_interrupt_keys.add(event as InputEventKey)
		return
	if _mode in ["shown", "casting"] or _none_left:
		# A spell's text waits with no key read (GAME.OVR 0x2A41B: game speed x 225 ms): a key typed meanwhile stays
		# buffered and the spell list after it takes the last one (main chat 126, DOSBox: check 173's start, CAST on
		# ARN, E typed during ARN / IS PROTECTED: the list took EXIT; ours dropped it).
		if not (event as InputEventKey).echo:
			_held_key.add(event as InputEventKey)
		return
	if _resting and _mode == "stop_ask":
		if key == KEY_Y:
			_mode = "rest"
			EclVM.menu_hl = 0
			_stop_rest()
		elif key == KEY_N:
			_mode = "rest"
			_refresh()
			_rest_go()
		return
	if _resting:
		# Any key, Escape too, waits in the buffer: the next step asks STOP RESTING? (main chat 126, DOSBox: x typed
		# 0.3 s in, the question; ours stopped at once on Escape and ignored the others).
		if not (event as InputEventKey).echo:
			_rest_key = true
		return
	var items := _items()
	if items.is_empty():
		return
	# Digits as the keypad's keys at REST, the spell lists, WHOM and ORDER (KeyBurst.ext_digit; main chat 157).
	if _mode in ["rest", "list", "pending", "whom", "order", "display", "speed"]:
		event = KeyBurst.ext_digit(event as InputEventKey)
		key = (event as InputEventKey).keycode
	var up := key in [KEY_HOME, KEY_KP_7, KEY_UP]
	var down := key in [KEY_END, KEY_KP_1, KEY_DOWN]
	if _mode == "rest":
		# REST's menu: Up / Down (8 / 2) are INC / DEC; Home, End (7 / 1), PgUp and PgDn change nothing (main chat 157,
		# DOSBox at 3:0's inn from check 391's start: Up, Up, Home, 4, 8, 6, End rested 1:10; ours took Home as INC
		# and End as DEC). Left / Right (4 / 6) pick the field, below.
		up = key in [KEY_UP, KEY_KP_8]
		down = key in [KEY_DOWN, KEY_KP_2]
		if key in [KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN]:
			return
	if _mode == "speed" and key in [KEY_UP, KEY_KP_8, KEY_DOWN, KEY_KP_2]:
		# GAME SPEED: Up (8) is SLOWER and Down (2) FASTER where the menu offers them (main chat 157, DOSBox at 3:0's
		# camp, ALTER SPEED from 0: Up 1, Down 0, 8 1, 2 0; Home, End, 7, 1, 4, 6 nothing). Ours took neither.
		var w := "SLOWER" if key in [KEY_UP, KEY_KP_8] else "FASTER"
		if w in items:
			_act(w)
		return
	if _mode in ["camp", "magic", "alter"]:
		# Combat Chat 57 (DOSBox at 3:11's camp, check 103's start; main chat 123's request): these menus move the lit
		# member on Home / End and on 7 / 1 (GAME.OVR 0x2CF60 makes the digits the keypad's keys); every other
		# extended key (the arrows, Left / Right, PgUp / PgDn, the digits 2-6, 8, 9) lights the first member;
		# letters off the menu and Enter do nothing.
		up = key in [KEY_HOME, KEY_KP_7, KEY_7]
		down = key in [KEY_END, KEY_KP_1, KEY_1]
		if key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_PAGEUP, KEY_PAGEDOWN, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6,
				KEY_8, KEY_9, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_8, KEY_KP_9]:
			if not _party.is_empty() and _sel != 0:
				_sel = 0
				_refresh()
			return
	if up or down:
		var step := 1 if down else -1
		if _mode == "rest":
			_pick = 4 if up else 5
			_change(1 if up else -1)
		elif _mode in ["list", "pending"]:
			_move_cursor(step)
		elif _mode == "whom" and _whom_off != 0:
			# From no one (after Esc): Home lights the last member, End no one past the party's end (bug 19; with
			# the bugs off the first member); Home from past the end no one again (main chat 93, as TRADE's, chat 92).
			if up:
				if _whom_off == -1:
					_sel = _party.size() - 1
					_whom_off = 0
				else:
					_whom_off = -1
			elif _whom_off == -1:
				if OriginalBugs.on():
					_whom_off = -2
				else:
					_sel = 0
					_whom_off = 0
			_refresh()
		elif _mode in ["camp", "magic", "whom", "alter", "order"]:
			_pick_member(step)
		return
	# CAST SPELL ON WHOM: Esc takes the light off the party and the question stays (main chat 93, DOSBox: check
	# 142's camp, CEDRIC's CURE LIGHT WOUNDS; as TRADE's member lists). Check 315.
	if _mode == "whom" and key == KEY_ESCAPE:
		_whom_off = -1
		_refresh()
		return
	# The camp's menu, MAGIC's and ALTER's take only their letters: Enter and Left / Right do nothing
	# there (main chat 89, DOSBox at 3:0, check 288; Q24 extended, as the temple's). REST's menu keeps them.
	if _mode in ["camp", "magic", "alter"] and key in [KEY_ENTER, KEY_KP_ENTER, KEY_LEFT, KEY_RIGHT]:
		return
	# The spell lists (CHOOSE SPELL: MEMORIZE / SCRIBE / CAST ... NEXT PREV EXIT) keep their light on Left / Right and
	# page on PgDn / PgUp as NEXT / PREV where offered, the light staying on its word (main chat 92, DOSBox at 3:0's
	# camp: ELWEN's MEMORIZE, Enter after the pages memorized the lit spell; LIRA's SCRIBE; check 311).
	if _mode == "list" and key in [KEY_LEFT, KEY_RIGHT]:
		return
	if _mode in ["list", "display"] and key in [KEY_PAGEDOWN, KEY_PAGEUP]:
		var word := "NEXT" if key == KEY_PAGEDOWN else "PREV"
		if word in items:
			_act(word)
		return
	if key == KEY_COMMA or key == KEY_PERIOD:
		EclVM.menu_step(items.size(), -1 if key == KEY_COMMA else 1)     # 0x2CE93 / 0x2CEB7 (main chat 122)
		_refresh()
		return
	if key == KEY_LEFT or key == KEY_RIGHT:
		var d := 1 if key == KEY_RIGHT else -1
		if _mode == "rest":
			_field = (_field + d + 3) % 3      # lab: Left/Right pick the field
		else:
			_pick = (_pick + d + items.size()) % items.size()
		_refresh()
		return
	if _mode == "rest" and key in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		# REST's loop (GAME.OVR 0x244FB-0x2461C) turns Enter into R whatever word is lit (0x2458C), and Escape (0)
		# ends it; neither moves the shared light (0x2CC8C), so the camp's or MAGIC's menu lights the word in the
		# same place (main chat 159, DOSBox at 3:0's camp from check 391's start: R lights MINS, Enter goes back to the
		# camp menu with REST lit; MAGIC's REST lights INC, Enter rests and MAGIC lights REST; Esc keeps REST lit).
		# Ours took Enter as the lit word: MINS, or INC from MAGIC (5 minutes more, no rest).
		if key == KEY_ESCAPE:
			_rest_leave()
		else:
			_act("REST")
		return
	if _mode == "order" and key in [KEY_ENTER, KEY_KP_ENTER]:
		# ORDER's loop (GAME.OVR 0x19056) takes Enter as S / P whatever word is lit: SELECT or PLACE, the light kept
		# (main chat 159, DOSBox at 3:0's camp: ALTER ORDER '.' (EXIT lit) Enter: BROTHER SEAN HAS BEEN SELECTED, PLACE
		# EXIT with EXIT lit). Ours took EXIT.
		var keep := _pick
		_act(items[0])
		_pick = keep
		_refresh()
		return
	var choice := ""
	if key in [KEY_ENTER, KEY_KP_ENTER]:
		choice = items[EclVM.menu_lit(items.size())]
	elif key == KEY_ESCAPE:
		# Esc is EXIT where the menu has one; at a YES NO question it does nothing (main chat 95, DOSBox at 3:0: DROP
		# FROM PARTY?, QUIT TO DOS, LOSE IT?, MEMORIZE THESE SPELLS?; checks 322-324).
		choice = "EXIT" if "EXIT" in items else ""
		if _mode == "save":
			# Chat 88 (DOSBox): Esc at SAVE WHICH GAME saves nothing, then asks QUIT TO DOS with NO lit,
			# as after a save; NO comes back to the camp menu with VIEW lit.
			_mode = "quit"
			_pick = 1
			_refresh()
			return
	else:
		for it in items:
			if _hot(it) == key:
				choice = it
	if choice == "":
		return
	_pick = items.find(choice)
	if _mode == "camp" and choice == "EXIT" and items.size() > CAMP_MENU.size():
		# The original's camp menu has no FIX: its EXIT is the 6th word, so the walking menu after it lights LOOK
		# (Combat Chat 57, DOSBox at 3:11; main chat 123's request). With FIX shown EXIT is the 7th, past the walking
		# menu's end (AREA lit): EXIT keeps the original's place.
		_pick = CAMP_MENU.find("EXIT")
	_act(choice)


func _act(choice: String) -> void:
	match _mode:
		"camp":
			match choice:
				"SAVE":
					if SaveListScreen.on():
						_open_save_list()
					else:
						_to_menu("save", SAVE_LETTERS)
				"VIEW":
					_sheet.open(_party, "PARTY", _sel, false, 1)
					_sheet.camp_look = not _walk
				"MAGIC":
					if spells != null:
						_magic_menu()
				"REST":
					Rememorize.refill(_party, spells)
					_rest_menu()
				"ALTER": _alter_menu()
				"FIX": _fix()
				"EXIT":
					visible = false
					_anim.stop()
					closed.emit()
		"save":
			# Lab: after saving, the original asks QUIT TO DOS (NO lit); NO comes back to
			# the camp menu with VIEW lit (NO's place carried over).
			save_requested.emit(choice)
			_mode = "quit"
			_pick = 1
			_fire_fast = true
			_refresh()
		"quit":
			_fire_fast = false
			if choice == "YES":
				get_tree().quit()
				return
			_pick = 1
			_show_menu()
		"rest":
			match choice:
				# REST TIME 00:00:00: straight back, as EXIT (main chat 93, DOSBox: the camp menu with SAVE lit, or
				# MAGIC's menu with CAST lit); ours stayed in the REST menu. Check 313.
				# R keeps the light on REST (SAVE or CAST lit after), Enter where it was (main chat 159).
				"REST": _rest_leave() if _to_rest <= 0 else _start_rest()
				"DAYS": _field = 0
				"HOURS": _field = 1
				"MINS": _field = 2
				"INC": _change(1)
				"DEC": _change(-1)
				"EXIT":
					_pick = REST_MENU.size() - 1    # past the camp's and MAGIC's menus: SAVE or CAST lit
					_rest_leave()
			_refresh()
		"magic":
			match choice:
				"CAST": _open_list("cast")
				"MEMORIZE": _open_list("memorize")
				"SCRIBE": _open_list("scribe")
				"DISPLAY":
					_mode = "display"
					_display_top = 0
					_refresh()
				"REST":
					Rememorize.refill(_party, spells)
					_rest_menu("magic")
				"EXIT":
					_pick = MAGIC_MENU.size() - 1
					_last_target = null
					_show_menu()
			_refresh()
		"list":
			match choice:
				"NEXT", "PREV":
					_turn_page(1 if choice == "NEXT" else -1)
				"EXIT": _leave_list()
				_: _choose()
		"pending":
			_mode = "confirm"
			_pick = 1                # NO lit (lab)
			_refresh()
		"confirm":
			if _starting:
				# YES: memorized at once; NO: the same character's page again, nothing picked.
				if choice == "YES":
					learn_at_once(_who())
					_next_starter()
				else:
					_who().cancel_learning()
					_open_list("memorize")
				return
			if choice == "NO":
				if _list_kind == "scribe":
					_who().cancel_scribing()
				else:
					_who().cancel_learning()
			_magic_menu()
		"display":
			if choice == "NEXT":
				_display_top += DISPLAY_PAGE
				_refresh()
			elif choice == "PREV":
				_display_top = maxi(_display_top - DISPLAY_PAGE, 0)
				_refresh()
			else:
				_pick = 0
				_magic_menu()
		"whom":
			if choice == "SELECT" and _whom_off == -2:
				# Bug 19: cast on no one past the party's end: the spell is used up, nobody healed (DOSBox).
				_whom_off = 0
				_caster.forget(_cast_id)
				_sel = maxi(_party.find(_caster), 0)
				_back_to_list()
			elif choice == "SELECT" and _whom_off == 0:
				_cast(_party[_sel])
			else:
				# EXIT (or SELECT with no one lit: backs out, the spell kept): the list is built again, its last spell
				# lit, as after a cast (main chat 86, checks 252-253:
				# DOSBox, the adventure menu's and the camp's CAST, ENLARGE then EXIT: SLEEP lit below it).
				_whom_off = 0
				_sel = maxi(_party.find(_caster), 0)
				_back_to_list()
		"ask":
			if choice == "YES":
				_who().forget(_cast_id)
			_caster = _who()
			_back_to_list()
		"alter":
			match choice:
				"ORDER":
					_ordering = -1
					_to_menu("order", ["SELECT", "EXIT"])
				"DROP":
					if _party.size() > 1:
						_mode = "drop"
						_pick = 1        # NO lit (lab)
						_say_name(_who().name, "WILL BE GONE")
						_refresh()
				"SPEED":
					_show_speed()
				"ICON":
					if _icon_editor == null:
						_icon_editor = IconEditor.new()
						_icon_editor.finished.connect(func(_c: bool) -> void:
							_pick = 0        # IS THIS ICON OK? YES: ORDER lit (main chat 91, DOSBox)
							_refresh())
						add_child(_icon_editor)
					_icon_editor.open(GameData.find_game_path(), _who())
				"PICS":
					_pick = 0            # lab: MONSTERS lit, not carried over
					_to_menu("pics", ["MONSTERS", "PORTRAITS", "EXIT"])
				"EXIT":
					_pick = ALTER_MENU.size() - 1
					_show_menu()
		"order":
			match choice:
				"SELECT":
					_ordering = _sel
					_say_name(_who().name, "HAS BEEN SELECTED")
					_pick = 0
				"PLACE":
					# Main chat 73 (check 142, DOSBox): PLACE clears the message area, through EXIT.
					_ordering = -1
					_say_lines([])
					_pick = 0
				"EXIT":
					# Main chat 87 (check 261, DOSBox): EXIT at PLACE keeps "<NAME> / HAS BEEN SELECTED" and the
					# order so far; the message stays through the camp menu and ALTER again.
					_ordering = -1
					_pick = 1
					_alter_menu()
					return
			_refresh()
		"drop":
			# Main chat 87 (check 264, DOSBox, the screen read every 8 ms): NO clears the message area and
			# says nothing (no "BREATHES A SIGH OF RELIEF"); the member stays lit.
			if choice == "YES":
				_party.remove_at(_sel)
				_sel = mini(_sel, _party.size() - 1)
			_lines = []
			_pick = 1
			_alter_menu()
		"speed":
			match choice:
				"FASTER": speed = maxi(speed - 1, 0)
				"SLOWER": speed = mini(speed + 1, 9)
				"EXIT":
					_lines = []
					_pick = _speed_menu().size() - 1
					_alter_menu()
					return
			_show_speed()
		"pics":
			match choice:
				"MONSTERS": show_monsters = not show_monsters
				"PORTRAITS": show_portraits = not show_portraits
				"EXIT":
					_pick = 2
					_alter_menu()
					return
			_refresh()


## FASTER only above speed 0, SLOWER only below 9 (main chat 91, DOSBox: GAME SPEED: SLOWER EXIT at 0,
## FASTER SLOWER EXIT at 1, FASTER EXIT at 9; the light keeps its index).
func _speed_menu() -> Array:
	return (["FASTER"] if speed > 0 else []) + (["SLOWER"] if speed < 9 else []) + ["EXIT"]


func _show_speed() -> void:
	_mode = "speed"
	_plain_rope = true
	_say_lines([["", GameScreen.GREEN], ["GAME SPEED = %d (0=FASTEST 9=SLOWEST)" % speed, GameScreen.GREEN]])
	if _pick >= _speed_menu().size():
		_pick = 0
	_refresh()
