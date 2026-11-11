class_name CharacterModify
extends Control
## MODIFY CHARACTER (the party menu), as the original: the character page with one value
## in magenta; Up/Down choose STR..CHA or HP (wrapping), Right/Left raise or lower it within
## the race's and class's limits (STR 18 goes on to 18(01)..18(99) for a fighter, as far as
## race and sex allow; HP from 1 to the classes' dice at their most, with CON);
## "MODIFY CHARACTER: KEEP EXIT". Lab-checked on a new dwarf fighter.
## Offered, as here, for characters who have not adventured yet (no experience).

signal finished(changed: bool)

var game_path := ""
var tables: ClassTables
var spells: SpellTable
var types: ItemTypes

var _rules: CreationRules
var _screen: GameScreen
var _member: PartyMember
var _d := PackedByteArray()
var _sel := 0
var _view: PartyMember
var _portrait: Image


func open(path: String, m: PartyMember, portrait: Image) -> void:
	game_path = path
	_rules = CreationRules.shared(path)
	_member = m
	_d = m.to_record()
	_portrait = portrait
	_sel = 0
	ShopScreen._fill(self, 0)
	if _screen == null:
		var bg := ColorRect.new()
		bg.color = Color.BLACK
		ShopScreen._fill(bg, 0)
		add_child(bg)
		_screen = GameScreen.new()
		ShopScreen._fill(_screen, 0)
		add_child(_screen)
	visible = true
	_refresh()


func _refresh() -> void:
	_view = _rules.member(_d, tables, spells, types)
	var g := _screen
	g.clear()
	CharacterCreator.draw_sheet(g, _view, _portrait, _sel)
	g.text(0, 24, "MODIFY CHARACTER:", CharacterCreator.MAGENTA)
	g.menu_line(24, ["KEEP", "EXIT"], 18)
	g.update()


func _change(step: int) -> void:
	if _sel == 6:
		var hp := clampi(_d[0x32] + step, 1, _rules.hp_most(_d))
		_d[0x32] = hp
		_d[0x11B] = hp
		return
	var r := _rules.ability_range(_d, _sel)
	var v := _d[0x10 + _sel]
	if _sel == 0 and _d[0x98] > 0 and v == 18 and _rules.exceptional_max(_d) > 0:
		# 18, 18(01) .. 18(99), 18(00)
		var e := _d[0x16]
		if step > 0 and e < _rules.exceptional_max(_d):
			_d[0x16] = e + 1
			return
		if step < 0 and e > 0:
			_d[0x16] = e - 1
			return
	_d[0x10 + _sel] = clampi(v + step, r.x, r.y)
	if _d[0x10] != 18:
		_d[0x16] = 0


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	match (event as InputEventKey).keycode:
		KEY_UP:
			_sel = (_sel + 6) % 7
		KEY_DOWN:
			_sel = (_sel + 1) % 7
		KEY_RIGHT, KEY_KP_ADD, KEY_EQUAL:
			_change(1)
		KEY_LEFT, KEY_KP_SUBTRACT, KEY_MINUS:
			_change(-1)
		KEY_K:
			var fresh := PartyMember.from_bytes(_d, PackedByteArray())
			for k in [0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x32, 0x11B]:
				_member.raw[k] = _d[k]
			_member.stats = fresh.stats
			_member.strength_exceptional = fresh.strength_exceptional
			_member.hp_max = fresh.hp_max
			_member.hp = fresh.hp
			if tables != null:
				_member.apply_class_tables(tables, spells)
			_member.recalculate(types)
			visible = false
			finished.emit(true)
			return
		KEY_E, KEY_ESCAPE:
			visible = false
			finished.emit(false)
			return
	_refresh()
