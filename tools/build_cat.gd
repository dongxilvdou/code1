extends SceneTree
func _initialize() -> void:
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
