extends SceneTree
# mapedge.gd <GEOn.DAX> <block> <x,y>...: each square's flag, walls and doors on its four sides.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var m := GeoMap.decode(DaxFile.open(a[0]).blocks[int(a[1])])
	for s in a.slice(2):
		var p := s.split(",")
		var x := int(p[0])
		var y := int(p[1])
		print("%d,%d flag %d  walls N%d E%d S%d W%d  doors N%d E%d S%d W%d" % [x, y, m.flag(x, y), m.wall(x, y, 0), m.wall(x, y, 1), m.wall(x, y, 2), m.wall(x, y, 3), m.door(x, y, 0), m.door(x, y, 1), m.door(x, y, 2), m.door(x, y, 3)])
	quit()
