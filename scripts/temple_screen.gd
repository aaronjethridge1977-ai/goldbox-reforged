class_name TempleScreen
extends Control
## A temple: the original's HEAL menu. A script opens it by writing 1 to TEMPLE_FLAG and
## running COMBAT (New Phlan's temples of Tyr, Sune and Tempus: "DO YOU SEEK HEALING?").
##
## As the original does it (texts and prices from Pool of Radiance's own GAME.OVR; the
## rules as documented by Pilgrim's reconstruction of the same engine):
## - "<NAME>, HOW CAN WE HELP YOU?" with nine cures, in gold: Cure Blindness 1000, Cure
##   Disease 1000, Cure Light Wounds 100, Cure Serious Wounds 350, Cure Critical Wounds
##   600, Raise Dead 5500, Neutralize Poison 1000, Remove Curse 3500, Stone to Flesh 2000.
## - "<CURE> WILL ONLY COST n GOLD PIECES." then "PAY FOR CURE?"; "NOT ENOUGH MONEY."
##   otherwise; "<NAME> IS CURED." when paid.
## - Wound cures heal 1d8, 2d8+1 and 3d8+3, up to full HP (paid even at full HP, as in the
##   original); an unconscious character wakes. Raise Dead brings the dead back at 1 HP.
## - A cure for something the character doesn't have asks first ("<NAME> IS NOT DEAD.
##   CAST CURE ANYWAY?").
## Modern controls, as in the shop: Left/Right choose the character, Up/Down the cure,
## Enter asks for it, Y/N answer, P pools the party's money with the chosen character,
## V views, Esc leaves.
## Not yet: blindness, disease, poison, curses and stoning aren't conditions our
## characters can have yet, so those cures always ask "cast cure anyway"; APPRAISE
## (gems and jewellery); Raise Dead's loss of constitution.

signal closed

const CURES := [["CURE BLINDNESS", 1000], ["CURE DISEASE", 1000], ["CURE LIGHT WOUNDS", 100],
	["CURE SERIOUS WOUNDS", 350], ["CURE CRITICAL WOUNDS", 600], ["RAISE DEAD", 5500],
	["NEUTRALIZE POISON", 1000], ["REMOVE CURSE", 3500], ["STONE TO FLESH", 2000]]
const NOT_NEEDED := ["IS NOT BLIND.", "IS NOT DISEASED.", "", "", "", "IS NOT DEAD.",
	"IS NOT POISONED.", "IS NOT CURSED.", "IS NOT STONED."]

var _party: Array[PartyMember] = []
var _who := 0
var _cure := 2
var _asking := ""            # "anyway" or "pay" while a Y/N question is open
var _rng := RandomNumberGenerator.new()

var _head: Label
var _party_label: Label
var _list_label: Label
var _note: Label
var _sheet: CharacterSheet


func open(party: Array[PartyMember]) -> void:
	_party = party
	_who = 0
	_cure = 2
	_asking = ""
	_rng.randomize()
	if _head == null:
		_build()
	_note.text = ""
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
	box.offset_left = 48
	box.offset_right = -48
	box.offset_top = 24
	box.offset_bottom = -24
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	_head = Label.new()
	_head.add_theme_font_size_override("font_size", 24)
	_head.add_theme_color_override("font_color", Color8(85, 255, 85))
	box.add_child(_head)
	_party_label = Label.new()
	_party_label.add_theme_font_size_override("font_size", 19)
	_party_label.add_theme_font_override("font", mono)
	box.add_child(_party_label)
	_list_label = Label.new()
	_list_label.add_theme_font_size_override("font_size", 19)
	_list_label.add_theme_font_override("font", mono)
	box.add_child(_list_label)
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 19)
	_note.modulate = Color(1, 0.85, 0.4)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_note)
	var help := Label.new()
	help.text = "←/→ who   ↑/↓ cure   Enter heal   P pool money   V view   Esc exit"
	help.add_theme_font_size_override("font_size", 17)
	box.add_child(help)
	_sheet = CharacterSheet.new()
	_sheet.visible = false
	add_child(_sheet)


func _refresh() -> void:
	if _party.is_empty():
		_head.text = "TEMPLE"
		return
	var m := _party[_who]
	_head.text = "%s, HOW CAN WE HELP YOU?" % m.name
	var lines := PackedStringArray(["  %-16s HP     STATUS        GOLD" % "NAME"])
	for i in _party.size():
		var p := _party[i]
		lines.append("%s %-16s %2d/%-2d  %-12s %5d" % [">" if i == _who else " ", p.name, p.hp, p.hp_max,
			p.status_name(), p.wealth_copper() / 200])
	_party_label.text = "\n".join(lines)
	var cures := PackedStringArray()
	for i in CURES.size():
		cures.append("%s %-22s %5d" % [">" if i == _cure else " ", CURES[i][0], CURES[i][1]])
	_list_label.text = "\n".join(cures)


func _ask() -> void:
	var m := _party[_who]
	var need := _needs(m, _cure)
	if not need:
		_asking = "anyway"
		_note.text = "%s %s CAST CURE ANYWAY?  Y / N" % [m.name, NOT_NEEDED[_cure]]
		return
	_ask_price()


func _ask_price() -> void:
	_asking = "pay"
	_note.text = "%s WILL ONLY COST %d GOLD PIECES.  PAY FOR CURE?  Y / N" % [CURES[_cure][0], CURES[_cure][1]]


## Does character `m` have what cure `i` cures? (Wound cures are always offered.)
func _needs(m: PartyMember, i: int) -> bool:
	match i:
		2, 3, 4:
			return true
		5:
			return m.status == PartyMember.STATUS_DEAD
	return false   # blindness, disease, poison, curses, stoning: not modelled yet


func _pay() -> void:
	var m := _party[_who]
	if not m.pay_gold(CURES[_cure][1]):
		_note.text = "NOT ENOUGH MONEY."
		return
	match _cure:
		2:
			_heal(m, _rng.randi_range(1, 8))
		3:
			_heal(m, _rng.randi_range(1, 8) + _rng.randi_range(1, 8) + 1)
		4:
			_heal(m, _rng.randi_range(1, 8) + _rng.randi_range(1, 8) + _rng.randi_range(1, 8) + 3)
		5:
			if m.status == PartyMember.STATUS_DEAD:
				m.status = PartyMember.STATUS_OKAY
				m.hp = 1
	_note.text = "%s IS CURED." % m.name
	_refresh()


func _heal(m: PartyMember, amount: int) -> void:
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
	_note.text = "THE PARTY'S MONEY IS POOLED WITH %s." % to.name
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or _sheet.visible:
		return
	get_viewport().set_input_as_handled()
	if _party.is_empty():
		if event.is_action("ui_cancel"):
			visible = false
			closed.emit()
		return
	var key := (event as InputEventKey).keycode if event is InputEventKey else KEY_NONE
	if _asking != "":
		if key == KEY_Y:
			var was := _asking
			_asking = ""
			if was == "anyway":
				_ask_price()
			else:
				_pay()
		elif key == KEY_N or event.is_action("ui_cancel"):
			_asking = ""
			_note.text = ""
		return
	if event.is_action("ui_cancel") or key == KEY_E:
		visible = false
		closed.emit()
	elif event.is_action("ui_left"):
		_who = (_who + _party.size() - 1) % _party.size()
		_note.text = ""
		_refresh()
	elif event.is_action("ui_right"):
		_who = (_who + 1) % _party.size()
		_note.text = ""
		_refresh()
	elif event.is_action("ui_up"):
		_cure = (_cure + CURES.size() - 1) % CURES.size()
		_refresh()
	elif event.is_action("ui_down"):
		_cure = (_cure + 1) % CURES.size()
		_refresh()
	elif event.is_action("ui_accept") or key == KEY_H:
		_ask()
	elif key == KEY_P:
		_pool()
	elif key == KEY_V:
		_sheet.open(_party, "PARTY", _who)
