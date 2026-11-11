class_name EndingScreen
extends Control
## The end of the game (PROGRAM 8, after Tyranthraxus falls): FINAL5.DAX's pictures with
## the original's closing words (GAME.OVR). Each picture sits at the screen position its
## block names (x in 8-pixel units, y in pixels); the animations (blocks 2, 7 and 8) play
## over their backgrounds (1 the dragon's lair, 3 the pool). Enter goes on to the next page;
## after the last the script carries on.
##
## Approximation: the order of pictures and lines follows the strings' order in GAME.OVR;
## the original's exact timing of each animation is not yet copied.

signal finished

const PAGES := [
	{"bg": 1, "anim": 2, "text": "MORTALLY WOUNDED, THE DRAGON ROARS! THE SPIRIT OF TYRANTHRAXUS FLARES UP FROM THE DRAGON'S BODY."},
	{"bg": 3, "anim": 7, "text": "\"FOOLS, YOU HAVE BUT SLAIN THE BODY I POSSESSED.  I CANNOT BE DEFEATED!\""},
	{"bg": 3, "anim": 7, "text": "\"WITH THE POWER OF THE POOL OF RADIANCE WHICH I MOVED HERE, TO MY LAIR, I WILL STILL RULE, BY POSSESSING ONE OF YOU!\""},
	{"bg": 3, "anim": 8, "text": "\"NO LORD BANE!  I CAN STILL RULE HERE! I HAVE NOT FAILED.  DO NOT CALL ME BACK THROUGH THE POOL!\""},
	{"bg": 3, "anim": 8, "text": "NOOOO..."},
]

var _screen: GameScreen
var _pics := {}
var _page := 0
var _frame := 0
var _timer: Timer


func open(game_path: String) -> void:
	ShopScreen._fill(self, 0)
	if _screen == null:
		var bg := ColorRect.new()
		bg.color = Color.BLACK
		ShopScreen._fill(bg, 0)
		add_child(bg)
		_screen = GameScreen.new()
		ShopScreen._fill(_screen, 0)
		add_child(_screen)
		_timer = Timer.new()
		_timer.wait_time = 0.18
		_timer.timeout.connect(_tick)
		add_child(_timer)
	var dax := DaxFile.open(game_path.path_join("FINAL5.DAX"))
	if dax != null:
		for id in dax.ids():
			var p := EgaPicture.decode_any(dax.blocks[id])
			if p != null:
				_pics[id] = p
	_page = 0
	_frame = 0
	visible = true
	_timer.start()
	_draw()


func _tick() -> void:
	_frame += 1
	_draw()


func _blit(pic: EgaPicture, frame: int) -> void:
	if pic == null or pic.frames.is_empty():
		return
	var f: Image = pic.frames[frame % pic.frames.size()].duplicate()
	f.convert(Image.FORMAT_RGBA8)
	_screen.img.blit_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i(pic.x * 8, pic.y))


func _draw() -> void:
	var page: Dictionary = PAGES[_page]
	var g := _screen
	g.clear()
	_blit(_pics.get(page.bg), 0)
	_blit(_pics.get(page.anim), _frame)
	g.text_box(GameScreen.wrap(page.text, 38), GameScreen.WHITE)
	g.text(0, 24, "PRESS <RETURN> TO CONTINUE", GameScreen.GREEN)
	g.update()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if event.is_action("ui_accept") or event is InputEventKey:
		_page += 1
		if _page >= PAGES.size():
			visible = false
			_timer.stop()
			finished.emit()
			return
		_draw()
