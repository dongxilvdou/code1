extends RefCounted
const Rules = preload("res://story_branches/rules.gd")
var manager: CalicoQuestManager
var system: Node
var replay := false
var busy := false
var last_error := ""
var reconciling := false

func configure(owner_system: Node) -> void:
	system=owner_system;manager=system.manager

func snapshot() -> Dictionary:
	var result:=manager.flags.duplicate(true)
	result.merge(manager.values,true)
	return result

func persistent() -> bool:
	return system.save_enabled and not "--quest-test" in OS.get_cmdline_user_args() and not system.game.demo_mode

func allowed(action: String) -> Dictionary:
	return Rules.evaluate(action,snapshot(),busy or replay)

func patch(flags: Dictionary, values: Dictionary, notify := true) -> bool:
	if replay:last_error="重看不会改变当前进度。";return false
	var f:=manager.flags.duplicate(true);f.merge(flags,true)
	var v:=manager.values.duplicate(true);v.merge(values,true)
	if int(v.get("br_schema",0))==2 and not f.get("br_legacy_flow",false):
		var merged:=f.duplicate(true);merged.merge(v,true)
		var derived:=Rules.reconciled(merged)
		for key in derived:
			if derived[key] is bool:f[key]=derived[key]
			elif derived[key] is int:v[key]=derived[key]
	last_error=validate_snapshot(f,v)
	if not last_error.is_empty():return false
	if f==manager.flags and v==manager.values:return true
	var ok:=manager.apply_story_patch(f,v,persistent(),notify)
	last_error="" if ok else manager.last_save_error
	if ok:reconcile_progress()
	return ok

func commit_step(action: String, input: Dictionary={}) -> bool:
	if action not in Rules.STEPS:last_error="无效的调查操作。";return false
	var check:=allowed(action)
	if not check.allowed:last_error="还缺少："+"、".join(check.missing_reasons);return false
	if manager.flags.get("br_"+action,false):return true
	last_error=Rules.validate_input(action,input)
	if not last_error.is_empty():return false
	var flags:={"br_"+action:true}
	if action=="imprint_cleared" and not manager.flags.get("br_legacy_flow",false):flags.br_imprint_verified=true
	return patch(flags,{})

func commit_mouse_intent(rescue: bool) -> bool:
	var check:=allowed("rescue_mouse" if rescue else "refuse_mouse")
	if not check.allowed:last_error="还缺少："+"、".join(check.missing_reasons);return false
	var flags:={"a10_refused":true}
	if rescue:flags.br_k2_spent=true
	return patch(flags,{"br_mouse_intent":2 if rescue else 1})

func resolve_mouse(result: int) -> bool:
	if int(manager.values.get("br_mouse",0))==result:return true
	if result not in [1,2] or int(manager.values.get("br_mouse_intent",0))!=result:
		last_error="命令结果与已保存的决定不符。";return false
	var flags:={"br_mouse_resolved":true,"a10_eat":result==1}
	if result==2 and not manager.flags.get("br_legacy_flow",false):
		flags.merge({"br_rewrite_off":true,"br_channel_off":true,"br_imprint_cleared":true})
	return patch(flags,{"br_mouse":result,"br_mouse_intent":0})

func commit_ending(kind: int) -> bool:
	if kind not in [2,3]:last_error="无效的离开方式。";return false
	var action:="return_human" if kind==2 else "default_finish" if int(manager.values.get("br_route",0))==1 and not manager.flags.get("br_legacy_flow",false) else "escape_cat"
	var check:=allowed(action)
	if not check.allowed:last_error="还缺少："+"、".join(check.missing_reasons);return false
	return patch({"a11_escape":true} if kind==3 else {},{"br_ending":kind,"br_phase":1})

func finish_ending() -> bool:
	if int(manager.values.get("br_phase",0))==2:return true
	if int(manager.values.get("br_ending",0)) not in [2,3] or int(manager.values.get("br_phase",0))!=1:
		last_error="尚未确认离开方式。";return false
	if not manager.flags.get("br_legacy_flow",false) and int(manager.values.get("br_route",0)) in [2,3] and not manager.flags.get("br_rescue_performed",false):last_error="请先完成救援交接。";return false
	var flags:={"a11_finished":true,"a11_complete":true}
	if manager.flags.get("br_rescue_performed",false):flags.br_rescue_done=true
	return patch(flags,{"br_phase":2})

func record_evidence_view(id: String, page := "") -> bool:
	if replay:last_error="回看不改变存档。";return false
	var facts:=snapshot()
	last_error=Rules.Evidence.access_reason(id,facts)
	if not last_error.is_empty():return false
	var flags: Dictionary={};var values: Dictionary={}
	if id=="d5":
		if page not in ["recording","access"]:last_error="请选择录音或访问说明页。";return false
		values.br_d5_read_mask=int(facts.get("br_d5_read_mask",0)) | (1 if page=="recording" else 2)
	else:flags["br_doc_"+id+"_read"]=true
	return patch(flags,values)

func record_manual_view() -> bool:
	if manager.flags.get("br_k2_manual_read",false):return true
	return patch({"br_k2_manual_read":true},{})

func reconcile_memory() -> bool:
	if replay or manager.flags.get("br_legacy_flow",false):return true
	var facts:=snapshot();var derived:=Rules.reconciled(facts)
	if facts==derived:return true
	return patch({}, {})

func commit_night_ten() -> bool:
	var facts:=Rules.reconciled(snapshot())
	if replay or busy or int(facts.get("current_day",1))!=10:last_error="请先结束当前演出。";return false
	for key in ["a10_catch","a10_note","a10_asked","br_mouse_resolved","daily_note_ack_10"]:
		if key=="a10_asked" and facts.get("br_legacy_mouse_resolved",false):continue
		if not facts.get(key,false):last_error="请完成第十天的事件后再休息。";return false
	var route:=Rules.choose_route(facts)
	if route==0:last_error="老鼠事件尚未结束，请先完成或恢复演出。";return false
	return patch({"a10_complete":true,"br_route_locked":true,"br_night_return_ready":Rules.return_ready(facts)},
		{"br_route":route,"br_night_mouse":int(facts.br_mouse),"current_day":11,"br_day11_intro_state":0})

func migrate_legacy(notify := false) -> bool:
	var f:=manager.flags.duplicate(true);var v:=manager.values.duplicate(true)
	var schema:=int(v.get("br_schema",0));var number:=int(v.get("current_day",1))
	last_error=validate_snapshot(f,v)
	if not last_error.is_empty():return false
	if schema==2:return true
	if schema==0:
		v.br_mouse=0;v.br_mouse_intent=0;v.br_ending=0;v.br_phase=0
		if f.get("a10_eat",false) or (number>=11 and manager.get_status(&"a10_eat")==CalicoQuestManager.State.COMPLETED):
			v.br_mouse=1;f.a10_eat=true;f.br_mouse_resolved=true
		elif number==10 and f.get("a10_refused",false):v.br_mouse_intent=1
		if f.get("a11_finished",false):
			v.br_ending=3;v.br_phase=2;f.br_legacy_completed=true;f.a11_escape=true;f.a11_complete=true
		elif f.get("a11_escape",false):v.br_ending=3;v.br_phase=1
	if number>=11 or int(v.get("br_phase",0))>0:
		f.br_legacy_flow=true;v.br_legacy_schema=schema;v.br_legacy_origin_day=number
	else:
		f.br_legacy_flow=false;v.br_route=0;f.br_route_locked=false
		if int(v.get("br_mouse",0)) in [1,2] and not f.get("a10_asked",false):f.br_legacy_mouse_resolved=true;v.br_legacy_mouse_schema=schema;f.a10_catch=true
		if int(v.get("br_mouse",0))==2:
			for key in ["br_rewrite_off","br_channel_off","br_imprint_cleared"]:f[key]=true
	if int(v.get("br_mouse",0)) in [1,2]:f.br_mouse_resolved=true;f.a10_eat=int(v.br_mouse)==1;v.br_mouse_intent=0
	if int(v.get("br_mouse",0))==2 or int(v.get("br_mouse_intent",0))==2:
		f.br_k2_owned=true;f.br_k2_ready=true;f.br_k2_spent=true;f.br_k2_manual_read=true
	if int(v.get("br_mouse_intent",0))!=0:
		for key in ["a10_catch","a10_note","a10_asked","a10_refused"]:f[key]=true
	if f.get("br_k2_ready",false):f.br_k2_owned=true;f.br_k2_manual_read=true
	if f.get("br_imprint_cleared",false):f.br_rewrite_off=true;f.br_channel_off=true
	if int(v.get("br_phase",0))==2:f.a11_finished=true;f.a11_complete=true
	if int(v.get("br_ending",0))==3 and int(v.get("br_phase",0))>=1:f.a11_escape=true
	v.br_schema=2
	last_error=validate_snapshot(f,v)
	if not last_error.is_empty():return false
	if persistent() and FileAccess.file_exists(manager.save_path):
		var path:=ProjectSettings.globalize_path(manager.save_path)
		if not FileAccess.file_exists(path+".branches_v2.bak") and DirAccess.copy_absolute(path,path+".branches_v2.bak")!=OK:
			last_error="无法备份旧剧情存档，原文件已保留。";return false
	var ok:=manager.apply_story_patch(f,v,persistent(),notify)
	if not ok:last_error=manager.last_save_error
	return ok

static func validate_snapshot(f: Dictionary,v: Dictionary) -> String:
	var schema:=int(v.get("br_schema",0));var number:=int(v.get("current_day",1))
	var mouse:=int(v.get("br_mouse",0));var intent:=int(v.get("br_mouse_intent",0))
	var ending:=int(v.get("br_ending",0));var phase:=int(v.get("br_phase",0))
	if schema not in [0,1,2]:return "剧情存档版本不支持，请保留原文件。"
	if mouse not in [0,1,2] or intent not in [0,1,2]:return "老鼠记录无效，请恢复备份。"
	if ending not in [0,2,3] or phase not in [0,1,2]:return "结局记录无效，请恢复备份。"
	if mouse==2 and f.get("a10_eat",false):return "老鼠获救与吞食记录冲突，原文件已保留。"
	if schema>=1 and mouse==0 and f.get("a10_eat",false):return "吞食结果缺少相符的命运记录。"
	if [mouse,intent] in [[1,2],[2,1]]:return "老鼠结果与待处理命令冲突。"
	if phase>0 and ending==0:return "结局缺少已确认的离开方式。"
	if ending==2 and f.get("a11_escape",false):return "人体与猫身离开记录冲突。"
	if intent>0 and (number!=10 or ending!=0):return "未完成的命令与当前章节冲突。"
	if schema<2:return ""
	if f.get("br_legacy_flow",false):
		if int(v.get("br_legacy_schema",-1)) not in [0,1] or int(v.get("br_legacy_origin_day",0))<11:return "旧流程缺少可验证的迁移来源。"
		return ""
	var facts:=f.duplicate(true);facts.merge(v,true)
	if f.get("br_legacy_mouse_resolved",false) and (int(v.get("br_legacy_mouse_schema",-1)) not in [0,1] or mouse not in [1,2]):return "旧版已结算事件缺少有效来源。"
	var level:=int(v.get("br_memory_level",0));var mask:=int(v.get("br_d5_read_mask",0))
	if level<0 or level>3 or mask<0 or mask>3 or int(v.get("br_memory_seen_mask",0)) not in range(8):return "记忆或资料页签记录无效。"
	if level>=1 and not (f.get("a3_photo",false) and f.get("br_doc_d1_read",false)):return "照护记忆缺少对应资料。"
	if level>=2 and not (f.get("a7_read_photo",false) and f.get("br_doc_d2_read",false) and f.get("br_doc_d3_read",false)):return "身份记忆缺少对应资料。"
	if level==3 and not (f.get("br_memory_verified",false) and f.get("br_doc_d4_read",false) and mask==3):return "完整记忆缺少封存会话核对。"
	if f.get("br_memory",false)!=(level==3):return "记忆阶段与结果冲突。"
	if f.get("br_doc_d5_read",false)!=(mask==3):return "封存会话页签不完整。"
	if f.get("br_imprint_cleared",false) and not (f.get("br_rewrite_off",false) and f.get("br_channel_off",false)):return "钢印解除结果缺少完整通道状态。"
	if mouse==2 and not (f.get("br_k2_spent",false) and f.get("br_imprint_cleared",false)):return "放鼠结果缺少设备激活及永久解除记录。"
	if intent==1 and f.get("br_imprint_cleared",false):return "已解除钢印的角色不能恢复强制吞食。"
	if intent==2 and not (f.get("br_k2_owned",false) and f.get("br_k2_ready",false) and f.get("br_k2_spent",false)):return "放鼠演出缺少已预留设备。"
	var route:=int(v.get("br_route",0));var locked: bool=f.get("br_route_locked",false)
	if route not in [0,1,2,3] or locked!=(route!=0):return "路线锁定记录无效。"
	if number>=11 and not locked:return "第十一天缺少第十晚提交的路线。"
	if locked:
		if number!=11 or mouse not in [1,2] or intent!=0 or int(v.get("br_night_mouse",0))!=mouse:return "已锁路线与第十晚事件记录冲突。"
		var expected:=3 if f.get("br_night_return_ready",false) else 2 if mouse==2 else 1
		if route!=expected:return "路线不符合第十晚提交的判定结果。"
		if route==3 and not Rules.return_ready(facts):return "回迁路线缺少前十天的完整准备。"
	if phase>0 and ((ending==2 and route!=3) or (ending==3 and route not in [1,2])):return "终章与已锁定路线冲突。"
	if int(v.get("br_day11_intro_state",0)) not in [0,1,2]:return "起床警报状态无效。"
	return ""

func reconcile_progress() -> void:
	if reconciling or replay:return
	reconciling=true
	for _pass in range(20):
		var advanced:=false
		for id in manager.definitions:
			if not str(id).begins_with("br_") and str(id) not in ["a10_catch","a10_note","a10_asked","a10_eat","a11_memory","a11_traces","a11_finished"]:continue
			if manager.get_status(id)!=CalicoQuestManager.State.ACTIVE:continue
			for goal in manager.definitions[id].objectives:
				var legacy_mouse: bool=str(goal.target_id)=="a10_asked" and manager.flags.get("br_legacy_mouse_resolved",false)
				if goal.kind!=CalicoQuestObjective.Kind.CUSTOM or (not manager.flags.get(str(goal.target_id),false) and not legacy_mouse):continue
				var old:=manager.get_progress(id,goal.id)
				if old>=goal.target_count:continue
				var event:="br:v2:"+str(goal.target_id)+":done"
				manager.report_event(CalicoQuestObjective.Kind.CUSTOM,goal.target_id,1,event)
				if manager.get_progress(id,goal.id)==old:
					manager.report_event(CalicoQuestObjective.Kind.CUSTOM,goal.target_id,1,event+":repair")
				advanced=advanced or manager.get_progress(id,goal.id)>old
		if not advanced:break
	reconciling=false
