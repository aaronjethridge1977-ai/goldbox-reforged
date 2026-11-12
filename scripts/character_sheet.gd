class_name CharacterSheet
extends Control
## The original's VIEW screen and its pages, drawn as the original draws them (Jeremy,
## 2026-11-12: every screen matches the original). Captured in the lab (chat 11, saves J, I,
## H and F) and matched pixel for pixel:
##
## The view page: the frame; the name light cyan at row 1; sex race AGE, alignment, class
## (white) rows 3-5; STR..CHA rows 7-12 (green); the money (jewelry, gems, platinum, gold,
## electrum, silver, copper: those held, the names right-aligned to column 20, green) from
## row 7; LEVEL and EXP row 15; AC THAC0 ENCUMBRANCE row 17; HP DAMAGE MOVEMENT row 18 (HP
## yellow below the maximum); WEAPON (the readied weapon) row 20, ARMOR row 21, STATUS row 22.
## The portrait in its own frame at the top right only from the party menu (training hall);
## the walking screen's and the camp's VIEW show none. Menu "VIEW:" (magenta) ITEMS SPELLS
## TRADE DROP EXIT; SPELLS only for someone with spells in memory.
##
## Menus as everywhere: the hot letter, or Left/Right and Enter; the chosen item's place
## carries over to the next menu (from the walking screen's VIEW, the third item is lit),
## an index past the end lights the first.
##
## ITEMS: "<NAME>'S ITEMS" (name cyan, ITEMS green), rope across at row 2, "READY ITEM" row 3,
##   the items from row 5 (YES/NO at column 2, the name at 7; the chosen one white). Menu
##   READY USE TRADE DROP HALVE JOIN EXIT (HALVE only with room for another item: fewer
##   than 16). READY toggles silently; refusals and other messages show on row 24 in green
##   for about 0.7 s (lab: MUST BE READIED, MUST BE UNREADIED, CAN'T HALVE THAT).
##   USE on a readied item with no power does nothing.
##   TRADE: the walking screen, "TRADE WITH WHOM?" (magenta) SELECT EXIT; Home/End choose.
##   DROP: "YOUR <ITEM> WILL BE GONE FOREVER" yellow at row 21, the chosen item green, menu
##   "DROP IT?" YES NO with NO lit.
## SPELLS: "<NAME>'S SPELLS IN MEMORY", rope at row 2, from row 5 the spells in memory in
##   their order, a level heading ("1ST LEVEL", magenta) wherever the level changes; the
##   spells at column 3, green, the last one white. Menu " EXIT".
## TRADE (money): the walking screen, "TRADE TO?" SELECT EXIT; then the view page with the
##   chosen coin white, "SELECT TYPE OF COIN" (magenta) EXIT; Home/End choose; Enter asks
##   "HOW MUCH <COIN> WILL YOU TRADE?" (green; digits white one column after); then back to
##   the coin choice, on the first. EXIT goes back to TRADE TO?, its EXIT to the view page.
## DROP (money): the coin choice at once, "HOW MUCH <COIN> WILL YOU DROP?"; more than held
##   drops all.
## In a shop (VIEW from the shop, which shows the portrait) the item menu is READY TRADE DROP
##   HALVE JOIN SELL ID EXIT: SELL offers half the price, "I'LL GIVE YOU n GOLD PIECES FOR
##   YOUR <item>" (yellow from row 21, wrapped at 37) / "IS IT A DEAL?" YES NO, paid in the
##   largest coins; a readied item can't be sold. ID: "FOR 200 GOLD PIECES I'LL IDENTIFY YOUR
##   <item>" / "IS IT A DEAL?"; NOT ENOUGH MONEY when short. What identifying reveals is not
##   built yet (the hidden parts of magic items' names).
## Not compared yet: the combat-only USE question and what using an item prints.

signal closed

## Set once by the game: the item types (slots, hands, classes) and spell table.
static var types: ItemTypes
static var spells: SpellTable
## Set by the game: the game folder (portraits).
static var game_path := ""

const MAGENTA := 13
const COIN_NAMES := ["COPPER", "SILVER", "ELECTRUM", "GOLD", "PLATINUM", "GEMS", "JEWELRY"]
const LEVEL_WORDS := ["1ST LEVEL", "2ND LEVEL", "3RD LEVEL", "4TH LEVEL", "5TH LEVEL",
	"6TH LEVEL", "7TH LEVEL", "8TH LEVEL", "9TH LEVEL"]
const MESSAGE_TIME := 0.7       # lab: a message stays about 0.7 s
const MAX_ITEMS := 16
const ID_PRICE := 200           # lab: "FOR 200 GOLD PIECES I'LL IDENTIFY YOUR BANDED MAIL"

var _people: Array[PartyMember] = []
var _index := 0
var _title := ""
var _mode := "view"      # view, items, spells, whom, coin_whom, coin, amount, confirm
var _cursor := 0         # the chosen item
var _pick := 0           # the lit menu item
var _pending := ""       # what whom/confirm/coin/amount are for: trade, drop, use, sell, coin_trade, coin_drop
var _target := 0         # member chosen for a trade
var _coin := 4           # the coin type chosen
var _coin_cursor := 0    # index into the coins held
var _amount := ""
var _note := ""          # the last thing said (also the bot's log)
var _message := ""       # shown on row 24 for MESSAGE_TIME
var _question := ""      # the confirm page's line at row 21
var _rng := RandomNumberGenerator.new()
var in_shop := false     # opened from a shop's VIEW: the item menu offers SELL
var portrait := false    # opened from the party menu: the portrait shows

var _scr: GameScreen
var _timer: Timer
var _rows: Array = []    # the screen as text (for the lab and the bot)
## The encumbrance shown: worked out when the sheet opens and after item changes, not
## after money changes (lab: trading 10 silver left ENCUMBRANCE 388 on the page).
var _enc := {}
## Kept for the lab's sheet= key and the bot: the screen as text, and the bottom line.
var _body := Label.new()
var _foot := Label.new()


func _init() -> void:
	_body.visible = false
	_foot.visible = false
	add_child(_body)
	add_child(_foot)


## Opens the sheet on people[start]. `pick`: the place of the menu item that opened it
## (the walking screen's VIEW is the third).
func open(people: Array[PartyMember], title: String, start: int = 0, shop: bool = false,
		pick: int = 0, with_portrait: bool = false) -> void:
	in_shop = shop
	portrait = with_portrait
	_people = people
	_title = title
	_index = clampi(start, 0, maxi(people.size() - 1, 0))
	_target = _index      # TRADE TO? / WITH WHOM? start on the last one chosen (lab)
	_mode = "view"
	_note = ""
	_message = ""
	_pick = pick
	_rng.randomize()
	_measure()
	if _scr == null:
		_build()
	visible = true
	_refresh()


func _build() -> void:
	ShopScreen._fill(self, 0)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	ShopScreen._fill(bg, 0)
	add_child(bg)
	_scr = GameScreen.new()
	add_child(_scr)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(func() -> void:
		_message = ""
		_refresh())
	add_child(_timer)


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


## The text of the screen (rows 0-24), for the lab and the bot.
func screen_text() -> String:
	var out := PackedStringArray()
	for r in _rows.size():
		var s: String = _rows[r]
		if s.strip_edges() != "":
			out.append("%2d|%s" % [r, s.rstrip(" ")])
	return "\n".join(out)


# --- drawing ---------------------------------------------------------------------------

func _t(col: int, row: int, s: String, color: int) -> void:
	_scr.text(col, row, s, color)
	if row >= 0 and row < _rows.size():
		var line: String = _rows[row]
		_rows[row] = line.left(col) + s + line.substr(mini(col + s.length(), line.length()))
		_rows[row] = (_rows[row] as String).left(40)


func _clear() -> void:
	_scr.clear()
	_rows = []
	for r in 25:
		_rows.append(" ".repeat(40))


func _frame(rope_row: int = -1, with_portrait: bool = false) -> void:
	var g := _scr
	for c in 40:
		g.tile(c, 0, 22)
		g.tile(c, 23, 22)
	for r in range(1, 23):
		g.tile(0, r, 21)
		g.tile(39, r, 21)
	for p in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 23), Vector2i(39, 23)]:
		g.tile(p.x, p.y, 20)
	if rope_row > 0:
		for c in range(1, 39):
			g.tile(c, rope_row, 22)
		g.tile(0, rope_row, 20)
		g.tile(39, rope_row, 20)
	if with_portrait:
		for c in range(27, 40):
			g.tile(c, 12, 22)
		for r in range(1, 12):
			g.tile(27, r, 21)
		for p in [Vector2i(27, 0), Vector2i(27, 12), Vector2i(39, 12)]:
			g.tile(p.x, p.y, 20)


## The coin types held, in the order the page lists them (jewelry first, copper last).
static func coins_held(m: PartyMember) -> Array[int]:
	var out: Array[int] = []
	for i in range(6, -1, -1):
		if m.money[i] > 0:
			out.append(i)
	return out


func _readied_in(m: PartyMember, slot: int) -> GameItem:
	if types == null:
		return null
	for it in m.items:
		if it.readied and types.slot(it.type) == slot:
			return it
	return null


func _draw_page(m: PartyMember, coin_lit: int = -1) -> void:
	var W := GameScreen.WHITE
	var G := GameScreen.GREEN
	var show_portrait := portrait and not m.is_monster and game_path != ""
	_frame(-1, show_portrait)
	if show_portrait:
		# The record keeps the choices 1-based (0xBB head, 0xBC body; checked on Thrender: 4, 1).
		var pic := CharacterCreator.portrait_for(game_path, (m.raw[0xBB] if m.raw.size() > 0xBC else 1) - 1,
			(m.raw[0xBC] if m.raw.size() > 0xBC else 1) - 1)
		if pic != null:
			_scr.img.blit_rect(pic, Rect2i(0, 0, 88, 88), Vector2i(224, 8))
	_t(1, 1, m.name, GameScreen.CYAN)
	if m.is_monster:
		_t(1, 3, "MONSTER", W)
	else:
		_t(1, 3, "%s %s AGE %d" % [m.gender, m.race, m.age], W)
		_t(1, 4, m.alignment, W)
		_t(1, 5, m.char_class.replace("MAGE", "MAGIC-USER"), W)
	var names := ["STR", "INT", "WIS", "DEX", "CON", "CHA"]
	for i in 6:
		var v := str(m.stats[i])
		if i == 0 and m.stats[0] == 18 and m.strength_exceptional > 0:
			v += "(%02d)" % (m.strength_exceptional % 100)
		_t(1, 7 + i, names[i], G)
		_t(5, 7 + i, v, G)
	var held := coins_held(m)
	for k in held.size():
		var name: String = COIN_NAMES[held[k]]
		var color := W if k == coin_lit else G
		_t(20 - name.length(), 7 + k, name, color)
		_t(21, 7 + k, str(m.money[held[k]]), color)
	var levels := PackedStringArray()
	for c in m.class_indices():
		levels.append(str(m.level_in(c)))
	_t(1, 15, "LEVEL", W)
	_t(7, 15, "/".join(levels) if not levels.is_empty() else "0", W)
	_t(17, 15, "EXP", W)
	_t(21, 15, str(m.experience), W)
	_t(1, 17, "AC", W)
	_t(4, 17, str(m.ac), G)
	_t(9, 17, "THAC0", W)
	_t(15, 17, str(m.thac0), G)
	_t(22, 17, "ENCUMBRANCE", W)
	_t(34, 17, str(_enc.get(m, m.encumbrance())), G)
	_t(1, 18, "HP", W)
	_t(4, 18, str(m.hp), GameScreen.YELLOW if m.hp < m.hp_max else G)
	_t(8, 18, "DAMAGE", W)
	_t(15, 18, PartyMember.dice_text(m.damage).to_upper(), G)
	_t(25, 18, "MOVEMENT", W)
	_t(34, 18, str(m.movement), G)
	var weapon := _readied_in(m, ItemTypes.SLOT_WEAPON)
	if weapon != null:
		_t(1, 20, "WEAPON", W)
		_t(8, 20, item_label(weapon).to_upper(), G)
	var armor := _readied_in(m, ItemTypes.SLOT_ARMOR)
	if armor != null:
		_t(2, 21, "ARMOR", W)
		_t(8, 21, item_label(armor).to_upper(), G)
	_t(1, 22, "STATUS", W)
	_t(8, 22, m.status_name(), G)


func _heading(m: PartyMember, what: String) -> void:
	_t(1, 1, m.name + "'S", GameScreen.CYAN)
	_t(m.name.length() + 4, 1, what, GameScreen.GREEN)


func _draw_items(m: PartyMember, cursor_lit: bool) -> void:
	_frame(2)
	_heading(m, "ITEMS")
	_t(1, 3, "READY", GameScreen.WHITE)
	_t(7, 3, "ITEM", GameScreen.WHITE)
	for i in mini(m.items.size(), MAX_ITEMS):
		var it := m.items[i]
		var color := GameScreen.WHITE if i == _cursor and cursor_lit and _message == "" else GameScreen.GREEN
		_t(2, 5 + i, "YES" if it.readied else "NO", color)
		_t(7, 5 + i, item_label(it).to_upper(), color)


func _spell_rows(m: PartyMember) -> Array:
	var rows := []
	var last := -1
	# The record keeps them last first (party_member.gd reads 0x2B down); the page lists
	# them in the record's own order.
	for k in range(m.memorized.size() - 1, -1, -1):
		var id := m.memorized[k]
		if id >= PartyMember.LEARNING:
			continue
		var lv := spells.level(id) if spells != null else 1
		if lv != last:
			rows.append([LEVEL_WORDS[clampi(lv - 1, 0, LEVEL_WORDS.size() - 1)], 0])
			last = lv
		rows.append([spells.name_of(id) if spells != null else str(id), id])
	return rows


func _draw_spells(m: PartyMember) -> void:
	_frame(2)
	_heading(m, "SPELLS IN MEMORY")
	var rows := _spell_rows(m)
	for i in rows.size():
		if 5 + i > 22:
			break
		if rows[i][1] == 0:
			_t(1, 5 + i, rows[i][0], MAGENTA)
		else:
			_t(3, 5 + i, String(rows[i][0]).to_upper(), GameScreen.WHITE if i == rows.size() - 1 else GameScreen.GREEN)
	_t(1, 24, "EXIT", GameScreen.WHITE)


## The walking screen with a prompt (TRADE WITH WHOM?, TRADE TO?) and SELECT EXIT.
func _draw_whom(prompt: String) -> void:
	_scr.draw_walk(OverlayLook.last_view, _people, _target, OverlayLook.last_place, PackedStringArray(),
		[], OverlayLook.last_wild, OverlayLook.last_overland, -1)
	_rows = []
	for r in 25:
		_rows.append(" ".repeat(40))
	_t(0, 24, prompt, MAGENTA)
	_menu(["SELECT", "EXIT"], prompt.length() + 1)
	for i in _people.size():
		_rows[4 + i] = " ".repeat(17) + _people[i].name


func _menu(items: Array, col: int) -> void:
	var lit := _pick if _pick < items.size() else 0
	_scr.menu_line(24, items, col, lit)
	var line: String = _rows[24]
	_rows[24] = line.left(col) + " ".join(items)


func _view_menu() -> Array:
	var items := ["ITEMS"]
	var m := _who()
	if _has_spells(m):
		items.append("SPELLS")
	items.append_array(["TRADE", "DROP", "EXIT"])
	return items


func _item_menu() -> Array:
	var m := _who()
	var room := m != null and m.items.size() < MAX_ITEMS
	if in_shop:
		return ["READY", "TRADE", "DROP"] + (["HALVE"] if room else []) + ["JOIN", "SELL", "ID", "EXIT"]
	return ["READY", "USE", "TRADE", "DROP"] + (["HALVE"] if room else []) + ["JOIN", "EXIT"]


func _current_menu() -> Array:
	match _mode:
		"view":
			return _view_menu() if _editable() else ["EXIT"]
		"items":
			return _item_menu()
		"spells", "coin":
			return ["EXIT"]
		"whom", "coin_whom":
			return ["SELECT", "EXIT"]
		"confirm":
			return ["YES", "NO"]
	return []


func _refresh() -> void:
	if _scr == null:
		return
	_clear()
	if _people.is_empty():
		_frame()
		_t(1, 1, "NOBODY TO SHOW", GameScreen.WHITE)
		_scr.update()
		return
	var m := _who()
	match _mode:
		"view":
			_draw_page(m)
			if _message == "":
				_t(0, 24, "VIEW:", MAGENTA)
				_menu(_current_menu(), 5)
		"items":
			_draw_items(m, true)
			if _message == "":
				_menu(_item_menu(), 0)
		"confirm":
			_draw_items(m, false)
			var q := GameScreen.wrap(_question, 37)   # lab: "...IDENTIFY" (33) then "YOUR BANDED MAIL"
			for i in q.size():
				_t(1, 21 + i, q[i], GameScreen.YELLOW)
			var prompt := {"drop": "DROP IT?", "sell": "IS IT A DEAL?", "id": "IS IT A DEAL?", "use": "USE IT?"}.get(_pending, "?") as String
			_t(0, 24, prompt, MAGENTA)
			_menu(["YES", "NO"], prompt.length() + 1)
		"spells":
			_draw_spells(m)
		"whom":
			_draw_whom("TRADE WITH WHOM?")
		"coin_whom":
			_draw_whom("TRADE TO?")
		"coin":
			_draw_page(m, _coin_cursor)
			_t(0, 24, "SELECT TYPE OF COIN", MAGENTA)
			_menu(["EXIT"], 20)
		"amount":
			_draw_page(m)
			var q := "HOW MUCH %s WILL YOU %s?" % [COIN_NAMES[_coin], "TRADE" if _pending == "coin_trade" else "DROP"]
			_t(0, 24, q, GameScreen.GREEN)
			_t(q.length() + 1, 24, _amount, GameScreen.WHITE)
	if _message != "":
		_t(0, 24, _message, GameScreen.GREEN)
	_scr.update()
	_body.text = screen_text()
	_foot.text = _rows[24].strip_edges() if _rows.size() > 24 else ""


## The original offers SPELLS to those with spells in memory.
func _has_spells(m: PartyMember) -> bool:
	if m == null:
		return false
	for id in m.memorized:
		if id < PartyMember.LEARNING:
			return true
	return false


func _caster() -> bool:
	return _has_spells(_who())


func _item() -> GameItem:
	var m := _who()
	return m.items[_cursor] if m != null and _cursor < m.items.size() else null


func _say(text: String) -> void:
	_note = text
	_message = text.left(40)
	if text != "" and _timer != null:
		_timer.start(MESSAGE_TIME)


func _measure() -> void:
	_enc.clear()
	for p in _people:
		_enc[p] = p.encumbrance()


func _after_change(items_changed: bool = true) -> void:
	for p in _people:
		p.recalculate(types)
	if items_changed:
		_measure()
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
		return "ALREADY USING " + item_label(blocking).to_upper()
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
		return ""     # lab: USE on readied armour does nothing
	if not wasted and not SpellCaster.castable_outside(spells, id):
		_pending = "use"
		_question = "THAT ITEM IS A COMBAT-ONLY ITEM..."
		_mode = "confirm"
		_pick = 1
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
	spend_use(m, it, id)


func _can_take(p: PartyMember, it: GameItem) -> bool:
	if p.items.size() >= MAX_ITEMS:
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

## The menu item a key picks: its hot letter, or Enter on the lit one ("" if neither).
func _chosen(event: InputEvent, key: int, items: Array) -> String:
	if event.is_action("ui_accept") and not items.is_empty():
		var lit := _pick if _pick < items.size() else 0
		return items[lit]
	for i in items.size():
		var s: String = items[i]
		if key == OS.find_keycode_from_string(s.substr(0, 1)):
			return s
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	if _message != "":
		_message = ""
		if _timer != null:
			_timer.stop()
	var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
	var cancel := event.is_action("ui_cancel")
	var items := _current_menu()
	if (event.is_action("ui_left") or event.is_action("ui_right")) and not items.is_empty() and _mode != "amount":
		var lit := _pick if _pick < items.size() else 0
		_pick = (lit + (1 if event.is_action("ui_right") else items.size() - 1)) % items.size()
		_refresh()
		return
	var choice := "EXIT" if cancel and _mode in ["view", "items", "spells"] else _chosen(event, key, items)
	if choice != "":
		_pick = items.find(choice)
	var m := _who()
	match _mode:
		"view":
			if key == KEY_HOME or key == KEY_END:
				if not _editable() and not _people.is_empty():     # the monsters' sheet (developer aid)
					_index = (_index + (1 if key == KEY_END else _people.size() - 1)) % _people.size()
			match choice:
				"EXIT":
					visible = false
					closed.emit()
					return
				"ITEMS":
					_mode = "items"
					_cursor = 0
				"SPELLS":
					_mode = "spells"
				"TRADE":
					_pending = "coin_trade"
					_mode = "coin_whom"
				"DROP":
					_pending = "coin_drop"
					_coin_cursor = 0
					_mode = "coin"
			_refresh()
		"spells":
			if choice == "EXIT":
				_mode = "view"
			_refresh()
		"items":
			var it := _item()
			if key == KEY_HOME and not m.items.is_empty():
				_cursor = (_cursor - 1 + m.items.size()) % m.items.size()
			elif key == KEY_END and not m.items.is_empty():
				_cursor = (_cursor + 1) % m.items.size()
			elif choice == "EXIT":
				_mode = "view"
			elif it == null:
				pass
			elif choice == "READY":
				_say(_ready_item(m, it))
			elif choice == "SELL":
				if not it.readied:
					_pending = "sell"
					_question = "I'LL GIVE YOU %d GOLD PIECES FOR YOUR %s" % [_sale_price(it), item_label(it).to_upper()]
					_mode = "confirm"
					_pick = 1
			elif choice == "ID":
				_pending = "id"
				_question = "FOR %d GOLD PIECES I'LL IDENTIFY YOUR %s" % [ID_PRICE, item_label(it).to_upper()]
				_mode = "confirm"
				_pick = 1
			elif choice == "USE":
				var r := _use_item(m, it, false)
				if r != "\u0001":
					_say(r)
			elif choice == "TRADE":
				if it.readied:
					_say("MUST BE UNREADIED")
				else:
					_pending = "trade"
					_mode = "whom"
			elif choice == "DROP":
				if it.readied:
					_say("MUST BE UNREADIED")
				else:
					_pending = "drop"
					_question = "YOUR %s WILL BE GONE FOREVER" % item_label(it).to_upper()
					_mode = "confirm"
					_pick = 1
			elif choice == "HALVE":
				_say(_halve(m, it))
			elif choice == "JOIN":
				_join(m, it)
			_after_change()
		"whom", "coin_whom":
			if key == KEY_HOME:
				_target = (_target - 1 + _people.size()) % _people.size()
			elif key == KEY_END:
				_target = (_target + 1) % _people.size()
			elif choice == "EXIT" or cancel:
				_mode = "items" if _pending == "trade" else "view"
			elif choice == "SELECT":
				var to := _people[_target]
				if _pending == "trade":
					var it := _item()
					if to != m and it != null:
						if not _can_take(to, it):
							_say("OVERLOADED")
						else:
							m.items.erase(it)
							to.items.append(it)
					_mode = "items"
				else:
					_coin_cursor = 0
					_mode = "coin"
			_after_change()
		"confirm":
			if choice == "YES":
				var it := _item()
				if _pending == "drop" and it != null:
					m.items.erase(it)
				elif _pending == "sell" and it != null:
					m.items.erase(it)
					m.receive_gold(_sale_price(it))
				elif _pending == "id" and it != null:
					# Lab: paid from all the coins (1000 gold, 2 platinum, 144 silver -> 163
					# platinum, 2 gold); with too little, NOT ENOUGH MONEY.
					if not m.pay_gold_in_shop(ID_PRICE):
						_say("NOT ENOUGH MONEY")
				elif _pending == "use" and it != null:
					_say(_use_item(m, it, true))
				_mode = "items"
			elif choice == "NO" or cancel:
				_mode = "items"
			_after_change()
		"coin":
			var held := coins_held(m)
			if key == KEY_HOME and not held.is_empty():
				_coin_cursor = (_coin_cursor - 1 + held.size()) % held.size()
			elif key == KEY_END and not held.is_empty():
				_coin_cursor = (_coin_cursor + 1) % held.size()
			elif event.is_action("ui_accept") and not held.is_empty():
				_coin = held[clampi(_coin_cursor, 0, held.size() - 1)]
				_amount = ""
				_mode = "amount"
			elif choice == "EXIT" or cancel:
				_mode = "coin_whom" if _pending == "coin_trade" else "view"
			_refresh()
		"amount":
			if cancel:
				_mode = "coin"
			elif key >= KEY_0 and key <= KEY_9 and _amount.length() < 5:
				_amount += str(key - KEY_0)
			elif key == KEY_BACKSPACE:
				_amount = _amount.left(-1)
			elif event.is_action("ui_accept"):
				var n := mini(int(_amount) if _amount != "" else 0, m.money[_coin])
				m.money[_coin] -= n
				if _pending == "coin_trade" and _people[_target] != m:
					_people[_target].money[_coin] += n
				_coin_cursor = 0
				_mode = "coin"
			_after_change(false)
