extends SceneTree
# mapparts.gd <GEOn.DAX> <block> (chat 19): the map's connected parts (walls block unless a door), with their events.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var m := GeoMap.decode(DaxFile.open(a[0]).blocks[int(a[1])])
	var part := {}
	var n := 0
	var D := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for y in 16:
		for x in 16:
			var s := Vector2i(x, y)
			if part.has(s):
				continue
			n += 1
			var todo := [s]
			part[s] = n
			var sq := []
			while not todo.is_empty():
				var c: Vector2i = todo.pop_back()
				sq.append(c)
				for d in 4:
					var q: Vector2i = c + D[d]
					if q.x < 0 or q.y < 0 or q.x > 15 or q.y > 15 or part.has(q):
						continue
					if m.wall(c.x, c.y, d) > 0 and m.door(c.x, c.y, d) == 0:
						continue
					part[q] = n
					todo.append(q)
			var evs := []
			for c in sq:
				var e: int = m.flag(c.x, c.y) & 127
				if e != 0:
					evs.append("%d@%d,%d" % [e, c.x, c.y])
			print("part %d: %d squares, from %s; events %s" % [n, sq.size(), sq[0], " ".join(evs)])
	quit()
