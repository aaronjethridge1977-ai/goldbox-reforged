class_name CharacterSheet
extends Control
## A combatant's sheet: abilities, AC, THAC0, damage, movement and readied gear.
##   Left/Right: previous/next   Esc: close
## For party characters it also shows what the original last worked out (the values
## cached in the save file), so the two can be compared at a glance.

signal closed

var _people: Array[PartyMember] = []
var _index := 0
var _title := ""
var _head: Label
var _body: Label
var _foot: Label


func open(people: Array[PartyMember], title: String) -> void:
	_people = people
	_title = title
	_index = 0
	if _head == null:
		_build()
	_refresh()
	visible = true


func _build() -> void:
	ShopScreen._fill(self, 0)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 0.97)
	ShopScreen._fill(bg, 0)
	add_child(bg)
	var box := VBoxContainer.new()
	ShopScreen._fill(box, 0)
	box.offset_left = 64
	box.offset_right = -64
	box.offset_top = 32
	box.offset_bottom = -32
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	_head = Label.new()
	_head.add_theme_font_size_override("font_size", 28)
	box.add_child(_head)
	_body = Label.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("font_size", 20)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	_body.add_theme_font_override("font", mono)
	box.add_child(_body)
	_foot = Label.new()
	_foot.add_theme_font_size_override("font_size", 16)
	_foot.modulate = Color(0.7, 0.75, 0.8)
	box.add_child(_foot)


func _refresh() -> void:
	if _people.is_empty():
		_head.text = _title
		_body.text = "Nobody to show."
		return
	var m := _people[_index]
	_head.text = m.name
	var lines := PackedStringArray()
	if m.is_monster:
		lines.append("MONSTER")
	else:
		lines.append("%s %s, %s, %s, age %d" % [m.gender, m.race, m.char_class, m.alignment, m.age])
	var str_text := str(m.stats[0])
	if m.stats[0] == 18 and m.strength_exceptional > 0:
		str_text = "18/%02d" % (m.strength_exceptional % 100) if m.strength_exceptional < 100 else "18/00"
	lines.append("")
	lines.append("STR %-6s INT %-3d WIS %-3d DEX %-3d CON %-3d CHA %d" % [str_text,
		m.stats[1], m.stats[2], m.stats[3], m.stats[4], m.stats[5]])
	lines.append("HP %d/%d   EXP %d" % [m.hp, m.hp_max, m.experience])
	lines.append("")
	lines.append("AC %d  (from behind %d)" % [m.ac, m.rear_ac])
	lines.append("THAC0 %d" % m.thac0)
	lines.append("DAMAGE %s  (against large: %s)" % [PartyMember.dice_text(m.damage), PartyMember.dice_text(m.damage_large)])
	lines.append("ATTACKS %s per round" % m.attacks_text())
	lines.append("MOVE %d   ENCUMBRANCE %d" % [m.movement, m.weight])
	if not m.is_monster:
		lines.append("")
		lines.append("Original (cached in the save): " + m.cached_text())
	lines.append("")
	lines.append("ITEMS")
	if m.items.is_empty():
		lines.append("  none")
	for it in m.items:
		var label := it.name if it.name != "" else "(item type %d)" % it.type
		if it.plus != 0:
			label += " %+d" % it.plus
		lines.append("  %s %s" % ["Yes" if it.readied else "No ", label])
	if not m.is_monster:
		lines.append("")
		lines.append("MONEY " + m.money_text())
	_body.text = "\n".join(lines)
	_foot.text = "%s   %d of %d    Left/Right: previous/next    Esc: close" % [_title, _index + 1, _people.size()]


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	if event.is_action("ui_cancel"):
		visible = false
		closed.emit()
	elif event.is_action("ui_left") and not _people.is_empty():
		_index = (_index + _people.size() - 1) % _people.size()
		_refresh()
	elif event.is_action("ui_right") and not _people.is_empty():
		_index = (_index + 1) % _people.size()
		_refresh()
	else:
		return
	get_viewport().set_input_as_handled()
