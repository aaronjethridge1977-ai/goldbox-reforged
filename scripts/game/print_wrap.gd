class_name PrintWrap
extends RefCounted
## The original's text printer's layout (START.EXE 0x77F8; main chat 106, DOSBox): a string is cut into
## chunks and a chunk that doesn't fit the row goes whole to the next one. From index i: the characters of
## SEPARATORS (DS:0xD16: ! , - . : ; ?) at i, then the run up to a space or a separator, that space or
## separator included, then (after a separator) the separators after it, but never the string's last
## character (`j + 1 < L`). So the space after a word must fit too (a word ends at column 37 at most unless
## punctuation or the string's end follows it), and a closing quote after a full stop is a chunk of its own:
## Rolf's "...MOST IMPORTANT BUILDING." with "'" alone on the next row; the clerk's "...YOUR REWARD." the
## same. At a new row the spaces at i are skipped (0x77A4). Ours had wrapped whole words at 38 columns:
## 314 of the game's 1390 PRINT_CLEAR texts broke their rows elsewhere.
## A message is one string here; the original prints each PRINT's string apart, so at the seam between two
## PRINTs a row may break one chunk differently (a PRINT's last word ending at column 38, a PRINT ending
## with a quote): not seen yet.

const SEPARATORS := "!,-.:;?"


## `s` laid out `width` columns wide, as rows (trailing spaces cut); "\n" starts a new row.
static func lines(s: String, width: int) -> PackedStringArray:
	var out := PackedStringArray()
	for para in s.split("\n"):
		out.append_array(_para(para, width))
	return out


static func _para(s: String, width: int) -> PackedStringArray:
	var out := PackedStringArray()
	var n := s.length()
	var row := ""
	var i := 0
	while i < n:
		var j := i
		while j < n - 1 and SEPARATORS.contains(s[j]):
			j += 1
		while j < n - 1 and not SEPARATORS.contains(s[j]) and s[j] != " ":
			j += 1
		if s[j] != " ":
			while j + 1 < n - 1 and SEPARATORS.contains(s[j + 1]):
				j += 1
		if row.length() + (j - i) >= width:
			if row.length() == 0:
				# A chunk wider than the box (none in Pool's texts): cut it at the edge.
				out.append(s.substr(i, width))
				i += width
				continue
			out.append(row.rstrip(" "))
			row = ""
			while i < n - 1 and s[i] == " ":
				i += 1
			continue
		row += s.substr(i, j - i + 1)
		i = j + 1
	out.append(row.rstrip(" "))
	return out
