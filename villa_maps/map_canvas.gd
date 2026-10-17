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
const LABEL_SIZE := 12
var label_font := SystemFont.new()
var label_style := StyleBoxFlat.new()
var prepared_spec: Dictionary = {}
var prepared_rooms: Array = []

func _init() -> void:
	label_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	label_style.bg_color = Color(.04,.09,.10,.82)
	label_style.set_corner_radius_all(3)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func world_to_pixel(p: Vector2) -> Vector2:
	var r: Array = spec.world_rect_xz
	return (p - Vector2(r[0], r[1])) / Vector2(r[2], r[3]) * 2048.0

func world_to_minimap(p: Vector2) -> Vector2:
	return size * .5 + ((p-position_xz) * pixels_per_metre).rotated(map_angle)

func prepare_room_labels() -> void:
	# Static text metrics and candidate room positions are built once per floor,
	# rather than sorting hundreds of positions on every rendered frame.
	prepared_spec = spec
	prepared_rooms.clear()
	for room in spec.get("regions",[]):
		var text: String = room.name
		# Step numbers belong on the full map; the mini map names the flight.
		if room.id in ["lower_flight","upper_flight"]:text = text.split(" ")[0]
		text = text.replace("/","\n")
		if not "\n" in text and text.length()>=4:
			var split := ceili(text.length()/2.0)
			text = text.left(split)+"\n"+text.substr(split)
		var lines := text.split("\n")
		var extent := Vector2(0,label_font.get_height(LABEL_SIZE)*lines.size())
		for line in lines:extent.x = maxf(extent.x,label_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,LABEL_SIZE).x)
		extent += Vector2(8,4)
		var polygon := PackedVector2Array()
		for v in room.polygon_xz:polygon.append(Vector2(v[0],v[1]))
		var anchor := Vector2(room.label_xz[0],room.label_xz[1])
		var candidates: Array[Vector2] = [anchor]
		var bounds := Rect2(polygon[0],Vector2.ZERO)
		for v in polygon:bounds = bounds.expand(v)
		# Fallback positions are sampled inside the room when the anchor is under
		# the cat marker or outside the viewport. They never drift into neighbours.
		for y in range(1,16):
			for x in range(1,16):
				var p := bounds.position + bounds.size*Vector2(x/16.0,y/16.0)
				if Geometry2D.is_point_in_polygon(p,polygon):candidates.append(p)
		candidates.sort_custom(func(a,b):return a.distance_squared_to(anchor)<b.distance_squared_to(anchor))
		prepared_rooms.append({"id":room.id,"text":text,"extent":extent,"anchor":anchor,"polygon":polygon,"candidates":candidates})

func minimap_label_layout() -> Array:
	# Rotate world anchors, never the glyphs. Each label centre stays in its room.
	if prepared_spec!=spec:prepare_room_labels()
	var result: Array = []
	var rooms := prepared_rooms.duplicate()
	rooms.sort_custom(func(a, b):
		var a_current: bool = a.id == region.get("id", "")
		var b_current: bool = b.id == region.get("id", "")
		if a_current != b_current:return a_current
		return a.anchor.distance_squared_to(position_xz) < b.anchor.distance_squared_to(position_xz))
	var safe_area := Rect2(Vector2(5,5),size-Vector2(10,10))
	var center := size*.5
	var north := center + Vector2.UP.rotated(map_angle)*(minf(size.x,size.y)*.5-14)
	var occupied: Array[Rect2] = [Rect2(center-Vector2(13,13),Vector2(26,26)),Rect2(north-Vector2(11,11),Vector2(22,22))]
	for room in rooms:
		var text: String = room.text
		var extent: Vector2 = room.extent
		var bounds := Rect2(world_to_minimap(room.polygon[0]),Vector2.ZERO)
		for p in room.polygon:bounds = bounds.expand(world_to_minimap(p))
		if not safe_area.intersects(bounds):continue
		for p in room.candidates:
			var candidate := world_to_minimap(p)
			var rect := Rect2(candidate-extent*.5,extent)
			if not safe_area.encloses(rect):continue
			# The backplate may cover a wall edge in a narrow room. Keeping the
			# centre inside its polygon lets that room retain a readable name.
			var valid := true
			for other in occupied:
				if other.intersects(rect.grow(2)):valid = false
			if not valid:continue
			result.append({"id":room.id,"text":text,"rect":rect,"current":room.id==region.get("id","")})
			occupied.append(rect)
			break
		if room.id==region.get("id","") and not result.any(func(entry):return entry.id==room.id):
			# A utility room can be smaller than the player arrow at this zoom.
			# In that case a short leader identifies the room without covering it.
			for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
				var offset: Vector2 = direction*(extent*.5+Vector2(18,18))
				var rect := Rect2(center+offset-extent*.5,extent)
				if not safe_area.encloses(rect):continue
				var valid := true
				for other in occupied:
					if other.intersects(rect.grow(2)):valid = false
				if not valid:continue
				result.append({"id":room.id,"text":text,"rect":rect,"current":true,"anchor":center})
				occupied.append(rect)
				break
	return result

func draw_minimap_labels() -> void:
	for entry in minimap_label_layout():
		var rect: Rect2 = entry.rect
		if entry.has("anchor"):draw_line(entry.anchor,rect.get_center(),Color("dfbd7b"),1.0,true)
		draw_style_box(label_style,rect)
		var lines: PackedStringArray = entry.text.split("\n")
		var y := rect.position.y+2+label_font.get_ascent(LABEL_SIZE)
		for line in lines:
			var width := label_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,LABEL_SIZE).x
			var start := Vector2(rect.get_center().x-width*.5,y)
			draw_string_outline(label_font,start,line,HORIZONTAL_ALIGNMENT_LEFT,-1,LABEL_SIZE,2,Color("101e23"))
			draw_string(label_font,start,line,HORIZONTAL_ALIGNMENT_LEFT,-1,LABEL_SIZE,Color("ffe0a2") if entry.current else Color("f5f1df"))
			y += label_font.get_height(LABEL_SIZE)

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
		var r: Array = spec.world_rect_xz
		var s := Vector2(r[2],r[3]) * pixels_per_metre / 2048.0
		draw_set_transform(size * 0.5, map_angle, s)
		image_rect.position = -point
		draw_texture_rect(base_texture, image_rect, false)
		if not region.is_empty():
			var points := PackedVector2Array()
			for vertex in region.polygon_xz:
				points.append(world_to_pixel(Vector2(vertex[0], vertex[1])) - point)
			draw_colored_polygon(points, Color("9cb8a2"))
			if structure_texture!=null:draw_texture_rect(structure_texture, image_rect, false)
		draw_set_transform(Vector2.ZERO)
		draw_minimap_labels()
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
