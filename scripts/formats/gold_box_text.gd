class_name GoldBoxText
extends RefCounted
## Gold Box packed text, as found in the ECL event scripts.
##
## Characters are 6 bits each, packed big-endian: every 3 bytes hold 4 characters.
## Value v < 0x20 is the letter chr(v + 0x40) ('@', 'A'..'Z', ...); otherwise chr(v)
## (space, punctuation, digits). Value 0 is padding and is skipped.
##
## In ECL scripts a string operand is: 0x80, u8 packed length (bytes), packed text.
## Verified by decoding readable game text from every ECL block.


static func decode(packed: PackedByteArray) -> String:
	var out := ""
	var i := 0
	while i < packed.size():
		var b0 := packed[i]
		var b1 := packed[i + 1] if i + 1 < packed.size() else 0
		var b2 := packed[i + 2] if i + 2 < packed.size() else 0
		var n := (b0 << 16) | (b1 << 8) | b2
		# A short final group of 1 or 2 bytes holds only 1 or 2 whole characters.
		var count := mini(4, packed.size() - i) if packed.size() - i < 3 else 4
		for k in count:
			var v: int = (n >> (18 - 6 * k)) & 63
			if v != 0:
				out += char(v + 0x40) if v < 0x20 else char(v)
		i += 3
	return out


## Finds the string operands in an ECL block: [{offset, text}].
## Heuristic scan (0x80, length, mostly-printable text) until the ECL bytecode is decoded.
static func find_strings(block: PackedByteArray) -> Array:
	var found := []
	var i := 0
	while i < block.size() - 2:
		var length := block[i + 1]
		if block[i] == 0x80 and length >= 2 and i + 2 + length <= block.size():
			var text := decode(block.slice(i + 2, i + 2 + length))
			if text.length() >= 3 and _printable_ratio(text) > 0.97:
				found.append({"offset": i, "text": text})
				i += 2 + length
				continue
		i += 1
	return found


static func _printable_ratio(text: String) -> float:
	var ok := 0
	for c in text:
		if c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,!?'\"-:;()/&":
			ok += 1
	return ok / float(text.length())
