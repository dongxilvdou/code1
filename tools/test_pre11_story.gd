extends SceneTree
const Rules=preload("res://story_branches/rules.gd")
const State=preload("res://story_branches/state.gd")
class Harness extends Node:
	var manager: CalicoQuestManager
	var save_enabled := false
var checks := 0
var failures: Array[String]=[]
var harness: Harness
var state

func verify(ok: bool, description: String) -> void:
	checks+=1
	if not ok:failures.append(description);printerr("PRE11_FAILED ",description)

func _initialize() -> void:call_deferred("run")

func reset(day := 10) -> void:
	harness.manager.start_new_game();harness.manager.set_value(&"current_day",day)
	state.busy=false;state.replay=false

func seed_mouse(mouse: int) -> void:
	var flags:={"daily_note_ack_10":true,"a10_catch":true,"a10_note":true,"a10_asked":true,"br_mouse_resolved":true,"a10_eat":mouse==1}
	if mouse==2:flags.merge({"br_k2_owned":true,"br_k2_ready":true,"br_k2_manual_read":true,"br_k2_spent":true,"br_rewrite_off":true,"br_channel_off":true,"br_imprint_cleared":true})
	verify(state.patch(flags,{"br_mouse":mouse}),"Prepare legal mouse result")

func evidence() -> void:
	verify(state.patch({"a3_photo":true,"a7_login":true,"a7_read_photo":true,"a7_read_site":true,"a7_read_chat":true,"a7_read_news":true},{}),"Set original photo evidence")
	verify(state.record_evidence_view("d3"),"Read transfer file out of order")
	verify(state.record_evidence_view("d4"),"Read report out of order")
	verify(state.record_evidence_view("d5","recording"),"Read first D5 page")
	verify(not harness.manager.flags.get("br_doc_d5_read",false),"One D5 page must remain incomplete")
	verify(state.record_evidence_view("d5","access"),"Read second D5 page")
	verify(not harness.manager.flags.get("br_memory",false),"D5 alone cannot restore memory")
	verify(not state.record_evidence_view("d6"),"D6 remains sealed before M3")
	verify(state.record_evidence_view("d2"),"Read personnel file")
	verify(state.record_evidence_view("d1"),"Filling early evidence advances all ready stages")
	verify(int(harness.manager.values.get("br_memory_level",0))==3,"Out-of-order evidence reaches M3")
	verify(not harness.manager.flags.get("br_imprint_cleared",false),"Memory cannot clear imprint")

func run() -> void:
	create_timer(60).timeout.connect(func():printerr("PRE11_TIMEOUT");quit(2))
	harness=Harness.new();root.add_child(harness);harness.manager=CalicoQuestManager.new();harness.add_child(harness.manager)
	verify(harness.manager.configure(load("res://act2/quests/catalog.tres")),"Formal catalog validates")
	state=State.new();state.configure(harness)
	reset(7)
	verify(not state.record_evidence_view("d2"),"Original four investigations required")
	verify(not state.record_evidence_view("d5","access"),"Locked D5 cannot count as read")
	verify(not state.record_evidence_view("missing"),"Unknown documents rejected")
	evidence()
	verify(state.record_evidence_view("d6"),"D6 opens after M3")
	verify(Rules.return_ready(state.snapshot()),"Return prerequisites complete")
	var snapshot=harness.manager.make_save_data()
	verify(state.record_evidence_view("d6") and snapshot==harness.manager.make_save_data(),"Repeat read is idempotent")
	state.replay=true;verify(not state.record_evidence_view("d1"),"Readonly replay cannot write");state.replay=false
	for prepared in [false,true]:
		for mouse in [1,2]:
			reset()
			if prepared:evidence();verify(state.record_evidence_view("d6"),"Read D6 for route")
			seed_mouse(mouse)
			var expected:=3 if prepared else 2 if mouse==2 else 1
			verify(state.commit_night_ten(),"Commit tenth night")
			verify(int(harness.manager.values.br_route)==expected,"Route priority %s / %d"%[prepared,mouse])
			verify(int(harness.manager.values.current_day)==11 and harness.manager.flags.br_route_locked,"Date and route commit together")
			verify(int(harness.manager.values.get("br_ending",0))==0,"Lock does not complete ending")
			verify(not state.commit_night_ten(),"Cannot lock again on day11")
			verify(not state.commit_ending(2 if expected!=3 else 3),"Opposite ending is rejected")
			verify(state.patch({"a11_enter":true,"a11_memory":true,"a11_cage":true,"a11_vent":true,"br_escape_path_known":true},{}),"Seed onsite exploration boundary")
			if expected==3:
				verify(not state.commit_ending(2),"Human ending still requires actual onsite repair")
			else:verify(state.commit_ending(3),"Matching escape/default ending can start")
	reset();evidence();seed_mouse(2)
	verify(state.commit_night_ten() and int(harness.manager.values.br_route)==2,"M3 without D6 remains route2")
	verify(state.record_evidence_view("d6") and int(harness.manager.values.br_route)==2,"Day11 late D6 does not change route")
	verify(int(harness.manager.values.br_memory_level)==3,"Escape does not erase restored identity")
	reset();verify(not state.commit_night_ten(),"Unresolved mouse cannot advance day")
	verify(state.patch({"a10_catch":true,"a10_note":true,"a10_asked":true,"daily_note_ack_10":true,"a7_login":true},{}),"Prepare independent K2")
	verify(not state.commit_step("k2_owned",{"code":"031","manual_read":true}),"Unpresented manual cannot count")
	verify(state.record_manual_view(),"Manual successfully presented")
	verify(state.commit_step("k2_owned",{"code":"031","manual_read":true}),"Acquire K2 without story documents")
	verify(not state.commit_step("k2_ready",{"choices":[1,1,2]}),"Wrong output rejected")
	verify(state.commit_step("k2_ready",{"choices":[1,1,0]}),"Calibrate independent K2")
	verify(not harness.manager.flags.get("br_imprint_cleared",false),"Calibration alone does not clear")
	verify(state.commit_mouse_intent(true),"Reserve rescue intent")
	verify(not state.commit_night_ten(),"Pending rescue cannot advance")
	verify(state.resolve_mouse(2),"Resolve rescue")
	verify(harness.manager.flags.br_imprint_cleared and not harness.manager.flags.a10_eat,"Rescue permanently clears imprint")
	verify(int(harness.manager.values.get("br_memory_level",0))==0,"K2 does not restore memory")
	verify(not state.commit_mouse_intent(false),"Cleared protagonist cannot be forced to swallow")
	verify(State.validate_snapshot(harness.manager.flags,harness.manager.values).is_empty(),"Legal final K2 state validates")
	var corrupted=harness.manager.values.duplicate();corrupted.br_route=3;corrupted.current_day=11
	verify(not State.validate_snapshot(harness.manager.flags,corrupted).is_empty(),"Forged route rejected")
	reset()
	harness.manager.apply_story_patch({"a10_eat":true},{"br_schema":0},false)
	verify(state.migrate_legacy(),"Old eaten result migrates without replay")
	verify(harness.manager.flags.get("br_legacy_mouse_resolved",false) and not harness.manager.flags.get("a10_asked",false),"Old result does not fabricate a conversation")
	verify(state.patch({"a10_note":true,"daily_note_ack_10":true},{}),"Old eaten save can read its remaining paper")
	verify(state.commit_night_ten() and int(harness.manager.values.br_route)==1,"Old resolved event can rest without an impossible new dialogue")
	print("PRE11_RULES_TEST ",JSON.stringify({"checks":checks,"failures":failures}))
	harness.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
