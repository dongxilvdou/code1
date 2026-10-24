extends Control
## Ink borders stay fixed while the artwork drifts gently within each panel.
var artwork: Texture2D
var polygon := PackedVector2Array()
var focus := Vector2(.5,.5)
var progress := 0.0
const PAGE_SIZE := Vector2(1920,1080)
func _draw() -> void:
	if artwork == null or polygon.size()<3:return
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	var zoom := 1.008+.012*smoothstep(0,1,progress)
	for vertex in polygon:
		points.append(vertex*PAGE_SIZE)
		uv.append(focus+(vertex-focus)/zoom)
	draw_polygon(points,PackedColorArray([Color.WHITE]),uv,artwork)
