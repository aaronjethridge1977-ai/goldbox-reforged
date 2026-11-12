extends SceneTree
## Prints one ECL block disassembled: godot --headless --path . -s res://tools/dis.gd -- <game folder> <ecl file number> <block>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var ecl := DaxFile.open(a[0].path_join("ECL%s.DAX" % a[1]))
	print(EclScript.decode(ecl.blocks[int(a[2])]).disassemble())
	quit()
