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
	var ok:=manager.apply_story_patch(flags,values,persistent(),notify)
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
	return patch({"br_"+action:true},{})

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
	return patch({"br_mouse_resolved":true,"a10_eat":result==1},{"br_mouse":result,"br_mouse_intent":0})

func commit_ending(kind: int) -> bool:
	if kind not in [2,3]:last_error="无效的离开方式。";return false
	var check:=allowed("return_human" if kind==2 else "escape_cat")
	if not check.allowed:last_error="还缺少："+"、".join(check.missing_reasons);return false
	return patch({"a11_escape":true} if kind==3 else {},{"br_ending":kind,"br_phase":1})

func finish_ending() -> bool:
	if int(manager.values.get("br_phase",0))==2:return true
	if int(manager.values.get("br_ending",0)) not in [2,3] or int(manager.values.get("br_phase",0))!=1:
		last_error="尚未确认离开方式。";return false
	return patch({"br_rescue_done":true,"a11_finished":true,"a11_complete":true},{"br_phase":2})

func migrate_legacy(notify := false) -> bool:
	var f:=manager.flags.duplicate(true)
	var v:=manager.values.duplicate(true)
	var legacy: bool=int(v.get("br_schema",0))==0
	if legacy:
		v.br_mouse=0;v.br_mouse_intent=0;v.br_ending=0;v.br_phase=0
		if f.get("a10_eat",false) or (int(v.get("current_day",1))>=11 and manager.get_status(&"a10_eat")==CalicoQuestManager.State.COMPLETED):
			v.br_mouse=1;f.a10_eat=true;f.br_mouse_resolved=true
		elif int(v.get("current_day",1))==10 and f.get("a10_refused",false):v.br_mouse_intent=1
		if f.get("a11_finished",false):
			v.br_ending=3;v.br_phase=2;f.br_legacy_completed=true;f.a11_escape=true;f.a11_complete=true
		elif f.get("a11_escape",false):v.br_ending=3;v.br_phase=1
		v.br_schema=1
	last_error=validate_snapshot(f,v)
	if not last_error.is_empty():return false
	# Upper-level facts can repair their implied prerequisites, never the opposite outcome.
	if int(v.get("br_mouse",0)) in [1,2]:
		f.br_mouse_resolved=true;f.a10_eat=int(v.br_mouse)==1;v.br_mouse_intent=0
	if int(v.get("br_mouse",0))==2 or int(v.get("br_mouse_intent",0))==2:
		f.br_k2_owned=true;f.br_k2_ready=true;f.br_k2_spent=true
	if int(v.get("br_mouse_intent",0))!=0:
		for key in ["a10_catch","a10_note","a10_asked","a10_refused"]:f[key]=true
	if f.get("br_k2_ready",false):f.br_k2_owned=true
	if f.get("br_imprint_cleared",false):f.br_rewrite_off=true;f.br_channel_off=true
	if int(v.get("br_phase",0))==2:
		f.a11_finished=true;f.a11_complete=true
		if not f.get("br_legacy_completed",false):f.br_rescue_done=true
	if int(v.get("br_ending",0))==3 and int(v.get("br_phase",0))>=1:f.a11_escape=true
	if f==manager.flags and v==manager.values:return true
	if legacy and persistent() and FileAccess.file_exists(manager.save_path):
		var path:=ProjectSettings.globalize_path(manager.save_path)
		if not FileAccess.file_exists(path+".branches_v1.bak"):
			if DirAccess.copy_absolute(path,path+".branches_v1.bak")!=OK:
				last_error="无法备份旧剧情存档，原文件已保留。";return false
	# No quest events/notifications before the complete migration has reached disk.
	var ok:=manager.apply_story_patch(f,v,persistent(),notify)
	if not ok:last_error=manager.last_save_error
	return ok

static func validate_snapshot(f: Dictionary,v: Dictionary) -> String:
	if int(v.get("br_schema",0)) not in [0,1]:return "剧情存档版本不支持，请保留原文件。"
	if int(v.get("br_mouse",0)) not in [0,1,2] or int(v.get("br_mouse_intent",0)) not in [0,1,2]:return "老鼠记录无效，请恢复备份。"
	if int(v.get("br_ending",0)) not in [0,2,3] or int(v.get("br_phase",0)) not in [0,1,2]:return "结局记录无效，请恢复备份。"
	if int(v.get("br_mouse",0))==2 and f.get("a10_eat",false):return "老鼠获救与吞食记录冲突，原存档已保留，请恢复备份。"
	if int(v.get("br_schema",0))==1 and int(v.get("br_mouse",0))==0 and f.get("a10_eat",false):return "吞食结果缺少相符的命运记录，原存档已保留。"
	if [int(v.get("br_mouse",0)),int(v.get("br_mouse_intent",0))] in [[1,2],[2,1]]:return "已确定结果与待处理命令冲突，原存档已保留。"
	if int(v.get("br_ending",0))==2 and f.get("a11_escape",false):return "人身与猫身离开记录冲突，原存档已保留，请恢复备份。"
	if int(v.get("br_phase",0))>0 and int(v.get("br_ending",0))==0:return "结局缺少已确认的离开方式，请恢复备份。"
	if int(v.get("br_mouse_intent",0))>0 and (int(v.get("current_day",1))!=10 or int(v.get("br_ending",0))!=0):return "未完成的命令与当前章节冲突，请恢复备份。"
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
				if goal.kind!=CalicoQuestObjective.Kind.CUSTOM or not manager.flags.get(str(goal.target_id),false):continue
				var old:=manager.get_progress(id,goal.id)
				if old>=goal.target_count:continue
				var event:="br:v1:"+str(goal.target_id)+":done"
				manager.report_event(CalicoQuestObjective.Kind.CUSTOM,goal.target_id,1,event)
				if manager.get_progress(id,goal.id)==old:
					manager.report_event(CalicoQuestObjective.Kind.CUSTOM,goal.target_id,1,event+":repair")
				advanced=advanced or manager.get_progress(id,goal.id)>old
		if not advanced:break
	reconciling=false
