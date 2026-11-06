extends SceneTree
const Builder = preload("res://story_branches/model_builder.gd")
const MODELS := ["conversion_retrofit","vent_service","recovery_bay","rescue_stage","memory_vignette","maintenance_box","k2_device"]

func own_children(n: Node, root_: Node) -> void:
	for c in n.get_children():
		c.owner=root_
		if c.scene_file_path.is_empty():own_children(c,root_)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://story_branches/scenes")
	for id in MODELS:
		var builder := Builder.new()
		var n := builder.create(id)
		own_children(n,n)
		var scene := PackedScene.new()
		assert(scene.pack(n)==OK)
		assert(ResourceSaver.save(scene,"res://story_branches/scenes/"+id+".tscn")==OK)
		var triangles := 0
		for mesh in n.find_children("*","MeshInstance3D",true,false):triangles+=mesh.mesh.get_faces().size()/3
		n.free()
		print("BRANCH_MODEL_SAVED ",id," triangles=",triangles)
	quit()
