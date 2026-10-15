extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var viewer = load("res://furniture_pack/preview.tscn").instantiate()
	root.add_child(viewer)
	for i in range(20,viewer.items.size()):
		viewer.select(i)
		viewer.ui.hide()
		viewer.cat.hide()
		var d: Array = viewer.items[i].dimensions_m
		viewer.focus = Vector3(0,d[1]*.48,0)
		viewer.distance = maxf(maxf(d[0],d[2]),d[1])*2.1+.25
		viewer.pitch = .50 if d[1]<.1 else .30
		viewer.update_camera()
		for frame in range(12):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://furniture_pack/previews/items/"+viewer.items[i].id+".png")
	# Exercise the expanded catalogue, including its camera framing.
	viewer.overview()
	for frame in range(8):await process_frame
	print("DECOR_CAPTURE ",viewer.items.size()-20," asset renders; ",viewer.items.size()," assets in viewer")
	viewer.free()
	quit()
