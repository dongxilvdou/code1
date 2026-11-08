extends RefCounted
## All new-session route and evidence rules are pure. Old saves opt in explicitly.
const COPY=preload("res://story_branches/data.gd")
const Evidence=preload("res://story_branches/evidence_data.gd")
const Legacy=preload("res://story_branches/legacy_rules.gd")
const STEPS := ["index","k2_owned","k2_ready","auto_stopped","body_seen","power_safe","records","memory","rewrite_off","channel_off","imprint_cleared","imprint_verified","module","routing","target_verified"]
const HUMAN_FACTS := ["br_memory","br_return_plan_ready","br_auto_stopped","br_body_seen","br_power_safe","br_rewrite_off","br_channel_off","br_imprint_cleared","br_imprint_verified","br_module","br_routing","br_target_verified"]
const NAMES := {"br_imprint_verified":"现场核验自主响应","br_return_plan_ready":"回迁准备已核对","br_auto_stopped":"暂停自动启动","br_body_seen":"核对原身体","br_power_safe":"验证维持电路隔离","br_records":"收录三类档案","br_memory":"恢复研究员记忆","br_rewrite_off":"停用自动重写","br_channel_off":"清除强制通道","br_imprint_cleared":"验证自主响应","br_module":"更换耦合模块","br_routing":"验证反向连接","br_target_verified":"核对目标和时间"}

static func reconciled(facts: Dictionary) -> Dictionary:
	var f:=facts.duplicate(true)
	var level:=int(f.get("br_memory_level",0))
	if f.get("a3_photo",false) and f.get("br_doc_d1_read",false):level=maxi(level,1)
	if level>=1 and f.get("a7_read_photo",false) and f.get("br_doc_d2_read",false) and f.get("br_doc_d3_read",false):level=maxi(level,2)
	f.br_doc_d5_read=int(f.get("br_d5_read_mask",0))==3
	if level>=2 and f.get("br_doc_d4_read",false) and f.br_doc_d5_read:level=3;f.br_memory_verified=true
	f.br_memory_level=level;f.br_memory_m1=level>=1;f.br_memory_m2=level>=2;f.br_memory=level>=3
	f.br_return_plan_ready=return_ready(f)
	return f

static func return_ready(facts: Dictionary) -> bool:
	for key in ["a3_photo","a7_read_photo","br_memory_m1","br_memory_m2","br_memory","br_memory_verified"]:
		if not facts.get(key,false):return false
	if int(facts.get("br_memory_level",0))!=3 or int(facts.get("br_d5_read_mask",0))!=3:return false
	for id in Evidence.IDS:
		if not facts.get("br_doc_"+id+"_read",false):return false
	return true

static func choose_route(facts: Dictionary) -> int:
	if not facts.get("br_mouse_resolved",false) or int(facts.get("br_mouse_intent",0))!=0 or int(facts.get("br_mouse",0)) not in [1,2]:return 0
	if return_ready(facts):return 3
	return 2 if int(facts.get("br_mouse",0))==2 else 1

static func evaluate(action: String, facts: Dictionary, busy := false) -> Dictionary:
	if facts.get("br_legacy_flow",false):return Legacy.evaluate(action,facts,busy)
	var missing: Array[String]=[]
	var number:=int(facts.get("current_day",1));var route:=int(facts.get("br_route",0))
	var need: Array=[]
	if busy:missing.append("请先结束当前演出或阅读。")
	if int(facts.get("br_ending",0))!=0:missing.append("终章已经启动。")
	match action:
		"index":
			need=["a7_read_photo","a7_read_site","a7_read_chat","a7_read_news"]
			if number<7:missing.append("先恢复电脑并完成调查。")
		"k2_owned","k2_ready":
			if number<7 or number>10:missing.append("维护附件在第七至十天准备。")
			need=["a7_login","br_k2_manual_read"]
			if action=="k2_ready":need.append("br_k2_owned")
			if facts.get("br_k2_spent",false):missing.append("设备已消耗，永久解除结果仍然保留。")
		"rescue_mouse","refuse_mouse":
			if number!=10:missing.append("只能在第十天处理命令。")
			need=["a10_catch","a10_note","a10_asked"]
			if int(facts.get("br_mouse",0))!=0 or int(facts.get("br_mouse_intent",0))!=0:missing.append("老鼠事件已经处理或正在恢复。")
			if facts.get("br_imprint_cleared",false):missing.append("强制通道已经解除，不能重新启动受控事件。")
			if action=="rescue_mouse":
				need.append_array(["br_k2_owned","br_k2_ready","br_k2_manual_read"])
				if facts.get("br_k2_spent",false):missing.append("设备已经消耗。")
		"default_finish","escape_cat","return_human":
			if number!=11 or not facts.get("br_route_locked",false):missing.append("尚未完成第十晚路线提交。")
			var expected: int={"default_finish":1,"escape_cat":2,"return_human":3}[action]
			if route!=expected:missing.append("这项操作不属于本次已确定的路线。")
			need=["a11_enter"]
			if action=="default_finish":need.append_array(["a11_memory","a11_cage","a11_vent"])
			elif action=="escape_cat":
				need.append_array(["br_escape_path_known","a11_vent","br_imprint_cleared"])
				if int(facts.get("br_mouse",0))!=2:missing.append("引路的老鼠并未获救。")
			else:
				need.append_array(HUMAN_FACTS)
				if not facts.get("br_night_return_ready",false) or not return_ready(facts):missing.append("第十晚尚未形成完整回迁方案。")
			if int(facts.get("br_mouse_intent",0))!=0:missing.append("先完成老鼠事件。")
		_:
			if action not in STEPS:missing.append("未知操作。")
			if number!=11 or route!=3 or not facts.get("br_route_locked",false):missing.append("这项现场操作仅供已确定的回迁路线。")
			need=["a11_enter","br_memory","br_return_plan_ready"]
			match action:
				"memory","records":missing.append("资料和记忆在第十晚前核对；此处仅可回看。")
				"power_safe":need.append_array(["br_auto_stopped","br_body_seen"])
				"rewrite_off":need.append_array(["br_power_safe","br_body_seen"])
				"channel_off":need.append_array(["br_rewrite_off","br_power_safe"])
				"imprint_cleared":need.append_array(["br_channel_off","br_power_safe"])
				"imprint_verified":need.append_array(["br_imprint_cleared","br_power_safe","br_body_seen"])
				"module":need.append("br_power_safe")
				"routing":need.append_array(["br_module","br_power_safe","br_imprint_cleared"])
				"target_verified":need.append_array(["br_routing","br_body_seen"])
	for key in need:
		if not facts.get(key,false):missing.append(NAMES.get(key,{"a11_enter":"进入地下室","a11_memory":"回想纸条","a11_cage":"检查旧抓痕","a11_vent":"打开格栅","br_k2_manual_read":"阅读设备折页","br_return_plan_ready":"形成回迁准备","br_escape_path_known":"听完通路引导"}.get(key,"完成前置调查")))
	return {"allowed":missing.is_empty(),"missing_reasons":missing}

static func validate_input(action: String, input: Dictionary) -> String:
	return Legacy.validate_input(action,input)
