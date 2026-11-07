extends Node3D
## Idempotent visual adapter: receives facts; never awards items or changes saves.
signal visual_action_completed(action: StringName)
@export_enum("retrofit", "vent", "recovery", "rescue", "memory", "box", "k2") var kind := "retrofit"
var snapshot: Dictionary = {}
var motion: Tween
var breathing_clock := 0.0

func _ready() -> void:
	if kind in ["memory","rescue"]:
		# Packed-scene descendants are deliberately not flattened into the assets.
		# Apply safe visual overrides after their own ready hooks have completed.
		for body in find_children("*","CollisionObject3D",true,false):body.collision_layer=0;body.collision_mask=0
		if kind=="rescue":$AjaoVisual/Bed.hide();$AjaoVisual.set_pose("stand",true)
		if kind=="memory":$CageVisual/Leaf/Sign.text="F-03\nC-031"
	if has_meta("render_mask"):
		var mask_: int=get_meta("render_mask")
		for child in find_children("*","GeometryInstance3D",true,false):child.layers=mask_
	apply_visual_state(snapshot)

func apply_visual_state(state: Dictionary) -> void:
	snapshot = state.duplicate(true)
	if motion and motion.is_valid():motion.kill()
	match kind:
		"retrofit":
			var safe := bool(state.get("br_power_safe",false))
			led("LifeLED",true)
			led("TransferLED",not (safe or state.get("br_auto_stopped",false)))
			led("ServiceLED",safe)
			for entry in [["LifeToggle",-18.0],["TransferToggle",18.0 if safe else -18.0],["ServiceToggle",-18.0 if safe else 18.0]]:
				get_node(NodePath(entry[0])).rotation_degrees.x=entry[1]
			$DrawerSlide.position=Vector3(-.02,.71,.415)+Vector3(0,0,.12 if state.get("drawer_open",false) else 0)
			$DrawerSlide/SpareModule.visible=not state.get("br_module",false)
			$ModuleBurnt.visible=not state.get("br_module",false)
			$ModuleInstalled.visible=state.get("br_module",false)
			$RoutingCables.visible=state.get("br_routing",false)
			$ObservationText.text="维持稳定 / 执行隔离 / 维护接入" if safe else "H-031 / 维持舱"
			$EmergencyRedButton.position.z=.369
		"vent":
			$GrillePivot.rotation.y=-1.05 if state.get("a11_vent",false) else -.12
			$LeftCatchPivot.rotation.z=deg_to_rad(-35) if state.get("a11_vent",false) else 0.0
			$GrillePivot/BentEdge.position.y=-.205 if state.get("a11_vent",false) else -.18
		"recovery":
			$HatchPivot.rotation.z=deg_to_rad(-78) if state.get("hatch_open",false) else 0.0
		"rescue":
			$MouseTransport.visible=int(state.get("br_mouse",0))==2
			$RescueStretcher.visible=int(state.get("branch",3))==3
		"memory":
			$CageVisual/Leaf.rotation.y=deg_to_rad(105) if state.get("door_open",false) else 0.0
			$Blanket.visible=state.get("blanket",true)
		"box":
			$BoxDoorPivot.rotation.y=deg_to_rad(-105) if state.get("box_open",false) or state.get("br_k2_owned",false) else 0.0
			$K2InBox.visible=not state.get("br_k2_owned",false)
			var code: String=str(state.get("box_digits","031" if state.get("br_k2_owned",false) else "000")).pad_zeros(3).right(3)
			for i in range(3):get_node("BoxDoorPivot/Digit%d"%(i+1)).text=code[i]
		"k2":
			var enabled: bool = state.get("br_k2_owned",true)
			visible=enabled
			for i in range(3):led("K2LED%d"%(i+1),enabled and state.get("br_k2_ready",false) and not state.get("br_k2_spent",false))
			$K2Button.position.z=.014
			$StateLabel.text="需重新维护" if state.get("br_k2_spent",false) else "可用次数 1" if state.get("br_k2_ready",false) else "未校准"

func led(path_: String, enabled: bool) -> void:
	var mesh := get_node(NodePath(path_)) as MeshInstance3D
	# Each LED owns a material; changing one cannot alter the other circuits.
	var m := mesh.material_override as StandardMaterial3D
	m.emission_enabled=enabled
	m.emission_energy_multiplier=.48 if enabled else 0.0
	m.albedo_color=Color("9fc8b9") if enabled else Color("344a46")

func play_action(action: StringName) -> void:
	if motion and motion.is_valid():motion.kill()
	motion=create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	match action:
		&"drawer":motion.tween_property($DrawerSlide,"position:z",.535,.28)
		&"module":
			$ModuleBurnt.hide();$ModuleInstalled.show();$ModuleInstalled.position.z=.552
			motion.tween_property($ModuleInstalled,"position:z",.452,.35)
			$DrawerSlide/SpareModule.hide()
		&"emergency":
			motion.tween_property($EmergencyRedButton,"position:z",.363,.10)
			motion.tween_property($EmergencyRedButton,"position:z",.369,.18)
		&"vent":
			motion.tween_property($LeftCatchPivot,"rotation:z",deg_to_rad(-35),.18)
			motion.tween_property($GrillePivot/BentEdge,"position:y",-.205,.18)
			motion.tween_property($GrillePivot,"rotation:y",-1.05,.38)
		&"hatch":motion.tween_property($HatchPivot,"rotation:z",deg_to_rad(-78),.8)
		&"box":motion.tween_property($BoxDoorPivot,"rotation:y",deg_to_rad(-105),.30)
		&"k2_press":
			motion.tween_property($K2Button,"position:z",.012,.10)
			motion.tween_property($K2Button,"position:z",.014,.15)
		&"care":
			$CageVisual/Leaf.rotation.y=0.0;$Blanket.show();$Blanket.position.y=.29
			motion.tween_property($CageVisual/Leaf,"rotation:y",deg_to_rad(105),.55)
			motion.tween_property($Blanket,"position:y",.10,.8)
	motion.tween_callback(func():visual_action_completed.emit(action))

func _process(delta: float) -> void:
	if kind=="recovery":
		breathing_clock+=delta
		$BreathingChest.position.y=.91+sin(breathing_clock*TAU/3.5)*.008
