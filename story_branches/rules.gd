extends RefCounted
## Pure prerequisites. UI and execution share the same checks.
const COPY = preload("res://story_branches/data.gd")
const STEPS := ["index","k2_owned","k2_ready","auto_stopped","body_seen","power_safe","records","memory","rewrite_off","channel_off","imprint_cleared","module","routing","target_verified"]
const HUMAN_FACTS := ["br_auto_stopped","br_body_seen","br_power_safe","br_records","br_memory","br_rewrite_off","br_channel_off","br_imprint_cleared","br_module","br_routing","br_target_verified"]
const NAMES := {"br_auto_stopped":"暂停自动启动","br_body_seen":"核对原身体","br_power_safe":"验证维持电路隔离","br_records":"收录三类档案","br_memory":"恢复研究员记忆","br_rewrite_off":"停用自动重写","br_channel_off":"清除强制通道","br_imprint_cleared":"验证自主响应","br_module":"更换耦合模块","br_routing":"验证反向连接","br_target_verified":"核对目标和时间"}

static func evaluate(action: String, facts: Dictionary, busy := false) -> Dictionary:
	var missing: Array[String]=[]
	var number: int=int(facts.get("current_day",1))
	var ending: int=int(facts.get("br_ending",0))
	var need: Array=[]
	if busy:missing.append("请先结束当前演出。")
	if ending!=0:missing.append("本次离开方式已经确认。")
	match action:
		"index":
			if number==7:need=["a7_login","a7_read_photo","a7_read_site","a7_read_chat","a7_read_news"]
			elif number>=11:need=["a11_enter"]
			else:missing.append("请在电脑原始记录或地下终端保留索引。")
		"k2_owned","k2_ready":
			if number<7 or number>10:missing.append("维护附件仅在第七至十天准备。")
			if number==7:need.append("a7_login")
			if action=="k2_ready":need.append("br_k2_owned")
			if facts.get("br_k2_spent",false):missing.append("设备已使用，需要实验室维护。")
		"rescue_mouse","refuse_mouse":
			if number!=10:missing.append("只能在第十天处理命令。")
			need=["a10_catch","a10_note","a10_asked"]
			if int(facts.get("br_mouse",0))!=0:missing.append("老鼠的结果已经确定。")
			if int(facts.get("br_mouse_intent",0))!=0:missing.append("上一次决定尚在处理中。")
			if action=="rescue_mouse":
				need.append_array(["br_k2_owned","br_k2_ready"])
				if facts.get("br_k2_spent",false):missing.append("校准器已经耗尽。")
		"escape_cat":
			if number!=11:missing.append("尚未到达地下室。")
			need=["a11_enter","a11_memory","a11_cage","a11_vent"]
			if int(facts.get("br_mouse_intent",0))!=0:missing.append("请先处理尚未结束的命令。")
		"return_human":
			if number!=11:missing.append("尚未到达地下室。")
			need=["a11_enter"]+HUMAN_FACTS
			if int(facts.get("br_mouse_intent",0))!=0:missing.append("请先处理尚未结束的命令。")
		_:
			if action not in STEPS:missing.append("未知操作。")
			if number!=11:missing.append("请先进入地下室。")
			need=["a11_enter"]
			match action:
				"power_safe":need.append_array(["br_auto_stopped","br_body_seen"])
				"records","memory":need.append_array(["br_body_seen","br_power_safe"])
				"rewrite_off":need.append_array(["br_memory","br_power_safe","br_records"])
				"channel_off":need.append("br_rewrite_off")
				"imprint_cleared":need.append_array(["br_channel_off","br_memory","br_power_safe"])
				"module":need.append("br_power_safe")
				"routing":need.append_array(["br_module","br_memory","br_power_safe","br_imprint_cleared"])
				"target_verified":need.append_array(["br_routing","br_body_seen","br_records"])
			if action=="memory":need.append("br_records")
	for key in need:
		if not facts.get(key,false):missing.append(NAMES.get(key,{"a10_catch":"抓住老鼠","a10_note":"查看老鼠纸条","a10_asked":"听完阿嚼的话","br_k2_owned":"取得校准器","br_k2_ready":"完成校准","a11_enter":"进入地下室","a11_memory":"回想逃跑纸条","a11_cage":"调查01号笼","a11_vent":"完全打开格栅"}.get(key,"完成前置调查")))
	return {"allowed":missing.is_empty(),"missing_reasons":missing}

static func validate_input(action: String, input: Dictionary) -> String:
	match action:
		"k2_owned":
			if str(input.get("code",""))!=COPY.BOX_CODE:return "维护盒使用接收载体尾号。"
			if not input.get("manual_read",false):return "先检查设备并读完折页说明。"
		"k2_ready":
			var choices: Array=input.get("choices",[])
			if choices.size()!=3:return "请设置载体、工作模式和输出档位。"
			if choices[0]!=COPY.K2_ANSWER[0]:return "载体不匹配：应匹配当前承载意识的身体。"
			if choices[1]!=COPY.K2_ANSWER[1]:return "模式不符：本机不读取个人记忆。"
			if choices[2]!=COPY.K2_ANSWER[2]:return "输出过高：使用最低可用输出。"
		"body_seen","records":
			if int(input.get("read_mask",0))!=7:return "请先完整核对三项内容。"
		"power_safe":
			var switches: Array=input.get("switches",[])
			if switches.size()!=3:return "请检查三路拨钮。"
			if not switches[0]:return "维持供电必须保留。"
			if switches[1]:return "先隔离转移执行回路。"
			if not switches[2]:return "维护总线未连接。"
		"memory":
			if input.get("choices",[])!=COPY.MEMORY_ANSWER:return "配对与档案不符，请重新查看身份、护理和操作记录。"
		"channel_off":
			if not input.get("confirmed",false):return "请确认仅移除强制指令通道。"
		"imprint_cleared":
			if not input.get("refused",false):return "离线验证尚未收到自主拒绝。"
		"routing":
			if input.get("choices",[])!=COPY.ROUTING_ANSWER:return "连接不符：从当前猫载体读取，写入原身体，以原始档案核验。"
		"target_verified":
			if input.get("target",-1)!=0:return "目标不匹配：请选择 H-031 原身体。"
			if input.get("time",[])!=COPY.VERIFY_TIME:return "时间与最后一次操作日志不匹配。"
	return ""
