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
##   SAVE: "SAVE WHICH GAME:" A to J.
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
##     DISPLAY: "DISPLAY" (white, column 16, row 1), each member (cyan) from row 5, three rows
##     apart, the spell effects under them (column 2), EXIT.
##   ALTER: ORDER DROP SPEED ICON PICS EXIT.
##     ORDER: "PARTY ORDER:" SELECT EXIT; SELECT: "<NAME>" / "HAS BEEN SELECTED", PLACE EXIT,
##       and Home/End carry the selected member up and down the party.
##     DROP: "<NAME>" / "WILL BE GONE", "DROP FROM PARTY?" (yellow) YES NO with NO lit; NO:
##       "<NAME>" / "BREATHES A SIGH OF RELIEF".
##     SPEED: "GAME SPEED = n (0=FASTEST 9=SLOWEST)", "GAME SPEED:" FASTER SLOWER EXIT (4 at
##       the start).
##     ICON: the icon editor. PICS: "MONSTERS ON  PORTRAITS ON  EXIT", M and P switch them.
## Not yet seen in the original (drawn the same way as the rest, to check): the heal and
## memorized messages while resting, SCRIBE's list, "CAN'T BE CAST HERE", and a SAVE in the
## original's own format (SAVE writes our save file for now, whichever letter is chosen).
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

const STEPS_PER_HEAL := 288
const STEPS_PER_TICK := 12  # steps shown per timer tick (a day takes about 1.2 s)
const ANIM_UNIT := 0.11     # seconds per unit of a picture frame's delay (lab: 2 units, 0.22 s)
const MAGENTA := 13
const PROMPT := 14          # yellow

const CAMP_MENU := ["SAVE", "VIEW", "MAGIC", "REST", "ALTER", "EXIT"]
const MAGIC_MENU := ["CAST", "MEMORIZE", "SCRIBE", "DISPLAY", "REST", "EXIT"]
const ALTER_MENU := ["ORDER", "DROP", "SPEED", "ICON", "PICS", "EXIT"]
const SAVE_LETTERS := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
## The rest menu: [text, column, hot letter's place in the text].
const REST_MENU := [["REST", 0, 0], ["DAYS", 7, 2], ["HOURS", 12, 0], ["MINS", 18, 0],
	["INC", 25, 0], ["DEC", 29, 0], ["EXIT", 35, 0]]
const YES_NO := ["YES", "NO"]
const LEVEL_WORDS := ["1ST LEVEL", "2ND LEVEL", "3RD LEVEL", "4TH LEVEL", "5TH LEVEL"]
const LIST_TOP := 5

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
var _sel := 0                      # selected character
var _mode := "camp"   # camp save rest magic list pending confirm whom display alter order drop speed pics ask
var _pick := 0                     # the lit menu item
var _list_kind := ""               # memorize, cast, scribe
var _list: Array = []              # rows: [text, spell id or 0 for a heading]
var _cursor := 0
var _page := 0
var _cast_id := 0
var _caster: PartyMember = null    # while choosing whom a spell is cast on
var _rng2 := RandomNumberGenerator.new()
var _hour_steps := 0
var _ordering := -1                # ORDER: the member being moved, or -1
## The original prints some messages (a member's name and what happened, the game speed) with
## a routine that redraws the rope under the view without its knot at column 16; the knot
## comes back when the whole screen is drawn again (lab: ORDER, DROP, SPEED, a cast's result;
## not "THE PARTY MAKES CAMP..." or "RUDELY INTERRUPTED").
var _plain_rope := false
## ALTER's SPEED: 0 fastest .. 9 slowest (4 at the start); scales the pause after each message.
static var speed := 4
## ALTER's PICS.
static var show_monsters := true
static var show_portraits := true
var _icon_editor: IconEditor
var _scrolls: Array = []          # SCRIBE list: [item, record byte, spell id]
var _learn_timer := {}             # member -> steps until its next spell is memorized


## The pause after a message, as a factor of the normal one (speed 4).
static func delay_scale() -> float:
	return (speed + 1) / 5.0


func _init() -> void:
	_note.visible = false
	add_child(_note)


func open(party: Array[PartyMember], period: int, percent: int) -> void:
	_party = party
	_period = period
	_percent = percent
	_rest_steps = 0
	_since_check = 0
	_to_rest = 0
	_resting = false
	_sel = clampi(_sel, 0, maxi(party.size() - 1, 0))
	_rng2.randomize()
	minutes_passed = 0
	_rng.randomize()
	if _scr == null:
		_build()
	_mode = "camp"
	_plain_rope = false
	_pick = 3                    # carried over from ENCAMP (lab: REST lit)
	_say_lines([["", GameScreen.GREEN], ["THE PARTY MAKES CAMP...", GameScreen.GREEN]])
	visible = true
	_anim.start(_fire_delay(0))
	_refresh()


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
	_timer.wait_time = 0.05
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


func _next_fire() -> void:
	if not visible or _fire.is_empty():
		return
	_fire_frame = (_fire_frame + 1) % _fire.size()
	_anim.start(_fire_delay(_fire_frame))
	if _mode in ["camp", "save", "rest", "magic", "whom", "alter", "order", "drop", "speed", "pics", "ask"]:
		_refresh()


## For the bot's log: what the camp shows.
func state_text() -> String:
	return "CAMP %s | %s | %s" % [_mode, " / ".join(_party.map(func(m): return "%s %d" % [m.name, m.hp])), _note.text]


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
	for w in GameScreen.wrap(text, 38):
		lines.append([w, GameScreen.GREEN])
	_say_lines(lines)


func _refresh() -> void:
	if _scr == null or not visible:
		return
	match _mode:
		"list", "pending", "confirm":
			_draw_list()
		"display":
			_draw_display()
		_:
			_draw_walk()
	_scr.update()


func _draw_walk() -> void:
	var view: Image = _fire[_fire_frame] if not _fire.is_empty() else OverlayLook.last_view
	var who := _sel
	if _mode == "whom":
		who = _sel
	_scr.draw_walk(view, _party, who, (place + " CAMPING").strip_edges(), PackedStringArray(), [])
	if _plain_rope:
		_scr.tile(16, 16, 22)
	for i in mini(_lines.size(), 6):
		_scr.text(1, 17 + i, _lines[i][0], _lines[i][1])
	match _mode:
		"camp":
			_labelled("CAMP:", CAMP_MENU, 6)
		"save":
			_scr.text(0, 24, "SAVE WHICH GAME:", MAGENTA)
			_scr.menu_line(24, SAVE_LETTERS, 17, -1)
		"rest":
			_draw_rest()
		"magic":
			_scr.menu_line(24, MAGIC_MENU, 0, _pick)
		"whom":
			_labelled("CAST SPELL ON WHOM", ["SELECT", "EXIT"], 19)
		"alter":
			_labelled("ALTER:", ALTER_MENU, 7)
		"order":
			_labelled("PARTY ORDER:", ["PLACE" if _ordering >= 0 else "SELECT", "EXIT"], 13)
		"drop":
			_scr.text(0, 24, "DROP FROM PARTY?", PROMPT)
			_scr.menu_line(24, YES_NO, 17, _pick)
		"speed":
			_labelled("GAME SPEED:", ["FASTER", "SLOWER", "EXIT"], 12)
		"pics":
			var items := ["MONSTERS " + ("ON" if show_monsters else "OFF"),
				"PORTRAITS " + ("ON" if show_portraits else "OFF"), "EXIT"]
			var col := 0
			for i in items.size():
				_scr.menu_line(24, [items[i]], col, 0 if i == _pick else -1)
				col += items[i].length() + 2
		"ask":
			_scr.text(0, 24, "LOSE IT?", PROMPT)
			_scr.menu_line(24, YES_NO, 9, _pick)


func _labelled(label: String, items: Array, col: int) -> void:
	_scr.text(0, 24, label, MAGENTA)
	_scr.menu_line(24, items, col, _pick)


func _draw_rest() -> void:
	var minutes := _to_rest * 5
	var parts := [minutes / 1440, (minutes / 60) % 24, minutes % 60]
	_scr.text(1, 17, "REST TIME:", GameScreen.GREEN)
	for i in 3:
		var lit := i == _field and not _resting
		_scr.text(12 + 3 * i, 17, "%02d" % parts[i], GameScreen.WHITE if lit else GameScreen.GREEN)
		if i < 2:
			_scr.text(14 + 3 * i, 17, ":", GameScreen.GREEN)
	for i in REST_MENU.size():
		var it: Array = REST_MENU[i]
		var s: String = it[0]
		var hot: int = it[2]
		for k in s.length():
			var white: bool = k >= hot if i == _pick else k == hot
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


func _page_rows() -> int:
	return 11 if _list_kind == "memorize" else 17


func _draw_list() -> void:
	_plain_rope = false
	var m := _who()
	_page_frame([0, 2, 23] if _list_kind != "memorize" or _mode != "list" else [0, 2, 16, 23])
	var title: String = {"memorize": "SPELLS IN SPELL BOOK", "cast": "SPELLS IN MEMORY",
		"scribe": "SPELLS ON SCROLLS"}.get(_list_kind, "SPELLS IN SPELL BOOK")
	if _mode != "list":
		title = "SPELLS TO BE MEMORIZED"
	var who := "%s'S" % m.name
	_scr.text(1, 1, who, GameScreen.CYAN)
	_scr.text(2 + who.length(), 1, title, GameScreen.GREEN)
	var rows := _page_rows()
	for i in range(_page * rows, mini((_page + 1) * rows, _list.size())):
		var row: Array = _list[i]
		var r := LIST_TOP + i - _page * rows
		if row[1] == 0:
			_scr.text(1, r, row[0], MAGENTA)
		else:
			var lit := i == _cursor and _mode != "confirm"
			_scr.text(2 if _mode != "list" else 3, r, row[0], GameScreen.WHITE if lit else GameScreen.GREEN)
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
	match _mode:
		"list":
			_labelled("CHOOSE SPELL:", _list_menu(), 14)
		"pending":
			_scr.menu_line(24, ["EXIT"], 1, 0)
		"confirm":
			_scr.text(0, 24, "MEMORIZE THESE SPELLS?", PROMPT)
			_scr.menu_line(24, YES_NO, 23, _pick)


func _list_menu() -> Array:
	var items: Array = [{"memorize": "MEMORIZE", "cast": "CAST", "scribe": "SCRIBE"}[_list_kind]]
	if (_page + 1) * _page_rows() < _list.size():
		items.append("NEXT")
	if _page > 0:
		items.append("PREV")
	items.append("EXIT")
	return items


func _draw_display() -> void:
	_plain_rope = false
	_page_frame([0, 23])
	_scr.text(16, 1, "DISPLAY", GameScreen.WHITE)
	var r := LIST_TOP
	for m in _party:
		if r > 21:
			break
		_scr.text(1, r, m.name, GameScreen.CYAN)
		var any := false
		for a in m.affects:
			# Only spell effects are listed (lab: a fighter's other effects, racial ones and
			# the like, aren't shown; he shows BLESS alone).
			var n := spells.effect_name(int(a.effect))
			if n.begins_with("EFFECT ") or r + 1 > 22:
				continue
			r += 1
			_scr.text(2, r, n, GameScreen.GREEN)
			any = true
		if not any:
			r += 1
			_scr.text(1, r, " <NO SPELL EFFECTS>", GameScreen.GREEN)
		r += 2
	_scr.menu_line(24, ["EXIT"], 1, 0)


# --- Menus ----------------------------------------------------------------------------------

func _to_menu(mode: String, items: Array) -> void:
	_mode = mode
	_pick = clampi(_pick, 0, items.size() - 1)
	_refresh()


func _show_menu() -> void:
	_to_menu("camp", CAMP_MENU)


func _magic_menu() -> void:
	_to_menu("magic", MAGIC_MENU)


func _alter_menu() -> void:
	_ordering = -1
	_to_menu("alter", ALTER_MENU)


func _rest_menu() -> void:
	_mode = "rest"
	_resting = false
	_to_rest = 0
	if spells != null:
		var need := 0
		for m in _party:
			need = maxi(need, m.learn_minutes(spells))
		_to_rest = (need + 4) / 5
	_pick = clampi(_pick, 0, REST_MENU.size() - 1)
	if _pick in [1, 2, 3]:
		_field = _pick - 1
	_lines = []
	_refresh()


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
	_hour_steps = 0
	_learn_timer.clear()
	if spells != null:
		for m in _party:
			m.learn_hours = 0
			# The study hours; each spell's 15 minutes a level follow (_learn_step).
			m.learn_hours = m.learn_study_hours(spells)
	_lines = []
	_timer.start()
	_refresh()


## Resting stopped (Esc) or done: back to the camp menu, the clock moved on.
func _stop_rest() -> void:
	_resting = false
	_timer.stop()
	if minutes_passed > 0:
		time_passed.emit(minutes_passed)
		minutes_passed = 0
	_show_menu()


func _tick() -> void:
	for i in STEPS_PER_TICK:
		if _to_rest <= 0:
			_stop_rest()
			return
		_to_rest -= 1
		_rest_steps += 1
		minutes_passed += 5
		var news := SpellCaster.pass_time(_party, 5)
		if not news.is_empty():
			_say(news[news.size() - 1])
		if _rest_steps % STEPS_PER_HEAL == 0:
			_heal_day()
		_learn_step()
		if _period > 0:
			_since_check += 1
			if _since_check >= _period:
				_since_check = 0
				if _rng.randi_range(1, 100) <= _percent:
					_interrupt()
					return
	_refresh()


## "THE PARTY IS RUDELY INTERRUPTED!" for a moment, then the area's script takes over.
## Still resting until then (the bot waits on _resting).
func _interrupt() -> void:
	_timer.stop()
	_say_lines([["", GameScreen.GREEN], ["", GameScreen.GREEN], ["THE PARTY IS RUDELY INTERRUPTED!", GameScreen.WHITE]])
	_refresh()
	await get_tree().create_timer(1.5 * delay_scale()).timeout
	_resting = false
	_to_rest = 0
	visible = false
	_anim.stop()
	interrupted.emit()


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
			var pending := m.learning_spells()
			if not pending.is_empty():
				var id: int = pending[0]
				var k := m.memorized.find(id + PartyMember.LEARNING)
				m.memorized[k] = id
				_say_name(m.name, "HAS MEMORIZED %s" % spells.name_of(id))
			elif not m.scribe_pending().is_empty():
				var id := m.scribe_next()
				_say_name(m.name, "HAS SCRIBED %s" % spells.name_of(id))
			t = _next_learn_steps(m)
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


## 5-minute steps for the next spell to memorize, then to scribe: 15 minutes a level.
func _next_learn_steps(m: PartyMember) -> int:
	var pending := m.learning_spells()
	if pending.is_empty():
		pending = m.scribe_pending()
	return spells.level(pending[0]) * 3 if not pending.is_empty() else 0


## A full day's rest: everyone alive gains 1 HP; the unconscious wake.
func _heal_day() -> void:
	var any := false
	for m in _party:
		if m.status in [PartyMember.STATUS_OKAY, PartyMember.STATUS_UNCONSCIOUS, PartyMember.STATUS_DYING] \
				and m.hp < m.hp_max and not SpecialAffects.diseased(m):
			m.hp += 1
			m.status = PartyMember.STATUS_OKAY
			any = true
	if any:
		_say("THE WHOLE PARTY IS HEALED")


# --- MAGIC ----------------------------------------------------------------------------------

func _who() -> PartyMember:
	return _party[_sel]


## Builds a spell list by level: rows [text, id] with headings as [text, 0].
func _build_list(ids: Array, mark: String = "") -> void:
	_list = []
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
	_page = 0
	_cursor = -1
	for i in mini(_list.size(), _page_rows()):
		if _list[i][1] != 0:
			_cursor = i


func _open_list(kind: String) -> void:
	var m := _who()
	var ids: Array = []
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
		"scribe":
			if m.status != PartyMember.STATUS_OKAY:
				return
			_scrolls = m.scribable(spells)
			for row in _scrolls:
				ids.append(row[2])
	if ids.is_empty():
		return        # lab: SCRIBE with no scrolls, nothing happens
	_list_kind = kind
	_build_list(ids)
	_lines = []
	_mode = "list"
	_pick = 0
	_refresh()


func _open_pending() -> void:
	_build_list(_who().learning_spells(), "*")
	_mode = "pending"
	_refresh()


func _move_cursor(d: int) -> void:
	if _list.is_empty():
		return
	var i := _cursor
	for k in _list.size():
		i = (i + d + _list.size()) % _list.size()
		if _list[i][1] != 0:
			_cursor = i
			break
	_page = _cursor / _page_rows()
	_refresh()


func _choose() -> void:
	if _cursor < 0 or _cursor >= _list.size() or _list[_cursor][1] == 0:
		return
	var id: int = _list[_cursor][1]
	var m := _who()
	if _list_kind == "memorize":
		if m.slots_left(spells, spells.spell_class(id), spells.level(id)) > 0:
			m.memorized.append(id + PartyMember.LEARNING)
		_refresh()
	elif _list_kind == "scribe":
		# Marks (or unmarks) the scroll spell to be scribed while resting.
		for row in _scrolls:
			if row[2] == id:
				var it: GameItem = row[0]
				it.raw[row[1]] ^= 0x80
				_note.text = ("%s WILL BE SCRIBED" if it.raw[row[1]] > 0x80 else "%s WILL NOT BE SCRIBED") % spells.name_of(id).to_upper()
				break
		_refresh()
	elif _list_kind == "cast":
		_cast_id = id
		_caster = m
		if not SpellCaster.castable_outside(spells, id):
			_mode = "ask"
			_pick = 1
			_say_lines([["", GameScreen.GREEN], [spells.name_of(id), GameScreen.GREEN], ["CAN'T BE CAST HERE...", GameScreen.GREEN]])
			_refresh()
		elif SpellCaster.needs_member(spells, id):
			_mode = "whom"
			_pick = 0
			_lines = []
			_refresh()
		else:
			_cast(null)


func _cast(target: PartyMember) -> void:
	var lines := SpellCaster.cast_outside(spells, _caster, _cast_id, _party, target, _rng2)
	_sel = maxi(_party.find(_caster), 0)
	if lines.size() > 0:
		_say(lines[lines.size() - 1])
	if _mode != "whom":
		_mode = "whom"     # the result shows on the adventure screen
	_refresh()
	await get_tree().create_timer(1.0 * delay_scale()).timeout
	if not visible or _mode != "whom":
		return
	_lines = []
	if _caster.ready_spells().is_empty():
		_magic_menu()
	else:
		var keep := _cursor
		_build_list(_caster.ready_spells())
		_cursor = mini(keep, _list.size() - 1)
		while _cursor > 0 and _list[_cursor][1] == 0:
			_cursor -= 1
		_mode = "list"
		_pick = 0
		_refresh()


func _leave_list() -> void:
	if _list_kind == "memorize" and not _who().learning_spells().is_empty():
		_open_pending()
		return
	_pick = MAGIC_MENU.size() - 1
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
		"camp": return CAMP_MENU
		"save": return SAVE_LETTERS
		"rest": return REST_MENU.map(func(it): return it[0])
		"magic": return MAGIC_MENU
		"list": return _list_menu()
		"pending", "display": return ["EXIT"]
		"confirm", "drop", "ask": return YES_NO
		"whom": return ["SELECT", "EXIT"]
		"alter": return ALTER_MENU
		"order": return ["PLACE" if _ordering >= 0 else "SELECT", "EXIT"]
		"speed": return ["FASTER", "SLOWER", "EXIT"]
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
	get_viewport().set_input_as_handled()
	var key := (event as InputEventKey).keycode
	if _resting:
		if key == KEY_ESCAPE and not _timer.is_stopped():
			_stop_rest()
		return
	var items := _items()
	if items.is_empty():
		return
	var up := key in [KEY_HOME, KEY_KP_7, KEY_UP]
	var down := key in [KEY_END, KEY_KP_1, KEY_DOWN]
	if up or down:
		var step := 1 if down else -1
		if _mode == "rest":
			_pick = 4 if up else 5
			_change(1 if up else -1)
		elif _mode in ["list", "pending"]:
			_move_cursor(step)
		elif _mode in ["camp", "magic", "whom", "alter", "order"]:
			_pick_member(step)
		return
	if key == KEY_LEFT or key == KEY_RIGHT:
		var d := 1 if key == KEY_RIGHT else -1
		if _mode == "rest":
			_field = (_field + d + 3) % 3      # lab: Left/Right pick the field
		else:
			_pick = (_pick + d + items.size()) % items.size()
		_refresh()
		return
	var choice := ""
	if key in [KEY_ENTER, KEY_KP_ENTER]:
		choice = items[clampi(_pick, 0, items.size() - 1)]
	elif key == KEY_ESCAPE:
		choice = "EXIT" if "EXIT" in items else ("NO" if "NO" in items else "")
		if _mode == "save":
			_show_menu()
			return
	else:
		for it in items:
			if _hot(it) == key:
				choice = it
	if choice == "":
		return
	_pick = items.find(choice)
	_act(choice)


func _act(choice: String) -> void:
	match _mode:
		"camp":
			match choice:
				"SAVE": _to_menu("save", SAVE_LETTERS)
				"VIEW": _sheet.open(_party, "PARTY", _sel)
				"MAGIC":
					if spells != null:
						_magic_menu()
				"REST": _rest_menu()
				"ALTER": _alter_menu()
				"EXIT":
					visible = false
					_anim.stop()
					closed.emit()
		"save":
			save_requested.emit(choice)
			_pick = 0
			_show_menu()
		"rest":
			match choice:
				"REST": _start_rest()
				"DAYS": _field = 0
				"HOURS": _field = 1
				"MINS": _field = 2
				"INC": _change(1)
				"DEC": _change(-1)
				"EXIT":
					_pick = 3
					_show_menu()
			_refresh()
		"magic":
			match choice:
				"CAST": _open_list("cast")
				"MEMORIZE": _open_list("memorize")
				"SCRIBE": _open_list("scribe")
				"DISPLAY":
					_mode = "display"
					_refresh()
				"REST": _rest_menu()
				"EXIT":
					_pick = 2
					_show_menu()
			_refresh()
		"list":
			match choice:
				"NEXT":
					_page += 1
					_cursor = _page * _page_rows()
					_move_cursor(1)
					_move_cursor(-1)
				"PREV":
					_page -= 1
					_cursor = _page * _page_rows()
					_move_cursor(1)
				"EXIT": _leave_list()
				_: _choose()
		"pending":
			_mode = "confirm"
			_pick = 1                # NO lit (lab)
			_refresh()
		"confirm":
			if choice == "NO":
				_who().cancel_learning()
			_magic_menu()
		"display":
			_pick = 3
			_magic_menu()
		"whom":
			if choice == "SELECT":
				_cast(_party[_sel])
			else:
				_sel = maxi(_party.find(_caster), 0)
				_mode = "list"
				_pick = 0
				_refresh()
		"ask":
			if choice == "YES":
				_who().forget(_cast_id)
			_lines = []
			_magic_menu()
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
						_icon_editor.finished.connect(func(_c: bool) -> void: _refresh())
						add_child(_icon_editor)
					_icon_editor.open(GameData.find_game_path(), _who())
				"PICS":
					_pick = 0            # lab: MONSTERS lit, not carried over
					_to_menu("pics", ["MONSTERS", "PORTRAITS", "EXIT"])
				"EXIT":
					_pick = 4
					_show_menu()
		"order":
			match choice:
				"SELECT":
					_ordering = _sel
					_say_name(_who().name, "HAS BEEN SELECTED")
					_pick = 0
				"PLACE":
					_ordering = -1
					_lines = []
					_pick = 0
				"EXIT":
					_ordering = -1
					_lines = []
					_pick = 0
					_alter_menu()
					return
			_refresh()
		"drop":
			var m := _who()
			if choice == "YES":
				_party.remove_at(_sel)
				_sel = mini(_sel, _party.size() - 1)
				_lines = []
			else:
				_say_name(m.name, "BREATHES A SIGH OF RELIEF")
			_pick = 1
			_alter_menu()
		"speed":
			match choice:
				"FASTER": speed = maxi(speed - 1, 0)
				"SLOWER": speed = mini(speed + 1, 9)
				"EXIT":
					_lines = []
					_pick = 2
					_alter_menu()
					return
			_show_speed()
		"pics":
			match choice:
				"MONSTERS": show_monsters = not show_monsters
				"PORTRAITS": show_portraits = not show_portraits
				"EXIT":
					_pick = 4
					_alter_menu()
					return
			_refresh()


func _show_speed() -> void:
	_mode = "speed"
	_plain_rope = true
	_say_lines([["", GameScreen.GREEN], ["GAME SPEED = %d (0=FASTEST 9=SLOWEST)" % speed, GameScreen.GREEN]])
	_pick = clampi(_pick, 0, 2)
	_refresh()
