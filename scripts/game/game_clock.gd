class_name GameClock
extends RefCounted
## The game clock, kept where the original keeps it: in ECL memory, so event scripts read
## it directly (they test the hour for night, and alarms compare hour and tens of minutes).
##
## Seven counters, each carrying into the next (the order the Gold Box engine uses):
##   0 0x49C6  tenths of a minute (10)     4 0x49CA  day (30)
##   1 0x49C7  minutes (10)                5 0x49CB  month (12)
##   2 0x49C8  tens of minutes (6)         6 0x49CC  year
##   3 0x49C9  hour (24)
## What costs time (checked in the lab where noted):
##   a step: one minute (lab: save J, 10:56 -> 10:57 for one step; turning costs nothing);
##   a step while SEARCHing: ten minutes; LOOK: ten minutes;
##   a combat round: one minute; camping: as rested;
##   the script opcode CLOCK n: n minutes (Pool of Radiance's form has one operand; its one
##   use moves the party along a forced walk, a minute a step).

const BASE := 0x49C6
const SCALES := [10, 10, 6, 24, 30, 12, 256]
const MINUTE := 1
const TEN_MINUTES := 2
const HOUR := 3


## Adds `amount` to counter `slot` and carries. Returns the whole minutes that passed.
static func advance(vm: EclVM, slot: int, amount: int) -> int:
	if amount <= 0:
		return 0
	var v: Array[int] = []
	for i in 7:
		v.append(vm.read_byte(BASE + i))
	v[slot] += amount
	for i in 6:
		while v[i] >= SCALES[i]:
			v[i] -= SCALES[i]
			v[i + 1] += 1
	v[6] %= 256
	for i in 7:
		vm.write_byte(BASE + i, v[i])
	return minutes_in(slot, amount)


## How many minutes `amount` of counter `slot` makes (tenths of a minute count as none).
static func minutes_in(slot: int, amount: int) -> int:
	if slot == 0:
		return 0
	var m := amount
	for i in range(1, slot):
		m *= SCALES[i]
	return m


## Adds whole minutes (camp, combat rounds).
static func add_minutes(vm: EclVM, minutes: int) -> int:
	return advance(vm, MINUTE, minutes)


static func hour(vm: EclVM) -> int:
	return vm.read_byte(BASE + 3)


static func minute(vm: EclVM) -> int:
	return vm.read_byte(BASE + 2) * 10 + vm.read_byte(BASE + 1)


## "HH:MM", as on the original's position line ("14,5 S 10:56").
static func text(vm: EclVM) -> String:
	return "%02d:%02d" % [hour(vm), minute(vm)]


## Sets the time of day (start of a new game, debugging).
static func set_time(vm: EclVM, h: int, m: int) -> void:
	vm.write_byte(BASE, 0)
	vm.write_byte(BASE + 1, m % 10)
	vm.write_byte(BASE + 2, m / 10)
	vm.write_byte(BASE + 3, h % 24)
