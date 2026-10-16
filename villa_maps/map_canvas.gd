extends Control
## Pure 2D display. Floor images and player markers are separate.
var spec: Dictionary = {}
var base_texture: Texture2D
var structure_texture: Texture2D
var labels_texture: Texture2D
var position_xz := Vector2.ZERO
var region: Dictionary = {}
var map_angle := 0.0
var large := false
var pixels_per_metre := 22.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func world_to_pixel(p: Vector2) -> Vector2:
	var r: Array = spec.world_rect_xz
	return (p - Vector2(r[0], r[1])) / float(r[2]) * 2048.0

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101e23"))
	if spec.is_empty() or base_texture == null:
		return
	var point := world_to_pixel(position_xz)
	var image_rect := Rect2(Vector2.ZERO, Vector2(2048, 2048))
	if large:
		var scale_factor := minf(size.x, size.y) / 2048.0
		var origin := (size - Vector2.ONE * 2048.0 * scale_factor) * 0.5
		draw_set_transform(origin, 0.0, Vector2.ONE * scale_factor)
		draw_texture_rect(base_texture, image_rect, false)
		if labels_texture!=null:draw_texture_rect(labels_texture, image_rect, false)
		draw_set_transform(Vector2.ZERO)
		var marker := origin + point * scale_factor
		draw_circle(marker, 8.0, Color("101e23"))
		draw_circle(marker, 5.5, Color("f6d995"))
	else:
		var s := pixels_per_metre * float(spec.world_rect_xz[2]) / 2048.0
		draw_set_transform(size * 0.5, map_angle, Vector2.ONE * s)
		image_rect.position = -point
		draw_texture_rect(base_texture, image_rect, false)
		if not region.is_empty():
			var points := PackedVector2Array()
			for vertex in region.polygon_xz:
				points.append(world_to_pixel(Vector2(vertex[0], vertex[1])) - point)
			draw_colored_polygon(points, Color("9cb8a2"))
			if structure_texture!=null:draw_texture_rect(structure_texture, image_rect, false)
		draw_set_transform(Vector2.ZERO)
		var center := size * 0.5
		draw_circle(center, 12, Color("101e23"))
		var arrow := PackedVector2Array([center + Vector2(0,-10), center + Vector2(8,8), center + Vector2(0,4), center + Vector2(-8,8)])
		draw_colored_polygon(arrow, Color("f6d995"))
		# North remains world north while the floor rotates.
		var north := Vector2.UP.rotated(map_angle)
		var edge := center + north * (minf(size.x,size.y)*0.5 - 14)
		draw_circle(edge, 9, Color("101e23"))
		draw_string(ThemeDB.fallback_font, edge+Vector2(-5,5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e6b875"))
	draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE*2), Color("718981"), false, 1.0)
