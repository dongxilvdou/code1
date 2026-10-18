extends SceneTree
## Repair only the existing sink instance. Preserve all other villa placements.
func _initialize() -> void:
	var villa: Node3D = load("res://scenes/villa.tscn").instantiate()
	var repaired := 0
	for node in villa.find_children("*","Node3D",true,false):
		if node.get_meta("asset_id","")!="sink_cabinet":continue
		node.get_node("Cabinet_shelf2").position.y = .61
		node.get_node("Collision/Solid_005").position.y = .61
		node.get_node("Tap_spout").rotation.x = deg_to_rad(135)
		repaired += 1
	var scene := PackedScene.new()
	var result := scene.pack(villa) if repaired==1 else ERR_INVALID_DATA
	if result==OK:result = ResourceSaver.save(scene,"res://scenes/villa.tscn")
	print("SINK_FIXTURE_REPAIR ",repaired," result=",result)
	villa.free()
	quit(0 if result==OK else 1)
