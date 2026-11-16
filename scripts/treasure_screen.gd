class_name TreasureScreen
extends Control
## After a won fight or a treasure find: the results, then the treasure on the ground, as the
## original shows them (Jeremy, 2026-11-12: every screen matches the original). Screens and
## keys from the lab (chat 10: a quick fight with the Slums' orcs, save I):
##   results: "THE PARTY HAS WON." (or "THE PARTY HAS FOUND TREASURE!") and "EACH CHARACTER
##     RECEIVES n EXPERIENCE POINTS.", Enter to go on. (Layout not yet compared.)
##   the treasure: the adventure screen with the chest (picture 1 of the area's PIC file), the
##     party list (Up/Down: who takes), no place line, VIEW TAKE POOL SHARE EXIT;
##   TAKE: the same screen, "TAKE:" then MONEY ITEMS EXIT;
##   MONEY: a framed page listing the coins on the pile ("SILVER 732", from row 2, column 2;
##     copper first), the chosen one white; "SELECT TYPE OF COIN" then EXIT; Enter picks the
##     coin, then "HOW MUCH SILVER WILL YOU TAKE? " and the number typed in white;
##   ITEMS: the LOOT page (title at column 17, items from row 4), "ITEMS:" then TAKE EXIT;
##   EXIT with treasure left: "THERE IS STILL TREASURE LEFT." (light green) "DO YOU WANT TO
##     GO BACK AND CLAIM YOUR TREASURE?" (white), YES NO.
## Menus as everywhere: the hot letter, or Left/Right and Enter; the chosen item stays lit
## and its place carries over to the next menu (EXIT from LOOT leaves ITEMS lit).
## POOL puts the player characters' money on the pile; SHARE splits the pile's money among them
## (CoinPile, GAME.OVR 0x25191 / 0x252C3: an NPC neither pools nor shares; the remainder one coin at
## a time from the first character; a share over the load ceiling stays on the pile).
## Not yet: the original's load and item-count limits when taking.

signal closed

const MONEY_LABELS := ["COPPER", "SILVER", "ELECTRUM", "GOLD", "PLATINUM", "GEMS", "JEWELRY"]
const MENU := ["VIEW", "TAKE", "POOL", "SHARE", "EXIT"]
const TAKE_MENU := ["MONEY", "ITEMS", "EXIT"]
const LIST_MENU := ["TAKE", "EXIT"]
const ASK_MENU := ["YES", "NO"]

## The chest picture main sets before opening (88 x 88).
var picture: Image

var _spoils: Spoils
var _party: Array[PartyMember] = []
var _who := 0
var _mode := "results"   # results, menu, take, coins, amount, items, ask_exit
var _pick := 0
var _cursor := 0         # the chosen coin or item
var _amount_coin := -1
var _typed := ""
var _won_text := ""
var _share_xp := 0
var _note := Label.new() # the last thing that happened (the bot logs it)
var _flash := ""         # a refusal on row 24 for a moment (OVERLOADED)
var _flash_id := 0
var _scr: GameScreen
var _sheet: CharacterSheet

# The bot and main look at these (kept from the old screen).
var _page: int:
	get: return 0 if _mode == "results" else 1
var _asking_exit: bool:
	get: return _mode == "ask_exit"
var _amount_open: bool:
	get: return _mode == "amount"


func _init() -> void:
	_note.visible = false
	add_child(_note)


func open(spoils: Spoils, party: Array[PartyMember], won_text: String, share: int) -> void:
	_spoils = spoils
	_party = party
	_who = 0
	_mode = "results"
	_pick = 0
	_won_text = won_text
	_share_xp = share
	_note.text = ""
	if _scr == null:
		ShopScreen._fill(self, 0)
		var bg := ColorRect.new()
		bg.color = Color.BLACK
		ShopScreen._fill(bg, 0)
		add_child(bg)
		_scr = GameScreen.new()
		add_child(_scr)
		_sheet = CharacterSheet.new()
		_sheet.visible = false
		add_child(_sheet)
	visible = true
	_refresh()


## The treasure menu (lab, Combat Chat 4): after Tyranthraxus's fight and the frogs', with
## nothing to take, the original showed VIEW POOL EXIT; with money, VIEW TAKE POOL SHARE EXIT.
## (TAKE with items only, SHARE only with money: assumed from those two.)
func _menu() -> Array:
	var items := ["VIEW"]
	if _spoils == null or _spoils.has_treasure():
		items.append("TAKE")
	items.append("POOL")
	if _spoils == null or _spoils.has_money():
		items.append("SHARE")
	items.append("EXIT")
	return items


func _show_treasure() -> void:
	_mode = "menu"
	_pick = 0
	_refresh()


# --- Drawing ----------------------------------------------------------------------------

func _refresh() -> void:
	if _scr == null:
		return
	_draw_mode()
	if _flash != "":
		_scr.text(0, 24, _flash.rpad(40), GameScreen.GREEN)
		_scr.update()


func _draw_mode() -> void:
	match _mode:
		"results":
			_page_frame()
			# The original (main's cold-open capture, chat 38): green, a blank row between the
			# lines; PRESS <ENTER> white.
			_scr.text(1, 3, _won_text, GameScreen.GREEN)
			_scr.text(1, 5, "EACH CHARACTER RECEIVES %d" % _share_xp, GameScreen.GREEN)
			_scr.text(1, 7, "EXPERIENCE POINTS.", GameScreen.GREEN)
			_scr.text(0, 24, "PRESS <ENTER>/<RETURN> TO CONTINUE", GameScreen.WHITE)
			_scr.update()
		"menu":
			_walk(_menu(), PackedStringArray())
		"take":
			_walk(TAKE_MENU, PackedStringArray(), "TAKE:")
		"ask_exit":
			_walk(ASK_MENU, PackedStringArray())
			_ask_text()
			_scr.update()
		"coins", "amount":
			_page_frame()
			var kinds := _coin_kinds()
			for i in kinds.size():
				var c: int = kinds[i]
				var lit := _mode == "coins" and i == _cursor
				_scr.text(2, 2 + i, "%s %d" % [MONEY_LABELS[c], _spoils.money[c]],
					GameScreen.WHITE if lit else GameScreen.GREEN)
			if _mode == "coins":
				_scr.text(0, 24, "SELECT TYPE OF COIN", 13)
				_scr.menu_line(24, ["EXIT"], 20, 0)
			else:
				var ask := "HOW MUCH %s WILL YOU TAKE? " % MONEY_LABELS[_amount_coin]
				_scr.text(0, 24, ask, GameScreen.GREEN)
				_scr.text(ask.length(), 24, _typed, GameScreen.WHITE)
			_scr.update()
		"items":
			_page_frame()
			_scr.text(17, 1, "LOOT", GameScreen.WHITE)
			var top := clampi(_cursor - 18, 0, maxi(_spoils.items.size() - 19, 0))
			for i in 19:
				var k := top + i
				if k >= _spoils.items.size():
					break
				var it := _spoils.items[k]
				var name := (it.name if it.name != "" else "ITEM").to_upper()
				_scr.text(1, 4 + i, name.left(38), GameScreen.WHITE if k == _cursor else GameScreen.GREEN)
			_scr.text(0, 24, "ITEMS:", 13)
			_scr.menu_line(24, LIST_MENU, 7, _pick)
			_scr.update()


func _walk(menu: Array, lines: PackedStringArray, label: String = "") -> void:
	_scr.draw_walk(picture, _party, _who, "", lines, [], false, false, 0)
	if label != "":
		_scr.text(0, 24, label, 13)
		_scr.menu_line(24, menu, label.length() + 1, _pick)
	else:
		_scr.menu_line(24, menu, 0, _pick)
	_scr.update()


## "THERE IS STILL TREASURE LEFT." in light green, the question in white, wrapped together.
func _ask_text() -> void:
	draw_ask(_scr, "THERE IS STILL TREASURE LEFT.", "DO YOU WANT TO GO BACK AND CLAIM YOUR TREASURE?")


## A question under the view, as the original prints it from row 17 (GAME.OVR 0x73A4, 0x709:0x768
## with 1, 17, 38, 22): `green` in light green, then `white` after two spaces, word-wrapped together.
static func draw_ask(scr: GameScreen, green: String, white: String) -> void:
	var words := []
	for w in green.strip_edges().split(" "):
		words.append([w, GameScreen.GREEN])
	words.append(["", GameScreen.GREEN])     # the original's two spaces after the full stop
	for w in white.split(" "):
		words.append([w, GameScreen.WHITE])
	var col := 1
	var row := 17
	for p in words:
		var w: String = p[0]
		if col > 1 and col + w.length() > 39:
			col = 1
			row += 1
		scr.text(col, row, w, p[1])
		col += w.length() + 1


func _page_frame() -> void:
	_scr.clear()
	for c in 40:
		_scr.tile(c, 0, 22)
		_scr.tile(c, 23, 22)
	for r in range(1, 23):
		_scr.tile(0, r, 21)
		_scr.tile(39, r, 21)
	for p in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 23), Vector2i(39, 23)]:
		_scr.tile(p.x, p.y, 20)


func _coin_kinds() -> Array:
	var out := []
	for c in 7:
		if _spoils.money[c] > 0:
			out.append(c)
	return out


# --- Actions (the bot calls these too) ----------------------------------------------------

## Takes item `i` from the pile for the chosen character.
func _take_item(i: int) -> bool:
	if i < 0 or i >= _spoils.items.size() or _party.is_empty():
		return false
	var m := _party[_who]
	var it: GameItem = _spoils.items[i]
	# GAME.OVR 0x6F0D: 0x23795 refuses a 17th item or one over the load ceiling ("OverLoaded").
	if not m.can_take_item(it):
		_refuse("OVERLOADED")
		return false
	_spoils.items.remove_at(i)
	m.items.append(it)
	_note.text = "%s TAKES THE %s." % [m.name, it.name.to_upper()]
	_cursor = clampi(_cursor, 0, maxi(_spoils.items.size() - 1, 0))
	_refresh()
	return true


func _take_money(c: int, n: int) -> void:
	n = clampi(n, 0, _spoils.money[c])
	# GAME.OVR 0x2570F: when the amount doesn't fit under the load ceiling (0x24CDD), nothing
	# is taken (main's lab, chat 26: Thrender at 1995 of 2000 took 5 gold, 6 refused).
	if not _party[_who].can_take_coins(n):
		_refuse("OVERLOADED")
		return
	_party[_who].money[c] += n
	_spoils.money[c] -= n
	_note.text = "%s TAKES %d %s." % [_party[_who].name, n, MONEY_LABELS[c]]


## The original's refusal (START.EXE 0xBA:0x1693, as the sheet's messages): row 24 for a moment.
func _refuse(text: String) -> void:
	_note.text = text + "."
	_flash = text
	_flash_id += 1
	var id := _flash_id
	_refresh()
	if not is_inside_tree():
		_flash = ""
		return
	await get_tree().create_timer(CharacterSheet.MESSAGE_TIME * CampScreen.delay_scale()).timeout
	if id == _flash_id:
		_flash = ""
		_refresh()


## POOL and SHARE as the original (CoinPile: player characters only; Combat Chat 13).
func _pool() -> void:
	_spoils.money = CoinPile.pool(_party, _spoils.money)
	_refresh()


func _share() -> void:
	if _party.is_empty():
		return
	_spoils.money = CoinPile.share(_party, _spoils.money)
	_refresh()


func _view() -> void:
	if _party.is_empty():
		return
	_sheet.open(_party, "PARTY", _who)


func _exit() -> void:
	if _spoils.has_treasure():
		_mode = "ask_exit"
		_pick = 0
		_refresh()
		return
	_close()


func _close() -> void:
	visible = false
	closed.emit()


# --- Keys ---------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or not event is InputEventKey or (_sheet != null and _sheet.visible):
		return
	var key := (event as InputEventKey).keycode
	get_viewport().set_input_as_handled()
	if _mode == "results":
		if key in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_SPACE]:
			# The menu comes with nothing to take too (the original's VIEW POOL EXIT; lab,
			# Combat Chat 4: 4:21's frogs, Tyranthraxus; main's closing-scene request).
			_show_treasure()
		return
	if _mode == "amount":
		if key >= KEY_0 and key <= KEY_9 and _typed.length() < 6:
			_typed += char(key)
		elif key == KEY_BACKSPACE:
			_typed = _typed.left(-1)
		elif key in [KEY_ENTER, KEY_KP_ENTER]:
			_take_money(_amount_coin, _typed.to_int())
			_mode = "coins"
			_cursor = 0
			if _coin_kinds().is_empty():
				_mode = "take"
		elif key == KEY_ESCAPE:
			_mode = "coins"
		_refresh()
		return
	var items: Array = _menu()
	match _mode:
		"take": items = TAKE_MENU
		"items": items = LIST_MENU
		"coins": items = ["EXIT"]
		"ask_exit": items = ASK_MENU
	var choice := ""
	if key in [KEY_ENTER, KEY_KP_ENTER]:
		choice = items[clampi(_pick, 0, items.size() - 1)]
		if _mode == "coins":
			choice = "COIN"
	elif key == KEY_LEFT or key == KEY_RIGHT:
		_pick = (_pick + (1 if key == KEY_RIGHT else -1) + items.size()) % items.size()
		_refresh()
		return
	elif key in [KEY_UP, KEY_DOWN, KEY_HOME, KEY_END, KEY_KP_7, KEY_KP_1]:
		# The original moves through lists and the party with Home and End (keypad 7 and 1).
		var step := 1 if key in [KEY_DOWN, KEY_END, KEY_KP_1] else -1
		if _mode in ["menu", "take"]:
			_who = (_who + step + _party.size()) % maxi(_party.size(), 1)
		elif _mode == "coins":
			_cursor = clampi(_cursor + step, 0, maxi(_coin_kinds().size() - 1, 0))
		elif _mode == "items":
			_cursor = clampi(_cursor + step, 0, maxi(_spoils.items.size() - 1, 0))
		_refresh()
		return
	elif key == KEY_ESCAPE:
		choice = "EXIT" if "EXIT" in items else "NO"
	else:
		for it in items:
			if String(it).unicode_at(0) == key:
				choice = it
	if choice == "":
		return
	if choice != "COIN":
		_pick = items.find(choice)
	match _mode:
		"menu":
			match choice:
				"VIEW": _view()
				"TAKE":
					_mode = "take"
					_refresh()
				"POOL": _pool()
				"SHARE": _share()
				"EXIT": _exit()
		"take":
			match choice:
				"MONEY":
					if _spoils.has_money():
						_mode = "coins"
						_cursor = 0
						_refresh()
				"ITEMS":
					if not _spoils.items.is_empty():
						_mode = "items"
						_cursor = 0
						_refresh()
				"EXIT":
					_mode = "menu"
					_refresh()
		"coins":
			if choice == "COIN":
				var kinds := _coin_kinds()
				if _cursor < kinds.size():
					_amount_coin = kinds[_cursor]
					_typed = ""
					_mode = "amount"
			else:
				_mode = "take"
			_refresh()
		"items":
			match choice:
				"TAKE":
					_take_item(_cursor)
					if _spoils.items.is_empty():
						_mode = "take"
						_refresh()
				"EXIT":
					_mode = "take"
					_refresh()
		"ask_exit":
			if choice == "YES":
				_mode = "menu"
				_refresh()
			else:
				_close()
