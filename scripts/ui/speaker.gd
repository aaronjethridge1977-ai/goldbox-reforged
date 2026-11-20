class_name Speaker
extends Node

## Pool of Radiance's PC-speaker sounds, played by the original's own sound driver run on the
## game's own data (Combat Chat 10; START.EXE, unpacked: the driver's code and data share one
## segment, found here by its note table). The lab's reference is combat10/sfx.py; each sound
## was checked against DOSBox's own recording of the original (combat10/sndmatch.py).
##
## The driver: the timer is set to divisor 0x13B1 (1193182 / 5041, 236.7 ticks a second;
## 0x9E83). Each tick (0x9F57) steps four voices (the block at +0x22D, 0x30 bytes each, note
## table +0x3AD) and the speaker sounds the first voice with time left and a non-zero gate word
## (+0x0A): PIT channel 2 gets its divisor (+0x08), port 0x61 its gate bits (+0x0A & 3). A sound
## starts at 0xA222 (row n: four script pointers at +0x55F + 8n). The game calls the wrapper
## 0x8BBC with an id: 0 sound off, 1 on, 0xFF stop, else row id - 1. With DS:0x5374 set (10, the
## game's usual value) the wrapper waits that many hundredths of a second (0x8B4C) and stops the
## sound: in DOSBox the hit's sound lasts 0.107 s of its 0.28; a spell's cast clears it first
## (0x27E08) and the sound plays out. Ours stops the sound at the same moment but doesn't hold
## the game for it.
##
## Voice fields: +0 ticks left, +2 script, +4 base divisor, +6 its slide, +8 out, +0A gate,
## +0C its slide, +0E tempo, +12 transpose, +14 release count, +16 envelope table, +18 its
## index, +1A its step count, +1C vibrato table, +1E phase, +20 speed, +22 depth, +24 length.
## Script bytes: FA reset this voice, FB return, FC call, FD reset another voice, FE loop, FF set
## a field (field 0 ends the tick's events), else a 3-byte note event.

const TICK_HZ := 1193182.0 / 0x13B1
const MIX_HZ := 44100.0
const VOLUME := 0.12
const BLOCK := 0x22D
const NOTES := 0x3AD
const TABLE := 0x55F
const SETTINGS_KEY := "sound"

## The game's sound ids (the wrapper's argument; DS:0x2618-0x262C hold 2-12), named from their
## callers in GAME.OVR.
const SPELL := 2        # a spell's cast (0x27C38), Hold Person's spark to each further target (0x286FE)
const DAMAGE := 3       # magic damage on a figure in a fight (START.EXE 0x2B8B, flag 0, from 0x2C3D6)
const EFFECT := 4       # an effect on a figure in a fight: held, healed, turned... (START.EXE 0x2B8B, flag 1)
const MISSILE := 6      # a missile weapon's flight (0x14EAB: 6 as it flies, 12 at its end, cut at once)
const HIT := 7          # a blow lands, "slays helpless", a door option that fails (0x13EF1, 0x13C54, 0x17702)
const MISS := 9         # an attack that hit nothing (0x13F6F)
const STEP := 10        # a step or a turn in the 3D view (0x16E06, 0x171DF, 0x17224), a square moved in a fight (0x13071)

static var _node: Speaker = null
static var _segment := PackedByteArray()
static var _looked := false
## DS:0x5374: a sound is stopped after this many hundredths of a second (0: it plays out).
static var sync_cs := 10

var _m := PackedByteArray()
var _size := 0x30
var _ret := 0
var _playing := false
var _left := -1             # samples until the wrapper stops the sound (-1: never)
var _div := 0               # the speaker's PIT divisor this tick, 0 off
var _tick_acc := 0.0
var _phase := 0.0
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback


## The wrapper 0x8BBC: plays sound `id` (2-20) on the speaker. `full`: as with DS:0x5374 at 0
## (a spell's sound), it plays to its end, or until `cut` seconds when `cut` > 0 (where the
## original sets DS:0x5374 again after a drawing of that length: START.EXE 0x1A5 takes the driver
## off the timer and silences the speaker, 0x13B1).
static func play(id: int, full := false, cut := 0.0) -> void:
	if OS.has_environment("SNDDBG"):           # lab: the sounds asked for, in order
		print("   SOUND %d%s" % [id, " full" if full else ""])
	if not on():
		return
	var s := _instance()
	if s == null:
		return
	if id == 0 or id == 0xFF:
		s._stop()
	elif id >= 2:
		s._start(id - 1, full)
		if full and cut > 0.0:
			s._left = int(cut * MIX_HZ)


## SETTINGS: SOUND (on by default, as the original with a PC speaker).
static func on() -> bool:
	var cf := ConfigFile.new()
	if cf.load(GameData.SETTINGS_PATH) != OK:
		return true
	return bool(cf.get_value("qol", SETTINGS_KEY, true))


static func save_on(value: bool) -> void:
	var cf := ConfigFile.new()
	cf.load(GameData.SETTINGS_PATH)
	cf.set_value("qol", SETTINGS_KEY, value)
	cf.save(GameData.SETTINGS_PATH)
	if not value and _node != null:
		_node._stop()


static func _instance() -> Speaker:
	if _node != null and is_instance_valid(_node):
		return _node
	var seg := _driver_segment()
	if seg.is_empty():
		return null
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_node = Speaker.new()
	_node._m = seg.duplicate()
	_node._size = maxi(seg[0x1DA], 0x30)
	tree.root.add_child.call_deferred(_node)
	return _node


## The driver's segment from START.EXE (unpacked), found by its note table (+0x3AD: 36484,
## 34436, 32503, 30679, ...).
static func _driver_segment() -> PackedByteArray:
	if _looked:
		return _segment
	_looked = true
	var path: String = CharacterSheet.game_path
	if path == "" or not GameData.exists(path.path_join("START.EXE")):
		return _segment
	var image := Exepack.unpack(GameData.read_bytes(path.path_join("START.EXE")))
	var sig := PackedByteArray([0x84, 0x8E, 0x84, 0x86, 0xF7, 0x7E, 0xD7, 0x77])
	var at := ItemNames._find(image, sig)
	if at < NOTES:
		return _segment
	var base := at - NOTES
	_segment = image.slice(base, mini(base + 0x10000, image.size()))
	_segment.resize(0x10000)
	return _segment


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_HZ
	gen.buffer_length = 0.1
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var n := _playback.get_frames_available()
	if n <= 0:
		return
	var per_tick := MIX_HZ / TICK_HZ
	var frames := PackedVector2Array()
	frames.resize(n)
	for k in n:
		_tick_acc += 1.0
		if _tick_acc >= per_tick:
			_tick_acc -= per_tick
			_div = _tick() if _playing else 0
		if _left > 0:
			_left -= 1
			if _left == 0:
				_stop()
		var v := 0.0
		if _div > 0:
			_phase = fmod(_phase + (1193182.0 / _div) / MIX_HZ, 1.0)
			v = VOLUME if _phase < 0.5 else -VOLUME
		frames[k] = Vector2(v, v)
	_playback.push_buffer(frames)


func _w(a: int) -> int:
	a &= 0xFFFF
	return _m[a] | (_m[(a + 1) & 0xFFFF] << 8)


func _sw(a: int, v: int) -> void:
	a &= 0xFFFF
	_m[a] = v & 0xFF
	_m[(a + 1) & 0xFFFF] = (v >> 8) & 0xFF


static func _signed(v: int) -> int:
	return v - 0x10000 if v & 0x8000 else v


## 0xA222: row `row`'s scripts into the four voices.
func _start(row: int, full: bool) -> void:
	for k in 4:
		var ptr := _w(TABLE + 8 * row + 2 * k)
		var v := BLOCK + k * _size
		if ptr != 0:
			for o in range(0, 0x30, 2):
				_sw(v + o, 0)
			_sw(v + 2, ptr)
			_sw(v, 1)
	_playing = true
	_tick_acc = 0.0
	_left = -1 if full or sync_cs <= 0 else int(sync_cs / 100.0 * MIX_HZ)


func _stop() -> void:
	_playing = false
	_div = 0
	_left = -1
	for k in 4:
		_sw(BLOCK + k * _size, 0)
		_sw(BLOCK + k * _size + 2, 0)


## One timer tick (0x9F57): the speaker's divisor, or 0 for off.
func _tick() -> int:
	var pick := 0
	var any := false
	for k in 4:
		var si := BLOCK + k * _size
		if _w(si) != 0:
			_step(si)
			if pick == 0 and _w(si + 0xA) != 0 and _w(si) != 0:
				pick = si
		any = any or _w(si) != 0
	if not any:
		_playing = false
	if pick == 0 or (_w(pick + 0xA) & 3) == 0:
		return 0
	return _w(pick + 8)


func _reset(v: int) -> void:
	for o in [4, 6, 8, 0xA, 0xC, 0x10, 0x12, 0x16, 0x18, 0x1A, 0x1C, 0x1E, 0x20, 0x22, 0x24]:
		_sw(v + o, 0)


## 0xA05A: one voice's tick.
func _step(si: int) -> void:
	_sw(si + 0xA, _w(si + 0xA) + _w(si + 0xC))
	_sw(si + 4, _w(si + 4) + _w(si + 6))
	var dx := 0
	var ax := (_w(si + 0x1E) + _w(si + 0x20)) & 0xFFFF
	if ax != 0:
		if ax >= _w(si + 0x24):
			ax = (ax - _w(si + 0x24)) & 0xFFFF
		_sw(si + 0x1E, ax)
		var idx := (_signed(ax) >> 4) + _w(si + 0x1C)
		var b := _m[idx & 0xFFFF]
		var p := _signed((b << 8) & 0xFFFF) * _signed(_w(si + 0x22))
		dx = (p >> 16) & 0xFFFF
	_sw(si + 8, dx + _w(si + 4))
	if _w(si + 0x14) != 0:
		_sw(si + 0x14, _w(si + 0x14) - 1)
		if _w(si + 0x14) == 0:
			_sw(si + 0x18, 0x10)
			_sw(si + 0x1A, 1)
	_sw(si, _w(si) - 1)
	if _w(si) == 0:
		_events(si)
	if _w(si + 0x1A) != 0:
		_sw(si + 0x1A, _w(si + 0x1A) - 1)
		if _w(si + 0x1A) == 0:
			for guard in 64:
				var bx := _w(si + 0x16) + _w(si + 0x18)
				if _w(bx + 2) == 0xFFFF:
					_sw(si + 0xA, _w(bx))
					if _w(bx) == 0:
						_sw(si + 0xC, 0)
					_sw(si + 0x18, _w(si + 0x18) + 4)
					continue
				_sw(si + 0xC, _w(bx))
				_sw(si + 0x1A, _w(bx + 2))
				_sw(si + 0x18, _w(si + 0x18) + 4)
				break


## 0xA0EB: the voice's next events.
func _events(si: int) -> void:
	var di := _w(si + 2)
	if di == 0:
		return
	for guard in 256:
		var bl := _m[di & 0xFFFF]
		di += 1
		if bl == 0xFE:                       # loop: counter field, target
			var f := _m[di & 0xFFFF]
			var tgt := _w(di + 1)
			di += 3
			if _w(si + f) == 0:
				di = tgt
			else:
				_sw(si + f, _w(si + f) - 1)
				if _w(si + f) != 0:
					di = tgt
			continue
		if bl == 0xFD:                       # reset another voice
			_reset(_w(di) + BLOCK)
			di += 2
			continue
		if bl == 0xFA:                       # reset this voice
			_reset(si)
			continue
		if bl == 0xFF:                       # set a field; field 0 ends the events
			var f2 := _m[di & 0xFFFF]
			var val := _w(di + 1)
			di += 3
			_sw(si + f2, val)
			if f2 != 0:
				continue
			break
		if bl == 0xFB:                       # return
			di = _ret
			continue
		if bl == 0xFC:                       # call
			var t2 := _w(di)
			_ret = di + 2
			di = t2
			continue
		# Note events (0xA1A4): byte 0 (voice in bits 5-7), note (bit 7: the last), duration.
		for guard2 in 64:
			var cl := bl >> 5
			var v := BLOCK + cl * _size
			var tempo := _w(si + 0xE) & 0xFF
			var dur := _m[(di + 1) & 0xFFFF]
			if tempo > 1:
				dur = (tempo * dur) & 0xFFFF
			_sw(si, dur)
			var note := _m[di & 0xFFFF] & 0x7F
			if note != 0x7F and cl == 0:
				var d := _w(si)
				_sw(v, d)
				_sw(v + 0x14, d)
				var n := (note + _w(v + 0x12)) & 0xFFFF
				_sw(v + 0x18, 0)
				_sw(v + 0x1A, 1)
				var div := _w(NOTES + 2 * (n % 12)) >> (n / 12)
				_sw(v + 4, div)
				_sw(v + 8, div)
			var last := _m[di & 0xFFFF] & 0x80
			di += 2
			if last != 0:
				break
			bl = _m[di & 0xFFFF]
			di += 1
		break
	if _w(si) == 0:
		di = 0
	_sw(si + 2, di)
