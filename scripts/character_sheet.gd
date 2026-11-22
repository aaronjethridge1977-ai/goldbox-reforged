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
##   <item>" / "IS IT A DEAL?"; NOT ENOUGH MONEY when short (row 24, the question kept). Paid,
##   GAME.OVR 0x22F8D (lab, Combat Chat 5): an item whose record byte 53 (the hidden name
##   words) is 0 gets "I CAN'T TELL ANYTHING NEW ABOUT YOUR <item>"; otherwise byte 53 is
##   cleared and "IT LOOKS LIKE SOME SORT OF <whole name>" (HAMMER +1). Either answer shows
##   yellow from row 21 under the item list (still the old name) with IS IT A DEAL? YES NO
##   left on row 24, for about 0.7 s; then the item menu, the list with the new name. The
##   record keeps the new name and byte 53 = 0 (the original's save: " No   Hammer +1 ").
## Not compared yet: the combat-only USE question and what using an item prints.

signal closed
## In a fight: CAST chose a spell, or USE chose an item that casts one.
signal spell_chosen(id: int)
signal item_used(item: GameItem)

## Set once by the game: the item types (slots, hands, classes) and spell table.
static var types: ItemTypes
## A scroll's spell chosen on its page in a fight: the item -> its record byte (60-62), for
## item_spell and spend_use when the fight casts it.
static var scroll_pick := {}
static var spells: SpellTable
## Set by the game: the game folder (portraits).
static var game_path := ""
## The anti-magic shell (ECL 0x49E5 above 0): the item list offers no USE (GAME.OVR 0x21FD6, in and out of fights).
## Set by the fight (CombatScreen) and by main.
static var anti_magic := false

const MAGENTA := 13
const COIN_NAMES := ["COPPER", "SILVER", "ELECTRUM", "GOLD", "PLATINUM", "GEMS", "JEWELRY"]
const LEVEL_WORDS := ["1ST LEVEL", "2ND LEVEL", "3RD LEVEL", "4TH LEVEL", "5TH LEVEL",
	"6TH LEVEL", "7TH LEVEL", "8TH LEVEL", "9TH LEVEL"]
const MESSAGE_TIME := 0.7       # lab: a message stays about 0.7 s
const SAID_TIME := 0.8          # lab: a scroll spell's result, once typed out
const MAX_ITEMS := 16
const ID_PRICE := 200           # lab: "FOR 200 GOLD PIECES I'LL IDENTIFY YOUR BANDED MAIL"

var _people: Array[PartyMember] = []
var _index := 0
var _title := ""
var _mode := "view"      # view, items, spells, whom, coin_whom, coin, amount, confirm
var _cursor := 0         # the chosen item
var _pick := 0           # the lit menu item
var _pending := ""       # what whom/confirm/coin/amount are for: trade, drop, use, sell, coin_trade, coin_drop
var _target := 0         # member chosen for a trade; -1 no one (after Esc), -2 past the party's end (bug 19)
var _target_kept := 0    # the member lit when Esc took the light off: the next TRADE starts there (DOSBox)
var _coin_asked := false # TRADE's coins: HOW MUCH asked on this visit (EXIT / Esc then go back to TRADE TO?)
var _coin := 4           # the coin type chosen
var _coin_cursor := 0    # index into the coins held
var _amount := ""
var _note := ""          # the last thing said (also the bot's log)
var _message := ""       # shown on row 24 for MESSAGE_TIME
var _question := ""      # the confirm page's line at row 21
var _reveal: GameItem = null   # ID's answer is up; this item's name changes after it
var _scroll: GameItem = null   # USE on a clerical scroll: its spell page, then WHOM
var _scroll_cursor := 0
var _scroll_target: PartyMember = null
var _said: Array = []          # the scroll spell's result lines still to show ([name, words])
var _rng := RandomNumberGenerator.new()
var in_shop := false     # opened from a shop's VIEW: the item menu offers SELL
## Platinum a SELL put on the shop's pile (the seller overloaded); the shop takes it when the sheet closes.
var shop_pile_platinum := 0
var camp_look := false   # opened from the camp: CAST SPELL ON WHOM and TRADE TO? show the camp's picture
## Opened from a screen with its own picture (the treasure): the party picks (TRADE TO?, TRADE WITH
## WHOM?) show it with this place line (main chat 106, P97: DOSBox, the treasure's VIEW, TRADE: the
## treasure's picture and no place line; ours drew the walking screen's last view, an encounter's portrait).
var own_look := false
var own_view: Image
var own_place := ""
var portrait := false    # opened from the party menu: the portrait shows
## In a fight (lab, chat 11): VIEW offers ITEMS DROP EXIT (DROP lit: VIEW's place), the item
## menu READY USE DROP HALVE JOIN EXIT. USE and CAST open their pages on the fight's grey
## (the frame's black left out): USE the items page with READY lit; CAST the spells page,
## "CHOOSE SPELL:" (magenta) CAST EXIT, the last spell chosen, Home/End to choose.
var in_combat := false
var grey := false
## The lit menu item's place when the sheet closed (it carries over to the next menu).
var last_pick := 0
var _cast_cursor := 0

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
	shop_pile_platinum = 0
	portrait = with_portrait
	camp_look = false
	own_look = false
	own_view = null
	own_place = ""
	_people = people
	_title = title
	_index = clampi(start, 0, maxi(people.size() - 1, 0))
	_target = _index      # TRADE TO? / WITH WHOM? start on the last one chosen (lab)
	if not people.is_empty() and not people[_index].is_monster:
		people[_index].refresh_load_word()     # VIEW's entry works the record out again (GAME.OVR 0x2165C)
	_mode = "view"
	_note = ""
	_message = ""
	_pick = pick
	# From the global generator, which RECORD MY GAME's seed (main _seed_all) sets: a replay rolls the same
	# dice (main chat 72: a camp scroll's d8 differed); random otherwise, as Godot seeds it at start.
	_rng.seed = randi()
	_measure()
	if _scr == null:
		_build()
	visible = true
	_refresh()


## In a fight: VIEW (black, the fight's menus), USE (the items page on grey) or CAST (the
## spells page on grey, to choose a spell).
func open_combat(people: Array[PartyMember], index: int, what: String, pick: int) -> void:
	in_combat = true
	grey = what != "view"
	open(people, "COMBAT", index, false, pick)
	if what == "use":
		_mode = "items"
		_cursor = 0
		_pick = 0
	elif what == "cast":
		_mode = "cast"
		_pick = 0
		_cast_cursor = maxi(_spell_ids().size() - 1, 0)
	_refresh()


func _close() -> void:
	last_pick = _pick
	visible = false
	in_combat = false
	grey = false
	closed.emit()


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
		if _mode == "id_reply":
			_end_id_reply()
		elif _mode == "scroll_said":
			_next_said()
		_refresh())
	add_child(_timer)


func _who() -> PartyMember:
	return _people[_index] if _index < _people.size() else null


func _editable() -> bool:
	var m := _who()
	return m != null and not m.is_monster and types != null


static func item_label(it: GameItem) -> String:
	# P30: an item read from a character's .ITM file (a save) keeps the record's cached name,
	# which is blank for monster loot (MONnITM); name it from its words as the original does.
	var named := false
	if game_path != "":
		var names := ItemNames.shared(game_path)
		named = names.is_loaded()
		if named and it.name == "":
			it.name = names.name_of(it)
	var label := it.name if it.name != "" else "(item type %d)" % it.type
	# The plus shows only through the name's words (lab: the orc leader's scroll, plus 1, is
	# "CLERICAL SCROLL WITH 2 SPELLS"; an unidentified item's "+1" word stays hidden).
	if not named and it.plus != 0 and not label.contains("+") and not label.contains("-"):
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
	_scr.transparent_tiles = grey
	if grey:
		_scr.img.fill(GameScreen.EGA[8])
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
	# VIEW's page works the cached THAC0 and AC (+0x110/+0x111) out again (GAME.OVR 0x2165C; main chat 82).
	m.refresh_cache()
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
	# GAME.OVR 0x210CC (main chat 104, DOSBox: SWORDSMAN's VIEW): a hired NPC (record 0x84 above 0x7F) is marked.
	if not m.is_monster and m.raw.size() > 0x84 and m.raw[0x84] > 0x7F:
		_t(m.name.length() + 3, 1, "(NPC)", G)
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
	if _orders_on(m):
		_t(24, 22, "ORDER", W)
		_t(30, 22, SmartQuick.ORDER_NAMES[clampi(m.quick_order, 0, 4)], G)


func _heading(m: PartyMember, what: String) -> void:
	_t(1, 1, m.name + "'S", GameScreen.CYAN)
	_t(m.name.length() + 4, 1, what, GameScreen.GREEN)


func _draw_items(m: PartyMember, cursor_lit: bool) -> void:
	_frame(2)
	_heading(m, "ITEMS")
	_t(1, 3, "READY", GameScreen.WHITE)
	_t(7, 3, "ITEM", GameScreen.WHITE)
	# Detect Magic (START.EXE 0xBA:0x443, main's chat 26 lab): while any member has its effect,
	# "* " goes before the name of a magic item (" YES  * FLAIL" for a +1 flail).
	var detect := PartyMember.party_detects_magic(_people)
	for i in mini(m.items.size(), MAX_ITEMS):
		var it := m.items[i]
		var color := GameScreen.WHITE if i == _cursor and cursor_lit and _message == "" else GameScreen.GREEN
		_t(2, 5 + i, "YES" if it.readied else "NO", color)
		var mark := "* " if detect and it.detect_magic_marks() else ""
		_t(7, 5 + i, mark + item_label(it).to_upper(), color)
		_scr.list_line(5 + i, i)
	if cursor_lit:
		_scr.list_chosen(_cursor, KEY_HOME, KEY_END)      # mouse step 2: a click picks the line


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
			var lit := i == rows.size() - 1 if _mode != "cast" else i == _cast_row()
			_t(3, 5 + i, String(rows[i][0]).to_upper(), GameScreen.WHITE if lit else GameScreen.GREEN)
	if _mode != "cast":
		_t(1, 24, "EXIT", GameScreen.WHITE)


## The page row of the spell CAST has chosen (_cast_cursor counts spells only).
func _cast_row() -> int:
	var rows := _spell_rows(_who())
	var k := 0
	for i in rows.size():
		if rows[i][1] != 0:
			if k == _cast_cursor:
				return i
			k += 1
	return -1


func _spell_ids() -> Array[int]:
	var out: Array[int] = []
	for r in _spell_rows(_who()):
		if r[1] != 0:
			out.append(r[1])
	return out


## The walking screen with a prompt (TRADE WITH WHOM?, TRADE TO?) and SELECT EXIT.
func _draw_whom(prompt: String, camp: bool = false) -> void:
	if camp and OverlayLook.camp_view != null:
		_scr.draw_walk(OverlayLook.camp_view, _people, _target, OverlayLook.camp_place, PackedStringArray(), [])
	elif own_look:
		_scr.draw_walk(own_view, _people, _target, own_place, PackedStringArray(), [], false, false, -1)
	else:
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
	# TRADE and DROP (money) only for a member carrying some, gems and jewelry included (main chat 86, check
	# 256: DOSBox, camp VIEW: ARN with nothing VIEW:ITEMS EXIT, with one gem ITEMS TRADE DROP EXIT). In a
	# fight: not seen (DROP kept as it was).
	var money := false
	if m != null:
		for c in m.money:
			money = money or c > 0
	if money and not in_combat and not _npc_barred(m):
		items.append("TRADE")
	if money or in_combat:
		items.append("DROP")
	if _orders_on(m):
		items.append("ORDER")
	items.append("EXIT")
	return items


## GAME.OVR 0x21BFE, 0x22034, 0x22107 (main chat 104, DOSBox: SWORDSMAN's VIEW): no TRADE (money or items) and no
## SELL for a hired NPC (record 0x84 from 0x80; 0x10D set; status not 1, ANIMATED).
func _npc_barred(m: PartyMember) -> bool:
	return m != null and not m.is_monster and m.npc >= 0x80 and m.raw.size() > 0x10D and m.raw[0x10D] != 0 \
			and m.status != PartyMember.STATUS_ANIMATED


## B3: ORDER on VIEW, for the party's own members, when TACTICS FOR QUICK is SMARTER.
func _orders_on(m: PartyMember) -> bool:
	return m != null and not m.is_monster and m.npc < 128 and SmartQuick.on()


func _item_menu() -> Array:
	var m := _who()
	var room := m != null and m.items.size() < MAX_ITEMS
	var use: Array = [] if anti_magic else ["USE"]
	if in_combat:
		return ["READY"] + use + ["DROP"] + (["HALVE"] if room else []) + ["JOIN", "EXIT"]
	var trade: Array = [] if _npc_barred(m) else ["TRADE"]
	var sell: Array = [] if _npc_barred(m) else ["SELL"]
	if in_shop:
		return ["READY"] + trade + ["DROP"] + (["HALVE"] if room else []) + ["JOIN"] + sell + ["ID", "EXIT"]
	return ["READY"] + use + trade + ["DROP"] + (["HALVE"] if room else []) + ["JOIN", "EXIT"]


func _current_menu() -> Array:
	match _mode:
		"view":
			return _view_menu() if _editable() else ["EXIT"]
		"items":
			return _item_menu()
		"spells", "coin":
			return ["EXIT"]
		"cast":
			return ["CAST", "EXIT"]
		"order":
			return SmartQuick.ORDER_NAMES + ["EXIT"]
		"whom", "coin_whom":
			return ["SELECT", "EXIT"]
		"confirm", "id_reply":
			return ["YES", "NO"]
		"scroll":
			return ["CAST", "EXIT"]
		"scroll_whom", "scroll_said":
			return ["SELECT", "EXIT"]
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
		"confirm", "id_reply":
			_draw_items(m, false)
			var q := GameScreen.wrap(_question, 37)   # lab: "...IDENTIFY" (33) then "YOUR BANDED MAIL"
			for i in q.size():
				_t(1, 21 + i, q[i], GameScreen.YELLOW)
			var prompt := {"drop": "DROP IT?", "sell": "IS IT A DEAL?", "id": "IS IT A DEAL?", "use": "USE IT?"}.get(_pending, "?") as String
			if _message == "":
				_t(0, 24, prompt, MAGENTA)
				_menu(["YES", "NO"], prompt.length() + 1)
		"spells":
			_draw_spells(m)
		"scroll":
			_draw_scroll(m)
		"scroll_whom":
			_draw_whom("CAST SPELL ON WHOM", camp_look)
		"scroll_said":
			_draw_whom("CAST SPELL ON WHOM")
			if not _said.is_empty():
				_t(1, 18, _said[0][0], GameScreen.CYAN)
				_t(1, 19, _said[0][1], GameScreen.GREEN)
		"cast":
			_draw_spells(m)
			_t(0, 24, "CHOOSE SPELL:", MAGENTA)
			_menu(["CAST", "EXIT"], 14)
		"order":
			_draw_page(m)
			_t(0, 24, "ORDER:", MAGENTA)
			_menu(_current_menu(), 6)
		"whom":
			_draw_whom("TRADE WITH WHOM?", camp_look)
		"coin_whom":
			_draw_whom("TRADE TO?", camp_look)
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


## ID paid for (GAME.OVR 0x22F8D): the answer, held like a message; the name changes after it.
func _identify(it: GameItem) -> void:
	_mode = "id_reply"
	if it.raw.size() < GameItem.SIZE or it.raw[53] == 0:
		_question = "I CAN'T TELL ANYTHING NEW ABOUT YOUR %s" % item_label(it).to_upper()
		_reveal = null
	else:
		var shown := it.copy()
		shown.raw[53] = 0
		shown.name = ""
		shown.count = it.count
		_question = "IT LOOKS LIKE SOME SORT OF %s" % item_label(shown).to_upper()
		_reveal = it
	_note = _question
	if _timer != null:
		_timer.start(MESSAGE_TIME)


func _end_id_reply() -> void:
	if _reveal != null:
		reveal_name(_reveal)
	_reveal = null
	_message = ""
	_mode = "items"
	_after_change()


## Clears the hidden name words (record byte 53) and caches the whole name in the record,
## as the original's ID does.
static func reveal_name(it: GameItem) -> void:
	if it.raw.size() < GameItem.SIZE:
		return
	it.raw[53] = 0
	recache_name(it)


## The item's name worked out again from its words, also into the record's cached name.
static func recache_name(it: GameItem) -> void:
	it.name = ""
	var label := item_label(it)
	var words := label.split(" ", false, 1)
	if it.count > 1 and words.size() == 2 and words[0].is_valid_int():
		label = words[1]
	it.name = label
	var bytes := label.to_ascii_buffer().slice(0, 41)
	it.raw[0] = bytes.size()
	for i in 41:
		it.raw[1 + i] = bytes[i] if i < bytes.size() else 0


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
		if _editable():
			_who().refresh_load_word()     # after an item action (GAME.OVR 0x224AF)
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
		if not wasted and spells != null and it.raw.size() >= GameItem.SIZE:
			# Lab (Combat Chat 5, camp, Restoration and Cure Light Wounds scrolls): the
			# scroll's own page, "<NAME>'S SPELLS ON SCROLL", the last one lit (main chat 86,
			# check 250: also with the scroll at the top of the item list).
			_scroll = it
			_scroll_cursor = maxi(_scroll_ids().size() - 1, 0)
			_mode = "scroll"
			_pick = 0
			return "\u0001"
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


## A clerical scroll's spells, in the record's order (bytes 60-62).
func _scroll_ids() -> Array[int]:
	var out: Array[int] = []
	if _scroll == null:
		return out
	for k in [60, 61, 62]:
		if _scroll.raw[k] & 0x7F > 0:
			out.append(_scroll.raw[k] & 0x7F)
	return out


## The record byte of the spell lit on the scroll's page.
func _scroll_slot() -> int:
	var n := 0
	for k in [60, 61, 62]:
		if _scroll.raw[k] & 0x7F > 0:
			if n == _scroll_cursor:
				return k
			n += 1
	return 60


func _draw_scroll(m: PartyMember) -> void:
	_frame(2)
	_heading(m, "SPELLS ON SCROLL")
	var ids := _scroll_ids()
	var row := 5
	var last := -1
	for i in ids.size():
		var lv := spells.level(ids[i]) if spells != null else 1
		if lv != last:
			_t(1, row, LEVEL_WORDS[clampi(lv - 1, 0, LEVEL_WORDS.size() - 1)], MAGENTA)
			row += 1
			last = lv
		_t(3, row, spells.name_of(ids[i]).to_upper(), GameScreen.WHITE if i == _scroll_cursor else GameScreen.GREEN)
		_scr.list_line(row, i)
		row += 1
	_scr.list_chosen(_scroll_cursor, KEY_HOME, KEY_END)
	_t(0, 24, "CHOOSE SPELL:", MAGENTA)
	_menu(["CAST", "EXIT"], 14)


## The scroll's chosen spell on `target` (lab: no CASTS line; "<NAME>" cyan on row 18,
## the result green on row 19, typed out, held about 0.8 s; then the item list. Restoration
## on someone not drained says nothing.) The spell leaves the scroll.
func _cast_scroll(m: PartyMember, target: PartyMember) -> void:
	var it := _scroll
	var id: int = _scroll_ids()[clampi(_scroll_cursor, 0, _scroll_ids().size() - 1)]
	var lines := PackedStringArray()
	if id == 56:
		var ct := ClassTables.shared(game_path) if game_path != "" else null
		if ct != null:
			var said := LevelDrain.restore(target, ct, spells)
			if said != "":
				lines.append(said)
	else:
		lines = SpellCaster.cast_outside(spells, m, id, _people, target, _rng, true)
		if not lines.is_empty():
			lines.remove_at(0)      # "<NAME> USES AN ITEM": not shown for a scroll
	_spend_scroll(m, it, _scroll_slot())
	_scroll = null
	_said.clear()
	for l in lines:
		var who := ""
		for p in _people:
			if l.begins_with(p.name + " ") and p.name.length() > who.length():
				who = p.name
		if who != "":
			_said.append([who, l.substr(who.length() + 1)])
		else:
			_said.append(["", l])
	if _said.is_empty():
		_mode = "items"
		_after_change()
		return
	_mode = "scroll_said"
	_after_change()
	_hold_said()


func _hold_said() -> void:
	if _timer != null and not _said.is_empty():
		var chars: int = String(_said[0][0]).length() + String(_said[0][1]).length()
		_timer.start(SAID_TIME + chars / 33.0)


func _next_said() -> void:
	if not _said.is_empty():
		_said.remove_at(0)
	if _said.is_empty():
		_mode = "items"
		_after_change()
	else:
		_hold_said()


## A clerical scroll gives up the spell in `slot`; its name says one spell fewer (word 48:
## 212 "With 3 Spells", 211 "With 2 Spells", 210 "With 1 Spell"; lab: 211 -> 210 after
## one of two Cure Light Wounds); an empty scroll is gone.
## The scroll spell in `slot` is used up: GAME.OVR 0x2A2A2 (PartyMember.spend_scroll_spell, main chat 76) takes the
## last of bytes 60-62 holding that spell, counts byte 48 down and drops the scroll below 210.
static func _spend_scroll(m: PartyMember, it: GameItem, slot: int) -> void:
	if slot < 60 or slot > 62 or it.raw.size() <= slot:
		return
	m.spend_scroll_spell(it, it.raw[slot] & 0x7F)
	if m.items.has(it):
		recache_name(it)


## The spell a readied item casts when used (a scroll: its first spell; a wand, potion or
## other charged item: record byte 61), 0 if none. Scrolls need a caster.
static func item_spell(m: PartyMember, it: GameItem) -> int:
	if types == null:
		return 0
	var slot := types.slot(it.type)
	if slot >= 11 and slot <= 13:
		if m.class_level(0) == 0 and m.class_level(1) == 0:
			return 0
		var k0: int = scroll_pick.get(it, -1)
		if k0 >= 60 and it.raw[k0] & 0x7F > 0:
			return it.raw[k0] & 0x7F
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
		# A scroll's USE spends through GAME.OVR 0x2A2A2 (0x22C77, after 0x2A255's scroll test), as SCRIBE does
		# (main chat 76): the last of bytes 60-62 holding the spell emptied, byte 48 one down, the scroll gone
		# below 210. Was: the chosen slot emptied, the scroll gone when all three were empty.
		scroll_pick.erase(it)
		m.spend_scroll_spell(it, id)
		if m.items.has(it):
			recache_name(it)
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


## TRADE's limit: GAME.OVR 0x23795, main's rule (PartyMember.can_take_item).
func _can_take(p: PartyMember, it: GameItem) -> bool:
	return p.can_take_item(it)


## What a shop pays for an item: half its price.
static func _sale_price(it: GameItem) -> int:
	return it.price / 2


## The shop pays for a sold item (GAME.OVR 0x22E47-0x22EE6, after the item is gone and before the record is
## worked out again): price / 5 platinum and price % 5 gold. When the coins don't fit the cached load
## word (0x24CDD), only the room left (ceiling - word, a 16-bit word) in platinum goes to the seller and the
## rest of the platinum on the shop's pile (DS:0x6804); the gold is his either way; the word isn't raised.
## Returns the message (Combat Chat 32: Player 30's p27d3, ARN's sales at 3:0 13,8 left money on the pile).
func _sell_pay(m: PartyMember, price: int) -> String:
	var plat := price / 5
	var gold := price % 5
	var said := "SOLD!"
	if not m.can_take_coins(plat + gold):
		said = "OVERLOADED.  MONEY WILL BE PUT IN POOL."
		var room := ((m.max_load() & 0xFFFF) - m.load_word) & 0xFFFF
		if not OriginalBugs.on():
			room = m.coins_room()      # bugs #9 and #10's fix: the load as carried, no wrap
		if room <= plat:
			m.money[4] += room
			shop_pile_platinum += plat - room
		else:
			m.money[4] += plat
	else:
		m.money[4] += plat
	m.money[3] += gold
	return said


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
	if _mode == "scroll_said":  # a key moves on, as other messages here
		if _timer != null:
			_timer.stop()
		_next_said()
		_refresh()
		return
	if _mode == "id_reply":    # a key ends ID's answer early, as other messages here
		if _timer != null:
			_timer.stop()
		_end_id_reply()
		_refresh()
		return
	var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
	# P33/P45 (an exception, Jeremy 2026-11-14): Up/Down move through every list here as
	# Home/End do (the item list, combat's CAST list, TRADE's and the coins' picks).
	if key in [KEY_UP, KEY_KP_7]:
		key = KEY_HOME
	elif key in [KEY_DOWN, KEY_KP_1]:
		key = KEY_END
	var cancel := event.is_action("ui_cancel")
	var items := _current_menu()
	# DROP IT?, IS IT A DEAL? (SELL, ID) and USE IT? take only Y and N: Enter, Esc and Left / Right do nothing (main
	# chat 90, DOSBox: 3:0's camp VIEW ITEMS DROP and the arms and armour shop's SELL; check 300; USE IT?: chat 91, 304).
	if _mode == "confirm" and _pending in ["drop", "sell", "id", "use"] and (cancel or event.is_action("ui_accept") \
			or event.is_action("ui_left") or event.is_action("ui_right")):
		return
	# The VIEW page's menu (VIEW:ITEMS ... EXIT) and the ITEMS menu (READY USE TRADE ...) take only their letters and
	# Esc (EXIT): Enter and Left / Right do nothing (main chat 90, DOSBox at 3:0's camp, check 303).
	if _mode in ["view", "items"] and (event.is_action("ui_accept") or event.is_action("ui_left") \
			or event.is_action("ui_right")):
		return
	# TRADE WITH WHOM? SELECT EXIT keeps its light on Left / Right (Enter is SELECT; main chat 90, check 302).
	if _mode in ["whom", "coin_whom"] and (event.is_action("ui_left") or event.is_action("ui_right")):
		return
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
					_close()
					return
				"ITEMS":
					_mode = "items"
					_cursor = 0
				"SPELLS":
					_mode = "spells"
				"TRADE":
					_pending = "coin_trade"
					_mode = "coin_whom"
					if _target < 0:
						_target = _target_kept
				"DROP":
					_pending = "coin_drop"
					_coin_cursor = 0
					_mode = "coin"
				"ORDER":
					_mode = "order"
					_pick = clampi(m.quick_order, 0, 4)
			_refresh()
		"order":
			if choice == "EXIT" or cancel:
				_mode = "view"
				_pick = _view_menu().find("ORDER")
			elif choice != "":
				m.quick_order = SmartQuick.ORDER_NAMES.find(choice)
				_mode = "view"
				_pick = _view_menu().find("ORDER")
			_refresh()
		"spells":
			if choice == "EXIT":
				_mode = "view"
			_refresh()
		"scroll":
			var ids := _scroll_ids()
			if key == KEY_HOME and not ids.is_empty():
				_scroll_cursor = (_scroll_cursor - 1 + ids.size()) % ids.size()
			elif key == KEY_END and not ids.is_empty():
				_scroll_cursor = (_scroll_cursor + 1) % ids.size()
			elif choice == "EXIT" or cancel:
				_mode = "items"
			elif choice == "CAST" and not ids.is_empty():
				var id: int = ids[clampi(_scroll_cursor, 0, ids.size() - 1)]
				if in_combat:
					var used := _scroll
					scroll_pick[used] = _scroll_slot()
					_scroll = null
					_close()
					item_used.emit(used)
					return
				if not SpellCaster.castable_outside(spells, id):
					_pending = "use"
					_question = "THAT ITEM IS A COMBAT-ONLY ITEM..."
					_mode = "confirm"
					_pick = 1
				elif SpellCaster.needs_member(spells, id):
					_mode = "scroll_whom"
					_pick = 0
					if _target < 0:
						_target = _target_kept
				else:
					_cast_scroll(m, m)
			_refresh()
		"scroll_whom":
			# As TRADE's member lists (main chat 93, DOSBox: check 185's scroll): Esc takes the light off the party and
			# stays; SELECT with no one backs out to the ITEMS page; Home from no one lights the last member; End from
			# no one is bug 19: SELECT casts on no one, the scroll's spell used up. Check 316.
			if cancel:
				if _target >= 0:
					_target_kept = _target
				_target = -1
			elif key == KEY_HOME:
				if _target == -1:
					_target = _people.size() - 1
				elif _target == -2:
					_target = -1
				else:
					_target = (_target - 1 + _people.size()) % _people.size()
			elif key == KEY_END:
				if _target == -1:
					_target = -2 if OriginalBugs.on() else 0
				elif _target >= 0:
					_target = (_target + 1) % _people.size()
			elif choice == "EXIT" or (choice == "SELECT" and _target == -1):
				_mode = "items"
			elif choice == "SELECT" and _target == -2:
				_spend_scroll(m, _scroll, _scroll_slot())   # bug 19: cast on no one, the spell used up
				_scroll = null
				_target = _target_kept
				_mode = "items"
				_after_change()
			elif choice == "SELECT":
				_cast_scroll(m, _people[_target])
			_refresh()
		"cast":
			var ids := _spell_ids()
			if key == KEY_HOME and not ids.is_empty():
				_cast_cursor = (_cast_cursor - 1 + ids.size()) % ids.size()
			elif key == KEY_END and not ids.is_empty():
				_cast_cursor = (_cast_cursor + 1) % ids.size()
			elif choice == "EXIT" or cancel:
				_close()
				return
			elif choice == "CAST" and not ids.is_empty():
				var id: int = ids[clampi(_cast_cursor, 0, ids.size() - 1)]
				_close()
				spell_chosen.emit(id)
				return
			_refresh()
		"items":
			var it := _item()
			if key == KEY_HOME and not m.items.is_empty():
				_cursor = (_cursor - 1 + m.items.size()) % m.items.size()
			elif key == KEY_END and not m.items.is_empty():
				_cursor = (_cursor + 1) % m.items.size()
			elif choice == "EXIT":
				if in_combat and grey:      # USE's page closes straight back to the fight
					_close()
					return
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
			elif choice == "USE" and in_combat:
				if not it.readied:
					_say("MUST BE READIED")
				elif _is_scroll(it) and item_spell(m, it) > 0 and it.raw.size() >= GameItem.SIZE:
					# Lab (Combat Chat 5, the Slums' orcs): the scroll's page as in camp, then AIM.
					_scroll = it
					_scroll_cursor = clampi(_cursor, 0, maxi(_scroll_ids().size() - 1, 0))
					_mode = "scroll"
					_pick = 0
				elif item_spell(m, it) > 0:
					_close()
					item_used.emit(it)
					return
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
					if _target < 0:
						_target = _target_kept
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
			# Esc takes the light off the party (no one chosen) and stays; SELECT with no one backs out as EXIT;
			# Home from no one lights the last member; End from no one is original's bug 19: a member past the
			# party's end, not lit, and a trade to it loses the item or the coins (main chat 92, DOSBox at 3:0's
			# camp: TRADE TO? and TRADE WITH WHOM?; Home after it: no one again).
			if cancel:
				if _target >= 0:
					_target_kept = _target
				_target = -1
			elif key == KEY_HOME:
				if _target == -1:
					_target = _people.size() - 1
				elif _target == -2:
					_target = -1
				else:
					_target = (_target - 1 + _people.size()) % _people.size()
			elif key == KEY_END:
				if _target == -1:
					_target = -2 if OriginalBugs.on() else 0
				elif _target >= 0:
					_target = (_target + 1) % _people.size()
			elif choice == "EXIT" or (choice == "SELECT" and _target == -1):
				_mode = "items" if _pending == "trade" else "view"
			elif choice == "SELECT":
				var to: PartyMember = _people[_target] if _target >= 0 else null
				if _pending == "trade":
					var it := _item()
					if to == null and it != null:
						m.items.erase(it)      # bug 19: given past the party's end, gone
					elif to != m and it != null:
						if not _can_take(to, it):
							_say("OVERLOADED")
						else:
							m.items.erase(it)
							to.items.append(it)
							to.refresh_load_word()     # the receiver (GAME.OVR 0x2280B)
					_mode = "items"
				else:
					_coin_cursor = 0
					_coin_asked = false
					_mode = "coin"
			_after_change()
		"confirm":
			if choice == "YES":
				var it := _item()
				if _pending == "drop" and it != null:
					m.items.erase(it)
				elif _pending == "sell" and it != null:
					m.items.erase(it)
					_say(_sell_pay(m, _sale_price(it)))
				elif _pending == "id" and it != null:
					# Lab: paid from all the coins (1000 gold, 2 platinum, 144 silver -> 163
					# platinum, 2 gold); with too little, NOT ENOUGH MONEY.
					if not m.pay_gold_in_shop(ID_PRICE):
						_mode = "id_reply"
						_say("NOT ENOUGH MONEY")
						_after_change()
						return
					_identify(it)
					_after_change()
					return
				elif _pending == "use" and _scroll != null and _mode == "confirm":
					var ids := _scroll_ids()
					if not ids.is_empty():
						_spend_scroll(m, _scroll, _scroll_slot())
					_scroll = null
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
				_coin_asked = true
			elif choice == "EXIT" or cancel:
				# TRADE's coins: EXIT and Esc go back to TRADE TO? once HOW MUCH was asked on this visit (answered
				# or not), else to the view page (main chat 92, DOSBox; DROP's always to the view page)
				_mode = "coin_whom" if _pending == "coin_trade" and _coin_asked else "view"
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
				if _pending == "coin_trade" and _target == -2:
					m.money[_coin] -= n     # bug 19: given past the party's end, gone
				elif _pending == "coin_trade" and _people[_target] != m:
					# GAME.OVR 0x250D5 lowers and raises the giver's cached load by the same amount: neither
					# word moves (Combat Chat 29). It first tests the receiver's word: word + n above his
					# most (0x24C89) moves nothing; its "Overloaded" never shows on the screen (chat 79,
					# check 181, DOSBox: 30000 platinum refused, then 3000 and 3000 taken: his word stays).
					if _people[_target].can_take_coins(n):
						m.money[_coin] -= n
						_people[_target].money[_coin] += n
				else:
					m.money[_coin] -= n
					m.lower_load(n)     # a DROP (GAME.OVR 0x2568A)
				_coin_cursor = 0
				# Back to the coin list while money is left, else to VIEW (main chat 86, checks 257-258:
				# DOSBox, a TRADE and a DROP of ARN's only gem: VIEW:ITEMS EXIT).
				_mode = "coin" if not coins_held(m).is_empty() else "view"
			_after_change(false)
