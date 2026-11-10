class_name Exepack
extends RefCounted
## Unpacks a DOS program compressed with Microsoft EXEPACK (START.EXE is one), giving the
## program's load module as it sits in memory. Used to read tables the game keeps in its
## code, such as the item name words.
##
## The format (publicly documented): the packed load module is followed, at CS:0, by a
## small header (real IP, CS, memory start, header size, real SP, SS, unpacked length in
## paragraphs, skip length, "RB"). The packed data is read backwards from its end, past any
## 0xFF padding: an opcode byte, a 16-bit count, then for 0xB0 a byte to repeat `count`
## times, or for 0xB2 `count` bytes to copy, all written backwards from the end of the
## unpacked image. Bit 0 of the opcode marks the last command.


static func unpack(exe: PackedByteArray) -> PackedByteArray:
	if exe.size() < 0x20 or exe[0] != 0x4D or exe[1] != 0x5A:
		return PackedByteArray()
	var start := exe.decode_u16(8) * 16
	var cs := exe.decode_u16(0x16)
	var eh := start + cs * 16
	if eh + 18 > exe.size():
		return PackedByteArray()
	var dest_len := exe.decode_u16(eh + 12)
	var skip := 1
	if exe[eh + 16] == 0x52 and exe[eh + 17] == 0x42:
		skip = exe.decode_u16(eh + 14)
	elif not (exe[eh + 14] == 0x52 and exe[eh + 15] == 0x42):
		return PackedByteArray()   # not EXEPACK
	var out_len := dest_len * 16
	var buf := exe.slice(start, eh)
	if buf.size() < out_len:
		buf.resize(out_len)
	var s := (eh - start) - (skip - 1) * 16 - 1
	while s > 0 and buf[s] == 0xFF:
		s -= 1
	var o := out_len - 1
	while s >= 2:
		var op := buf[s]
		var count := (buf[s - 1] << 8) | buf[s - 2]
		s -= 3
		if (op & 0xFE) == 0xB0:
			var fill := buf[s]
			s -= 1
			for i in count:
				buf[o] = fill
				o -= 1
		elif (op & 0xFE) == 0xB2:
			for i in count:
				buf[o] = buf[s]
				o -= 1
				s -= 1
		else:
			return PackedByteArray()
		if op & 1:
			break
	return buf.slice(0, out_len)
