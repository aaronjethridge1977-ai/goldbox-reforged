class_name CharacterSheet
extends Control
## A combatant's sheet: abilities, AC, THAC0, damage, movement and gear. Left/Right: previous/
## next; Esc: close. For party characters it also shows what the original last worked out
## (the values cached in the save file), so the two can be compared at a glance.
##
## For the party (not monsters) it is the original's VIEW screen with its menu,
## ITEMS SPELLS TRADE DROP EXIT (Pool of Radiance's own words):
## - ITEMS: Up/Down pick an item; READY USE TRADE DROP HALVE JOIN, as the original:
##   READY (or unready): "IT'S CURSED" (a cursed item stays readied), "WRONG CLASS",
##   "ALREADY USING <item>" (one item per body slot, two rings, one stack of arrows and one
##   of quarrels), "YOUR HANDS ARE FULL!" (weapons and shield take at most two hands).
##   USE: "MUST BE READIED"; a wand, potion or other charged item casts its spell (record
##   byte 61; byte 60 counts the charges: a stack loses one piece, otherwise a charge, and
##   the item is gone at none); outside a fight a combat-only one says "THAT ITEM IS A
##   COMBAT-ONLY ITEM..." and asks "USE IT?" (yes wastes the charge); a scroll casts its
##   first spell for a cleric or magic-user.
##   TRADE and DROP: "MUST BE UNREADIED"; TRADE WITH WHOM? (a receiver with 16 items or more
##   than their load allowance + 1500 coins says "OVERLOADED"); DROP: "YOUR <item> WILL BE
##   GONE FOREVER" / "DROP IT?". HALVE splits a stack ("CAN'T HALVE THAT" for one piece);
##   JOIN gathers matching stacks into this one.
## - In a shop (VIEW from the shop) the item menu is READY TRADE DROP HALVE JOIN SELL ID EXIT,
##   as the original's: SELL offers half the price, "I'LL GIVE YOU n GOLD PIECES FOR YOUR
##   <item>" / "IS IT A DEAL?", paid in the largest coins; a readied item can't be sold
##   (the original doesn't react). Lab-checked: Two-Handed Sword (30) 15, Flail (3) 1. ID is
##   not built yet.
## - SPELLS lists the spells memorized and known. TRADE and DROP at the top move money:
##   TRADE TO? (another member), SELECT TYPE OF COIN, HOW MUCH WILL YOU TRADE? (or DROP).

signal closed

## Set once by the game: the item types (slots, hands, classes) and spell table.
static var types: ItemTypes
static var spells: SpellTable

var _people: Array[PartyMember] = []
var _index := 0
var _title := ""
var _head: Label
var _body: Label
var _foot: Label
var _mode := "view"      # view, items, spells, whom, confirm, coin, amount
var _cursor := 0
var _pending := ""       # what whom/confirm/coin/amount are for: trade, drop, use, coin_trade, coin_drop
var _target := 0         # member chosen for a trade
var _coin := 4
var _amount := ""
var _note := ""
var _rng := RandomNumberGenerator.new()
var in_shop := false       # opened from a shop's VIEW: the item menu offers SELL

const COIN_KEYS := {KEY_C: 0, KEY_S: 1, KEY_E: 2, KEY_G: 3, KEY_P: 4}


func open(people: Array[PartyMember], title: String, start: int = 0, shop: bool = false) -> void:
	in_shop = shop
	_people = people
	_title = title
	_index = clampi(start, 0, maxi(people.size() - 1, 0))
	_mode = "view"
	_note = ""
	_rng.randomize()
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
	var look := OverlayLook.new()
	look.head = _head
	look.bodies = [_body]
	look.note = null
	look.menu = _foot
	look.full = true
	add_child(look)


func _who() -> PartyMember:
	return _people[_index] if _index < _people.size() else null


func _editable() -> bool:
	var m := _who()
	return m != null and not m.is_monster and types != null


static func item_label(it: GameItem) -> String:
	var label := it.name if it.name != "" else "(item type %d)" % it.type
	if it.plus != 0 and not label.contains("+") and not label.contains("-"):
		label += " %+d" % it.plus
	if it.count > 1:
		# The cached name may carry the count from when the record was written.
		var words := label.split(" ", false, 1)
		if words.size() == 2 and words[0].is_valid_int():
			label = words[1]
		label = "%d %s" % [it.count, label]
	return label


func _refresh() -> void:
	if _people.is_empty():
		_head.text = _title
		_body.text = "Nobody to show."
		return
	var m := _who()
	_head.text = m.name + ("'S ITEMS" if _mode == "items" else "")
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
	lines.append("HP %d/%d   EXP %d   STATUS %s" % [m.hp, m.hp_max, m.experience, m.status_name()])
	lines.append("")
	lines.append("AC %d  (from behind %d)" % [m.ac, m.rear_ac])
	lines.append("THAC0 %d" % m.thac0)
	lines.append("DAMAGE %s  (against large: %s)" % [PartyMember.dice_text(m.damage), PartyMember.dice_text(m.damage_large)])
	lines.append("ATTACKS %s per round" % m.attacks_text())
	lines.append("MOVE %d   ENCUMBRANCE %d" % [m.movement, m.weight])
	if not m.is_monster and _mode == "view":
		lines.append("")
		lines.append("Original (cached in the save): " + m.cached_text())
	lines.append("")
	if _mode == "spells":
		lines.append("SPELLS MEMORIZED")
		for id in m.memorized:
			lines.append("  " + (spells.name_of(id) if spells != null else str(id)).to_upper())
		if m.memorized.is_empty():
			lines.append("  none")
	else:
		lines.append("ITEMS")
		if m.items.is_empty():
			lines.append("  none")
		for i in m.items.size():
			var it := m.items[i]
			var mark := ">" if _mode in ["items", "whom", "confirm"] and i == _cursor else " "
			lines.append("%s %s %s" % [mark, "YES" if it.readied else "NO ", item_label(it)])
	if not m.is_monster:
		lines.append("")
		lines.append("MONEY " + m.money_text())
	if _mode == "whom":
		lines.append("")
		lines.append("TRADE WITH WHOM?" if _pending == "trade" else "TRADE TO?")
		for i in _people.size():
			lines.append("%s %s" % [">" if i == _target else " ", _people[i].name])
	_body.text = "\n".join(lines)
	var nav := "%s   %d of %d    Left/Right: previous/next" % [_title, _index + 1, _people.size()]
	match _mode:
		"view":
			_foot.text = (_note + "\n" if _note != "" else "") + nav + \
				(("    VIEW: ITEMS %sTRADE DROP EXIT (first letter)" % ("SPELLS " if _caster() else "")) if _editable() else "    Esc: close")
		"items":
			_foot.text = (_note + "\n" if _note != "" else "") + ("↑/↓ item    READY  TRADE  DROP  HALVE  JOIN  SELL  ID  EXIT (first letter)" \
				if in_shop else "↑/↓ item    READY  USE  TRADE  DROP  HALVE  JOIN  EXIT (first letter)")
		"spells":
			_foot.text = "Esc: back"
		"whom":
			_foot.text = "↑/↓ choose   Enter trade   Esc back"
		"confirm":
			_foot.text = _note + "   Y/N"
		"coin":
			_foot.text = "SELECT TYPE OF COIN:  C copper  S silver  E electrum  G gold  P platinum   Esc back"
		"amount":
			_foot.text = "HOW MUCH WILL YOU %s?  %s_   (digits, Enter)" % ["TRADE" if _pending == "coin_trade" else "DROP", _amount]


## The original offers SPELLS only to those who cast them.
func _caster() -> bool:
	var m := _who()
	return m != null and (m.class_level(0) > 0 or m.class_level(1) > 0)


func _item() -> GameItem:
	var m := _who()
	return m.items[_cursor] if m != null and _cursor < m.items.size() else null


func _after_change() -> void:
	for p in _people:
		p.recalculate(types)
	var m := _who()
	_cursor = clampi(_cursor, 0, maxi(m.items.size() - 1, 0))
	_refresh()


# --- item actions ---------------------------------------------------------------------

func _ready_item(m: PartyMember, it: GameItem) -> String:
	if it.readied:
		if it.cursed:
			return "IT'S CURSED"
		it.readied = false
		return " / ".join(ItemPowers.changed(m, it, false))
	var slot := types.slot(it.type)
	var hands := 0
	var blocking: GameItem = null
	var rings := 0
	for o in m.items:
		if not o.readied or o == it:
			continue
		hands += types.hands(o.type)
		if o.type == it.type and (it.type == ItemTypes.TYPE_ARROW or it.type == ItemTypes.TYPE_QUARREL):
			blocking = o
		elif types.slot(o.type) == slot and slot <= 8:
			blocking = o
		elif types.slot(o.type) == 9 and slot == 9:
			rings += 1
			if rings >= 2:
				blocking = o
	if (m.class_flags & types.class_flags(it.type)) == 0:
		return "WRONG CLASS"
	if blocking != null:
		return "ALREADY USING " + item_label(blocking)
	if hands + types.hands(it.type) > 2:
		return "YOUR HANDS ARE FULL!"
	var no := ItemPowers.refuse(m, it)
	if no != "":
		return no
	it.readied = true
	return " / ".join(ItemPowers.changed(m, it, true))


func _is_scroll(it: GameItem) -> bool:
	var s := types.slot(it.type)
	return s >= 11 and s <= 13


func _use_item(m: PartyMember, it: GameItem, wasted: bool) -> String:
	if not it.readied:
		return "MUST BE READIED"
	var id := 0
	if _is_scroll(it):
		if m.class_level(0) == 0 and m.class_level(1) == 0:
			return "OOPS!"
		for k in [60, 61, 62]:
			if it.raw.size() > k and it.raw[k] & 0x7F > 0:
				id = it.raw[k] & 0x7F
				break
	elif it.raw.size() > 62 and it.raw[61] > 0 and it.raw[62] < 0x80:
		id = SpellTable.from_item(it.raw[61] & 0x7F)
	if id == 0 or spells == null:
		return "NOTHING HAPPENS..."
	if not wasted and not SpellCaster.castable_outside(spells, id):
		_pending = "use"
		_note = "THAT ITEM IS A COMBAT-ONLY ITEM...  USE IT?"
		_mode = "confirm"
		return "\u0001"
	var lines := PackedStringArray()
	if not wasted:
		lines = SpellCaster.cast_outside(spells, m, id, _people, m, _rng, true)
	_spend(m, it, id)
	return " / ".join(lines)


## The spell a readied item casts when used (a scroll: its first spell; a wand, potion or
## other charged item: record byte 61), 0 if none. Scrolls need a caster.
static func item_spell(m: PartyMember, it: GameItem) -> int:
	if types == null:
		return 0
	var slot := types.slot(it.type)
	if slot >= 11 and slot <= 13:
		if m.class_level(0) == 0 and m.class_level(1) == 0:
			return 0
		for k in [60, 61, 62]:
			if it.raw.size() > k and it.raw[k] & 0x7F > 0:
				return it.raw[k] & 0x7F
		return 0
	if it.raw.size() > 62 and it.raw[61] > 0 and it.raw[62] < 0x80:
		return SpellTable.from_item(it.raw[61] & 0x7F)
	return 0


static func spend_use(m: PartyMember, it: GameItem, id: int) -> void:
	var slot := types.slot(it.type) if types != null else 0
	if slot >= 11 and slot <= 13:
		for k in [60, 61, 62]:
			if it.raw[k] & 0x7F == id:
				it.raw[k] = 0
				break
		if it.raw[60] & 0x7F == 0 and it.raw[61] & 0x7F == 0 and it.raw[62] & 0x7F == 0:
			m.items.erase(it)
		return
	if it.raw[60] > 0:
		if it.count > 1:
			it.count -= 1
		else:
			it.raw[60] -= 1
			if it.raw[60] == 0:
				m.items.erase(it)


## A use spends a scroll's spell, a piece of a stack, or a charge (gone at none).
func _spend(m: PartyMember, it: GameItem, id: int) -> void:
	if _is_scroll(it):
		for k in [60, 61, 62]:
			if it.raw[k] & 0x7F == id:
				it.raw[k] = 0
				break
		if it.raw[60] & 0x7F == 0 and it.raw[61] & 0x7F == 0 and it.raw[62] & 0x7F == 0:
			m.items.erase(it)
		return
	if it.raw[60] > 0:
		if it.count > 1:
			it.count -= 1
		else:
			it.raw[60] -= 1
			if it.raw[60] == 0:
				m.items.erase(it)


func _can_take(p: PartyMember, it: GameItem) -> bool:
	if p.items.size() >= 16:
		return false
	return p.encumbrance() + it.total_weight() <= p.load_allowance() + 1500


## What a shop pays for an item: half its price.
static func _sale_price(it: GameItem) -> int:
	return it.price / 2


func _halve(m: PartyMember, it: GameItem) -> String:
	var half := it.count / 2
	if half <= 0:
		return "CAN'T HALVE THAT"
	var copy := GameItem.from_record(it.raw)
	copy.name = it.name
	copy.count = half
	copy.readied = false
	it.count -= half
	m.items.append(copy)
	return ""


func _join(m: PartyMember, it: GameItem) -> void:
	if it.count <= 0:
		return
	var keep: Array[GameItem] = []
	for o in m.items:
		if o != it and o.count > 0 and o.type == it.type and o.name == it.name and o.plus == it.plus \
				and o.cursed == it.cursed and o.weight == it.weight and o.raw.slice(60, 63) == it.raw.slice(60, 63) \
				and (o.raw[60] if o.raw.size() > 60 else 0) < 2:
			it.count += o.count
		else:
			keep.append(o)
	m.items = keep


# --- input -----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
	var cancel := event.is_action("ui_cancel")
	var m := _who()
	match _mode:
		"view":
			if cancel or (key == KEY_E and _editable()):
				visible = false
				closed.emit()
			elif event.is_action("ui_left") and not _people.is_empty():
				_index = (_index + _people.size() - 1) % _people.size()
				_note = ""
			elif event.is_action("ui_right") and not _people.is_empty():
				_index = (_index + 1) % _people.size()
				_note = ""
			elif not _editable():
				return
			elif key == KEY_I:
				_mode = "items"
				_cursor = 0
				_note = ""
			elif key == KEY_S and _caster():
				_mode = "spells"
			elif key == KEY_T or key == KEY_D:
				_pending = "coin_trade" if key == KEY_T else "coin_drop"
				_target = (_index + 1) % _people.size()
				_mode = "whom" if key == KEY_T else "coin"
			_refresh()
		"spells":
			if cancel:
				_mode = "view"
				_refresh()
		"items":
			var it := _item()
			if cancel or key == KEY_E:
				_mode = "view"
				_note = ""
			elif event.is_action("ui_up") and not m.items.is_empty():
				_cursor = (_cursor - 1 + m.items.size()) % m.items.size()
				_note = ""
			elif event.is_action("ui_down") and not m.items.is_empty():
				_cursor = (_cursor + 1) % m.items.size()
				_note = ""
			elif it == null:
				pass
			elif key == KEY_R:
				_note = _ready_item(m, it)
			elif key == KEY_S and in_shop:
				if not it.readied:
					_pending = "sell"
					_note = "I'LL GIVE YOU %d GOLD PIECES FOR YOUR %s.  IS IT A DEAL?" % [_sale_price(it), item_label(it)]
					_mode = "confirm"
			elif key == KEY_U and in_shop:
				pass
			elif key == KEY_U:
				var r := _use_item(m, it, false)
				if r != "\u0001":
					_note = r
				_after_change()
				return
			elif key == KEY_T or key == KEY_D:
				if it.readied:
					_note = "MUST BE UNREADIED"
				elif key == KEY_T:
					_pending = "trade"
					_target = (_index + 1) % _people.size()
					_mode = "whom"
				else:
					_pending = "drop"
					_note = "YOUR %s WILL BE GONE FOREVER.  DROP IT?" % item_label(it)
					_mode = "confirm"
			elif key == KEY_H:
				_note = _halve(m, it)
			elif key == KEY_J:
				_join(m, it)
				_note = ""
			_after_change()
		"whom":
			if cancel:
				_mode = "items" if _pending == "trade" else "view"
			elif event.is_action("ui_up"):
				_target = (_target - 1 + _people.size()) % _people.size()
			elif event.is_action("ui_down"):
				_target = (_target + 1) % _people.size()
			elif event.is_action("ui_accept"):
				var to := _people[_target]
				if _pending == "trade":
					var it := _item()
					if to != m and it != null:
						if not _can_take(to, it):
							_note = "OVERLOADED"
						else:
							m.items.erase(it)
							to.items.append(it)
							_note = ""
					_mode = "items"
				else:
					_mode = "coin"
			_after_change()
		"confirm":
			if key == KEY_Y:
				var it := _item()
				if _pending == "drop" and it != null:
					m.items.erase(it)
					_note = ""
				elif _pending == "sell" and it != null:
					m.items.erase(it)
					m.receive_gold(_sale_price(it))
					_note = ""
				elif _pending == "use" and it != null:
					_note = _use_item(m, it, true)
				_mode = "items"
			elif key == KEY_N or cancel:
				_note = ""
				_mode = "items"
			_after_change()
		"coin":
			if cancel:
				_mode = "view"
			elif COIN_KEYS.has(key):
				_coin = COIN_KEYS[key]
				_amount = ""
				_mode = "amount"
			_refresh()
		"amount":
			if cancel:
				_mode = "view"
			elif key >= KEY_0 and key <= KEY_9 and _amount.length() < 5:
				_amount += str(key - KEY_0)
			elif key == KEY_BACKSPACE:
				_amount = _amount.left(-1)
			elif event.is_action("ui_accept"):
				var n := mini(int(_amount) if _amount != "" else 0, m.money[_coin])
				m.money[_coin] -= n
				if _pending == "coin_trade" and _people[_target] != m:
					_people[_target].money[_coin] += n
				_mode = "view"
			_after_change()
