class_name PartyMenu
extends Control
## The party menu the scripts open with PROGRAM 0: the training halls (each room writes its
## class bits to 0x6DA8 first) and the start of the game. Pool of Radiance's items, in its
## order: CREATE NEW CHARACTER, DROP CHARACTER, MODIFY CHARACTER, TRAIN CHARACTER (only
## where a hall trains), VIEW CHARACTER, ADD CHARACTER TO PARTY, REMOVE CHARACTER FROM
## PARTY, SAVE CURRENT GAME, BEGIN ADVENTURING. Home/End (or Up/Down) pick the character;
## the first letter runs an item.
##
## Training follows PartyMember.training_plan/train: "<NAME> WILL BECOME:" with "A LEVEL n
## <CLASS>" lines, "DO YOU WISH TO TRAIN?" (Y/N), "CONGRATULATIONS...", and a magic-user who
## gained a level then picks one new spell.
## Removed characters wait in the roster (saved with the game) and ADD brings them back;
## DROP removes one for good. Not built yet: CREATE and MODIFY (character creation).

signal closed
signal save_requested

var party: Array[PartyMember] = []
var roster: Array[PartyMember] = []   # characters removed from the party
var hall_mask := 0                     # 0x6DA8: the classes this hall trains (0 = no training)
var tables: ClassTables
var spells: SpellTable

var _sel := 0
var _mode := "menu"                    # menu, confirm_train, confirm_drop, learn, add
var _plan: Array[int] = []
var _cursor := 0
var _list: Array[int] = []
var _head: Label
var _party_label: Label
var _items_label: Label
var _note: Label
var _menu: Label
var _sheet: CharacterSheet
var _rng := RandomNumberGenerator.new()


func open(members: Array[PartyMember], mask: int) -> void:
	party = members
	hall_mask = mask
	_sel = clampi(_sel, 0, maxi(party.size() - 1, 0))
	_rng.randomize()
	if _head == null:
		_build()
	_note.text = ""
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
	_head.add_theme_font_size_override("font_size", 26)
	_head.add_theme_color_override("font_color", Color8(85, 255, 85))
	box.add_child(_head)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	_party_label = Label.new()
	_party_label.add_theme_font_size_override("font_size", 20)
	_party_label.add_theme_font_override("font", mono)
	box.add_child(_party_label)
	_items_label = Label.new()
	_items_label.add_theme_font_size_override("font_size", 20)
	_items_label.add_theme_font_override("font", mono)
	_items_label.add_theme_color_override("font_color", Color8(85, 255, 85))
	box.add_child(_items_label)
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
	look.bodies = [_party_label, _items_label]
	look.note = _note
	look.menu = _menu
	add_child(look)
	_sheet = CharacterSheet.new()
	_sheet.visible = false
	add_child(_sheet)


func _refresh_party() -> void:
	var lines := PackedStringArray(["  %-16s AC  HP" % "NAME"])
	for i in party.size():
		var m := party[i]
		lines.append("%s %-16s %2d  %2d" % [">" if i == _sel else " ", m.name, m.ac, m.hp])
	_party_label.text = "\n".join(lines)


func _items() -> Array:
	var out := [["C", "CREATE NEW CHARACTER"], ["D", "DROP CHARACTER"], ["M", "MODIFY CHARACTER"]]
	if hall_mask > 0:
		out.append(["T", "TRAIN CHARACTER"])
	out.append_array([["V", "VIEW CHARACTER"], ["A", "ADD CHARACTER TO PARTY"],
		["R", "REMOVE CHARACTER FROM PARTY"], ["S", "SAVE CURRENT GAME"], ["B", "BEGIN ADVENTURING"]])
	return out


func _show_menu() -> void:
	_mode = "menu"
	_head.text = "PARTY"
	_refresh_party()
	var lines := PackedStringArray()
	for it in _items():
		lines.append(it[1])
	_items_label.text = "\n".join(lines)
	_menu.text = "CHOOSE A FUNCTION   (first letter; Home/End or ↑/↓ pick the character)"


func _who() -> PartyMember:
	return party[_sel] if _sel < party.size() else null


func _train() -> void:
	var m := _who()
	if m == null or tables == null:
		return
	var plan := m.training_plan(tables, hall_mask)
	if plan.has("error"):
		_note.text = plan.error
		return
	_plan.assign(plan.classes)
	var lines := PackedStringArray([m.name + " WILL BECOME:"])
	for i in _plan.size():
		var c := _plan[i]
		lines.append(("    A LEVEL %d %s" if i == 0 else "AND A LEVEL %d %s") % [m.level_in(c) + 1, ClassTables.CLASS_NAMES[c]])
	_items_label.text = "\n".join(lines)
	_note.text = ""
	_menu.text = "DO YOU WISH TO TRAIN?  Y/N"
	_mode = "confirm_train"


func _do_train() -> void:
	var m := _who()
	var learn := m.train(tables, spells, _plan, _rng)
	_note.text = "CONGRATULATIONS..."
	if learn and spells != null:
		_list = m.learnable_spells(spells)
		if not _list.is_empty():
			_cursor = 0
			_mode = "learn"
			_show_learn()
			return
	_show_menu()


func _show_learn() -> void:
	var lines := PackedStringArray(["LEARN WHICH SPELL?"])
	for i in _list.size():
		lines.append("%s %s" % [">" if i == _cursor else " ", spells.names[_list[i]].to_upper()])
	_items_label.text = "\n".join(lines)
	_menu.text = "↑/↓ choose   Enter learn"


func _show_add() -> void:
	var lines := PackedStringArray(["ADD WHICH CHARACTER?"])
	for i in roster.size():
		lines.append("%s %s" % [">" if i == _cursor else " ", roster[i].name])
	if roster.is_empty():
		lines.append("  (NO ONE IS WAITING)")
	_items_label.text = "\n".join(lines)
	_menu.text = "↑/↓ choose   Enter add   Esc back"


## What the screen shows below the party (for the lab's headless checks).
func screen_text() -> String:
	return "%s | %s | %s" % [_items_label.text if _mode != "menu" else "", _note.text, _menu.text]


func _pick(d: int) -> void:
	if party.is_empty():
		return
	_sel = (_sel + d + party.size()) % party.size()
	_refresh_party()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or _sheet.visible:
		return
	get_viewport().set_input_as_handled()
	var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
	var cancel := event.is_action("ui_cancel")
	var up := event.is_action("ui_up") or key == KEY_HOME
	var down := event.is_action("ui_down") or key == KEY_END
	var accept := event.is_action("ui_accept")
	match _mode:
		"menu":
			if up or down:
				_pick(-1 if up else 1)
				_note.text = ""
			elif key == KEY_T and hall_mask > 0:
				_train()
			elif key == KEY_V and _who() != null:
				_sheet.open(party, "PARTY", _sel)
			elif key == KEY_S:
				save_requested.emit()
				_note.text = "GAME SAVED."
			elif key == KEY_R and party.size() > 1:
				roster.append(party[_sel])
				party.remove_at(_sel)
				_sel = mini(_sel, party.size() - 1)
				_show_menu()
			elif key == KEY_A:
				_cursor = 0
				_mode = "add"
				_show_add()
			elif key == KEY_D and party.size() > 1:
				_menu.text = "DROP FROM PARTY? %s WILL BE GONE FOR GOOD.  Y/N" % _who().name
				_mode = "confirm_drop"
			elif key == KEY_C or key == KEY_M:
				_note.text = "CHARACTER CREATION: not built yet."
			elif key == KEY_B or cancel:
				visible = false
				closed.emit()
		"confirm_train":
			if key == KEY_Y:
				_do_train()
			elif key == KEY_N or cancel:
				_show_menu()
		"confirm_drop":
			if key == KEY_Y:
				party.remove_at(_sel)
				_sel = mini(_sel, party.size() - 1)
			_show_menu()
		"learn":
			if up:
				_cursor = (_cursor - 1 + _list.size()) % _list.size()
				_show_learn()
			elif down:
				_cursor = (_cursor + 1) % _list.size()
				_show_learn()
			elif accept:
				_who().spell_book[_list[_cursor] - 1] = 1
				_note.text = "%s LEARNS %s." % [_who().name, spells.names[_list[_cursor]].to_upper()]
				_show_menu()
		"add":
			if up and not roster.is_empty():
				_cursor = (_cursor - 1 + roster.size()) % roster.size()
				_show_add()
			elif down and not roster.is_empty():
				_cursor = (_cursor + 1) % roster.size()
				_show_add()
			elif accept and not roster.is_empty() and party.size() < 6:
				party.append(roster[_cursor])
				roster.remove_at(_cursor)
				_show_menu()
			elif cancel:
				_show_menu()
