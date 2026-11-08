extends SceneTree
const Rules=preload("res://story_branches/rules.gd")
var checks := 0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("RETIREMENT_FAILED ",message)
func run() -> void:
	var root_scene=load("res://scenes/main.tscn").instantiate();root_scene.get_node("QuestSystem").save_enabled=false;root.add_child(root_scene);current_scene=root_scene
	for _i in range(12):await process_frame
	root_scene.start_game()
	for _i in range(12):await process_frame
	var branch=root_scene.get_node("StoryBranches")
	for prepared in [false,true]:
		for mouse in [1,2]:
			var f:={"br_route_locked":true,"br_mouse_resolved":true,"a11_enter":true,"a11_memory":true,"a11_cage":true,"a11_vent":true,"br_escape_path_known":true,"br_imprint_cleared":true}
			var route:=3 if prepared else 2 if mouse==2 else 1
			var facts=f.duplicate();facts.merge({"current_day":11,"br_route":route,"br_mouse":mouse,"br_night_return_ready":prepared})
			for action in ["default_finish","escape_cat","return_human"]:
				var expected: int={"default_finish":1,"escape_cat":2,"return_human":3}[action]
				if route!=expected:check(not Rules.evaluate(action,facts).allowed,"Old action cannot switch locked route: "+action)
	check(not root_scene.get_node("HouseMemes").story_tv_active,"Menu/new session has no old TV override")
	check(branch.world.documents.size()==3,"Exactly three new world documents")
	for document in branch.world.documents.values():
		check(document.find_children("*","CollisionObject3D",true,false).is_empty(),"Evidence adds no invisible blocking colliders")
	for path in ["res://story_branches/panels.gd","res://story_branches/data.gd","res://act4/panels.gd"]:
		var text=FileAccess.get_file_as_string(path)
		for phrase in ["短暂干扰","先前只是临时干扰","强制通道干扰","我读完了，开始今天任务"]:check(not phrase in text,"Retired instruction absent: "+phrase)
	check(not "restore_clock" in FileAccess.get_file_as_string("res://story_branches/chapter.gd"),"No periodic save/world rebuild loop")
	var definition=load("res://story_branches/quests/br_memory.tres")
	check(not definition.extra_conditions.any(func(c):return c.key in [&"br_body_seen",&"br_power_safe",&"br_records"]),"Pre-day11 memory has no basement dependency cycle")
	var standalone=load("res://quest_system/quest_system.tscn").instantiate()
	check(standalone.catalog.resource_path=="res://act2/quests/catalog.tres","Reusable controller references formal catalog");standalone.free()
	print("STORY_RETIREMENT_AUDIT ",JSON.stringify({"checks":checks,"failures":failures}))
	root_scene.get_node("StoryBranches").cancel_runtime();root_scene.stop_audio();root_scene.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
