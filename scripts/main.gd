extends Control
## M0 smoke test: proves the project runs and can see the player's game files.
## Replaced by the real title/menu screen in later milestones.

@onready var _status: Label = $Status


func _ready() -> void:
	var path := GameData.find_game_path()
	if path == "":
		_status.text = (
			"Gold Box Reforged\n\n"
			+ "Pool of Radiance (DOS) data not found.\n"
			+ "Place the GOG install folder \"Pool of Radiance\" next to the project,\n"
			+ "or run with --game-path=\"<folder containing GEO1.DAX>\"."
		)
		return
	var dax_files := GameData.list_files(path, "DAX")
	_status.text = (
		"Gold Box Reforged\n\n"
		+ "Found Pool of Radiance data:\n%s\n\n%d .DAX files ready to decode."
	) % [path, dax_files.size()]
	print("Game data: ", path, " (", dax_files.size(), " DAX files)")
