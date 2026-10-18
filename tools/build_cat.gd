extends SceneTree
func _initialize() -> void:
	call_deferred("build_current_cat")

func build_current_cat() -> void:
	# The supplied cat is now authored/exported in Blender. Do not silently
	# regenerate the retired procedural model over its live scene wrapper.
	if FileAccess.file_exists("res://assets/models/pets/house_cat.glb"):
		var current = load("res://scenes/calico.tscn").instantiate()
		root.add_child(current)
		print("CAT_BUILD supplied model ready; Blender source: assets/models/pets/authoring/cat.blend; clips: ",current.clips.keys())
		current.free()
		quit()
		return
	var cat: Node3D = load("res://scripts/cat_model.gd").new()
	cat.name = "Calico"
	cat.build_model()
	root.add_child(cat)
	cat.bake_animation_library()
	assign_owner(cat,cat)
	var packed := PackedScene.new()
	var result := packed.pack(cat)
	if result==OK:result = ResourceSaver.save(packed,"res://scenes/calico.tscn")
	print("CALICO_BUILD ",result," ",cat.get_meta("model_stats"))
	quit(0 if result==OK else 1)
func assign_owner(parent: Node, owner_node: Node) -> void:
	for child in parent.get_children():
		child.owner = owner_node
		assign_owner(child,owner_node)
