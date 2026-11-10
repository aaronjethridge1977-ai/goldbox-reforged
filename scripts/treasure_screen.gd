class_name TreasureScreen
extends Control
## After a won fight or a treasure find: the results, then the treasure on the ground.
##
## As the original shows it (checked in the lab after the Slums orcs): first "THE PARTY HAS
## WON." (or "THE PARTY HAS FOUND TREASURE!") and "EACH CHARACTER RECEIVES n EXPERIENCE
## POINTS."; then, if anything was left, the party list with VIEW TAKE POOL SHARE EXIT.
## TAKE picks money (a coin type, then how much) or items (the "LOOT" list); POOL puts
## everyone's money on the pile; SHARE splits the pile's money evenly (the remainder one
## coin at a time from the first character); EXIT with treasure left asks
## "THERE IS STILL TREASURE LEFT. DO YOU WANT TO GO BACK AND CLAIM YOUR TREASURE?".
## Modern controls, as in the shop: one list holds the pile's money and items.
##   Up/Down: choose   Enter or T: take   Left/Right: change character   V: view
##   P: pool   S: share   Esc or E: exit
## Not yet: the original's load and item-count limits when taking.

signal closed

const MONEY_LABELS := ["COPPER", "SILVER", "ELECTRUM", "GOLD", "PLATINUM", "GEMS", "JEWELRY"]

var _spoils: Spoils
var _party: Array[PartyMember] = []
var _who := 0
var _page := 0               # 0 results, 1 treasure
var _asking_exit := false
var _amount_coin := -1

var _head: Label
var _party_label: Label
var _list: Tree
var _note: Label
var _amount_box: HBoxContainer
var _amount_label: Label
var _amount: LineEdit
var _buttons: HBoxContainer
var _sheet: CharacterSheet


func open(spoils: Spoils, party: Array[PartyMember], won_text: String, share: int) -> void:
	_spoils = spoils
	_party = party
	_who = 0
	_page = 0
	_asking_exit = false
	_amount_coin = -1
	if _head == null:
		_build()
	_head.text = "%s\n\nEACH CHARACTER RECEIVES %d\nEXPERIENCE POINTS." % [won_text, share]
	_party_label.text = ""
	_list.visible = false
	_buttons.visible = false
	_amount_box.visible = false
	_note.text = "PRESS ENTER TO CONTINUE"
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
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	_head = Label.new()
	_head.add_theme_font_size_override("font_size", 26)
	_head.add_theme_color_override("font_color", Color8(85, 255, 85))
	box.add_child(_head)
	_party_label = Label.new()
	_party_label.add_theme_font_size_override("font_size", 20)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	_party_label.add_theme_font_override("font", mono)
	box.add_child(_party_label)
	_list = Tree.new()
	_list.columns = 1
	_list.hide_root = true
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_size_override("font_size", 20)
	_list.item_activated.connect(_take)
	box.add_child(_list)
	_amount_box = HBoxContainer.new()
	_amount_label = Label.new()
	_amount_label.add_theme_font_size_override("font_size", 20)
	_amount_box.add_child(_amount_label)
	_amount = LineEdit.new()
	_amount.custom_minimum_size = Vector2(160, 0)
	_amount.text_submitted.connect(_amount_entered)
	_amount_box.add_child(_amount)
	box.add_child(_amount_box)
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 18)
	_note.modulate = Color(1, 0.85, 0.4)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_note)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 16)
	box.add_child(_buttons)
	for spec in [["◀", _prev], ["VIEW", _view], ["TAKE", _take], ["POOL", _pool],
			["SHARE", _share], ["▶", _next], ["EXIT", _exit]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(spec[1])
		_buttons.add_child(b)
	_sheet = CharacterSheet.new()
	_sheet.visible = false
	add_child(_sheet)


func _show_treasure() -> void:
	_page = 1
	_head.text = "TREASURE"
	_list.visible = true
	_buttons.visible = true
	_note.text = ""
	_refresh()
	_list.grab_focus()
	_reselect(0)


func _refresh() -> void:
	var lines := PackedStringArray(["%-16s AC  HP" % "NAME"])
	for i in _party.size():
		var m := _party[i]
		lines.append("%s%-16s %2d  %2d" % ["> " if i == _who else "  ", m.name, m.ac, m.hp])
	_party_label.text = "\n".join(lines)
	_list.clear()
	var root := _list.create_item()
	for c in range(6, -1, -1):
		if _spoils.money[c] > 0:
			var row := _list.create_item(root)
			row.set_text(0, "%s %d" % [MONEY_LABELS[c], _spoils.money[c]])
			row.set_metadata(0, -1 - c)
	for i in _spoils.items.size():
		var row := _list.create_item(root)
		var it := _spoils.items[i]
		row.set_text(0, (it.name if it.name != "" else "(item type %d)" % it.type).to_upper())
		row.set_metadata(0, i)
	if not _spoils.has_treasure():
		var row := _list.create_item(root)
		row.set_text(0, "(nothing left)")
		row.set_metadata(0, null)
		row.set_selectable(0, false)


func _selected() -> Variant:
	var sel := _list.get_selected()
	return sel.get_metadata(0) if sel else null


func _reselect(i: int) -> void:
	var root := _list.get_root()
	if root == null or root.get_child_count() == 0:
		return
	root.get_child(clampi(i, 0, root.get_child_count() - 1)).select(0)


func _take() -> void:
	if _page != 1 or _party.is_empty():
		return
	var what: Variant = _selected()
	if what == null:
		return
	var m := _party[_who]
	if int(what) < 0:
		_amount_coin = -1 - int(what)
		_amount_label.text = "HOW MUCH %s WILL YOU TAKE? " % MONEY_LABELS[_amount_coin]
		_amount.text = str(_spoils.money[_amount_coin])
		_amount_box.visible = true
		_amount.grab_focus()
		_amount.select_all()
		return
	var it: GameItem = _spoils.items[int(what)]
	_spoils.items.remove_at(int(what))
	m.items.append(it)
	_note.text = "%s TAKES THE %s." % [m.name, it.name.to_upper()]
	var keep := _list.get_selected().get_index() if _list.get_selected() else 0
	_refresh()
	_reselect(keep)


func _amount_entered(text: String) -> void:
	if _amount_coin < 0:
		return
	var n := clampi(text.to_int(), 0, _spoils.money[_amount_coin])
	var m := _party[_who]
	m.money[_amount_coin] += n
	_spoils.money[_amount_coin] -= n
	_note.text = "%s TAKES %d %s." % [m.name, n, MONEY_LABELS[_amount_coin]]
	_amount_coin = -1
	_amount_box.visible = false
	_refresh()
	_list.grab_focus()
	_reselect(0)


func _pool() -> void:
	if _page != 1:
		return
	for m in _party:
		for c in 7:
			_spoils.money[c] += m.money[c]
			m.money[c] = 0
	_note.text = "THE PARTY'S MONEY IS POOLED."
	_refresh()
	_reselect(0)


## Splits the pile's money evenly; the remainder goes one coin at a time from the first
## character, as the original does it.
func _share() -> void:
	if _page != 1 or _party.is_empty():
		return
	var n := _party.size()
	for c in range(6, -1, -1):
		var each := _spoils.money[c] / n
		var rest := _spoils.money[c] % n
		for m in _party:
			m.money[c] += each
			if rest > 0:
				m.money[c] += 1
				rest -= 1
		_spoils.money[c] = 0
	_note.text = "THE MONEY IS SHARED."
	_refresh()
	_reselect(0)


func _view() -> void:
	if _page != 1 or _party.is_empty():
		return
	_sheet.open(_party, "PARTY", _who)


func _prev() -> void:
	if _party.is_empty():
		return
	_who = (_who + _party.size() - 1) % _party.size()
	_refresh_keep()


func _next() -> void:
	if _party.is_empty():
		return
	_who = (_who + 1) % _party.size()
	_refresh_keep()


func _refresh_keep() -> void:
	var keep := _list.get_selected().get_index() if _list.get_selected() else 0
	_refresh()
	_reselect(keep)


func _exit() -> void:
	if _page == 1 and _spoils.has_treasure() and not _asking_exit:
		_asking_exit = true
		_note.text = "THERE IS STILL TREASURE LEFT.  DO YOU WANT TO GO BACK AND CLAIM YOUR TREASURE?   Y / N"
		return
	_close()


func _close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or _sheet.visible:
		return
	var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
	if _amount_box.visible:
		if event.is_action("ui_cancel"):
			_amount_coin = -1
			_amount_box.visible = false
			_list.grab_focus()
			get_viewport().set_input_as_handled()
		return
	if _page == 0:
		if event.is_action("ui_accept") or event.is_action("ui_cancel"):
			if _spoils.has_treasure():
				_show_treasure()
			else:
				_close()
			get_viewport().set_input_as_handled()
		return
	if _asking_exit:
		if key == KEY_N:
			_close()
		elif key == KEY_Y or event.is_action("ui_cancel"):
			_asking_exit = false
			_note.text = ""
		get_viewport().set_input_as_handled()
		return
	if event.is_action("ui_cancel") or key == KEY_E:
		_exit()
	elif event.is_action("ui_left"):
		_prev()
	elif event.is_action("ui_right"):
		_next()
	elif key == KEY_T:
		_take()
	elif key == KEY_V:
		_view()
	elif key == KEY_P:
		_pool()
	elif key == KEY_S:
		_share()
	else:
		return
	get_viewport().set_input_as_handled()
