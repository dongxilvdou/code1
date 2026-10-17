extends SceneTree
const PACK := "res://furniture_pack/"
func _initialize() -> void:call_deferred("install")
func collision(root_node: Node3D, label: String, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 2
	root_node.add_child(body)
	body.owner = root_node
	var col := CollisionShape3D.new()
	col.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	col.owner = root_node
func install() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK+"workrooms_catalog.json"))
	for record in catalog.assets:
		var asset := Node3D.new()
		asset.name = str(record.id).to_pascal_case()
		var visual: Node3D = load(record.model).instantiate()
		visual.name = "BlenderModel"
		asset.add_child(visual)
		visual.owner = asset
		asset.set_meta("furniture",record)
		if record.id=="work_desk":
			collision(asset,"DesktopCollision",Vector3(0,.752,0),Vector3(1.8,.052,.76))
			for x in [-.72,.72]:collision(asset,"Leg",Vector3(x,.37,0),Vector3(.085,.74,.14))
			collision(asset,"Brace",Vector3(0,.58,.08),Vector3(1.48,.065,.05))
		elif record.id=="computer_tower":collision(asset,"CaseCollision",Vector3(0,.29,0),Vector3(.245,.55,.45))
		elif record.id=="office_chair":
			collision(asset,"Seat",Vector3(0,.465,0),Vector3(.50,.10,.47))
			collision(asset,"Back",Vector3(0,.86,-.225),Vector3(.49,.53,.09))
			collision(asset,"Lift",Vector3(0,.24,0),Vector3(.08,.35,.08))
		# Desktop props intentionally have no blocking collision at cat height.
		var packed := PackedScene.new()
		var result := packed.pack(asset)
		if result==OK:result = ResourceSaver.save(packed,PACK+"scenes/"+record.id+".tscn")
		assert(result==OK,"Cannot save "+record.id)
		asset.free()
	print("WORKROOMS_INSTALL ",catalog.assets.size()," reusable GLB scenes")
	quit()
