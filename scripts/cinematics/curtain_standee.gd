extends Node3D
## Optional living-room discovery. Only its own curtain state is saved.
const CardMesh = preload("res://furniture_pack/meshes/milk_frog_standee.res")
const OPEN_FLAG := "living_curtain_standee_open"
const CLOSED_HINT := "似乎可以拉开，拉开之后会看到什么，谁也说不准哦"
const GAZE_TEXT := "你在凝视深渊的时候，深渊也在凝望你"
var game: Node
var player: CharacterBody3D
var curtain: Node3D
var standee: Node3D
var manager: Node
var panels: Array = []
var rings: Array = []
var opened := false
var animating := false
var open_amount := 0.0
var animation_time := 0.0
var animation_from := 0.0

func setup(game_: Node) -> void:
	game=game_;player=game.get_node("Miso")
	curtain=game.get_node("Apartment/GroundFloor/Furnishings/Living/DecorCurtains_015")
	# Clear the projecting window sill while keeping the card behind the cloth.
	curtain.position+=curtain.basis.z.normalized()*.12
	for label in ["Pleated_linen","Pleated_linen2"]:
		var panel: Node3D=curtain.get_node(label)
		panels.append([panel,panel.transform,-1.0 if label=="Pleated_linen" else 1.0])
	for ring in curtain.get_children():
		if str(ring.name).begins_with("Curtain_ring"):rings.append([ring,ring.transform])
	standee=Node3D.new();standee.name="MilkFrogStandee"
	curtain.add_child(standee)
	# Stand between the existing cloth and wall, with its feet on the room floor.
	standee.position=Vector3(0,.010-curtain.global_position.y,-.075)
	standee.scale.x=1.0/curtain.global_basis.x.length()
	var card:=MeshInstance3D.new();card.name="PrintedCardboard";card.mesh=CardMesh
	standee.add_child(card)
	var body:=StaticBody3D.new();body.name="StandeeBody";body.collision_layer=1;body.collision_mask=2
	standee.add_child(body)
	var card_collision:=CardMesh.create_trimesh_shape();card_collision.backface_collision=true
	var shape:=CollisionShape3D.new();shape.shape=card_collision;body.add_child(shape)
	# A low folded foot and rear brace give the printed cutout a physical support.
	var paper:=StandardMaterial3D.new();paper.albedo_color=Color(.78,.75,.67);paper.roughness=1
	_box("FoldedFoot",Vector3(0,.006,.025),Vector3(.73,.012,.10),paper)
	var brace:=_box("RearBrace",Vector3(0,.25,-.018),Vector3(.09,.50,.010),paper)
	brace.rotation.x=.05
	var brass: Material=load("res://furniture_pack/materials/brass.tres")
	for side in [-1,1]:
		_box("PoleBracket",Vector3(side*1.12,2.37,-.10),Vector3(.018,.024,.20),brass,curtain)
		_box("BracketWallPlate",Vector3(side*1.12,2.37,-.21),Vector3(.05,.10,.014),brass,curtain)
	_apply_open_amount(0)
	set_process(false)
	call_deferred("_connect_progress")

func _box(label_: String, position_: Vector3, size_: Vector3, material_: Material, parent_: Node3D=null) -> MeshInstance3D:
	var part:=MeshInstance3D.new();part.name=label_
	var mesh:=BoxMesh.new();mesh.size=size_;part.mesh=mesh
	part.material_override=material_;part.position=position_
	(standee if parent_==null else parent_).add_child(part)
	return part

func _connect_progress() -> void:
	manager=game.get_node("QuestSystem").manager
	if not is_instance_valid(manager):return
	manager.changed.connect(_sync_progress)
	_sync_progress()

func _sync_progress() -> void:
	var saved_open: bool=manager.flags.get(OPEN_FLAG,false)
	if saved_open==opened:return
	opened=saved_open;animating=false;set_process(false)
	_apply_open_amount(1.0 if opened else 0.0)

func _gameplay_available() -> bool:
	return game.started and player.active and not game.cinematic_active and not game.photo and not game.inspecting and curtain.is_visible_in_tree()

func available() -> bool:
	if not _gameplay_available():return false
	var view:=get_viewport().get_camera_3d()
	if view!=player.camera:return false
	var eye:=curtain.to_local(view.global_position)
	var direction:=curtain.global_basis.inverse()*(-view.global_basis.z)
	if eye.z<=.10 or direction.z>=-.0001:return false
	var distance_: float=(.09-eye.z)/direction.z
	if distance_<=0 or distance_>1.45:return false
	var hit_point:=eye+direction*distance_
	if absf(hit_point.x)>1.16 or hit_point.y<-.12 or hit_point.y>2.30:return false
	var query:=PhysicsRayQueryParameters3D.create(view.global_position,curtain.to_global(hit_point),1,[player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func standee_available() -> bool:
	if not opened or animating or not _gameplay_available():return false
	var view:=get_viewport().get_camera_3d()
	if view!=player.camera or standee.to_local(view.global_position).z<=.01:return false
	var eye:=view.global_position
	var query:=PhysicsRayQueryParameters3D.create(eye,eye-view.global_basis.z*2.1,1,[player.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider")==standee.get_node("StandeeBody")

func target_hint() -> String:
	if standee_available():return "[ E ]  凝视立牌"
	if not available() or animating:return ""
	return "[ E ]  "+("合上窗帘" if opened else CLOSED_HINT)

func try_interact() -> bool:
	if standee_available():
		game.ui.toast(GAZE_TEXT,5.0)
		return true
	if not available():return false
	if animating:return true
	opened=not opened
	animation_from=open_amount;animation_time=0;animating=true
	if is_instance_valid(manager):manager.set_flag(StringName(OPEN_FLAG),opened)
	set_process(true)
	return true

func _apply_open_amount(amount: float) -> void:
	open_amount=amount
	var stretch:=lerpf(2.4,1.0,amount)
	var centre:=lerpf(.576,.91,amount)
	# The source pose places one foot higher. Lift the closed hem to expose both.
	var hem_lift: float=(1.0-amount)*.10
	for entry in panels:
		var original: Transform3D=entry[1]
		var transform_: Transform3D=original
		transform_.basis=Basis.from_scale(Vector3(stretch,1.0-hem_lift/2.28,1))*original.basis
		transform_.origin.x+=entry[2]*(centre-.91*stretch)
		transform_.origin.y+=hem_lift
		entry[0].transform=transform_
	for entry in rings:
		var original: Transform3D=entry[1]
		var transform_: Transform3D=original
		var side:=signf(original.origin.x)
		transform_.origin.x=side*centre+(original.origin.x-side*.91)*stretch
		entry[0].transform=transform_

func _process(delta: float) -> void:
	if not animating or not _gameplay_available():return
	animation_time+=delta
	var t:=smoothstep(0,1,clampf(animation_time/.95,0,1))
	_apply_open_amount(lerpf(animation_from,1.0 if opened else 0.0,t))
	if animation_time>=.95:
		animating=false;set_process(false)
