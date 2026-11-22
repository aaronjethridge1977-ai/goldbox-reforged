extends SceneTree
## Lab (main chat 106): PrintWrap.lines against a JSON list of [text, rows] (the original printer's layout as
## modelled in the lab: ~/gbr/lab/data/c106/origwrap.py, checked against DOSBox screens).
## godot --headless --path <proj> --script res://tools/lab/printwrap_check.gd -- <cases.json>


func _init() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	var bad := 0
	for c in cases:
		var got := PrintWrap.lines(String(c[0]), 38)
		var want := PackedStringArray(c[1])
		if got != want:
			bad += 1
			if bad <= 5:
				print("DIFF: ", c[0], "\n  got  ", got, "\n  want ", want)
	print("printwrap: %d of %d differ" % [bad, cases.size()])
	quit(1 if bad > 0 else 0)
