class_name EndingScreen
extends Control
## The end of the game (PROGRAM 8, after Tyranthraxus falls), as the original's routine
## (GAME.OVR 0x20948, read in Combat Chat 4 and captured in the lab after check 5's fight):
## three pages that go by themselves, no key, in the walking screen's frame. The picture area
## (120 x 120 at 8, 8, as the wilderness map's), the party list and the place line stay; the
## bottom row is left as the treasure screen had it (VIEW POOL EXIT); the words in the text
## box in light green, the box cleared between pages (0x709:0xDD3).
##
## Pictures from FINAL5.DAX at the routine's positions (8-pixel cells inside the area):
##   page 1: block 1 (the dragon's lair), block 2's animation at 2,4;
##   pages 2 and 3: block 3 (the pool), with the party's backs by party size (ECL 0x6E3E:
##   above 1 block 4 at 0,11; above 2 block 5 at 13,9; above 3 block 6 at 0,9), block 7's
##   animation at 2,0, then block 8's.
## Timing (the animation routine 0x206A3, the clock 0x709:0xC3F in hundredths): each frame
## for its delay x (game speed + 3) hundredths; pages 1 and 2 play their animation
## (10 - speed) x 5 / 2 times, page 3 once, then three pauses of speed x 225 ms (0x709:0xDBE).

signal finished

const AREA := Vector2i(8, 8)
const PAGES := [
	{"lines": ["MORTALLY WOUNDED, THE DRAGON ROARS!", "THE SPIRIT OF TYRANTHRAXUS FLARES UP",
		"FROM THE DRAGON'S BODY."], "anim": 2, "at": Vector2i(2, 4), "long": true},
	{"lines": ["\"FOOLS, YOU HAVE BUT SLAIN THE BODY", "I POSSESSED.  I CANNOT BE DEFEATED!\"",
		"WITH THE POWER OF THE POOL OF RADIANCE", "WHICH I MOVED HERE, TO MY LAIR,",
		"I WILL STILL RULE, BY POSSESSING ONE", "OF YOU!\""], "anim": 7, "at": Vector2i(2, 0), "long": true},
	{"lines": ["\"NO LORD BANE!  I CAN STILL RULE HERE!", "I HAVE NOT FAILED.  DO NOT CALL ME BACK",
		"THROUGH THE POOL!\"", "NOOOO..."], "anim": 8, "at": Vector2i(2, 0), "long": false},
]
## The party's backs on the pool page: [block, x, y in cells, party size above which].
const BACKS := [[4, 0, 11, 1], [5, 13, 9, 2], [6, 0, 9, 3]]
const MENU := ["VIEW", "POOL", "EXIT"]

## Set by main before open (else read from it): the party, its size (ECL 0x6E3E) and the
## walking screen's place line.
var party: Array = []
var party_size := -1
var place := ""

var _screen: GameScreen
var _pics := {}
var _page := 0
var _frame := 0
var _loop := 0
var _pauses := 0
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
		_timer.one_shot = true
		_timer.timeout.connect(_tick)
		add_child(_timer)
	_from_main()
	var dax := DaxFile.open(game_path.path_join("FINAL5.DAX"))
	if dax != null:
		for id in dax.ids():
			var p := EgaPicture.decode_any(dax.blocks[id])
			if p != null:
				_pics[id] = p
	visible = true
	_start_page(0)


## The party, its size and the place line from main when it hasn't set them (main.gd is the
## main lane's: read only).
func _from_main() -> void:
	var main := get_parent()
	if party.is_empty() and main != null and main.get("_party") != null:
		party = main.get("_party")
	if party_size < 0:
		party_size = party.size()
	if place == "" and main != null and main.has_method("_place_line"):
		place = main.call("_place_line")


func _speed() -> int:
	return clampi(CampScreen.speed, 0, 10)


func _start_page(i: int) -> void:
	_page = i
	_frame = 0
	_loop = 0
	_pauses = 0
	_draw()
	_wait_frame()


func _loops() -> int:
	return maxi((10 - _speed()) * 5 / 2, 1) if PAGES[_page].long else 1


func _anim() -> EgaPicture:
	return _pics.get(PAGES[_page].anim)


func _wait_frame() -> void:
	var pic := _anim()
	var d := 1
	if pic != null and _frame < pic.delays.size():
		d = maxi(int(pic.delays[_frame]), 1)
	_timer.start(d * (_speed() + 3) / 100.0)


func _tick() -> void:
	if not visible:
		return
	if _pauses > 0:
		_pauses -= 1
		if _pauses > 0:
			_timer.start(_speed() * 0.225 if _speed() > 0 else 0.01)
		else:
			_end()
		return
	var pic := _anim()
	var n := pic.frames.size() if pic != null else 1
	_frame += 1
	if _frame >= n:
		_frame = 0
		_loop += 1
		if _loop >= _loops():
			_frame = n - 1          # the last frame stays (the routine leaves without drawing again)
			_next_page()
			return
	_draw()
	_wait_frame()


func _next_page() -> void:
	if _page + 1 < PAGES.size():
		_start_page(_page + 1)
		return
	# After the last animation: three pauses of game speed x 225 ms.
	_pauses = 3
	_timer.start(_speed() * 0.225 if _speed() > 0 else 0.01)


func _end() -> void:
	visible = false
	_timer.stop()
	finished.emit()


func _blit(id: int, frame: int, cell: Vector2i) -> void:
	var pic: EgaPicture = _pics.get(id)
	if pic == null or pic.frames.is_empty():
		return
	var f: Image = pic.frames[frame % pic.frames.size()].duplicate()
	f.convert(Image.FORMAT_RGBA8)
	_screen.img.blit_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), AREA + cell * 8)


func _draw() -> void:
	var page: Dictionary = PAGES[_page]
	_screen.draw_walk(null, party, 0, place, PackedStringArray(page.lines), [], true, false, 0)
	_screen.tile(16, 16, 20)        # a junction under the picture's corner (the wilderness has rope)
	# The bottom row as the treasure menu left it (lab capture): EXIT lit.
	_screen.menu_line(24, MENU, 0, 2)
	if _page == 0:
		_blit(1, 0, Vector2i.ZERO)
	else:
		_blit(3, 0, Vector2i.ZERO)
		for b in BACKS:
			if party_size > int(b[3]):
				_blit(int(b[0]), 0, Vector2i(int(b[1]), int(b[2])))
	_blit(int(page.anim), _frame, page.at)
	_screen.update()
