extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var studio = load("res://scenes/cat_studio.tscn").instantiate()
	root.add_child(studio)
	current_scene = studio
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	for shot in [["cat_01_refined","idle",false,false],["cat_02_stretch","stretch",false,false],["cat_03_skeleton","stretch",true,true],["cat_04_crouch","crouch",true,false]]:
		studio.set_pose(shot[1])
		studio.set_clay(shot[2])
		studio.show_bones = shot[3]
		studio.cat.animate = false
		studio.cat.pose_model(shot[1],0,0,0,1.0 if shot[1]=="crouch" else 0.0)
		await create_timer(.35).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://screenshots/"+shot[0]+".png")
	print("CALICO_STUDIO_CAPTURE saved four actual model views")
	studio.queue_free()
	await process_frame
	quit()
