extends SceneTree
## Lab (chat 121): where the original's edge wrap shows in the 3D view. For every 3D map but blocks
## 0 and 10, every square and facing, renders the view with DungeonView.wrap off and on and prints the
## squares whose pixels differ (count of pixels).
## godot --headless --path <project> --script res://tools/lab/wrapscan.gd -- --game-path=<POOLRAD>

func _init() -> void:
	var game_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--game-path="):
			game_path = arg.trim_prefix("--game-path=")
	for n in range(1, 10):
		var geo := DaxFile.open(game_path.path_join("GEO%d.DAX" % n))
		var ecl := DaxFile.open(game_path.path_join("ECL%d.DAX" % n))
		if geo == null or ecl == null:
			continue
		for id in geo.ids():
			if id in [0, 10, 25, 26, 27]:
				continue
			var map := GeoMap.decode(geo.blocks[id])
			var deco := _deco(ecl, id)
			var walls := WallSet.build_for_area(game_path, n, deco)
			if walls == null:
				print("%d:%d no walls" % [n, id])
				continue
			var v := DungeonView.new()
			var hits := []
			for y in 16:
				for x in 16:
					for f in 4:
						v.wrap = false
						var a := v.render(map, walls, x, y, f)
						v.wrap = true
						var b := v.render(map, walls, x, y, f)
						var d := 0
						for i in a.size():
							if a[i] != b[i]:
								d += 1
						if d > 0:
							hits.append("%d,%d %s %d" % [x, y, "NESW"[f], d])
			print("%d:%d %d  %s" % [n, id, hits.size(), "  ".join(hits)])
	quit()


func _deco(ecl: DaxFile, id: int) -> Array:
	if ecl.blocks.has(id):
		var d := EclScript.decode(ecl.blocks[id]).wall_ids_for_map(id)
		if not d.is_empty():
			return d
	for other in ecl.ids():
		var s := EclScript.decode(ecl.blocks[other])
		if s.loads_map(id):
			var d := s.wall_ids_for_map(id)
			if not d.is_empty():
				return d
	return []
