extends "res://quest_system/tests/test_story_persistence.gd"
## Real disk transactions, isolated user data only. Boundary fixtures aren't full runs.
func flags_for(mouse: int, prepared: bool) -> Dictionary:
	var f:={"intro_seen":true,"a10_catch":true,"a10_note":true,"a10_asked":true,"daily_note_ack_10":true,"br_mouse_resolved":true,"a10_eat":mouse==1}
	if mouse==2:f.merge({"br_k2_owned":true,"br_k2_ready":true,"br_k2_spent":true,"br_k2_manual_read":true,"br_rewrite_off":true,"br_channel_off":true,"br_imprint_cleared":true})
	if prepared:
		f.merge({"a3_photo":true,"a7_read_photo":true,"br_memory_m1":true,"br_memory_m2":true,"br_memory":true,"br_memory_verified":true,"br_return_plan_ready":true})
		for id in Rules.Evidence.IDS:f["br_doc_"+id+"_read"]=true
	return f

func values_for(mouse: int, prepared: bool) -> Dictionary:
	return {"current_day":10,"br_schema":2,"br_mouse":mouse,"br_memory_level":3 if prepared else 0,"br_d5_read_mask":3 if prepared else 0,"br_memory_seen_mask":7 if prepared else 0}

func run() -> void:
	create_timer(120).timeout.connect(func():printerr("STORY_V2_SAVE_TIMEOUT");quit(2))
	for prepared in [false,true]:
		for mouse in [1,2]:
			fixture(flags_for(mouse,prepared),values_for(mouse,prepared))
			var bytes:=FileAccess.get_file_as_bytes(path_)
			var system=await boot()
			check(system.inspect_save().valid and FileAccess.get_file_as_bytes(path_)==bytes,"Menu reads schema2 without writing")
			check(system.prepare_session(false),"Valid schema2 prepares")
			var branch=game.get_node("StoryBranches");var before=system.manager.make_save_data()
			var blocking:=path_.get_base_dir()+"/not_a_directory"
			var file=FileAccess.open(blocking,FileAccess.WRITE);file.store_string("write blocker");file.close()
			system.manager.save_path=blocking+"/slot.json"
			check(not branch.state.commit_night_ten(),"Night save failure is rejected")
			check(before==system.manager.make_save_data(),"Failed night restores flags, values, quests and event history")
			check(FileAccess.get_file_as_bytes(path_)==bytes,"Night failure preserves disk bytes")
			system.manager.save_path=path_
			var observed: Array=[]
			system.manager.changed.connect(func():observed.append([system.manager.values.get("current_day",1),system.manager.values.get("br_route",0),system.manager.flags.get("br_route_locked",false)]))
			check(branch.state.commit_night_ten(),"Night can retry")
			var route:=3 if prepared else 2 if mouse==2 else 1
			check(not observed.is_empty() and observed.all(func(x):return x==[11,route,true]),"Observers see date/route/lock committed together")
			var saved=JSON.parse_string(FileAccess.get_file_as_string(path_))
			check(saved.values.br_route==route and saved.flags.br_route_locked and int(saved.values.get("br_phase",0))==0,"Disk contains locked route, not ending completion")
			await leave();system=await boot();check(system.prepare_session(false),"Locked route survives reload")
			branch=game.get_node("StoryBranches")
			check(branch.value("br_route")==route and not branch.state.commit_night_ten(),"Reload does not recalculate route")
			check(not branch.state.commit_ending(3 if route==3 else 2),"Mismatching ending rejected after load")
			await leave()
	# New early legacy rescue gains permanent control freedom, never invented documents.
	fixture({"br_k2_owned":true,"br_k2_ready":true,"br_k2_spent":true,"br_mouse_resolved":true,"a10_eat":false},{"current_day":10,"br_schema":1,"br_mouse":2})
	var original:=FileAccess.get_file_as_bytes(path_);var system=await boot()
	check(system.prepare_session(false),"Old rescued day10 migrates")
	var branch=game.get_node("StoryBranches")
	check(branch.flag("br_imprint_cleared") and not branch.flag("br_memory") and not branch.flag("br_doc_d1_read"),"Migration applies only permanent K2 semantics")
	check(FileAccess.get_file_as_bytes(path_+".branches_v2.bak")==original,"Backup preserves exact pre-migration bytes")
	await leave()
	# Day11 old flows explicitly preserve the prior two-ending system.
	fixture({"a11_enter":true,"a11_memory":true},{"current_day":11,"br_schema":1,"br_mouse":0})
	system=await boot();check(system.prepare_session(false),"Old unknown-mouse day11 remains continuable")
	branch=game.get_node("StoryBranches")
	check(branch.flag("br_legacy_flow") and branch.value("br_legacy_schema")==1 and branch.value("br_route")==0,"Legacy flow has verified migration provenance")
	await leave()
	for bad in ["missing_route","forged_legacy","wrong_ending","invalid_mask"]:
		var f=flags_for(1,true);var v=values_for(1,true)
		match bad:
			"missing_route":v.current_day=11
			"forged_legacy":f.br_legacy_flow=true;v.current_day=11
			"wrong_ending":v.merge({"current_day":11,"br_route":3,"br_night_mouse":1,"br_ending":3,"br_phase":1});f.br_route_locked=true;f.br_night_return_ready=true
			"invalid_mask":v.br_d5_read_mask=4
		fixture(f,v);original=FileAccess.get_file_as_bytes(path_);system=await boot();var before=system.manager.make_save_data()
		check(not system.inspect_save().valid,"Menu rejects invalid schema2: "+bad)
		check(not system.prepare_session(false),"Invalid schema2 cannot start: "+bad)
		check(FileAccess.get_file_as_bytes(path_)==original and system.manager.make_save_data()==before,"Invalid data preserves disk and memory: "+bad)
		await leave()
	print("STORY_V2_PERSISTENCE_TEST ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
