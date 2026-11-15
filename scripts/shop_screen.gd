class_name ShopScreen
extends Control
## The shop, as the original shows it (Jeremy, 2026-11-12: every screen matches the original;
## additions go on top as overlays). Two levels, as the lab showed them in New Phlan's arms shop:
##   the adventure screen (view, party list, text box) with BUY VIEW POOL APPRAISE EXIT; the
##     party list's selected member is the buyer (Up/Down);
##   BUY: a page headed SHOP, 19 items a page (name, price in gold at column 30), the selected
##     one white and the rest light green, menu "ITEMS: BUY NEXT PREV EXIT". It opens a line in,
##     on the second item (HAND AXE; PREV shows BATTLE AXE, the first); NEXT and PREV turn a
##     page (the last page ends on the last item).
##   Menus as everywhere: the hot letter, or Left/Right and Enter.
##   VIEW: the buyer's sheet, whose item menu offers SELL (CharacterSheet.in_shop)
##   POOL: the party's coins to the buyer
##   APPRAISE: the buyer's gems and jewellery, one at a time, as the original (lab and
##     GAME.OVR 0x26680, chat 8): "YOU HAVE A FINE COLLECTION OF:" n GEMS / n PIECES OF
##     JEWELRY, then GEMS JEWELRY EXIT; each appraised piece leaves the count, "THE GEM IS
##     VALUED AT n GP." (or JEWEL), then SELL (whole platinum for it, n / 5: the original
##     drops the rest) or KEEP (an item: type 70, weight 1, price n, "Gem" or "Jewelry").
##     Values by d100: a gem 10 (1-25), 50 (-50), 100 (-70), 500 (-90), 1000 (-99), 5000;
##     jewellery 100 + Random(900) (1-10), 200 + Random(1000) (-20), 300 + Random(1500)
##     (-40), 500 + Random(2500) (-50), 1000 + Random(5000) (-70), 2000 + Random(6000)
##     (-90), 2000 + Random(10000).
## Prices are in gold; the buyer pays from all their coins and the change comes back in
## platinum and gold, the part under a gold piece lost (PartyMember.pay_gold_in_shop;
## checked against the original: 140 gold - 80 = 12 platinum; lab chat 10, two more).
## After a purchase the original says nothing (lab, side chat 2, 2026-11-13: BUY on the SHOP page
## twice gave Thrender two hand axes, row 24 never changed). QoL (Jeremy: he bought two long
## swords without noticing): row 24 shows "BOUGHT <ITEM>" for a moment, with how many the buyer
## now carries when it's more than one. Refusals are the original's (GAME.OVR 0x7080-0x7136,
## Combat Chat 6): the money is checked first ("NOT ENOUGH MONEY."), then the buyer's load and item
## count ("OVERLOADED", main's PartyMember.can_take_item), and only then is the price paid.

signal closed

const PAGE := 19
const MENU := ["BUY", "VIEW", "POOL", "APPRAISE", "EXIT"]
const LIST_MENU := ["BUY", "NEXT", "PREV", "EXIT"]

var _items: Array[GameItem] = []
var _party: Array[PartyMember] = []
var _buyer := 0
var _flash_green := false   # the flash is the original's refusal, not our BOUGHT line
## The character sheet main uses, for VIEW (set by main).
var sheet: CharacterSheet
var _mode := "menu"      # menu, list, appraise (the collection), value (SELL / KEEP)
var _value := 0
var _jewel := false
var _rng := RandomNumberGenerator.new()
var _cursor := 1         # the selected item
var _top := 1            # the first item on the page
var _pick := 0           # the highlighted menu item
var _note := Label.new() # the text box's message (kept as a Label: the bot reads .text)
var _scr: GameScreen
var _flash := ""       # QoL: row 24's message after BUY on the SHOP page
var _flash_id := 0


func _init() -> void:
	_note.visible = false
	add_child(_note)


func open(items: Array[GameItem], party: Array[PartyMember], _title: String = "SHOP") -> void:
	_items = items
	_party = party
	_buyer = 0
	_mode = "menu"
	_pick = 0
	_note.text = ""
	_cursor = mini(1, maxi(items.size() - 1, 0))
	_top = _cursor
	_rng.randomize()
	if _scr == null:
		_fill(self, 0)
		var bg := ColorRect.new()
		bg.color = Color.BLACK
		_fill(bg, 0)
		add_child(bg)
		_scr = GameScreen.new()
		add_child(_scr)
	visible = true
	_refresh()


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
	if _scr == null:
		return
	if _mode == "list":
		_draw_list()
		return
	var menu: Array = MENU
	if _mode == "appraise":
		menu = ["GEMS", "JEWELRY", "EXIT"]
	elif _mode == "value":
		menu = ["SELL", "KEEP"]
	var lines := PackedStringArray()
	for l in _note.text.split("\n"):
		lines.append_array(GameScreen.wrap(l, 38))
	_scr.draw_walk(OverlayLook.last_view, _party, _buyer, "", lines, menu,
		false, false, _pick)


func _draw_list() -> void:
	_scr.clear()
	for c in 40:
		_scr.tile(c, 0, 22)
		_scr.tile(c, 23, 22)
	for r in range(1, 23):
		_scr.tile(0, r, 21)
		_scr.tile(39, r, 21)
	for p in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 23), Vector2i(39, 23)]:
		_scr.tile(p.x, p.y, 20)
	_scr.text(17, 1, "SHOP", GameScreen.WHITE)     # (lab: x 136, not centred)
	for i in PAGE:
		var k := _top + i
		if k >= _items.size():
			break
		var it := _items[k]
		var color := GameScreen.WHITE if k == _cursor else GameScreen.GREEN
		_scr.text(1, 4 + i, it.name.to_upper().left(26), color)
		var price := str(it.price)
		_scr.text(31 - price.length(), 4 + i, price, color)
	if _flash != "":
		_scr.text(0, 24, _flash, GameScreen.GREEN if _flash_green else GameScreen.YELLOW)
	else:
		_scr.text(0, 24, "ITEMS:", 13)
		_scr.menu_line(24, LIST_MENU, 7, _pick)
	_scr.update()


func _selected_index() -> int:
	return _cursor if _cursor >= 0 and _cursor < _items.size() else -1


func _buy() -> void:
	var i := _selected_index()
	if i < 0 or _party.is_empty():
		return
	var it := _items[i]
	var member := _party[_buyer]
	# GAME.OVR 0x7080-0x7136: the money first ("Not enough Money."), then the item is added
	# through 0x6F0D (refused as "OverLoaded" by 0x23795, main's PartyMember.can_take_item),
	# and only then paid for.
	if member.wealth_copper() < it.price * 200:
		_note.text = "NOT ENOUGH MONEY."
		_show_flash("NOT ENOUGH MONEY.", true)
		return
	if not member.can_take_item(it):
		_note.text = "OVERLOADED."
		_show_flash("OVERLOADED", true)
		return
	member.pay_gold_in_shop(it.price)
	member.items.append(it.copy())
	_note.text = ""
	var has := 0
	for own in member.items:
		if own.name == it.name:
			has += 1
	var name := it.name.to_upper()
	var tail := " (HAS %d)" % has if has > 1 else ""
	_show_flash("BOUGHT " + name.left(39 - 7 - tail.length()) + tail)


## Row 24 shows `text` in place of the menu for a moment (QoL; see the top). A refusal is the
## original's own message (GAME.OVR 0x712C / 0x6F2F through START.EXE 0xBA:0x1693, the routine
## that shows combat's "Magic On"): green, for the sheet's MESSAGE_TIME.
func _show_flash(text: String, refusal: bool = false) -> void:
	_flash = text
	_flash_green = refusal
	_flash_id += 1
	var id := _flash_id
	_refresh()
	if not is_inside_tree():
		return
	var t := CharacterSheet.MESSAGE_TIME if refusal else 1.2
	await get_tree().create_timer(t * CampScreen.delay_scale()).timeout
	if id == _flash_id and _flash != "":
		_flash = ""
		_refresh()


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
	_refresh()


func _change_buyer(step: int) -> void:
	if _party.is_empty():
		return
	_buyer = (_buyer + step + _party.size()) % _party.size()
	_note.text = ""
	_refresh()


func _reselect(i: int) -> void:
	if i < 0 or i >= _items.size():
		return
	_cursor = i
	if _cursor < _top or _cursor >= _top + PAGE:
		_top = clampi(_cursor, 0, maxi(_items.size() - PAGE, 0))
	_refresh()


func _page(step: int) -> void:
	if step > 0:
		_top = mini(_top + PAGE, maxi(_items.size() - PAGE, 0))
	else:
		_top = maxi(_top - PAGE, 0)
	_cursor = _top
	_refresh()


func _move(step: int) -> void:
	var c := clampi(_cursor + step, 0, maxi(_items.size() - 1, 0))
	_reselect(c)


func _exit() -> void:
	if _mode != "menu":
		_mode = "menu"
		_pick = clampi(_pick, 0, MENU.size() - 1)
		_note.text = ""
		_refresh()
		return
	visible = false
	closed.emit()


func _view() -> void:
	if sheet == null or _party.is_empty() or _mode != "menu":
		return
	if not sheet.closed.is_connected(_after_view):
		sheet.closed.connect(_after_view)
	sheet.open(_party, "SHOP", _buyer, true, 1, true)


func _after_view() -> void:
	if visible:
		_refresh()


# --- APPRAISE -----------------------------------------------------------------------------

func _appraise() -> void:
	if _party.is_empty():
		return
	var m := _party[_buyer]
	if m.money[5] == 0 and m.money[6] == 0:
		_mode = "menu"
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
	_note.text = "\n".join(lines)
	_pick = 0
	_refresh()


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
	_note.text = "THE %s IS VALUED AT %d GP." % ["JEWEL" if jewel else "GEM", _value]
	_pick = 0
	_refresh()
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
		_mode = "menu"
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
	if not visible or not event.is_pressed() or not event is InputEventKey:
		return
	_flash = ""          # a key brings the menu back at once
	var key := (event as InputEventKey).keycode
	var items: Array = MENU
	match _mode:
		"list": items = LIST_MENU
		"appraise": items = ["GEMS", "JEWELRY", "EXIT"]
		"value": items = ["SELL", "KEEP"]
	var choice := ""
	if key == KEY_ENTER or key == KEY_KP_ENTER:
		choice = items[_pick]
	elif key == KEY_LEFT or key == KEY_RIGHT:
		_pick = (_pick + (1 if key == KEY_RIGHT else -1) + items.size()) % items.size()
		_refresh()
	elif key in [KEY_UP, KEY_DOWN, KEY_HOME, KEY_END, KEY_KP_7, KEY_KP_1]:
		# The original moves through lists and the party with Home and End (keypad 7 and 1).
		var step := 1 if key in [KEY_DOWN, KEY_END, KEY_KP_1] else -1
		if _mode == "list":
			_move(step)
		elif _mode == "menu":
			_change_buyer(step)
	elif key == KEY_ESCAPE:
		choice = "EXIT"
	else:
		for it in items:
			if String(it).unicode_at(0) == key:
				choice = it
	get_viewport().set_input_as_handled()
	if choice == "":
		return
	# The chosen item stays highlighted, and the index carries over to the next menu
	# (lab, chat 10: EXIT, the fourth of the list's menu, leaves APPRAISE, the fourth of the
	# shop's, highlighted).
	_pick = items.find(choice)
	match _mode:
		"menu":
			match choice:
				"BUY":
					_mode = "list"
					_refresh()
				"VIEW": _view()
				"POOL": _pool()
				"APPRAISE": _appraise()
				"EXIT": _exit()
		"list":
			match choice:
				"BUY": _buy()
				"NEXT": _page(1)
				"PREV": _page(-1)
				"EXIT": _exit()
		"appraise":
			match choice:
				"GEMS": appraise_one(false)
				"JEWELRY": appraise_one(true)
				"EXIT": _exit()
		"value":
			settle(choice == "SELL")
