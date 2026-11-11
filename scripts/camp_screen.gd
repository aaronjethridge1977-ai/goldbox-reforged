class_name CampScreen
extends Control
## Encamp: the original's CAMP menu (SAVE VIEW MAGIC REST ALTER EXIT) and its rest.
##
## As the original does it (rules as documented by Pilgrim's reconstruction, checked in
## the lab: save J rested 24 hours in the Slums' "dirty room" and Bakshi and Phineas each
## went from 4 to 5 HP; 4 hours elsewhere gave nothing and were interrupted by orcs):
## - REST TIME is set in days, hours and minutes (minutes in fives). Resting runs in
##   5-minute steps.
## - Every 288 steps (24 hours) spent in this camp, everyone not dead gains 1 HP ("THE
##   WHOLE PARTY IS HEALED"); an unconscious character wakes with it. The count starts
##   again each time the party makes camp.
## - The area's "on rest" script sets how often rest may be interrupted: every `period`
##   steps, a d100 roll of `percent` or less ends it, and the area's "rest interrupted"
##   script runs (usually an encounter). The Slums: every 24 steps (2 hours), 24%; none on
##   an event square.
## - REST offers the time the party needs to memorize the spells picked under MAGIC
##   (see PartyMember "Spells"); while resting they are memorized one by one.
## - MAGIC: CAST MEMORIZE SCRIBE DISPLAY REST EXIT, for the selected character (screens
##   checked in the lab): MEMORIZE shows "<NAME>'S SPELLS IN SPELL BOOK" by level with
##   "CAN MEMORIZE:" and the free slots per level; leaving asks "MEMORIZE THESE SPELLS?"
##   over the "SPELLS TO BE MEMORIZED" (marked *). CAST shows "SPELLS IN MEMORY".
##   DISPLAY lists each character's spell effects ("<NO SPELL EFFECTS>").
## Modern controls: Up/Down (or Home/End) pick the character in the menus; in the rest
## time Up/Down change the selected part, Left/Right or D/H/M pick it, Enter or R rests,
## Esc stops resting or leaves. V views, S quick-saves. In a spell list Up/Down move,
## Enter chooses, Esc leaves.
## SCRIBE (MAGIC): a magic-user marks spells on their scrolls; resting copies them into the
## spell book after any memorizing, 15 minutes a level ("<NAME> HAS SCRIBED <SPELL>").
## ALTER: ORDER (move the chosen member up the party), DROP (gone for good, "DROP FROM
## PARTY?"), SPEED (message speed), ICON and PICS (not built yet).
## The game clock runs while resting (GameClock); the caller adds the minutes rested.

signal closed
signal save_requested
signal interrupted          # the area's "rest interrupted" script should run now

const STEPS_PER_HEAL := 288
const STEPS_PER_TICK := 12  # steps shown per timer tick (a day takes about 1.2 s)

var _party: Array[PartyMember] = []
var _period := 0
var _percent := 0
var _rest_steps := 0        # 5-minute steps rested in this camp (for healing)
var _since_check := 0       # steps since the last interruption check
var _to_rest := 0           # 5-minute steps still to rest
var _field := 1             # 0 days, 1 hours, 2 minutes
var _resting := false
var _rng := RandomNumberGenerator.new()
var minutes_passed := 0     # minutes rested since the camp opened, for the caller's clock

var _head: Label
var _party_label: Label
var _time_label: Label
var _note: Label
var _menu: Label
var _timer: Timer
var _sheet: CharacterSheet

var spells: SpellTable = null      # set by the game before opening
var _sel := 0                      # selected character
var _mode := "camp"                # camp rest magic list whom ask display
var _list_kind := ""               # memorize, cast, pending
var _list: Array = []              # rows: [text, spell id or 0 for a heading]
var _cursor := 0
var _ask_kind := ""                # memorize_confirm, lose
var _cast_id := 0
var _caster: PartyMember = null    # while choosing whom a spell is cast on
var _rng2 := RandomNumberGenerator.new()
var _hour_steps := 0
## ALTER's SPEED: 0 fastest .. 2 slowest; scales the pause after each message.
static var speed := 1
var _scrolls: Array = []          # SCRIBE list: [item, record byte, spell id]
var _learn_timer := {}             # member -> steps until its next spell is memorized


func open(party: Array[PartyMember], period: int, percent: int) -> void:
	_party = party
	_period = period
	_percent = percent
	_rest_steps = 0
	_since_check = 0
	_to_rest = 0
	_resting = false
	_sel = clampi(_sel, 0, maxi(party.size() - 1, 0))
	_mode = "camp"
	_rng2.randomize()
	minutes_passed = 0
	_rng.randomize()
	if _head == null:
		_build()
	_note.text = "THE PARTY MAKES CAMP..."
	_show_menu()
	visible = true


func _build() -> void:
	ShopScreen._fill(self, 0)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 0.97)
	ShopScreen._fill(bg, 0)
	add_child(bg)
	var box := VBoxContainer.new()
	ShopScreen._fill(box, 0)
	box.offset_left = 48
	box.offset_right = -48
	box.offset_top = 24
	box.offset_bottom = -24
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	_head = Label.new()
	_head.text = "CAMPING"
	_head.add_theme_font_size_override("font_size", 26)
	_head.add_theme_color_override("font_color", Color8(85, 255, 85))
	box.add_child(_head)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	_party_label = Label.new()
	_party_label.add_theme_font_size_override("font_size", 20)
	_party_label.add_theme_font_override("font", mono)
	box.add_child(_party_label)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 22)
	_time_label.add_theme_font_override("font", mono)
	box.add_child(_time_label)
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 20)
	_note.modulate = Color(1, 0.85, 0.4)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_note)
	_menu = Label.new()
	_menu.add_theme_font_size_override("font_size", 20)
	box.add_child(_menu)
	var look := OverlayLook.new()
	look.head = _head
	look.bodies = [_party_label, _time_label]
	look.note = _note
	look.menu = _menu
	add_child(look)
	_timer = Timer.new()
	_timer.wait_time = 0.05
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_sheet = CharacterSheet.new()
	_sheet.visible = false
	add_child(_sheet)


func _refresh_party() -> void:
	var lines := PackedStringArray(["  %-16s AC  HP  STATUS" % "NAME"])
	for i in _party.size():
		var m := _party[i]
		lines.append("%s %-16s %2d  %2d  %s" % [">" if i == _sel else " ", m.name, m.ac, m.hp, m.status_name()])
	_party_label.text = "\n".join(lines)


func _show_menu() -> void:
	_mode = "camp"
	_head.text = "CAMPING"
	_refresh_party()
	_time_label.text = ""
	_menu.text = "CAMP:  S save   V view   M magic   R rest   A alter   Esc exit"


func _alter_menu() -> void:
	_mode = "alter"
	_head.text = "ALTER"
	_refresh_party()
	_menu.text = "ALTER:  O order (move up)   D drop   S speed (%s)   I icon   P pics   Esc exit" % ["FAST", "MEDIUM", "SLOW"][speed]


func _rest_menu() -> void:
	_mode = "rest"
	_head.text = "CAMPING"
	_refresh_party()
	_to_rest = 0
	if spells != null:
		var need := 0
		for m in _party:
			need = maxi(need, m.learn_minutes(spells))
		_to_rest = (need + 4) / 5
	_show_time()
	_menu.text = "REST:  ←/→ or D/H/M pick days, hours or minutes   ↑/↓ more or less   Enter rest   Esc back"


func _show_time() -> void:
	var minutes := _to_rest * 5
	var parts := [minutes / 1440, (minutes / 60) % 24, minutes % 60]
	var text := "REST TIME: "
	for i in 3:
		var s := "%02d" % parts[i]
		text += ("[%s]" % s if i == _field and not _resting else s) + (":" if i < 2 else "")
	_time_label.text = text


func _change(sign: int) -> void:
	var step: int = [288, 12, 1][_field]
	_to_rest = clampi(_to_rest + sign * step, 0, 288 * 99)
	_show_time()


func _start_rest() -> void:
	if _to_rest <= 0:
		return
	_resting = true
	_hour_steps = 0
	_learn_timer.clear()
	if spells != null:
		for m in _party:
			m.learn_hours = 0
			var mins := m.learn_minutes(spells)
			if mins > 0:
				m.learn_hours = mins / 60
	_menu.text = "RESTING...   Esc: stop resting"
	_timer.start()


func _stop_rest(text: String) -> void:
	_resting = false
	_timer.stop()
	_note.text = text
	_rest_menu()


func _tick() -> void:
	for i in STEPS_PER_TICK:
		if _to_rest <= 0:
			_stop_rest(_note.text)
			return
		_to_rest -= 1
		_rest_steps += 1
		minutes_passed += 5
		SpellCaster.pass_time(_party, 5)
		if _rest_steps % STEPS_PER_HEAL == 0:
			_heal_day()
		_learn_step()
		if _period > 0:
			_since_check += 1
			if _since_check >= _period:
				_since_check = 0
				if _rng.randi_range(1, 100) <= _percent:
					_resting = false
					_timer.stop()
					_to_rest = 0
					visible = false
					interrupted.emit()
					return
	_show_time()
	_refresh_party()


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
				_note.text = "%s HAS MEMORIZED %s" % [m.name, spells.name_of(id)]
			elif not m.scribe_pending().is_empty():
				var id := m.scribe_next()
				_note.text = "%s HAS SCRIBED %s" % [m.name, spells.name_of(id)]
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
				and m.hp < m.hp_max:
			m.hp += 1
			m.status = PartyMember.STATUS_OKAY
			any = true
	_note.text = "THE WHOLE PARTY IS HEALED" if any else ""


# --- MAGIC --------------------------------------------------------------------------------

const LEVEL_WORDS := ["1ST LEVEL", "2ND LEVEL", "3RD LEVEL", "4TH LEVEL", "5TH LEVEL"]


func _magic_menu() -> void:
	_mode = "magic"
	_head.text = "CAMPING"
	_refresh_party()
	_time_label.text = ""
	_menu.text = "MAGIC:  C cast   M memorize   S scribe   D display   R rest   Esc exit"


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
		for id in by_level[l]:
			_list.append([mark + spells.name_of(id), id])
	_cursor = _list.size() - 1      # the original starts on the last spell


func _open_list(kind: String) -> void:
	var m := _who()
	_list_kind = kind
	var ids: Array = []
	match kind:
		"memorize":
			if m.status != PartyMember.STATUS_OKAY:
				_note.text = "%s IS IN NO CONDITION TO MEMORIZE SPELLS" % m.name
				return
			if not m.has_slots():
				_note.text = "%s CANNOT MEMORIZE ANY SPELLS" % m.name
				return
			for id in range(1, SpellTable.NAMED + 1):
				if m.knows(id) and spells.spell_class(id) <= 1 and spells.level(id) <= 3:
					ids.append(id)
			_head.text = "%s'S SPELLS IN SPELL BOOK" % m.name
		"cast":
			if m.status != PartyMember.STATUS_OKAY:
				_note.text = "%s IS IN NO CONDITION TO CAST ANY SPELLS" % m.name
				return
			ids = m.ready_spells()
			if ids.is_empty():
				_note.text = "%s HAS NO SPELLS MEMORIZED" % m.name
				return
			_head.text = "%s'S SPELLS IN MEMORY" % m.name
		"pending":
			ids = m.learning_spells()
			_head.text = "%s'S SPELLS TO BE MEMORIZED" % m.name
		"scribe":
			if m.status != PartyMember.STATUS_OKAY:
				_note.text = "%s IS IN NO CONDITION TO SCRIBE SPELLS" % m.name
				return
			_scrolls = m.scribable(spells)
			if _scrolls.is_empty():
				_note.text = "%s HAS NO SPELLS TO SCRIBE" % m.name
				return
			for row in _scrolls:
				ids.append(row[2])
			_head.text = "%s'S SPELLS ON SCROLLS" % m.name
	_build_list(ids, "*" if kind == "pending" else "")
	_note.text = ""
	_mode = "list"
	_show_list()


func _show_list() -> void:
	var lines := PackedStringArray()
	for i in _list.size():
		var row: Array = _list[i]
		if row[1] == 0:
			lines.append(row[0])
		else:
			lines.append(("> " if i == _cursor and _list_kind != "pending" else "  ") + row[0])
	if _list_kind == "memorize":
		lines.append("")
		lines.append(_who().name)
		lines.append("CAN MEMORIZE:")
		for c in 2:
			var counts := PackedStringArray()
			var any := false
			for l in range(1, 4):
				if _who().spell_slots[c][l - 1] > 0:
					any = true
					counts.append(str(_who().slots_left(spells, c, l)))
				else:
					counts.append(" ")
			if any:
				lines.append("    %s %s" % ["    CLERIC SPELLS:" if c == 0 else "MAGIC-USER SPELLS:", "  ".join(counts)])
	_party_label.text = "\n".join(lines)
	_time_label.text = ""
	match _list_kind:
		"memorize":
			_menu.text = "CHOOSE SPELL:  ↑/↓ move   Enter memorize   Esc exit"
		"cast":
			_menu.text = "CHOOSE SPELL:  ↑/↓ move   Enter cast   Esc exit"
		"pending":
			_menu.text = "MEMORIZE THESE SPELLS?  Y yes   N no"


func _move_cursor(d: int) -> void:
	if _list.is_empty():
		return
	var i := _cursor
	for k in _list.size():
		i = (i + d + _list.size()) % _list.size()
		if _list[i][1] != 0:
			_cursor = i
			break
	_show_list()


func _choose() -> void:
	if _cursor < 0 or _cursor >= _list.size() or _list[_cursor][1] == 0:
		return
	var id: int = _list[_cursor][1]
	var m := _who()
	if _list_kind == "memorize":
		if m.slots_left(spells, spells.spell_class(id), spells.level(id)) > 0:
			m.memorized.append(id + PartyMember.LEARNING)
		_show_list()
	elif _list_kind == "scribe":
		# Marks (or unmarks) the scroll spell to be scribed while resting.
		for row in _scrolls:
			if row[2] == id:
				var it: GameItem = row[0]
				it.raw[row[1]] ^= 0x80
				_note.text = ("%s WILL BE SCRIBED" if it.raw[row[1]] > 0x80 else "%s WILL NOT BE SCRIBED") % spells.name_of(id).to_upper()
				break
		_show_list()
	elif _list_kind == "cast":
		_cast_id = id
		_caster = m
		if not SpellCaster.castable_outside(spells, id):
			_mode = "ask"
			_ask_kind = "lose"
			_note.text = "%s\nCAN'T BE CAST HERE..." % spells.name_of(id)
			_menu.text = "LOSE IT?  Y yes   N no"
		elif SpellCaster.needs_member(spells, id):
			_mode = "whom"
			_head.text = "CAST SPELL ON WHOM"
			_refresh_party()
			_menu.text = "CAST SPELL ON WHOM:  ↑/↓ choose   Enter select   Esc exit"
		else:
			_cast(null)


func _cast(target: PartyMember) -> void:
	var lines := SpellCaster.cast_outside(spells, _caster, _cast_id, _party, target, _rng2)
	_sel = maxi(_party.find(_caster), 0)
	_note.text = "\n".join(lines)
	_magic_menu()


func _leave_list() -> void:
	if _list_kind == "memorize" and not _who().learning_spells().is_empty():
		_open_list("pending")
		return
	_magic_menu()


func _show_display() -> void:
	_mode = "display"
	_head.text = "DISPLAY"
	var lines := PackedStringArray()
	for m in _party:
		lines.append(m.name)
		var any := false
		for a in m.affects:
			lines.append("  " + spells.effect_name(int(a.effect)))
			any = true
		if not any:
			lines.append(" <NO SPELL EFFECTS>")
		lines.append("")
	_party_label.text = "\n".join(lines)
	_menu.text = "Esc exit"


func _pick(d: int) -> void:
	if _party.is_empty():
		return
	_sel = (_sel + d + _party.size()) % _party.size()
	_refresh_party()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or _sheet.visible:
		return
	get_viewport().set_input_as_handled()
	var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
	if _resting:
		if event.is_action("ui_cancel"):
			_stop_rest("RESTING STOPPED.")
		return
	var cancel := event.is_action("ui_cancel")
	var up := event.is_action("ui_up") or key == KEY_HOME
	var down := event.is_action("ui_down") or key == KEY_END
	match _mode:
		"camp":
			if up or down:
				_pick(-1 if up else 1)
			elif key == KEY_R:
				_note.text = ""
				_rest_menu()
			elif key == KEY_M and spells != null:
				_note.text = ""
				_magic_menu()
			elif key == KEY_V:
				_sheet.open(_party, "PARTY", _sel)
			elif key == KEY_S:
				save_requested.emit()
				_note.text = "SAVED."
			elif key == KEY_A:
				_note.text = ""
				_alter_menu()
			elif cancel or key == KEY_E:
				visible = false
				closed.emit()
		"alter":
			if up or down:
				_pick(-1 if up else 1)
			elif key == KEY_O and _sel > 0:
				var m: PartyMember = _party[_sel]
				_party.remove_at(_sel)
				_party.insert(_sel - 1, m)
				_sel -= 1
				_refresh_party()
			elif key == KEY_D and _party.size() > 1:
				_mode = "drop"
				_menu.text = "DROP FROM PARTY? %s WILL BE GONE FOR GOOD.  Y/N" % _who().name
			elif key == KEY_S:
				speed = (speed + 1) % 3
				_alter_menu()
			elif key == KEY_I or key == KEY_P:
				_note.text = "ICON and PICS: not built yet."
			elif cancel or key == KEY_E:
				_note.text = ""
				_show_menu()
		"drop":
			if key == KEY_Y:
				_party.remove_at(_sel)
				_sel = mini(_sel, _party.size() - 1)
			_alter_menu()
		"magic":
			if up or down:
				_pick(-1 if up else 1)
			elif key == KEY_C:
				_open_list("cast")
			elif key == KEY_M:
				_open_list("memorize")
			elif key == KEY_S:
				_open_list("scribe")
			elif key == KEY_D:
				_show_display()
			elif key == KEY_R:
				_note.text = ""
				_rest_menu()
			elif cancel or key == KEY_E:
				_note.text = ""
				_show_menu()
		"list":
			if _list_kind == "pending":
				if key == KEY_Y or event.is_action("ui_accept"):
					_magic_menu()
				elif key == KEY_N or cancel:
					_who().cancel_learning()
					_magic_menu()
			elif up:
				_move_cursor(-1)
			elif down:
				_move_cursor(1)
			elif event.is_action("ui_accept"):
				_choose()
			elif cancel or key == KEY_E:
				_leave_list()
		"whom":
			if up or down:
				_pick(-1 if up else 1)
			elif event.is_action("ui_accept"):
				_cast(_party[_sel])
			elif cancel:
				_sel = maxi(_party.find(_caster), 0)
				_magic_menu()
		"ask":
			if key == KEY_Y:
				_who().forget(_cast_id)
				_note.text = ""
				_magic_menu()
			elif key == KEY_N or cancel:
				_note.text = ""
				_magic_menu()
		"display":
			if cancel or event.is_action("ui_accept") or key == KEY_E:
				_magic_menu()
		"rest":
			if cancel:
				_note.text = ""
				_show_menu()
			elif key == KEY_D:
				_field = 0
				_show_time()
			elif key == KEY_H:
				_field = 1
				_show_time()
			elif key == KEY_M:
				_field = 2
				_show_time()
			elif event.is_action("ui_left"):
				_field = (_field + 2) % 3
				_show_time()
			elif event.is_action("ui_right"):
				_field = (_field + 1) % 3
				_show_time()
			elif up or key == KEY_I or key == KEY_EQUAL or key == KEY_KP_ADD:
				_change(1)
			elif down or key == KEY_MINUS or key == KEY_KP_SUBTRACT:
				_change(-1)
			elif event.is_action("ui_accept") or key == KEY_R:
				_start_rest()
