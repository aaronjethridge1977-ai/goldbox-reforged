extends SceneTree
# pathkeys.gd <GEOn.DAX> <block> <x,y> <goal x,y> <facing NESW> [hedges|-] [avoid x,y ...] (chat 24): the shortest walk on
# one map (walls block unless a door; "hedges": walls 7 and 9 pass too, 5:5's thorn hedges), never through
# a square whose event (flag & 31) is 30 or more (5:5's ways out to 5:3), as --keys (turns, up, wait).
# Also lists the open edge sides the start reaches (where a step leaves the map).
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var m := GeoMap.decode(DaxFile.open(a[0]).blocks[int(a[1])])
	var s := Vector2i(int(a[2].split(",")[0]), int(a[2].split(",")[1]))
	var g := Vector2i(int(a[3].split(",")[0]), int(a[3].split(",")[1]))
	var face := "NESW".find(a[4])
	var hedges := a.size() > 5 and a[5] == "hedges"
	var avoid := []
	for k in range(6, a.size()):
		avoid.append(Vector2i(int(a[k].split(",")[0]), int(a[k].split(",")[1])))
	var D := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var prev := {s: s}
	var todo := [s]
	var edges := []
	while not todo.is_empty():
		var c: Vector2i = todo.pop_front()
		for d in 4:
			var w := m.wall(c.x, c.y, d)
			if w > 0 and m.door(c.x, c.y, d) == 0 and not (hedges and w in [7, 9]):
				continue
			var q: Vector2i = c + D[d]
			if q.x < 0 or q.y < 0 or q.x > 15 or q.y > 15:
				edges.append("%d,%d %s" % [c.x, c.y, "NESW"[d]])
				continue
			if prev.has(q) or (m.flag(q.x, q.y) & 31) >= 30 or q in avoid:
				continue
			prev[q] = c
			todo.append(q)
	print("edges: ", ", ".join(edges))
	if not prev.has(g):
		print("no way to ", g)
		quit()
		return
	var path := [g]
	while path[0] != s:
		path.push_front(prev[path[0]])
	var keys := []
	for i in range(1, path.size()):
		var d := D.find(path[i] - path[i - 1])
		var t := (d - face + 4) % 4
		keys.append_array([[], ["right"], ["right", "right"], ["left"]][t])
		keys.append_array(["up", "wait"])
		face = d
	print("path: ", path)
	print("keys: ", ",".join(keys), "   (facing ", "NESW"[face], ")")
	quit()
