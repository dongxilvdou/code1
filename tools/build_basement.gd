extends SceneTree

func save_scene(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	var error := packed.pack(node)
	if error==OK:error = ResourceSaver.save(packed,path)
	if error!=OK:push_error("Cannot save basement scene: "+path)
	print("BASEMENT_SCENE ",path," ",error)

func _initialize() -> void:
	var builder = load("res://scripts/basement/laboratory_builder.gd").new()
	var cage: Node3D = builder.cage_scene()
	save_scene(cage,"res://furniture_pack/basement/observation_cage.tscn")
	cage.free()
	builder = load("res://scripts/basement/laboratory_builder.gd").new()
	var lab: Node3D = builder.build()
	save_scene(lab,"res://scenes/basement/medical_laboratory.tscn")
	lab.free()
	quit()
