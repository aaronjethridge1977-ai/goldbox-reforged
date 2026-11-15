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
## Not yet: blindness and curses aren't conditions our characters can have, so those cures
## always ask "cast cure anyway"; APPRAISE; Raise Dead's loss of constitution.

signal closed

const CURES := [["CURE BLINDNESS", 1000], ["CURE DISEASE", 1000], ["CURE LIGHT WOUNDS", 100],
	["CURE SERIOUS WOUNDS", 350], ["CURE CRITICAL WOUNDS", 600], ["NEUTRALIZE POISON", 1000],
	["RAISE DEAD", 5500], ["REMOVE CURSE", 3500], ["STONE TO FLESH", 2000]]
const NOT_NEEDED := ["IS NOT BLIND.", "IS NOT DISEASED.", "", "", "", "IS NOT POISONED.",
	"IS NOT DEAD.", "IS NOT CURSED.", "IS NOT STONED."]
const MENU := ["HEAL", "VIEW", "POOL", "APPRAISE", "EXIT"]
const LIST_MENU := ["HEAL", "EXIT"]
const YES_NO := ["YES", "NO"]

var _party: Array[PartyMember] = []
var _who := 0
var _cure := 0               # the chosen line of the list (CURES.size() is EXIT)
var _mode := "menu"          # menu, list, anyway, pay
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


func open(party: Array[PartyMember]) -> void:
	_party = party
	_who = 0
	_cure = 0
	_mode = "menu"
	_pick = 0
	_lines = []
	_note.text = ""
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
	if _mode == "menu":
		_scr.draw_walk(OverlayLook.last_view, _party, _who, "", PackedStringArray(), MENU, false, false, _pick)
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


func _say(lines: Array) -> void:
	_lines = []
	var text := PackedStringArray()
	for l in lines:
		for w in GameScreen.wrap(l[0], 38):
			_lines.append([w, l[1]])
			text.append(w)
	_note.text = " ".join(text)


# --- Actions (the bot calls these too) ----------------------------------------------------

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
	return false   # blindness, curses: not modelled yet


func _pay() -> void:
	var m := _party[_who]
	if not m.pay_gold(CURES[_cure][1]):
		# The original says nothing here, not even briefly (lab, three captures over 3 s): the
		# list comes back with an empty text box. Only the bot's note says why.
		_lines = []
		_note.text = "NOT ENOUGH MONEY."
		_mode = "list"
		_refresh()
		return
	match CURES[_cure][0]:
		"CURE LIGHT WOUNDS":
			_heal(m, _rng.randi_range(1, 8))
		"CURE SERIOUS WOUNDS":
			_heal(m, _rng.randi_range(1, 8) + _rng.randi_range(1, 8) + 1)
		"CURE CRITICAL WOUNDS":
			_heal(m, _rng.randi_range(1, 8) + _rng.randi_range(1, 8) + _rng.randi_range(1, 8) + 3)
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
		"NEUTRALIZE POISON":
			for b in m.affects.duplicate():
				if int(b.effect) in [SpellCaster.POISONED, SpellCaster.SLOWED_POISON, SpellCaster.POISON_TICK]:
					m.affects.erase(b)
	_say([["%s IS CURED." % m.name, GameScreen.GREEN]])
	_mode = "list"
	_refresh()


func _heal(m: PartyMember, amount: int) -> void:
	if SpecialAffects.diseased(m):
		return
	if m.status in [PartyMember.STATUS_OKAY, PartyMember.STATUS_UNCONSCIOUS, PartyMember.STATUS_DYING]:
		m.hp = mini(m.hp + amount, m.hp_max)
		if m.hp > 0:
			m.status = PartyMember.STATUS_OKAY


func _pool() -> void:
	var to := _party[_who]
	for m in _party:
		if m == to:
			continue
		for c in 5:
			to.money[c] += m.money[c]
			m.money[c] = 0
	_refresh()


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
	var items: Array = MENU
	match _mode:
		"list": items = LIST_MENU
		"anyway", "pay": items = YES_NO
	# The original moves through lists and the party with Home and End (keypad 7 and 1).
	var up := key in [KEY_HOME, KEY_KP_7, KEY_UP]
	var down := key in [KEY_END, KEY_KP_1, KEY_DOWN]
	if up or down:
		var step := 1 if down else -1
		if _mode == "menu":
			_who = (_who + step + _party.size()) % _party.size()
		elif _mode == "list":
			_cure = clampi(_cure + step, 0, CURES.size())
		_refresh()
		return
	var choice := ""
	if key in [KEY_ENTER, KEY_KP_ENTER]:
		choice = items[clampi(_pick, 0, items.size() - 1)]
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
	if choice == "":
		return
	_pick = items.find(choice)
	match _mode:
		"menu":
			match choice:
				"HEAL":
					_mode = "list"
					_lines = []
					_refresh()
				"VIEW": _sheet.open(_party, "PARTY", _who)
				"POOL": _pool()
				"APPRAISE": pass        # not yet
				"EXIT":
					visible = false
					closed.emit()
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
