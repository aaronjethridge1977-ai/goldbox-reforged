class_name TempleScreen
extends Control
## A temple, as the original shows it (Jeremy, 2026-11-12: every screen matches the original).
## A script opens it by writing 1 to TEMPLE_FLAG and running COMBAT (New Phlan's temples of
## Tyr, Sune and Tempus: "DO YOU SEEK HEALING?").
##
## Screens and keys from the lab (chat 10, the temple of Tempus, New Phlan 2,12):
##   the adventure screen with the priest's picture, the party list (Home/End: who), no place
##     line, HEAL VIEW POOL APPRAISE EXIT;
##   HEAL: a page headed "<NAME>, HOW CAN WE HELP YOU?" (row 1, rope under it at row 2), the
##     cures from row 4 at column 2 with EXIT last, the chosen one white (Home/End move it),
##     the text box below, HEAL EXIT;
##   a cure for something the character doesn't have: "<NAME>" (light cyan) "IS NOT BLIND."
##     in the text box, "CAST CURE ANYWAY:" then YES NO with NO lit;
##   "<CURE> WILL ONLY COST n GOLD PIECES." then "PAY FOR CURE" YES NO; "NOT ENOUGH MONEY."
##     otherwise; "<NAME> IS CURED." when paid. (Their exact look after paying: not yet.)
## Rules (texts and prices from Pool of Radiance's own GAME.OVR; as documented by Pilgrim's
## reconstruction): wound cures heal 1d8, 2d8+1 and 3d8+3 up to full HP (paid even at full
## HP); an unconscious character wakes; Raise Dead brings the dead back at 1 HP; Cure Disease
## ends a mummy's disease; Stone to Flesh brings the stoned back at 1 HP (GAME.OVR 0x4EB4).
## The wound cures don't heal the diseased (the original's heal skips them).
## NEUTRALIZE POISON (GAME.OVR 0x4CC9, Combat Chat 3): needed when the member has effect 0x37
## (poisoned); paid, it removes 0x37, Slow Poison's 0x16 and its tick 0x0F, nothing else (a
## member dead of poison stays dead: Raise Dead after).
## The money pile (GAME.OVR's temple loop 0x5280, Combat Chat 31; main's 3:0 temple ready check): the
## shop's pile (CoinPile, DS:0x67F4), emptied as the temple opens (0x529D). POOL (0x25191) puts the
## player characters' coins on it; with money on it the menu is HEAL VIEW TAKE POOL SHARE APPRAISE EXIT
## (0x51B6), TAKE the treasure's coin page (0x25974), SHARE the treasure's split (0x252C3: a stale load
## word's wrap included). A cure is paid (0x46E1) by the member's purse if it is worth the price (its
## coins become platinum and gold: CoinPile.set_gold), else by the pile if it is, else "NOT ENOUGH
## MONEY.". EXIT with money on the pile asks 'As you leave a priest says, "Excuse me but you have left
## some money here"' / "Do you want to go back and retrieve your money?" (0x53A3, YES NO): NO leaves
## it behind.
## Not yet: blindness and curses aren't conditions our characters can have, so those cures
## always ask "cast cure anyway"; Raise Dead's loss of constitution. APPRAISE is the shop's (main chat 74).

signal closed

const CURES := [["CURE BLINDNESS", 1000], ["CURE DISEASE", 1000], ["CURE LIGHT WOUNDS", 100],
	["CURE SERIOUS WOUNDS", 350], ["CURE CRITICAL WOUNDS", 600], ["NEUTRALIZE POISON", 1000],
	["RAISE DEAD", 5500], ["REMOVE CURSE", 3500], ["STONE TO FLESH", 2000]]
const NOT_NEEDED := ["IS NOT BLIND.", "IS NOT DISEASED.", "", "", "", "IS NOT POISONED.",
	"IS NOT DEAD.", "IS NOT CURSED.", "IS NOT STONED."]
const MENU := ["HEAL", "VIEW", "POOL", "APPRAISE", "EXIT"]
const POOL_MENU := ["HEAL", "VIEW", "TAKE", "POOL", "SHARE", "APPRAISE", "EXIT"]
const LIST_MENU := ["HEAL", "EXIT"]
const YES_NO := ["YES", "NO"]
const BLIND := 0x21     # Cause Blindness's effect (GAME.OVR 0x47D9 tests it, 0x4834 removes it)

var _party: Array[PartyMember] = []
var _who := 0
var _cure := 0               # the chosen line of the list (CURES.size() is EXIT)
var _mode := "menu"          # menu, list, anyway, pay, coins, amount, ask_leave, appraise, value
var _app_text := ""          # APPRAISE's text box (the shop's: ShopScreen), "" when none
var _jewel := false          # APPRAISE: the piece just valued is jewellery
var _value := 0              # ... and its value
var _keep_ok := true         # ... and KEEP is offered for it
## The temple's money pile (CoinPile): POOL puts coins on it, TAKE and SHARE give them back.
var pile := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
var _coin := 0               # the coin page's lit line
var _amount_coin := -1
var _typed := ""
var _pick := 0
var _lines: Array = []       # the text box: [[text, colour], ...] a line each
var _note := Label.new()     # what happened (the bot logs it)
var _rng := RandomNumberGenerator.new()
var _scr: GameScreen
var _sheet: CharacterSheet


func _init() -> void:
	_note.visible = false
	add_child(_note)


func cure_index(name: String) -> int:
	for i in CURES.size():
		if CURES[i][0] == name:
			return i
	return -1


## The member selected when the temple closes: it stays selected, as the shop's last buyer (Combat Chat 23).
func who() -> int:
	return _who


## `who`: the member selected on the walking screen (the original's temple opens on it: Player 3's
## sweep, Tyr's greeting runs the mad-man check, LOAD_CHAR 0..7, which leaves the last member
## selected, and the HEAL page reads "DORN, HOW CAN WE HELP YOU?"; Combat Chat 7).
func open(party: Array[PartyMember], who: int = 0) -> void:
	_party = party
	_who = clampi(who, 0, maxi(party.size() - 1, 0))
	_cure = 0
	_mode = "menu"
	_pick = 0
	_lines = []
	_note.text = ""
	pile = PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
	_rng.randomize()
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


# --- Drawing ----------------------------------------------------------------------------

func _refresh() -> void:
	if _scr == null:
		return
	if _mode in ["menu", "ask_leave", "appraise", "value"]:
		var lines := PackedStringArray()
		if _mode != "ask_leave":
			for l in _app_text.split("\n", false):
				lines.append_array(GameScreen.wrap(l, 38))
		_scr.draw_walk(OverlayLook.last_view, _party, _who, "", lines, _menu_items(), false, false, _pick)
		if _mode == "ask_leave":
			TreasureScreen.draw_ask(_scr, "AS YOU LEAVE A PRIEST SAYS, \"EXCUSE ME BUT YOU HAVE LEFT SOME MONEY HERE\"",
				"DO YOU WANT TO GO BACK AND RETRIEVE YOUR MONEY?")
			_scr.update()
		return
	if _mode in ["coins", "amount"]:
		ShopScreen.draw_coin_page(_scr, pile, _mode == "coins", _coin, _amount_coin, _typed)
		return
	_scr.clear()
	for c in 40:
		_scr.tile(c, 0, 22)
		_scr.tile(c, 2, 22)
		_scr.tile(c, 16, 22)
		_scr.tile(c, 23, 22)
	for r in range(1, 23):
		_scr.tile(0, r, 21)
		_scr.tile(39, r, 21)
	for r in [0, 2, 16, 23]:
		_scr.tile(0, r, 20)
		_scr.tile(39, r, 20)
	var m: PartyMember = _party[_who] if not _party.is_empty() else null
	if m != null:
		_scr.text(1, 1, "%s, HOW CAN WE HELP YOU?" % m.name, GameScreen.WHITE)
	for i in CURES.size() + 1:
		var label: String = CURES[i][0] if i < CURES.size() else "EXIT"
		_scr.text(2, 4 + i, label, GameScreen.WHITE if i == _cure and _mode == "list" else GameScreen.GREEN)
	for i in mini(_lines.size(), 6):
		_scr.text(1, 17 + i, _lines[i][0], _lines[i][1])
	match _mode:
		"list":
			_scr.menu_line(24, LIST_MENU, 0, _pick)
		"anyway":
			_scr.text(0, 24, "CAST CURE ANYWAY:", 13)
			_scr.menu_line(24, YES_NO, 18, _pick)
		"pay":
			# This menu has no hot letters lit: the chosen item white but for its first letter,
			# the other light green (lab, two captures).
			_scr.text(0, 24, "PAY FOR CURE", 13)
			var col := 13
			for i in YES_NO.size():
				var w: String = YES_NO[i]
				_scr.text(col, 24, w.left(1), GameScreen.GREEN)
				_scr.text(col + 1, 24, w.substr(1), GameScreen.WHITE if i == _pick else GameScreen.GREEN)
				col += w.length() + 1
	_scr.update()


## The walking menu's words: the pile's longer menu while money is on it (GAME.OVR 0x52C1).
func _menu_items() -> Array:
	if _mode == "ask_leave":
		return YES_NO
	if _mode == "appraise":
		return ["GEMS", "JEWELRY", "EXIT"]
	if _mode == "value":
		return ["SELL", "KEEP"] if _keep_ok else ["SELL"]
	return POOL_MENU if CoinPile.has_money(pile) else MENU


func _say(lines: Array) -> void:
	_lines = []
	var text := PackedStringArray()
	for l in lines:
		for w in GameScreen.wrap(l[0], 38):
			_lines.append([w, l[1]])
			text.append(w)
	_note.text = " ".join(text)


# --- Actions (the bot calls these too) ----------------------------------------------------

## APPRAISE (main chat 74: the original's temple APPRAISE is the shop's, GAME.OVR 0x26680): the member's
## gems and jewellery one at a time, SELL or KEEP (ShopScreen's rules and helpers).
func _appraise() -> void:
	var m := _party[_who]
	if m.money[5] == 0 and m.money[6] == 0:
		_app_text = "NO GEMS OR JEWELRY"
		_note.text = _app_text
		_refresh()
		return
	_mode = "appraise"
	_show_collection()


func _show_collection() -> void:
	_app_text = "\n".join(ShopScreen.collection_lines(_party[_who]))
	_note.text = _app_text.replace("\n", " ")
	_pick = 0
	_refresh()


func appraise_one(jewel: bool) -> int:
	var m := _party[_who]
	var k := 6 if jewel else 5
	if m.money[k] <= 0:
		return -1
	m.money[k] -= 1
	_jewel = jewel
	_value = ShopScreen.piece_value(jewel, _rng)
	_keep_ok = ShopScreen.keep_offered(m)
	_mode = "value"
	_app_text = "THE %s IS VALUED AT %d GP." % ["JEWEL" if jewel else "GEM", _value]
	_note.text = _app_text
	_pick = 0
	_refresh()
	return _value


func settle(sell: bool) -> void:
	var m := _party[_who]
	var said := ""
	if sell or not _keep_ok:
		var paid := ShopScreen.appraisal_pay(m, _value / 5)
		said = paid[0]
		pile[4] += int(paid[1])
	else:
		m.items.append(ShopScreen.appraised_item(_jewel, _value))
	m.refresh_load_word()     # GAME.OVR 0x26ECA
	if m.money[5] > 0 or m.money[6] > 0:
		_mode = "appraise"
		_show_collection()
		if said != "":
			_app_text = said + "\n" + _app_text
	else:
		_mode = "menu"
		_app_text = said
	_note.text = _app_text.replace("\n", " ")
	_refresh()


func _ask() -> void:
	if _cure >= CURES.size():
		_mode = "menu"
		_pick = MENU.size() - 1
		_lines = []
		_refresh()
		return
	var m := _party[_who]
	if not _needs(m, _cure):
		_mode = "anyway"
		_pick = 1        # NO lit (lab)
		_lines = [["", GameScreen.GREEN], [m.name, GameScreen.CYAN], [NOT_NEEDED[_cure], GameScreen.GREEN]]
		_note.text = "%s %s" % [m.name, NOT_NEEDED[_cure]]
		_refresh()
		return
	_ask_price()


func _ask_price() -> void:
	_mode = "pay"
	_pick = 0
	_say([["%s WILL ONLY COST %d GOLD PIECES." % [CURES[_cure][0], CURES[_cure][1]], GameScreen.GREEN]])
	_refresh()


## Does character `m` have what cure `i` cures? (Wound cures are always offered.)
func _needs(m: PartyMember, i: int) -> bool:
	match CURES[i][0]:
		"CURE LIGHT WOUNDS", "CURE SERIOUS WOUNDS", "CURE CRITICAL WOUNDS":
			return true
		"CURE DISEASE":
			return SpecialAffects.diseased(m) or m.has_affect(SpecialAffects.ROT)
		"RAISE DEAD":
			return m.status == PartyMember.STATUS_DEAD
		"STONE TO FLESH":
			return m.status == SpecialAffects.STONED
		"NEUTRALIZE POISON":
			return m.has_affect(SpellCaster.POISONED)
		"CURE BLINDNESS":
			return m.has_affect(BLIND)
		"REMOVE CURSE":
			# GAME.OVR 0x4DB6: a carried item with its curse byte (record 54) set, or effect 0x24.
			for it in m.items:
				if it.cursed:
					return true
			return m.has_affect(0x24)
	return false


func _pay() -> void:
	var m := _party[_who]
	# GAME.OVR 0x46E1: the purse pays if it is worth the price, else the pile, else nothing.
	var price: int = CURES[_cure][1]
	var purse := CoinPile.gold_of(m.money)
	if price <= purse:
		m.money = CoinPile.set_gold(m.money, purse - price)
	elif price <= CoinPile.gold_of(pile):
		pile = CoinPile.set_gold(pile, CoinPile.gold_of(pile) - price)
	else:
		# The original says nothing here, not even briefly (lab, three captures over 3 s): the
		# list comes back with an empty text box. Only the bot's note says why.
		_lines = []
		_note.text = "NOT ENOUGH MONEY."
		_mode = "list"
		_refresh()
		return
	match CURES[_cure][0]:
		"CURE LIGHT WOUNDS":
			_heal(m, _d8(1))
		"CURE SERIOUS WOUNDS":
			_heal(m, _d8(2) + 1)
		"CURE CRITICAL WOUNDS":
			_heal(m, _d8(3) + 3)
		"CURE DISEASE":
			SpecialAffects.cure_disease(m)
		"RAISE DEAD":
			# GAME.OVR 0x4A86: HP 1, status 0, effects 0x20 and 0x37 off, then the loss
			# (main's PartyMember.raised_from_dead: CON - 1 and the max-HP cut; chat 26's lab).
			if m.status == PartyMember.STATUS_DEAD:
				m.status = PartyMember.STATUS_OKAY
				m.hp = 1
				for b in m.affects.duplicate():
					if int(b.effect) in [0x20, SpellCaster.POISONED]:
						m.affects.erase(b)
				m.raised_from_dead()
		"STONE TO FLESH":
			if m.status == SpecialAffects.STONED:
				m.status = PartyMember.STATUS_OKAY
				m.hp = 1
		"CURE BLINDNESS":
			# GAME.OVR 0x482C: the first effect 0x21 goes (0x2AF10).
			for b in m.affects:
				if int(b.effect) == BLIND:
					m.affects.erase(b)
					break
		"REMOVE CURSE":
			# GAME.OVR 0x29558 (the spell): effect 0x24 goes if there is one, else the first carried
			# item with its curse byte set loses it ("'S ITEM IS UN-CURSED").
			var gone := false
			for b in m.affects:
				if int(b.effect) == 0x24:
					m.affects.erase(b)
					gone = true
					break
			var said := ""
			if gone:
				said = "IS UN-CURSED"
			else:
				for it in m.items:
					if it.cursed:
						it.cursed = false
						said = "'S ITEM IS UN-CURSED"
						break
			# The spell's own text (GAME.OVR 0x29537 / 0x29544 through START.EXE 0x2B8B -> 0x228C: out of
			# combat the name on one line, the text on the next, as IS NOT CURSED), not "IS CURED.";
			# nothing when there was nothing to lift (CAST CURE ANYWAY). The original then holds and
			# clears the box (0x709:0xDBE, 0x2383); ours keeps it until the next key.
			if said == "":
				_lines = []
				_note.text = ""
			else:
				_lines = [["", GameScreen.GREEN], [m.name, GameScreen.CYAN], [said, GameScreen.GREEN]]
				_note.text = "%s %s" % [m.name, said]
			_mode = "list"
			_refresh()
			return
		"NEUTRALIZE POISON":
			for b in m.affects.duplicate():
				if int(b.effect) in [SpellCaster.POISONED, SpellCaster.SLOWED_POISON, SpellCaster.POISON_TICK]:
					m.affects.erase(b)
	_say([["%s IS CURED." % m.name, GameScreen.GREEN]])
	_mode = "list"
	_refresh()


## n d8 from the game's dice, as GAME.OVR 0x49AB / 0x49F7 / 0x4A45 draw them after the payment
## (main's 3:0 temple ready check: the original's d8 at 0x49B0, draw 20).
func _d8(n: int) -> int:
	var t := 0
	for k in n:
		t += (TpDice.random(8, "cure") + 1) if TpDice.on else _rng.randi_range(1, 8)
	return t


func _heal(m: PartyMember, amount: int) -> void:
	if SpecialAffects.diseased(m):
		return
	if m.status in [PartyMember.STATUS_OKAY, PartyMember.STATUS_UNCONSCIOUS, PartyMember.STATUS_DYING]:
		m.hp = mini(m.hp + amount, m.hp_max)
		if m.hp > 0:
			m.status = PartyMember.STATUS_OKAY


func _pool() -> void:
	pile = CoinPile.pool(_party, pile)
	_refresh()


func _share() -> void:
	pile = CoinPile.share(_party, pile)
	_pick = mini(_pick, _menu_items().size() - 1)
	_refresh()


func _close() -> void:
	visible = false
	closed.emit()


## E from the menu: with money on the pile a priest asks first (GAME.OVR 0x53A3).
func _leave() -> void:
	if CoinPile.has_money(pile):
		_mode = "ask_leave"
		_pick = 0
		_refresh()
		return
	_close()


# --- Keys ---------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or not event is InputEventKey or (_sheet != null and _sheet.visible):
		return
	get_viewport().set_input_as_handled()
	if _party.is_empty():
		visible = false
		closed.emit()
		return
	var key := (event as InputEventKey).keycode
	if _mode == "amount":
		if key >= KEY_0 and key <= KEY_9 and _typed.length() < 6:
			_typed += char(key)
		elif key == KEY_BACKSPACE:
			_typed = _typed.left(-1)
		elif key in [KEY_ENTER, KEY_KP_ENTER]:
			var left := ShopScreen.take_from(_party[_who], pile, _amount_coin, _typed.to_int())
			if left.is_empty():
				_note.text = "OVERLOADED"
			else:
				pile = left
			_mode = "coins"
			_coin = 0
			if ShopScreen.coin_kinds_of(pile).is_empty():
				_mode = "menu"
				_pick = 0
		elif key == KEY_ESCAPE:
			_mode = "coins"
		_refresh()
		return
	var items: Array = _menu_items()
	match _mode:
		"list": items = LIST_MENU
		"anyway", "pay": items = YES_NO
		"coins": items = ["EXIT"]
	# The original moves through lists and the party with Home and End (keypad 7 and 1).
	var up := key in [KEY_HOME, KEY_KP_7, KEY_UP]
	var down := key in [KEY_END, KEY_KP_1, KEY_DOWN]
	if up or down:
		var step := 1 if down else -1
		if _mode == "menu":
			_who = (_who + step + _party.size()) % _party.size()
		elif _mode == "list":
			_cure = clampi(_cure + step, 0, CURES.size())
		elif _mode == "coins":
			_coin = clampi(_coin + step, 0, maxi(ShopScreen.coin_kinds_of(pile).size() - 1, 0))
		_refresh()
		return
	var choice := ""
	if key in [KEY_ENTER, KEY_KP_ENTER]:
		choice = items[clampi(_pick, 0, items.size() - 1)]
		if _mode == "coins":
			choice = "COIN"
	elif key == KEY_LEFT or key == KEY_RIGHT:
		_pick = (_pick + (1 if key == KEY_RIGHT else -1) + items.size()) % items.size()
		_refresh()
		return
	elif key == KEY_ESCAPE:
		choice = "EXIT" if "EXIT" in items else "NO"
	else:
		for it in items:
			if String(it).unicode_at(0) == key:
				choice = it
		if _mode == "value" and not _keep_ok and key == KEY_K:
			choice = "SELL"
	if choice == "":
		return
	if choice != "COIN":
		_pick = items.find(choice)
	match _mode:
		"menu":
			_app_text = ""       # APPRAISE's last words go with the next choice
			match choice:
				"HEAL":
					# The list opens at its top every time (main's 3:0 temple check: End End reaches
					# CURE LIGHT WOUNDS on both visits; ours reopened it on the last cure).
					_mode = "list"
					_cure = 0
					_lines = []
					_refresh()
				"VIEW": _sheet.open(_party, "PARTY", _who)
				"TAKE":
					_mode = "coins"
					_coin = 0
					_refresh()
				"POOL": _pool()
				"SHARE": _share()
				"APPRAISE": _appraise()
				"EXIT": _leave()
		"appraise":
			match choice:
				"GEMS": appraise_one(false)
				"JEWELRY": appraise_one(true)
				"EXIT":
					_mode = "menu"
					_app_text = ""
					_pick = _menu_items().find("APPRAISE")
					_refresh()
		"value":
			settle(choice == "SELL")
		"coins":
			if choice == "COIN":
				var kinds := ShopScreen.coin_kinds_of(pile)
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
			if choice == "HEAL":
				_ask()
			else:
				_mode = "menu"
				_lines = []
				_refresh()
		"anyway":
			if choice == "YES":
				_ask_price()
			else:
				_mode = "list"
				_lines = []
				_refresh()
		"pay":
			if choice == "YES":
				_pay()
			else:
				_mode = "list"
				_lines = []
				_refresh()
