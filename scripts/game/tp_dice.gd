class_name TpDice
extends RefCounted
## Lab only (side chat 2, 2026-11-13): the original's own random numbers, so a fight can be
## replayed roll for roll against the original from the same seed.
##
## Pool of Radiance draws every random number from Turbo Pascal's generator (START.EXE
## 0AF8:118F, checked in the lab: the seed, a dword at DS:0x4428, moved exactly 19 steps over
## a computer-run turn): seed = seed * 134775813 + 1, and Random(n) = (seed >> 16) mod n.
## A die is Random(size) + 1 (GAME.OVR 0x2BCCD rolls count dice that way).
##
## Off unless a lab run turns it on (--tpseed=<hex> on the command line, or tpseed=<hex> in
## --keys); normal play and the bot keep Godot's generator. tools/lab/seed.py reads and sets
## the original's seed in a running DOSBox.

const MULT := 134775813

static var on := false
static var seed := 0
static var calls := 0
static var log := PackedStringArray()


static func start(value: int) -> void:
	on = true
	seed = value & 0xFFFFFFFF
	calls = 0
	log.clear()


## Random(n): 0..n-1 (0 when n is 0), as Turbo Pascal 5 does it.
static func random(n: int, why: String = "") -> int:
	seed = (seed * MULT + 1) & 0xFFFFFFFF
	calls += 1
	var r := (seed >> 16) % n if n > 0 else 0
	log.append("#%d %s Random(%d) = %d" % [calls, why, n, r])
	if log.size() > 4000:
		log = log.slice(2000)
	return r


## lo..hi inclusive, as Random(hi - lo + 1) + lo.
static func between(lo: int, hi: int, why: String = "") -> int:
	return lo + random(hi - lo + 1, why)
