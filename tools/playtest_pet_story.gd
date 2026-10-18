extends "res://tools/playtest_map_stairs.gd"
var checks := 0
func verify(ok: bool, label: String) -> void:
	checks += 1
	expect(ok,label)
func run_tests() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.get_node("QuestSystem").save_enabled = false
	root.add_child(game)
	current_scene = game
	map_hud = game.get_node("VillaMap/MapHUD")
	await ticks(8)
	game.request_start_game(true)
	await ticks(6)
	verify(game.opening.active,"New model did not enter cinematic")
	verify(game.player.model.clips.has("stretch"),"Cinematic stretch unavailable")
	if "--natural-intro" in OS.get_cmdline_user_args():
		await ticks(1700)
	else:
		await key(KEY_ESCAPE)
		await ticks(40)
	var day = game.get_node("DayOne")
	var second = game.get_node("DayTwo")
	verify(day.dialog=="intro","First-day story did not follow opening")
	await key(KEY_ESCAPE)
	await ticks(6)
	verify(day.dialog.is_empty() and game.player.active,"Story dialog did not restore control")
	verify(game.player.camera.current and not game.opening.active,"Cinematic camera did not restore")
	for flag in ["walk","run","open_living","light_off","papers_done"]:day.manager.set_flag(StringName(flag),true)
	day.restore_world()
	second.restore_world()
	verify(second.feeding_available(),"Existing feeding quest disabled")
	var nest = game.get_node("Apartment/Staircase/DogNest")
	verify(second.world.items.dog.get_meta("actor")==nest,"Quest does not refer to landing dog")
	verify(second.world.items.dog.find_children("*","MeshInstance3D",true,false).is_empty(),"Old primitive dog duplicated")
	second.set_value("d2_holding",5)
	second.set_value("dog_hunger",45)
	second.set_flag("dog_portion",true)
	second.restore_world()
	game.player.position = Vector3(4.12,1.51,-1.15)
	game.player.rotation.y = 0
	game.player.yaw = 0
	game.player.velocity = Vector3.ZERO
	await ticks(8)
	game.player.camera.look_at(second.target_position("dog"))
	verify(second.nearest_item()=="dog","Landing dog's feeding point not reachable by ray")
	await key(KEY_E)
	await ticks(3)
	verify(second.flag("d2_dog_fed"),"E feeding action did not complete")
	verify(second.val("dog_hunger")==100 and second.val("d2_holding")==0,"Feeding state not preserved")
	verify(nest.fed_time>0,"Fed dog did not react")
	verify(not game.get_node("QuestSystem").manager.autosave,"Test unexpectedly enabled saves")
	print("PET_STORY_TEST ",JSON.stringify({"checks":checks,"cinematic_story_feeding":true,"failures":failures}))
	game.stop_audio()
	game.queue_free()
	await ticks(3)
	quit(0 if failures.is_empty() else 1)
