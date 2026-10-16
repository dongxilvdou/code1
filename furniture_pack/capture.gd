extends SceneTree
var viewer: Node3D

func _initialize() -> void:
	call_deferred("capture")

func shot(name: String) -> void:
	for i in range(12):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://furniture_pack/previews/"+name+".png")

func capture() -> void:
	viewer = load("res://furniture_pack/preview.tscn").instantiate()
	root.add_child(viewer)
	await shot("01_sofa_and_cat")
	viewer.select(10)
	await shot("02_bed_and_cat")
	viewer.select(15)
	await shot("03_bath_vanity")
	viewer.select(4)
	viewer.eye_view = true
	viewer.distance = 3.2
	viewer.yaw = .25
	viewer.update_camera()
	await shot("04_cat_eye_table")
	viewer.overview()
	viewer.ui.hide()
	viewer.update_camera()
	await shot("05_collection")
	DirAccess.make_dir_recursive_absolute("res://furniture_pack/previews/items")
	for i in range(viewer.items.size()):
		viewer.select(i)
		viewer.ui.hide()
		viewer.cat.hide()
		var d: Array = viewer.items[i].dimensions_m
		viewer.focus = Vector3(0,d[1]*.48,0)
		viewer.distance = maxf(maxf(d[0],d[2]),d[1])*2.1+.4
		viewer.pitch = .30
		viewer.update_camera()
		await shot("items/"+viewer.items[i].id)
	print("FURNITURE_CAPTURE 5 views and ",viewer.items.size()," asset thumbnails saved")
	viewer.free()
	quit()
