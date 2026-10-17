extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var studio = load("res://scenes/cat_studio.tscn").instantiate()
	root.add_child(studio)
	current_scene = studio
	DirAccess.make_dir_recursive_absolute("res://previews/calico")
	for shot in [["front",0.0,"idle",0.0],["left",PI/2,"idle",0.0],["back",PI,"idle",0.0],["right",-PI/2,"idle",0.0],["portrait",.55,"idle",0.0],["sit",.6,"sit",0.0],["walk",.7,"walk",1.9],["run",.7,"run",3.8],["jump",.7,"jump",0.0]]:
		studio.yaw = shot[1]
		studio.elevation = .12 if shot[0]!="portrait" else .22
		studio.distance = 1.28
		studio.update_camera()
		studio.set_pose(shot[2])
		studio.cat.animate = false
		studio.cat.pose_model(shot[2],PI if shot[2]=="jump" else shot[3],0,1.0 if shot[2] in ["walk","run"] else 0.0,0.0)
		await create_timer(.12).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/calico/"+shot[0]+".png")
	print("CALICO_REVIEW nine real Godot renders")
	studio.queue_free()
	await process_frame
	quit()
