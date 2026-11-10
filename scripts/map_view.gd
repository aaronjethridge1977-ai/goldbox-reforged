class_name MapView
extends Control
## Draws a GeoMap as a top-down grid: walls coloured by wall type, doors in gold,
## cells with flag bit 7 shaded (meaning still unknown).

const WALL_COLORS: Array[Color] = [
	Color.TRANSPARENT, Color("#9a9a9a"), Color("#c96a4a"), Color("#5aa0d8"), Color("#7cc46a"),
	Color("#c27fd0"), Color("#d8c25a"), Color("#4fc9c0"), Color("#e07a9a"), Color("#a08060"),
	Color("#8090e0"), Color("#b0d070"), Color("#e09040"), Color("#60b080"), Color("#d0a0d0"),
	Color("#ffffff"),
]
const DOOR_COLOR := Color("#ffd23a")
const GRID_COLOR := Color(1, 1, 1, 0.07)
const FLAG_COLOR := Color(0.25, 0.45, 0.6, 0.35)

var map: GeoMap:
	set(value):
		map = value
		queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var cell := floorf(minf(size.x, size.y) / GeoMap.SIZE)
	var origin := ((size - Vector2(cell, cell) * GeoMap.SIZE) / 2).floor()
	var thick := maxf(2.0, cell / 10.0)
	for y in GeoMap.SIZE:
		for x in GeoMap.SIZE:
			var p := origin + Vector2(x, y) * cell
			if map.flag(x, y) & 0x80:
				draw_rect(Rect2(p, Vector2(cell, cell)), FLAG_COLOR)
			draw_rect(Rect2(p, Vector2(cell, cell)), GRID_COLOR, false, 1.0)
	for y in GeoMap.SIZE:
		for x in GeoMap.SIZE:
			var p := origin + Vector2(x, y) * cell
			var corners := [p, p + Vector2(cell, 0), p + Vector2(cell, cell), p + Vector2(0, cell)]
			for side in 4:
				var a: Vector2 = corners[side]
				var b: Vector2 = corners[(side + 1) % 4]
				var w := map.wall(x, y, side)
				if w:
					draw_line(a, b, WALL_COLORS[w], thick)
				if map.door(x, y, side):
					var mid := (a + b) / 2
					var half := (b - a) * 0.25
					draw_line(mid - half, mid + half, DOOR_COLOR, thick * 1.8)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
