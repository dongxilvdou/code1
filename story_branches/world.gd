extends Node3D
const Props = preload("res://furniture_pack/quest_props/props.gd")
var chapter: Node
var box: Node3D
var chest: Node3D
var mouse: Node3D
var desk: Node3D
var cameo_played := false
var last_day := 0

func build(owner_: Node) -> void:
	chapter=owner_
	desk=Props.furniture(chapter.game,"work_desk","ComputerRoom")
	box=preload("res://story_branches/scenes/maintenance_box.tscn").instantiate();add_child(box)
	box.global_transform=desk.global_transform*Transform3D(Basis.IDENTITY,Vector3(.44,.44,.20))
	chest=preload("res://story_branches/k2_attachment.gd").new();chapter.game.get_node("Miso").add_child(chest)
	mouse=preload("res://furniture_pack/quest_props/house_mouse.glb").instantiate();mouse.name="BranchSavedMouse";add_child(mouse);mouse.scale=Vector3.ONE*.48
	for body in mouse.find_children("*","CollisionObject3D",true,false):body.collision_layer=0;body.collision_mask=0
	box.hide();mouse.hide()

func restore(facts: Dictionary) -> void:
	var number: int=int(facts.get("current_day",1))
	if number!=last_day:cameo_played=false;last_day=number
	box.visible=number>=6 and number<=10
	box.apply_visual_state(facts)
	chest.apply_visual_state(facts)
	# The same world actor is reused, never a second caught mouse at the camera.
	mouse.visible=int(facts.get("br_mouse",0))==2 and number in [10,11] and int(facts.get("br_phase",0))==0
	if number==10:mouse.position=Vector3(1.15,.025,-4.12)
	elif number==11 and not cameo_played:mouse.position=Vector3(3.18,-2.665,-2.55)
	if number==11 and mouse.visible and not cameo_played and chapter.day.active_play() and chapter.game.player.global_position.distance_to(mouse.global_position)<2.6:
		cameo_played=true
		var motion:=create_tween();motion.tween_property(mouse,"position",Vector3(3.40,-2.665,-2.72),.6);motion.tween_property(mouse,"position",Vector3(3.62,-2.665,-2.66),.6)

func nearest_item() -> String:
	if not box.visible or not chapter.day.active_play():return ""
	var player=chapter.game.player
	var pos: Vector3=box.get_node("BoxAim").global_position
	var delta: Vector3=pos-player.camera.global_position
	if delta.length()>1.4 or (-player.camera.global_basis.z).dot(delta.normalized())<.72:return ""
	var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.camera.global_position,pos,1))
	if not hit.is_empty() and hit.position.distance_to(pos)>.16:return ""
	return "maintenance_box"

func _exit_tree() -> void:
	# Miso owns the attachment; its parent frees it with the player.
	# Never enqueue a child of another dying subtree during scene teardown.
	pass
