class_name OverlayLook
extends GameScreen
## Gives one of the overlay screens (camp, shop, temple, treasure, training, the character
## sheet) the original's look without rewriting its logic: it reads the screen's own labels
## each frame and, when anything changed, draws them in the game's font and frame.
##
##   "page" layout: heading row 1, body rows 3-15 (lists: the selected line white, the rest
##                  light cyan), note in the text box rows 17-22, menu on row 24.
##   "walk" layout: the adventure screen (view, party list, place line) with the note in
##                  the text box and the menu on row 24, as the original's camp.
##
## Menus written for the modern layout ("CAMP:  S save   V view   Esc exit") are read back
## into the original's form: "CAMP: SAVE VIEW EXIT", each hot letter white.

## The adventure screen's last view and place line (main sets them), for "walk" layouts.
static var last_view: Image
static var last_place := ""
static var last_wild := false
static var last_overland := false
## The camp's picture and place line as it last drew them (the sheet's CAST SPELL ON WHOM
## in camp shows them: lab, Combat Chat 5).
static var camp_view: Image
static var camp_place := ""

var layout := "page"
var head: Control
var bodies: Array = []          # Labels / ItemLists, in order
var note: Control
var menu: Control
var party_of: Callable          # -> Array of PartyMember (walk layout)
var place_suffix := ""
var full := false               # page without the text box: the body runs to row 22
var _last := ""


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.show_behind_parent = true
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var key := _snapshot()
	if key != _last:
		_last = key
		redraw()


static func _text_of(c: Control) -> String:
	if c == null or not c.is_visible_in_tree():
		return ""
	if c is Label:
		return (c as Label).text
	if c is ItemList:
		var il := c as ItemList
		var out := PackedStringArray()
		var sel := il.get_selected_items()
		for i in il.item_count:
			out.append((">" if sel.has(i) else " ") + il.get_item_text(i))
		return "\n".join(out)
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text()
	if c is Tree:
		var t := c as Tree
		var out := PackedStringArray()
		var it := t.get_root().get_first_child() if t.get_root() else null
		while it != null:
			var cols := PackedStringArray()
			for k in t.columns:
				if it.get_text(k) != "":
					cols.append(it.get_text(k))
			out.append((">" if it.is_selected(0) else " ") + "  ".join(cols))
			it = it.get_next()
		return "\n".join(out)
	if c is BoxContainer:
		# A row of buttons: the original's menu ("BUY  POOL  EXIT").
		var words := PackedStringArray()
		for b in c.get_children():
			if b is Button and b.visible and not "◀▶".contains((b as Button).text):
				words.append("%s %s" % [(b as Button).text.substr(0, 1), (b as Button).text.to_lower()])
		return "   ".join(words)
	return ""


func _snapshot() -> String:
	var parts := PackedStringArray([_text_of(head), _text_of(note), _text_of(menu), layout])
	for b in bodies:
		parts.append(_text_of(b))
	if layout == "walk" and party_of.is_valid():
		for m in party_of.call():
			parts.append("%s%d%d" % [m.name, m.ac, m.hp])
	return "\u0001".join(parts)


## Characters the font has: upper case, digits, punctuation; arrows spelled out.
static func plain(s: String) -> String:
	return s.replace("↑/↓", "UP/DOWN").replace("←/→", "LEFT/RIGHT").replace("↑", "UP") \
		.replace("↓", "DOWN").replace("←", "LEFT").replace("→", "RIGHT").replace("—", "-").to_upper()


## The modern menu text read back as the original's items.
static func menu_items(text: String) -> Array:
	var out := []
	var re := RegEx.create_from_string("^(Esc|Enter|Space|[A-Z0-9]) (.+)$")
	var tokens := RegEx.create_from_string(" {2,}").sub(text.strip_edges(), "\t", true).split("\t", false)
	for t in tokens:
		var m := re.search(t)
		if m != null:
			var word := plain(m.get_string(2))
			var k := m.get_string(1)
			if k.length() == 1 and word.begins_with(k):
				out.append(word)
			elif k == "Esc" and word.begins_with("EXIT"):
				out.append("EXIT")
			else:
				out.append("~" + plain(t))
		else:
			out.append("~" + plain(t))
	return out


func draw_menu(row: int, items: Array) -> void:
	var c := 0
	for it in items:
		var s := String(it)
		if s.begins_with("~"):
			s = s.substr(1)
			text(c, row, s, GameScreen.WHITE if s.ends_with(":") else GameScreen.GREEN)
		else:
			text(c, row, s.substr(0, 1), GameScreen.WHITE)
			text(c + 1, row, s.substr(1), GameScreen.GREEN)
		c += s.length() + 1


func redraw() -> void:
	var note_lines := GameScreen.wrap(plain(_text_of(note)).strip_edges(), 38)
	var items := menu_items(_text_of(menu).split("\n")[0]) if _text_of(menu) != "" else []
	if layout == "walk":
		var party: Array = party_of.call() if party_of.is_valid() else []
		var heading := plain(_text_of(head))
		var lines := note_lines
		draw_walk(last_view, party, 0, last_place + place_suffix, lines, [], last_wild, last_overland)
		draw_menu(24, items)
		update()
		return
	clear()
	for c in 40:
		tile(c, 0, 22)
		if not full:
			tile(c, 16, 22)
		tile(c, 23, 22)
	for r in range(1, 23):
		tile(0, r, 21)
		tile(39, r, 21)
	for p in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 23), Vector2i(39, 23)]:
		tile(p.x, p.y, 20)
	if not full:
		tile(0, 16, 20)
		tile(39, 16, 20)
	var rows := 20 if full else 13
	text(1, 1, plain(_text_of(head)).split("\n")[0].left(38), GameScreen.WHITE)
	# Body: every body control's lines, wrapped to 38; a list keeps its selection in view.
	var lines := PackedStringArray()
	var colors := PackedInt32Array()
	var focus := -1
	for b in bodies:
		var t := _text_of(b)
		if t == "":
			continue
		for raw in t.split("\n"):
			var selected := raw.begins_with(">")
			var line := plain(raw.substr(1) if (b is ItemList or b is Tree) else raw)
			if line.begins_with("> "):
				selected = true
				line = line.substr(2)
			for w in GameScreen.wrap(line, 38):
				if selected and focus < 0:
					focus = lines.size()
				lines.append(w)
				colors.append(GameScreen.WHITE if selected else GameScreen.CYAN)
	var first := 0
	if lines.size() > rows:
		first = clampi(focus - rows / 2, 0, lines.size() - rows) if focus >= 0 else 0
	for i in range(first, mini(first + rows, lines.size())):
		text(1, 3 + i - first, lines[i], colors[i])
	if not full:
		text_box(note_lines)
	draw_menu(24, items)
	update()
