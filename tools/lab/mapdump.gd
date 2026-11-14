extends SceneTree
# mapdump.gd <GEOn.DAX> <block> (chat 19; copy into proj/ as _mapdump.gd): the map as text. Each square shows
# its event number (.. none); between squares: | or - a wall (its type as a hex digit when not 1), D a door
# (2 locked, 3 wizard-locked: L, W), space open.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dax := DaxFile.open(a[0])
	var m := GeoMap.decode(dax.blocks[int(a[1])])
	var head := "    "
	for x in 16:
		head += "%3d" % x
	print(head)
	for y in 16:
		var top := "    "
		var mid := "%3d " % y
		for x in 16:
			top += "+" + _edge(m, x, y, 0, "--")
			mid += _edge(m, x, y, 3, "|") + ("%2d" % (m.flag(x, y) & 127) if m.flag(x, y) & 127 else "..")
		mid += _edge(m, 15, y, 1, "|")
		print(top + "+")
		print(mid)
	var bot := "    "
	for x in 16:
		bot += "+" + _edge(m, x, 15, 2, "--")
	print(bot + "+")
	quit()


func _edge(m: GeoMap, x: int, y: int, side: int, wall: String) -> String:
	var d := m.door(x, y, side)
	var w := m.wall(x, y, side)
	var s := " "
	if d != 0:
		s = ["", "D", "L", "W"][d]
	elif w != 0:
		s = wall[0] if w == 1 else "%x" % w
	return s.repeat(wall.length())
