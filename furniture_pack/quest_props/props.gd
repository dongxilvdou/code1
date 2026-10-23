extends RefCounted
## Shared visual resources and reversible, save-derived daily lifecycle.
const PATH := "res://furniture_pack/quest_props/"
const Details = preload("res://furniture_pack/quest_props/refined_props.gd")

static func model(parent: Node3D, id: String, pos := Vector3.ZERO) -> Node3D:
	var visual: Node3D
	if id in ["fish","half_fish"]:
		visual = Node3D.new()
		Details.fish(visual,id=="half_fish")
	else:
		var scene := load(PATH+id+".glb") as PackedScene
		assert(scene != null,"Missing quest prop: "+id)
		visual = scene.instantiate() as Node3D
		Details.finish_imported(visual,id)
	visual.name = "Visual_"+id
	parent.add_child(visual)
	visual.position = pos
	visual.set_meta("quest_model",id)
	return visual

static func furniture(game: Node, id: String, room := "") -> Node3D:
	for n in game.get_tree().get_nodes_in_group("placed_furniture"):
		if n.get_meta("asset_id","")==id and (room.is_empty() or n.get_meta("placement_room","")==room):return n
	return null

static func bind(proxy: Node3D, existing: Node3D) -> void:
	assert(is_instance_valid(existing),"Quest furniture binding failed: "+str(proxy.name))
	proxy.set_meta("bound_furniture",existing)

static func days(n: Node3D, numbers: Array, interactive: Array = []) -> void:
	n.set_meta("quest_days",numbers)
	n.set_meta("interaction_days",interactive if not interactive.is_empty() else numbers)

static func interactable(n: Node3D, today: int) -> bool:
	return n.is_visible_in_tree() and not n.get_meta("interaction_complete",false) and today in n.get_meta("interaction_days",[1,2,3,4,5,6,7])

static func fit_mesh(n: MeshInstance3D, template: Mesh, dimensions: Vector3) -> void:
	# Reuse the furniture library's manufactured edges and tapered legs at the required scale.
	var bounds := template.get_aabb()
	n.mesh = template
	n.scale = dimensions/bounds.size
	n.position -= bounds.get_center()*n.scale

static func activate(n: Node3D, enabled: bool) -> void:
	n.visible = enabled
	for body in n.find_children("*","CollisionObject3D",true,false):
		if not body.has_meta("quest_layer") or body.collision_layer!=0:body.set_meta("quest_layer",body.collision_layer)
		body.collision_layer = int(body.get_meta("quest_layer")) if enabled else 0

static func apply(items: Dictionary, today: int) -> void:
	for n in items.values():
		if n.has_meta("quest_days"):activate(n,n.visible and today in n.get_meta("quest_days"))

static func retire(items: Dictionary, today: int) -> void:
	# Also visit inactive chapters: a hidden parent does not disable physics.
	for n in items.values():
		if n.has_meta("quest_days") and today not in n.get_meta("quest_days"):activate(n,false)

static func memo_day(n: Node3D, today: int) -> void:
	if today>11 or int(n.get_meta("memo_day",0))==today:return
	for mesh in n.find_children("*","MeshInstance3D",true,false):
		for surface_index in range(mesh.mesh.get_surface_count()):
			var original: Material = mesh.mesh.surface_get_material(surface_index)
			if original is StandardMaterial3D and original.resource_name=="memo":
				var material := original.duplicate() as StandardMaterial3D
				material.albedo_texture = load("res://act4/textures/day%d_note.svg"%today if today>=8 else "res://act3/textures/day%d_note.png"%today if today>=6 else PATH+("lunch_memo.png" if today==4 else "memo.png" if today==1 else "memo%d.png"%today))
				mesh.set_surface_override_material(surface_index,material)
	n.set_meta("memo_day",today)

static func surface(n: Node3D, player: CharacterBody3D, default_half: Vector2, default_top: float) -> bool:
	var origin: Vector3 = n.get_meta("surface_origin",n.global_position)
	var half: Vector2 = n.get_meta("surface_half",default_half)
	var top: float = n.get_meta("surface_top",default_top)
	var p := player.global_position-origin
	return absf(p.x)<half.x and absf(p.z)<half.y and absf(player.global_position.y-top)<.11 and player.is_on_floor()
