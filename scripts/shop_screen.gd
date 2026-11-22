class_name ShopScreen
extends Control
## The shop, as the original shows it (Jeremy, 2026-11-12: every screen matches the original;
## additions go on top as overlays). Two levels, as the lab showed them in New Phlan's arms shop:
##   the adventure screen (view, party list, text box) with BUY VIEW POOL APPRAISE EXIT; the
##     party list's selected member is the buyer (Up/Down);
##   BUY: a page headed SHOP, 19 items a page (name, price in gold at column 30), the selected
##     one white and the rest light green, menu "ITEMS: BUY NEXT PREV EXIT" (NEXT and PREV only
##     when they would move the list: _list_menu). It opens a line in,
##     on the second item (HAND AXE; PREV shows BATTLE AXE, the first); NEXT and PREV turn a
##     page (the last page ends on the last item).
##   Menus as everywhere: the hot letter, or Left/Right and Enter.
##   VIEW: the buyer's sheet, whose item menu offers SELL (CharacterSheet.in_shop)
##   POOL: the player characters' coins go on the shop's pile (CoinPile; GAME.OVR's shop loop
##     0x7212, Combat Chat 13 from Player 12's run): with money on it the menu is BUY VIEW TAKE POOL
##     SHARE APPRAISE EXIT; TAKE is the treasure's coin page (SELECT TYPE OF COIN, HOW MUCH ... WILL
##     YOU TAKE?), SHARE the treasure's split; leaving with money on the pile asks "AS YOU LEAVE THE
##     SHOPKEEPER SAYS, "EXCUSE ME BUT YOU HAVE LEFT SOME MONEY HERE."  DO YOU WANT TO GO BACK AND GET
##     YOUR MONEY?" (YES back to the menu, NO leaves it behind). The pile is emptied as a shop opens.
##   APPRAISE: the buyer's gems and jewellery, one at a time, as the original (lab and
##     GAME.OVR 0x26680, chat 8): "YOU HAVE A FINE COLLECTION OF:" n GEMS / n PIECES OF
##     JEWELRY, then GEMS JEWELRY EXIT; each appraised piece leaves the count, "THE GEM IS
##     VALUED AT n GP." (or JEWEL), then SELL (whole platinum for it, n / 5: the original
##     drops the rest) or KEEP (an item: type 70, weight 1, price n, "Gem" or "Jewelry").
##     Values by d100: a gem 10 (1-25), 50 (-50), 100 (-70), 500 (-90), 1000 (-99), 5000;
##     jewellery 100 + Random(900) (1-10), 200 + Random(1000) (-20), 300 + Random(1500)
##     (-40), 500 + Random(2500) (-50), 1000 + Random(5000) (-70), 2000 + Random(6000)
##     (-90), 2000 + Random(10000).
## Prices are in gold (GAME.OVR 0x7035): the buyer pays if his purse is worth the price, else the
## pile pays if it is; either way all its coins become its worth less the price, in platinum and
## gold (CoinPile.gold_of / set_gold: the worth rounded to the nearest gold piece; checked against
## the original: 140 gold - 80 = 12 platinum; lab chat 10, two more).
## After a purchase the original says nothing (lab, side chat 2, 2026-11-13: BUY on the SHOP page
## twice gave Thrender two hand axes, row 24 never changed). QoL (Jeremy: he bought two long
## swords without noticing): row 24 shows "BOUGHT <ITEM>" for a moment, with how many the buyer
## now carries when it's more than one. Refusals are the original's (GAME.OVR 0x7080-0x7136,
## Combat Chat 6): the money is checked first ("NOT ENOUGH MONEY."), then the buyer's load and item
## count ("OVERLOADED", main's PartyMember.can_take_item), and only then is the price paid.

signal closed

const PAGE := 19
const MENU := ["BUY", "VIEW", "POOL", "APPRAISE", "EXIT"]
const POOL_MENU := ["BUY", "VIEW", "TAKE", "POOL", "SHARE", "APPRAISE", "EXIT"]
const ASK_MENU := ["YES", "NO"]
const LIST_MENU := ["BUY", "NEXT", "PREV", "EXIT"]   # every item; row 24 shows _list_menu()

var _items: Array[GameItem] = []
## The original's list top (GAME.OVR DS:0x6B29): one for every list of the list routine 0x2D669, 1 at the program's
## start (0xE9D8), kept across shops and loads (main chat 103, p17a6). The BUY list reads and writes it.
static var list_top := 1
var _party: Array[PartyMember] = []
var _buyer := 0
var _flash_green := false   # the flash is the original's refusal, not our BOUGHT line
## The character sheet main uses, for VIEW (set by main).
var sheet: CharacterSheet
var _keep_ok := true     # APPRAISE: KEEP offered for the piece just valued
var _mode := "menu"      # menu, list, appraise (the collection), value (SELL / KEEP), coins, amount, ask_leave
## The shop's money pile (CoinPile): POOL puts coins on it, TAKE and SHARE give them back.
var pile := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
var _coin := 0           # the chosen line of the coin page
var _amount_coin := -1
var _typed := ""
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


## `who`: the member selected on the walking screen. The shop's menu (GAME.OVR 0x7212, its menu 0x2CC8C as the
## walking screen's) moves the one selected member: the shop opens on it and leaves the last buyer selected
## (Combat Chat 23, Player 19's p13a1: the original left New Phlan's arms shop with DORN lit, its last buyer, and
## paid at the inn with him; ours opened on ARN and went back to the member lit before).
func open(items: Array[GameItem], party: Array[PartyMember], _title: String = "SHOP", who: int = 0) -> void:
	_items = items
	_party = party
	_buyer = clampi(who, 0, maxi(party.size() - 1, 0))
	_mode = "menu"
	_pick = 0
	_note.text = ""
	pile = PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
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
	if _mode in ["coins", "amount"]:
		_draw_coins()
		return
	var menu := _menu_items()
	var lines := PackedStringArray()
	if _mode != "ask_leave":
		for l in _note.text.split("\n"):
			lines.append_array(PrintWrap.lines(l, 38))
	_scr.draw_walk(OverlayLook.last_view, _party, _buyer, "", lines, menu,
		false, false, _pick)
	if _mode == "menu":
		_scr.party_clickable(_party.size(), _buyer)
	if _mode == "ask_leave":
		TreasureScreen.draw_ask(_scr, "AS YOU LEAVE THE SHOPKEEPER SAYS, \"EXCUSE ME BUT YOU HAVE LEFT SOME MONEY HERE.\"",
			"DO YOU WANT TO GO BACK AND GET YOUR MONEY?")
		_scr.update()


## Row 24's words in the current mode (not the item list's).
func _menu_items() -> Array:
	match _mode:
		"appraise": return ["GEMS", "JEWELRY", "EXIT"]
		"value": return ["SELL", "KEEP"] if _keep_ok else ["SELL"]
		"ask_leave": return ASK_MENU
		"coins": return ["EXIT"]
	return POOL_MENU if CoinPile.has_money(pile) else MENU


## TAKE's coin page, the treasure's (GAME.OVR 0x8F:0x34 in both): the pile's coins, copper first.
func _draw_coins() -> void:
	draw_coin_page(_scr, pile, _mode == "coins", _coin, _amount_coin, _typed)


## The coin page for any pile (the shop's and the temple's TAKE: GAME.OVR 0x25974): `choosing` the
## SELECT TYPE OF COIN step with line `coin` lit, else HOW MUCH of kind `amount_coin` with `typed`.
static func draw_coin_page(scr: GameScreen, coins: PackedInt32Array, choosing: bool, coin: int,
		amount_coin: int, typed: String) -> void:
	scr.clear()
	for c in 40:
		scr.tile(c, 0, 22)
		scr.tile(c, 23, 22)
	for r in range(1, 23):
		scr.tile(0, r, 21)
		scr.tile(39, r, 21)
	for p in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 23), Vector2i(39, 23)]:
		scr.tile(p.x, p.y, 20)
	var kinds := coin_kinds_of(coins)
	for i in kinds.size():
		var c: int = kinds[i]
		var lit := choosing and i == coin
		scr.text(2, 2 + i, "%s %d" % [TreasureScreen.MONEY_LABELS[c], coins[c]],
			GameScreen.WHITE if lit else GameScreen.GREEN)
		scr.list_line(2 + i, i)
	if choosing:
		scr.list_chosen(coin)
		scr.text(0, 24, "SELECT TYPE OF COIN", 13)
		scr.menu_line(24, ["EXIT"], 20, 0)
	else:
		var ask := "HOW MUCH %s WILL YOU TAKE? " % TreasureScreen.MONEY_LABELS[amount_coin]
		scr.text(0, 24, ask, GameScreen.GREEN)
		scr.text(ask.length(), 24, typed, GameScreen.WHITE)
	scr.update()


func _coin_kinds() -> Array:
	return coin_kinds_of(pile)


static func coin_kinds_of(coins: PackedInt32Array) -> Array:
	var out := []
	for c in 7:
		if coins[c] > 0:
			out.append(c)
	return out


## TAKE n coins of kind c from the pile for the buyer (refused whole when over his load, as the
## treasure's: GAME.OVR 0x2570F).
func take_coins(c: int, n: int) -> void:
	var left := take_from(_party[_buyer], pile, c, n)
	if left.is_empty():
		_show_flash("OVERLOADED", true)
		return
	pile = left


## Member `m` takes n coins of kind c from `coins`: the pile left, or an empty array when refused
## (the cached load, Combat Chat 29, tested with the amount asked, raised by what is taken: 0x257DA).
static func take_from(m: PartyMember, coins: PackedInt32Array, c: int, n: int) -> PackedInt32Array:
	if not m.can_take_coins(maxi(n, 0)):
		return PackedInt32Array()
	var out := coins.duplicate()
	n = clampi(n, 0, out[c])
	m.money[c] += n
	m.raise_load(n)
	out[c] -= n
	return out


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
		_scr.list_line(4 + i, k)
	_scr.list_chosen(_cursor)
	if _flash != "":
		_scr.text(0, 24, _flash, GameScreen.GREEN if _flash_green else GameScreen.YELLOW)
	else:
		_scr.text(0, 24, "ITEMS:", 13)
		_scr.menu_line(24, _list_menu(), 7, mini(_pick, _list_menu().size() - 1))
	_scr.update()


## The member selected when the shop closes (the last buyer).
func buyer() -> int:
	return _buyer


func _selected_index() -> int:
	return _cursor if _cursor >= 0 and _cursor < _items.size() else -1


func _buy() -> void:
	var i := _selected_index()
	if i < 0 or _party.is_empty():
		return
	var it := _items[i]
	var member := _party[_buyer]
	# GAME.OVR 0x7080-0x7136: the money first, the buyer's purse and then the pile ("Not enough
	# Money."), then the item is added through 0x6F0D (refused as "OverLoaded" by 0x23795, main's
	# PartyMember.can_take_item), and only then paid for.
	var purse := CoinPile.gold_of(member.money)
	var from_pile := it.price > purse
	if from_pile and it.price > CoinPile.gold_of(pile):
		_note.text = "NOT ENOUGH MONEY."
		_show_flash("NOT ENOUGH MONEY.", true)
		return
	if not member.can_take_item(it):
		_note.text = "OVERLOADED."
		_show_flash("OVERLOADED", true)
		return
	# 0x6F0D adds the item and works the buyer's record out again (0x7018: the cached load word now counts
	# the item and the coins before payment); the payment after it (0x70C7) leaves the word (Combat Chat 33,
	# Player 32's segment 1: DORN's word, 0 in an old start save, was 322 in the original's `shopped` save).
	var bought := it.copy()
	# The record keeps the shop's price, a 0 made 1 (Combat Chat 34, Player 32's segment 1: LIRA's 10 arrows had
	# price word 1 in the original's `shopped` save, 0 in ours; record bytes 58-59).
	bought.price = it.price
	if bought.raw.size() >= 60:
		bought.raw.encode_u16(58, it.price)
	member.items.append(bought)
	member.refresh_load_word()
	if from_pile:
		pile = CoinPile.set_gold(pile, CoinPile.gold_of(pile) - it.price)
	else:
		member.money = CoinPile.set_gold(member.money, purse - it.price)
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
	pile = CoinPile.pool(_party, pile)
	_refresh()


func _share() -> void:
	pile = CoinPile.share(_party, pile)
	_pick = mini(_pick, _menu_items().size() - 1)
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
	if _mode == "list":
		list_top = _top
	_refresh()


## The list's row 24 offers NEXT and PREV only when they'd move it (Player 2's sweep of New Phlan's
## 13 shop doors, Combat Chat 7): "ITEMS: BUY PREV EXIT" as the general store opens (a line in),
## "BUY EXIT" once its first item is at the top; a long list "BUY NEXT EXIT" at the top, "BUY NEXT
## PREV EXIT" in the middle, "BUY PREV EXIT" at the end.
func _list_menu() -> Array:
	var m: Array = ["BUY"]
	if _top + PAGE < _items.size():
		m.append("NEXT")
	if _top > 0:
		m.append("PREV")
	m.append("EXIT")
	return m


## NEXT / PREV keep the light on its screen row, as the original (Player 13's p13a1 at 13,8: Long Sword lit on
## row 19, NEXT, one End lights Banded Mail on row 20; ours used to put it on the page's top row).
func _page(step: int) -> void:
	var row := _cursor - _top
	if step > 0:
		_top = mini(_top + PAGE, maxi(_items.size() - PAGE, 0))
	else:
		_top = maxi(_top - PAGE, 0)
	list_top = _top
	_cursor = clampi(_top + row, 0, maxi(_items.size() - 1, 0))
	_refresh()


## Home / End move the light on the page shown and wrap on it; the page never scrolls (GAME.OVR 0x2D594, main chat
## 103, DOSBox at 3:0's arms shop, check 379: Home on the top line lights the page's last line). End past the page's
## last line, or past the list's last item, lights the page's first line; Home above it lights its last line (or the
## list's last item). Only NEXT / PREV move the page.
func _move(step: int) -> void:
	var n := _items.size()
	if n == 0:
		return
	var c := _cursor + step
	if step > 0:
		if c > _top + PAGE - 1 or c > n - 1:
			c = _top
	else:
		if c < _top:
			c = _top + PAGE - 1
		if c > n - 1:
			c = n - 1
	_reselect(c)


func _exit() -> void:
	if _mode != "menu":
		_mode = "menu"
		_pick = clampi(_pick, 0, _menu_items().size() - 1)
		_note.text = ""
		_refresh()
		return
	# Called by code (main's and the bot's ways out): the pile is shared back first; a player's E asks.
	if CoinPile.has_money(pile):
		_share()
	_close()


func _close() -> void:
	visible = false
	closed.emit()


## E from the menu: with money on the pile the shopkeeper asks first (GAME.OVR 0x7357).
func _leave() -> void:
	if CoinPile.has_money(pile):
		_mode = "ask_leave"
		_pick = 0
		_refresh()
		return
	_close()


func _view() -> void:
	if sheet == null or _party.is_empty() or _mode != "menu":
		return
	if not sheet.closed.is_connected(_after_view):
		sheet.closed.connect(_after_view)
	sheet.open(_party, "SHOP", _buyer, true, 1, true)


func _after_view() -> void:
	# A SELL whose seller was overloaded left platinum on the pile (CharacterSheet._sell_pay).
	if sheet != null and sheet.shop_pile_platinum > 0:
		pile[4] += sheet.shop_pile_platinum
		sheet.shop_pile_platinum = 0
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
	_note.text = "\n".join(collection_lines(_party[_buyer]))
	_pick = 0
	_refresh()


## Appraises one gem (or piece of jewellery): it leaves the count and is valued.
func appraise_one(jewel: bool) -> int:
	var m := _party[_buyer]
	var k := 6 if jewel else 5
	if m.money[k] <= 0:
		return -1
	m.money[k] -= 1
	m.refresh_cache()       # the appraisal works the cached THAC0 and AC out again (GAME.OVR 0x26ECA; main chat 82)
	_jewel = jewel
	_value = piece_value(jewel, _rng)
	_mode = "value"
	_keep_ok = keep_offered(m)
	_note.text = "THE %s IS VALUED AT %d GP." % ["JEWEL" if jewel else "GEM", _value]
	_pick = 0
	_refresh()
	return _value


## A piece's value as APPRAISE draws it (the shop's and the temple's).
static func piece_value(jewel: bool, rng: RandomNumberGenerator) -> int:
	if not TpDice.on:
		return jewel_value(rng) if jewel else gem_value(rng)
	# Lab replays (Player 22's (a)): the game's own stream, as the original draws it: a d100 (GAME.OVR
	# 0x26900 a gem, 0x26B8D a piece of jewellery), then for jewellery Random(range) (START.EXE 0x8D1D).
	return jewel_value_by(func(n: int) -> int: return TpDice.random(n, "appraise")) if jewel \
			else gem_value_by(func(n: int) -> int: return TpDice.random(n, "appraise"))


## "YOU HAVE A FINE COLLECTION OF:" and the counts (APPRAISE, the shop's and the temple's).
static func collection_lines(m: PartyMember) -> PackedStringArray:
	var lines := PackedStringArray(["YOU HAVE A FINE COLLECTION OF:"])
	if m.money[5] > 0:
		lines.append("%d GEM%s" % [m.money[5], "" if m.money[5] == 1 else "S"])
	if m.money[6] > 0:
		lines.append("%d PIECE%s OF JEWELRY" % [m.money[6], "" if m.money[6] == 1 else "S"])
	return lines


static func gem_value(rng: RandomNumberGenerator) -> int:
	return gem_value_by(func(n: int) -> int: return rng.randi_range(0, n - 1))


## `random` is Random(n): 0..n-1. The table: GAME.OVR 0x26904.
static func gem_value_by(random: Callable) -> int:
	var r: int = random.call(100) + 1
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
	return jewel_value_by(func(n: int) -> int: return rng.randi_range(0, n - 1))


## The table: GAME.OVR 0x26B95 (a d100, then the base + Random(range)).
static func jewel_value_by(random: Callable) -> int:
	var r: int = random.call(100) + 1
	for row in [[10, 100, 900], [20, 200, 1000], [40, 300, 1500], [50, 500, 2500], [70, 1000, 5000], [90, 2000, 6000]]:
		if r <= row[0]:
			return row[1] + int(random.call(row[2]))
	return 2000 + int(random.call(10000))


## SELL (true) or KEEP the piece just appraised (KEEP only when offered: `_keep_ok`).
func settle(sell: bool) -> void:
	var m := _party[_buyer]
	var said := ""
	if sell or not _keep_ok:
		var paid := appraisal_pay(m, _value / 5)
		said = paid[0]
		pile[4] += int(paid[1])
	else:
		m.items.append(appraised_item(_jewel, _value))
	m.refresh_load_word()     # each piece settled works the record out again (GAME.OVR 0x26ECA)
	if m.money[5] > 0 or m.money[6] > 0:
		_mode = "appraise"
		_show_collection()
		if said != "":
			_note.text = said + "\n" + _note.text
	else:
		_mode = "menu"
		_note.text = said
	_refresh()


## Whether APPRAISE offers KEEP (GAME.OVR 0x269D3, main chat 74): one more coin fits the load (0x24CDD with 1:
## the cached word, as the original; the load carried with ORIGINAL'S BUGS off) and fewer than 16 items; else
## row 24 is SELL alone (and K sells).
static func keep_offered(m: PartyMember) -> bool:
	return m.can_take_coins(1) and m.items.size() < 16


## The platinum of a sale paid to `m` (GAME.OVR 0x24E8C, APPRAISE's SELL at 0x26B5D, main chat 74): when it
## doesn't fit (0x24CDD), "Overloaded.  Money will be put in Pool.", the room (ceiling - the cached word, a
## 16-bit word, so it can wrap huge: the original's bug #10 family) is added to his platinum (a word) whatever
## the price, and the price less the room goes on the pile (a double word). With ORIGINAL'S BUGS off he gets
## what fits of it (the load carried), the rest goes on the pile. Returns [message, platinum to the pile].
static func appraisal_pay(m: PartyMember, plat: int) -> Array:
	if m.can_take_coins(plat):
		m.money[4] += plat
		m.raise_load(plat)
		return ["", 0]
	if not OriginalBugs.on():
		var fit := mini(m.coins_room(), plat)
		m.money[4] += fit
		m.raise_load(fit)
		return ["OVERLOADED.  MONEY WILL BE PUT IN POOL.", plat - fit]
	var room := ((m.max_load() & 0xFFFF) - m.load_word) & 0xFFFF
	m.money[4] = (m.money[4] + room) & 0xFFFF
	m.raise_load(room)
	return ["OVERLOADED.  MONEY WILL BE PUT IN POOL.", (plat - room) & 0xFFFFFFFF]


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
	if _mode == "amount":
		if key >= KEY_0 and key <= KEY_9 and _typed.length() < 6:
			_typed += char(key)
		elif key == KEY_BACKSPACE:
			_typed = _typed.left(-1)
		elif key in [KEY_ENTER, KEY_KP_ENTER]:
			take_coins(_amount_coin, _typed.to_int())
			_mode = "coins"
			_coin = 0
			if _coin_kinds().is_empty():
				_mode = "menu"
				_pick = 0
		elif key == KEY_ESCAPE:
			_mode = "coins"
		get_viewport().set_input_as_handled()
		_refresh()
		return
	if _mode == "appraise":
		# APPRAISE's menu (GEMS JEWELRY EXIT) reads keys as the original's own loop (main chat 90, DOSBox at 3:0's
		# shop and temple, checks 297, 298): Home (keypad 7: scan code 0x47, the letter G) appraises a gem; Enter,
		# Space, the digits, the arrows and End choose nothing but work the cached load out again (the word KEEP's
		# offer reads with ORIGINAL'S BUGS on); other letters and Backspace do nothing.
		if key in [KEY_HOME, KEY_KP_7]:
			key = KEY_G
		elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_END, KEY_KP_1,
				KEY_KP_2, KEY_KP_4, KEY_KP_6, KEY_KP_8] or (key >= KEY_0 and key <= KEY_9):
			_party[_buyer].refresh_load_word()
			get_viewport().set_input_as_handled()
			return
	var items: Array = _list_menu() if _mode == "list" else _menu_items()
	var choice := ""
	_pick = mini(_pick, items.size() - 1)
	# The shop's menu (BUY VIEW ... EXIT), APPRAISE's (GEMS JEWELRY EXIT) and YOU HAVE LEFT SOME MONEY's YES NO
	# take no Enter; neither they nor the BUY list (ITEMS: BUY NEXT PREV EXIT) move the light with Left / Right;
	# the list takes Enter for its lit word (main chat 89, DOSBox at 3:0's arms and armour shop, checks 285, 286,
	# 292, 293; Q24 extended).
	if (_mode in ["menu", "appraise", "ask_leave"] and key in [KEY_ENTER, KEY_KP_ENTER, KEY_LEFT, KEY_RIGHT]) \
			or (_mode == "list" and key in [KEY_LEFT, KEY_RIGHT]):
		get_viewport().set_input_as_handled()
		return
	if key == KEY_ENTER or key == KEY_KP_ENTER:
		choice = items[_pick]
		if _mode == "coins":
			choice = "COIN"
	elif _mode == "value" and key in [KEY_LEFT, KEY_KP_4, KEY_RIGHT, KEY_KP_6]:
		# YOU CAN: SELL KEEP: Right (keypad 6) sells, Left (keypad 4, scan code 0x4B, read as K) keeps, or sells
		# when KEEP isn't offered (main chat 90, DOSBox at 3:0's shop and temple; the Lead, 2026-11-21).
		choice = "SELL" if key in [KEY_RIGHT, KEY_KP_6] or not _keep_ok else "KEEP"
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
		elif _mode == "coins":
			_coin = clampi(_coin + step, 0, maxi(_coin_kinds().size() - 1, 0))
			_refresh()
	elif key == KEY_ESCAPE and _mode == "value":
		# The original sells on Esc too: original's bug 18 (on under ORIGINAL'S BUGS; off, Esc keeps).
		choice = "SELL" if OriginalBugs.on() or not _keep_ok else "KEEP"
	elif key == KEY_ESCAPE and _mode in ["menu", "ask_leave"]:
		# The shop's menu and YOU HAVE LEFT SOME MONEY's YES NO ignore Esc; the BUY list and APPRAISE take it as EXIT
		# (main chat 94, DOSBox at 3:0's arms and armour shop, check 317).
		pass
	elif key == KEY_ESCAPE:
		choice = "EXIT" if "EXIT" in items else "NO"
	elif _mode == "list" and key in [KEY_PAGEDOWN, KEY_PAGEUP]:
		# PgDn / PgUp page the BUY list as NEXT / PREV where the menu offers them (main chat 92, DOSBox at 3:0's arms
		# and armour shop, check 310; PgDn on the last page and PgUp on the first do nothing).
		var word := "NEXT" if key == KEY_PAGEDOWN else "PREV"
		if word in items:
			choice = word
	else:
		for it in items:
			if String(it).unicode_at(0) == key:
				choice = it
		if _mode == "value" and not _keep_ok and key == KEY_K:
			choice = "SELL"
	get_viewport().set_input_as_handled()
	if choice == "":
		return
	# The chosen item stays highlighted, and the index carries over to the next menu
	# (lab, chat 10: EXIT, the fourth of the list's menu, leaves APPRAISE, the fourth of the
	# shop's, highlighted).
	if choice != "COIN":
		_pick = items.find(choice)
	match _mode:
		"menu":
			match choice:
				"BUY":
					# The original lights item 1 at every BUY (0x7050; Player 14, p13a1 key 64: ours reopened it
					# where the last purchase left it) and keeps the list top unless it is past the light
					# (0x2D766; main chat 103, p17a6: after the mirror shop's PREV the arms shop opened at its top).
					_cursor = mini(1, maxi(_items.size() - 1, 0))
					_top = mini(list_top, _cursor)
					if _top > _items.size():
						_top = 0
					list_top = _top
					_mode = "list"
					_refresh()
				"VIEW": _view()
				"TAKE":
					_mode = "coins"
					_coin = 0
					_refresh()
				"POOL": _pool()
				"SHARE": _share()
				"APPRAISE": _appraise()
				"EXIT": _leave()
		"coins":
			if choice == "COIN":
				var kinds := _coin_kinds()
				if _coin < kinds.size():
					_amount_coin = kinds[_coin]
					_typed = ""
					_mode = "amount"
			else:
				_mode = "menu"
				_pick = _menu_items().find("TAKE") if CoinPile.has_money(pile) else 0
			_refresh()
		"ask_leave":
			if choice == "YES":
				_mode = "menu"
				_pick = 0
				_refresh()
			else:
				_close()
		"list":
			match choice:
				"BUY": _buy()
				"NEXT", "PREV":
					_page(1 if choice == "NEXT" else -1)
					var now := _list_menu()      # the menu may have lost the item just used
					_pick = now.find(choice) if choice in now else mini(_pick, now.size() - 1)
					_refresh()
				"EXIT": _exit()
		"appraise":
			match choice:
				"GEMS": appraise_one(false)
				"JEWELRY": appraise_one(true)
				"EXIT": _exit()
		"value":
			settle(choice == "SELL")      # with KEEP not offered, K sells too (main chat 74)
