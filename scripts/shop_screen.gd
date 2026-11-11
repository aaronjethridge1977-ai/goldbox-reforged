class_name ShopScreen
extends Control
## The shop: the original's BUY VIEW POOL APPRAISE EXIT with modern controls.
##   Up/Down or mouse: choose an item    Enter or double-click / BUY: buy it
##   Left/Right: change buyer             P / POOL: gather the party's coins to the buyer
##   V / VIEW: the buyer's sheet, whose item menu offers SELL (CharacterSheet.in_shop)
##   A / APPRAISE: the buyer's gems and jewellery, one at a time, as the original (lab and
##     GAME.OVR 0x26680, chat 8): "YOU HAVE A FINE COLLECTION OF:" n GEMS / n PIECES OF
##     JEWELRY, then GEMS JEWELRY EXIT; each appraised piece leaves the count, "THE GEM IS
##     VALUED AT n GP." (or JEWEL), then SELL (whole platinum for it, n / 5: the original
##     drops the rest) or KEEP (an item: type 70, weight 1, price n, "Gem" or "Jewelry").
##     Values by d100: a gem 10 (1-25), 50 (-50), 100 (-70), 500 (-90), 1000 (-99), 5000;
##     jewellery 100 + Random(900) (1-10), 200 + Random(1000) (-20), 300 + Random(1500)
##     (-40), 500 + Random(2500) (-50), 1000 + Random(5000) (-70), 2000 + Random(6000)
##     (-90), 2000 + Random(10000).
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
## The character sheet main uses, for VIEW (set by main).
var sheet: CharacterSheet
var _mode := "buy"       # buy, appraise (the collection), value (SELL / KEEP)
var _value := 0
var _jewel := false
var _rng := RandomNumberGenerator.new()


func open(items: Array[GameItem], party: Array[PartyMember], title: String = "SHOP") -> void:
	_items = items
	_party = party
	_buyer = 0
	_mode = "buy"
	_rng.randomize()
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
	for spec in [["◀", _prev_buyer], ["BUY", _buy], ["VIEW", _view], ["POOL", _pool], ["APPRAISE", _appraise],
			["▶", _next_buyer], ["EXIT", _exit]]:
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
	if _mode != "buy":
		_mode = "buy"
		_note.text = ""
		_refresh()
		return
	visible = false
	closed.emit()


func _view() -> void:
	if sheet == null or _party.is_empty() or _mode != "buy":
		return
	if not sheet.closed.is_connected(_after_view):
		sheet.closed.connect(_after_view)
	sheet.open(_party, "SHOP", _buyer, true)


func _after_view() -> void:
	if visible:
		var i := _selected_index()
		_refresh()
		_reselect(i)
		_list.grab_focus()


# --- APPRAISE -----------------------------------------------------------------------------

func _appraise() -> void:
	if _party.is_empty():
		return
	var m := _party[_buyer]
	if m.money[5] == 0 and m.money[6] == 0:
		_mode = "buy"
		_note.text = "NO GEMS OR JEWELRY"
		return
	_mode = "appraise"
	_show_collection()


func _show_collection() -> void:
	var m := _party[_buyer]
	var lines := PackedStringArray(["YOU HAVE A FINE COLLECTION OF:"])
	if m.money[5] > 0:
		lines.append("%d GEM%s" % [m.money[5], "" if m.money[5] == 1 else "S"])
	if m.money[6] > 0:
		lines.append("%d PIECE%s OF JEWELRY" % [m.money[6], "" if m.money[6] == 1 else "S"])
	lines.append("APPRAISE :   G GEMS   J JEWELRY   E EXIT")
	_note.text = "\n".join(lines)


## Appraises one gem (or piece of jewellery): it leaves the count and is valued.
func appraise_one(jewel: bool) -> int:
	var m := _party[_buyer]
	var k := 6 if jewel else 5
	if m.money[k] <= 0:
		return -1
	m.money[k] -= 1
	_jewel = jewel
	_value = jewel_value(_rng) if jewel else gem_value(_rng)
	_mode = "value"
	_note.text = "THE %s IS VALUED AT %d GP.\nYOU CAN : S SELL   K KEEP" % ["JEWEL" if jewel else "GEM", _value]
	return _value


static func gem_value(rng: RandomNumberGenerator) -> int:
	var r := rng.randi_range(1, 100)
	if r <= 25:
		return 10
	if r <= 50:
		return 50
	if r <= 70:
		return 100
	if r <= 90:
		return 500
	if r <= 99:
		return 1000
	return 5000


static func jewel_value(rng: RandomNumberGenerator) -> int:
	var r := rng.randi_range(1, 100)
	for row in [[10, 100, 900], [20, 200, 1000], [40, 300, 1500], [50, 500, 2500], [70, 1000, 5000], [90, 2000, 6000]]:
		if r <= row[0]:
			return row[1] + rng.randi_range(0, row[2] - 1)
	return 2000 + rng.randi_range(0, 9999)


## SELL (true) or KEEP the piece just appraised.
func settle(sell: bool) -> void:
	var m := _party[_buyer]
	if sell:
		m.money[4] += _value / 5
	else:
		m.items.append(appraised_item(_jewel, _value))
	if m.money[5] > 0 or m.money[6] > 0:
		_mode = "appraise"
		_show_collection()
	else:
		_mode = "buy"
		_note.text = ""
	_refresh()


## The item KEEP makes, as the original's record: type 70, weight 1, price = the value,
## name word 101 (Gem) or 214 (Jewelry).
static func appraised_item(jewel: bool, value: int) -> GameItem:
	var rec := PackedByteArray()
	rec.resize(GameItem.SIZE)
	var name := "Jewelry" if jewel else "Gem"
	rec[0] = name.length()
	for i in name.length():
		rec[1 + i] = name.unicode_at(i)
	rec[46] = 70
	rec[49] = 214 if jewel else 101
	rec.encode_u16(55, 1)
	rec.encode_u16(58, mini(value, 65535))
	return GameItem.from_record(rec)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
	if _mode == "appraise":
		if key == KEY_G:
			appraise_one(false)
		elif key == KEY_J:
			appraise_one(true)
		elif key == KEY_E or event.is_action("ui_cancel"):
			_exit()
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if _mode == "value":
		if key == KEY_S:
			settle(true)
		elif key == KEY_K:
			settle(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action("ui_cancel"):
		_exit()
	elif key == KEY_V:
		_view()
	elif key == KEY_A:
		_appraise()
	elif event.is_action("ui_left"):
		_prev_buyer()
	elif event.is_action("ui_right"):
		_next_buyer()
	elif event is InputEventKey and (event as InputEventKey).keycode == KEY_P:
		_pool()
	else:
		return
	get_viewport().set_input_as_handled()
