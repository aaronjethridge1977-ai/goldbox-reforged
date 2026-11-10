class_name EclScript
extends RefCounted
## Gold Box ECL event scripts (ECL*.DAX blocks): reader and disassembler.
##
## Block: optional u16 5000 marker, then bytecode loaded at address 0x9900. The first five
## instructions are GOTOs to the area's entry points: on move, on search, on rest,
## on rest interrupted, on init.
##
## Instruction: u8 opcode, then a fixed number of operands; a few opcodes (menus, ON_GOTO,
## ON_GOSUB) take extra operands, their count given by one of the fixed ones.
## Operand: u8 type, then
##   0x00 u8 value | 0x04 s32 value | 0x01/0x02/0x03/0x05/0x81 u16 memory address |
##   0x80 u8 length + packed text (see GoldBoxText).
## Code and data tables are interleaved, so instructions are found by following the
## control flow from the entry points, not by reading straight through.
##
## Opcode arities for Pool of Radiance follow the ssi-engine project's documentation.
## Verified: all 29 ECL blocks disassemble without error, covering 90-99% of each block
## (the rest is lookup tables).

const BASE := 0x9900
const ENTRY_NAMES := ["on move", "on search", "on rest", "on rest interrupted", "on init"]

## opcode -> [name, operand count, index of the operand giving the extra-operand count or -1]
const OPS := {
	0x00: ["EXIT", 0, -1], 0x01: ["GOTO", 1, -1], 0x02: ["GOSUB", 1, -1], 0x03: ["COMPARE", 2, -1],
	0x04: ["ADD", 3, -1], 0x05: ["SUBTRACT", 3, -1], 0x06: ["DIVIDE", 3, -1], 0x07: ["MULTIPLY", 3, -1],
	0x08: ["RANDOM", 2, -1], 0x09: ["WRITE_MEM", 2, -1], 0x0A: ["LOAD_CHAR", 1, -1],
	0x0B: ["LOAD_MON", 3, -1], 0x0C: ["SPRITE_START", 3, -1], 0x0D: ["SPRITE_ADVANCE", 0, -1],
	0x0E: ["PICTURE", 1, -1], 0x0F: ["INPUT_NUMBER", 2, -1], 0x10: ["INPUT_STRING", 2, -1],
	0x11: ["PRINT", 1, -1], 0x12: ["PRINT_CLEAR", 1, -1], 0x13: ["RETURN", 0, -1],
	0x14: ["COMPARE_AND", 4, -1], 0x15: ["MENU_VERTICAL", 3, 2],
	0x16: ["IF_EQ", 0, -1], 0x17: ["IF_NE", 0, -1], 0x18: ["IF_LT", 0, -1], 0x19: ["IF_GT", 0, -1],
	0x1A: ["IF_LE", 0, -1], 0x1B: ["IF_GE", 0, -1], 0x1C: ["CLEAR_MON", 0, -1],
	0x1D: ["PARTY_STRENGTH", 1, -1], 0x1E: ["PARTY_CHECK", 6, -1], 0x1F: ["UNUSED_1F", 0, -1],
	0x20: ["NEW_ECL", 1, -1], 0x21: ["LOAD_AREA_MAP", 3, -1], 0x22: ["PARTY_SKILL_CHECK", 2, -1],
	0x23: ["SURPRISE", 4, -1], 0x24: ["COMBAT", 0, -1], 0x25: ["ON_GOTO", 2, 1], 0x26: ["ON_GOSUB", 2, 1],
	0x27: ["TREASURE", 8, -1], 0x28: ["ROB", 3, -1], 0x29: ["ENCOUNTER_MENU", 14, -1],
	0x2A: ["COPY_MEM", 3, -1], 0x2B: ["MENU_HORIZONTAL", 2, 1], 0x2C: ["PARLAY", 6, -1],
	0x2D: ["CALL", 1, -1], 0x2E: ["DAMAGE", 5, -1], 0x2F: ["AND", 3, -1], 0x30: ["OR", 3, -1],
	0x31: ["SPRITE_OFF", 0, -1], 0x32: ["FIND_ITEM", 1, -1], 0x33: ["PRINT_RETURN", 0, -1],
	0x34: ["CLOCK", 1, -1], 0x35: ["WRITE_MEM_BASE_OFF", 3, -1], 0x36: ["NPC_ADD", 2, -1],
	0x37: ["LOAD_AREA_DECO", 3, -1], 0x38: ["PROGRAM", 1, -1], 0x39: ["WHO", 1, -1],
	0x3A: ["DELAY", 0, -1], 0x3B: ["SPELL", 3, -1], 0x3C: ["PRINT_RUNES", 1, -1],
	0x3D: ["CLEAR_BOX", 0, -1], 0x3E: ["NPC_REMOVE", 0, -1], 0x3F: ["HAS_EFFECT", 1, -1],
	0x40: ["DESTROY_ITEM", 1, -1], 0x41: ["GIVE_EXP", 2, -1], 0x42: ["UNUSED_42", 0, -1],
	0x43: ["SOUND", 1, -1], 0x44: ["UNKNOWN_44", 0, -1], 0x45: ["RANDOM0", 2, -1],
	0x46: ["FOR_START", 2, -1], 0x47: ["FOR_REPEAT", 0, -1], 0x48: ["UNKNOWN_48", 1, -1],
	0x49: ["UNKNOWN_49", 6, -1], 0x4A: ["UNKNOWN_4A", 0, -1], 0x4B: ["UNKNOWN_4B", 1, -1],
	0x4C: ["PICTURE2", 2, -1],
}
## Opcodes after which execution does not continue with the next instruction.
const STOPS := ["EXIT", "RETURN", "GOTO", "NEW_ECL", "UNUSED_1F", "ON_GOTO"]

var code: PackedByteArray
## Decoded instructions by offset: {offset: {"op": name, "args": [{"type", "value"}], "size"}}
var instructions := {}
var errors: Array[String] = []


static func decode(block: PackedByteArray) -> EclScript:
	var s := EclScript.new()
	s.code = block.slice(2) if block.size() >= 2 and block.decode_u16(0) == 5000 else block
	s._follow()
	return s


## Offsets of the instructions in address order.
func offsets() -> Array:
	var keys := instructions.keys()
	keys.sort()
	return keys


## Walls an area uses: the LOAD_AREA_DECO operands [id1, id2, id3] nearest to a
## LOAD_AREA_MAP of map_id, or the block's first LOAD_AREA_DECO when none names the map.
## Empty if the script sets none.
func wall_ids_for_map(map_id: int) -> Array:
	var maps := []
	var decos := []
	for off in instructions:
		var ins: Dictionary = instructions[off]
		if ins.op == "LOAD_AREA_MAP" and ins.args[0].type == 0 and ins.args[0].value == map_id:
			maps.append(off)
		elif ins.op == "LOAD_AREA_DECO":
			decos.append(off)
	if decos.is_empty():
		return []
	decos.sort()
	var best: int = decos[0]
	if not maps.is_empty():
		var best_distance := 1 << 30
		for m in maps:
			for d in decos:
				if absi(d - m) < best_distance:
					best_distance = absi(d - m)
					best = d
	var result := []
	for a in instructions[best].args:
		result.append(a.value)
	return result


## True if some LOAD_AREA_MAP names map_id literally.
func loads_map(map_id: int) -> bool:
	for off in instructions:
		var ins: Dictionary = instructions[off]
		if ins.op == "LOAD_AREA_MAP" and ins.args[0].type == 0 and ins.args[0].value == map_id:
			return true
	return false


## Human-readable listing.
func disassemble() -> String:
	var lines := PackedStringArray()
	var entries := {}
	for i in ENTRY_NAMES.size():
		var off := i * 4
		if instructions.has(off):
			entries[int(instructions[off].args[0].value) - BASE] = ENTRY_NAMES[i]
	for off in offsets():
		if entries.has(off):
			lines.append("; --- %s ---" % entries[off])
		var ins: Dictionary = instructions[off]
		var parts := PackedStringArray()
		for a in ins.args:
			parts.append(_arg_text(a))
		lines.append("%04X  %-18s %s" % [off + BASE, ins.op, ", ".join(parts)])
	for e in errors:
		lines.append("; error: " + e)
	return "\n".join(lines)


static func _arg_text(a: Dictionary) -> String:
	match int(a.type):
		0, 4:
			return str(a.value)
		0x80:
			return "\"%s\"" % a.value
		_:
			return "[%04X]" % int(a.value)


func _follow() -> void:
	var work: Array[int] = []
	# The five entry points.
	var p := 0
	for i in ENTRY_NAMES.size():
		var ins := _read(p)
		if ins.is_empty():
			return
		instructions[p] = ins
		if ins.op == "GOTO":
			work.append(int(ins.args[0].value) - BASE)
		p += int(ins["size"])
	while not work.is_empty():
		p = work.pop_back()
		while p >= 0 and p < code.size() and not instructions.has(p):
			var ins := _read(p)
			if ins.is_empty():
				break
			instructions[p] = ins
			var op: String = ins.op
			if op == "GOTO" or op == "GOSUB":
				work.append(int(ins.args[0].value) - BASE)
			elif op == "ON_GOTO" or op == "ON_GOSUB":
				for i in range(2, ins.args.size()):
					work.append(int(ins.args[i].value) - BASE)
			var next := p + int(ins["size"])
			if op.begins_with("IF_"):
				# A failed test skips the next instruction.
				var skipped := _read(next)
				if not skipped.is_empty():
					work.append(next + int(skipped["size"]))
			if op in STOPS:
				break
			p = next


func _read(p: int) -> Dictionary:
	if p < 0 or p >= code.size():
		return {}
	var opcode := code[p]
	if not OPS.has(opcode):
		errors.append("unknown opcode %02X at %04X" % [opcode, p + BASE])
		return {}
	var spec: Array = OPS[opcode]
	var q := p + 1
	var args := []
	for i in int(spec[1]):
		var a := _read_arg(q)
		if a.is_empty():
			return {}
		args.append(a)
		q += int(a["size"])
	if int(spec[2]) >= 0:
		for i in int(args[int(spec[2])].value):
			var a := _read_arg(q)
			if a.is_empty():
				return {}
			args.append(a)
			q += int(a["size"])
	return {"op": spec[0], "args": args, "size": q - p}


func _read_arg(q: int) -> Dictionary:
	if q >= code.size():
		errors.append("operand past end at %04X" % (q + BASE))
		return {}
	var t := code[q]
	match t:
		0x00:
			return {"type": t, "value": code[q + 1], "size": 2}
		0x04:
			return {"type": t, "value": code.decode_s32(q + 1), "size": 5}
		0x01, 0x02, 0x03, 0x05, 0x81:
			return {"type": t, "value": code.decode_u16(q + 1), "size": 3}
		0x80:
			var length := code[q + 1]
			return {"type": t, "value": GoldBoxText.decode(code.slice(q + 2, q + 2 + length)), "size": 2 + length}
	errors.append("unknown operand type %02X at %04X" % [t, q + BASE])
	return {}
