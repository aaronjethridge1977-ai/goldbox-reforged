extends SceneTree
# walls.gd <GEOn.DAX> <block> <event or -1 for all>: event squares and their four walls.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dax := DaxFile.open(a[0])
	var m := GeoMap.decode(dax.blocks[int(a[1])])
	for y in 16:
		for x in 16:
			var ev := m.flag(x, y) & 127
			if ev == int(a[2]) or (int(a[2]) < 0 and ev != 0):
				print("%d,%d ev %d walls N%d E%d S%d W%d" % [x, y, ev, m.wall(x, y, 0), m.wall(x, y, 1), m.wall(x, y, 2), m.wall(x, y, 3)])
	quit()
