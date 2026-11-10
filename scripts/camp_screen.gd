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
## Modern controls: Up/Down change the selected part of the rest time, Left/Right or
## D/H/M pick it, Enter or R rests, Esc stops resting or leaves. V views, S quick-saves.
## Not yet: MAGIC (memorizing spells, with C5), ALTER, and the full game clock (resting
## moves the hour on; minutes and days aren't kept yet).

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
var hours_passed := 0       # whole hours rested, for the caller's clock

var _head: Label
var _party_label: Label
var _time_label: Label
var _note: Label
var _menu: Label
var _timer: Timer
var _sheet: CharacterSheet
var _minute_carry := 0


func open(party: Array[PartyMember], period: int, percent: int) -> void:
	_party = party
	_period = period
	_percent = percent
	_rest_steps = 0
	_since_check = 0
	_to_rest = 0
	_resting = false
	hours_passed = 0
	_minute_carry = 0
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
	_timer = Timer.new()
	_timer.wait_time = 0.05
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_sheet = CharacterSheet.new()
	_sheet.visible = false
	add_child(_sheet)


func _refresh_party() -> void:
	var lines := PackedStringArray(["%-16s AC  HP  STATUS" % "NAME"])
	for m in _party:
		lines.append("%-16s %2d  %2d  %s" % [m.name, m.ac, m.hp, m.status_name()])
	_party_label.text = "\n".join(lines)


func _show_menu() -> void:
	_refresh_party()
	_time_label.text = ""
	_menu.text = "CAMP:  S save   V view   R rest   Esc exit        (MAGIC and ALTER: not built yet)"


func _rest_menu() -> void:
	_refresh_party()
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
		_minute_carry += 5
		if _minute_carry >= 60:
			_minute_carry -= 60
			hours_passed += 1
		if _rest_steps % STEPS_PER_HEAL == 0:
			_heal_day()
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


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or _sheet.visible:
		return
	get_viewport().set_input_as_handled()
	var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
	if _resting:
		if event.is_action("ui_cancel"):
			_stop_rest("RESTING STOPPED.")
		return
	var in_rest := _menu.text.begins_with("REST:")
	if not in_rest:
		if key == KEY_R:
			_note.text = ""
			_rest_menu()
		elif key == KEY_V:
			_sheet.open(_party, "PARTY")
		elif key == KEY_S:
			save_requested.emit()
			_note.text = "SAVED."
		elif event.is_action("ui_cancel") or key == KEY_E:
			visible = false
			closed.emit()
		return
	if event.is_action("ui_cancel"):
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
	elif event.is_action("ui_up") or key == KEY_I or key == KEY_EQUAL or key == KEY_KP_ADD:
		_change(1)
	elif event.is_action("ui_down") or key == KEY_MINUS or key == KEY_KP_SUBTRACT:
		_change(-1)
	elif event.is_action("ui_accept") or key == KEY_R:
		_start_rest()
