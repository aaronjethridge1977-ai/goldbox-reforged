class_name ShopScreen
extends Control
## The shop: the original's BUY / POOL / EXIT flow with modern controls.
##   Up/Down or mouse: choose an item    Enter or double-click / BUY: buy it
##   Left/Right: change buyer             P / POOL: gather the party's coins to the buyer
##   Esc / EXIT: leave
## Prices are in gold; the buyer pays from all their coins and the change is regrouped
## into the largest coins (checked against the original: 140 gold - 80 = 12 platinum).

signal closed

var _items: Array[GameItem] = []
var _party: Array[PartyMember] = []
var _buyer := 0

var _list: Tree
var _who: Label
var _note: Label


func open(items: Array[GameItem], party: Array[PartyMember], title: String = "SHOP") -> void:
	_items = items
	_party = party
	_buyer = 0
	_build(title)
	_refresh()
	visible = true
	_list.grab_focus()
	var root := _list.get_root()
	if root != null and root.get_child_count() > 0:
		root.get_child(0).select(0)


func _build(title: String) -> void:
	for c in get_children():
		c.queue_free()
	_fill(self, 0)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 0.97)
	_fill(bg, 0)
	add_child(bg)
	var box := VBoxContainer.new()
	_fill(box, 0)
	box.offset_left = 48
	box.offset_right = -48
	box.offset_top = 24
	box.offset_bottom = -24
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 28)
	box.add_child(head)
	_list = Tree.new()
	_list.columns = 2
	_list.hide_root = true
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.set_column_expand(0, true)
	_list.set_column_expand(1, false)
	_list.set_column_custom_minimum_width(1, 140)
	_list.add_theme_font_size_override("font_size", 20)
	_list.item_activated.connect(_buy)
	box.add_child(_list)
	_who = Label.new()
	_who.add_theme_font_size_override("font_size", 20)
	box.add_child(_who)
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 18)
	_note.modulate = Color(1, 0.85, 0.4)
	box.add_child(_note)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	for spec in [["◀", _prev_buyer], ["BUY", _buy], ["POOL", _pool], ["▶", _next_buyer], ["EXIT", _exit]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(spec[1])
		buttons.add_child(b)
	var look := OverlayLook.new()
	look.head = head
	look.bodies = [_list, _who]
	look.note = _note
	look.menu = buttons
	add_child(look)


## Stretches a control over its parent. (set_anchors_preset alone keeps the control's
## old size in Godot 4, which left the shop squashed into a strip.)
static func _fill(c: Control, margin: int) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = margin
	c.offset_top = margin
	c.offset_right = -margin
	c.offset_bottom = -margin


func _refresh() -> void:
	_list.clear()
	var root := _list.create_item()
	var member: PartyMember = _party[_buyer] if not _party.is_empty() else null
	var wealth := member.wealth_copper() if member else 0
	for it in _items:
		var row := _list.create_item(root)
		row.set_text(0, it.name)
		row.set_text(1, str(it.price))
		row.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
		if it.price * 200 > wealth:
			row.set_custom_color(0, Color(0.55, 0.55, 0.55))
			row.set_custom_color(1, Color(0.55, 0.55, 0.55))
	if member:
		_who.text = "Buyer: %s   %s   (worth %d gold)   encumbrance %d" % [
			member.name, member.money_text(), wealth / 200, member.encumbrance()]
	else:
		_who.text = "No party loaded."


func _selected_index() -> int:
	var sel := _list.get_selected()
	if sel == null:
		return -1
	return sel.get_index()


func _buy() -> void:
	var i := _selected_index()
	if i < 0 or _party.is_empty():
		return
	var it := _items[i]
	var member := _party[_buyer]
	if not member.pay_gold(it.price):
		_note.text = "%s can't afford the %s (%d gold). POOL gathers the party's money." % [member.name, it.name, it.price]
		return
	member.items.append(it.copy())
	_note.text = "%s bought the %s." % [member.name, it.name]
	_refresh()
	_reselect(i)


func _pool() -> void:
	if _party.is_empty():
		return
	var to := _party[_buyer]
	for m in _party:
		if m == to:
			continue
		for c in 5:
			to.money[c] += m.money[c]
			m.money[c] = 0
	_note.text = "The party's money is pooled with %s." % to.name
	var i := _selected_index()
	_refresh()
	_reselect(i)


func _prev_buyer() -> void:
	_change_buyer(-1)


func _next_buyer() -> void:
	_change_buyer(1)


func _change_buyer(step: int) -> void:
	if _party.is_empty():
		return
	_buyer = (_buyer + step + _party.size()) % _party.size()
	var i := _selected_index()
	_note.text = ""
	_refresh()
	_reselect(i)


func _reselect(i: int) -> void:
	var root := _list.get_root()
	if root == null or i < 0 or i >= root.get_child_count():
		return
	root.get_child(i).select(0)


func _exit() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	if event.is_action("ui_cancel"):
		_exit()
	elif event.is_action("ui_left"):
		_prev_buyer()
	elif event.is_action("ui_right"):
		_next_buyer()
	elif event is InputEventKey and (event as InputEventKey).keycode == KEY_P:
		_pool()
	else:
		return
	get_viewport().set_input_as_handled()
