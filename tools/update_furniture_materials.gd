extends SceneTree
## Update material files in place without regenerating any furniture geometry.
func _initialize() -> void:
	for key in ["oak","walnut","linen","cream","sage_fabric","rust","rope","stone"]:
		var path: String = "res://furniture_pack/materials/"+key+".tres"
		var mat: ShaderMaterial = load(path)
		mat.set_shader_parameter("wood_texture",load("res://furniture_pack/textures/oak_grain.png"))
		mat.set_shader_parameter("fabric_texture",load("res://furniture_pack/textures/linen_weave.png"))
		mat.set_shader_parameter("stone_texture",load("res://furniture_pack/textures/mineral_detail.png"))
		if ResourceSaver.save(mat,path)!=OK:
			push_error("Cannot save "+path)
			quit(1)
			return
	print("FURNITURE_MATERIALS 8 updated")
	var catalog_path := "res://furniture_pack/decor_catalog.json"
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	var found := false
	for entry in catalog.items:
		if entry.id=="decor_room_plaque":found = true
	if not found:
		catalog.items.append({"id":"decor_room_plaque","name":"可编辑房间门牌","room":"陈设与生活设备","scene":"res://furniture_pack/scenes/decor_room_plaque.tscn","dimensions_m":[.26,.11,.02],"bounds_min_m":[-.13,0,-.009],"collision_shapes":0,"triangles":24,"note":"修改 room_title 即可复用；+Z 面朝走廊，固定墙面安装。"})
		FileAccess.open(catalog_path,FileAccess.WRITE).store_string(JSON.stringify(catalog,"\t"))
	quit()
