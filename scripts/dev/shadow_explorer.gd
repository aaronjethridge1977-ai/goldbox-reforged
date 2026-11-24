class_name ShadowExplorer
extends RefCounted
## Dev only (M6 coverage, 2026-11-12): when a script menu opens in a real game, tries every
## choice in a copy of the script VM (a fork: the real game is never touched) and follows each
## to its end, a few menus deep, as the original would run it from this exact state. Fights in
## the copy are taken as won, shops and other screens closed at once, and a step to another
## area ends the branch. What runs is recorded in its own coverage file, apart from what the
## played game ran: "played" is what a player saw, "branches" what the choices not taken lead
## to from the same moment.

const DEPTH := 3
const GUARD := 60

var coverage: ScriptCoverage
var forks := 0


func _init(file: String) -> void:
	coverage = ScriptCoverage.new(file)


## Explores the open menu of `real` if any of its choices hasn't run yet (played or here).
func explore(real: EclVM) -> void:
	if real.state != EclVM.State.MENU or real.menu.size() < 2 or real._menu_kind == "who":
		return
	var played: ScriptCoverage = real.coverage
	var fresh := false
	var n := 5 if real._menu_kind in ["encounter", "parlay"] else real.menu.size()
	for i in n:
		var s := "%d:c%d" % [real._menu_at, i]
		var p: Dictionary = played.blocks.get(real.block_key, {}) if played != null else {}
		var b: Dictionary = coverage.blocks.get(real.block_key, {})
		if not (p.has("br") and p.br.has(s)) and not (b.has("br") and b.br.has(s)):
			fresh = true
	if not fresh:
		return
	var base := real.fork(coverage)
	for i in real.menu.size():
		var vm := base.fork(coverage)
		forks += 1
		vm.choose(i)
		_follow(vm, 1)
	coverage.save()


func _follow(vm: EclVM, depth: int) -> void:
	for guard in GUARD:
		match vm.state:
			EclVM.State.WAIT:
				vm.resume()
			EclVM.State.COMBAT:
				vm.end_combat(0)
			EclVM.State.SHOP:
				vm.close_shop()
			EclVM.State.TEMPLE:
				vm.close_temple()
			EclVM.State.INPUT:
				vm.answer_input("0" if vm.input_numeric else "")
			EclVM.State.PROGRAM:
				vm.close_program()
			EclVM.State.MENU:
				if depth >= DEPTH:
					return
				for i in maxi(vm.menu.size(), 1):
					var f := vm.fork(coverage)
					forks += 1
					f.choose(i)
					_follow(f, depth + 1)
				return
			_:
				return
