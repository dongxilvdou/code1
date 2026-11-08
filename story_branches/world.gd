extends Node3D
const Props = preload("res://furniture_pack/quest_props/props.gd")
var chapter: Node
var box: Node3D
var chest: Node3D
var mouse: Node3D
var desk: Node3D
var cameo_played := false
var last_day := 0
var guide_motion: Tween
var documents: Dictionary={}

func build(owner_: Node) -> void:
	chapter=owner_
	desk=Props.furniture(chapter.game,"work_desk","ComputerRoom")
	box=preload("res://story_branches/scenes/maintenance_box.tscn").instantiate();add_child(box)
	box.global_transform=desk.global_transform*Transform3D(Basis.IDENTITY,Vector3(.44,.44,.20))
	chest=preload("res://story_branches/k2_attachment.gd").new();chapter.game.get_node("Miso").add_child(chest)
	mouse=preload("res://furniture_pack/quest_props/house_mouse.glb").instantiate();mouse.name="BranchSavedMouse";add_child(mouse);mouse.scale=Vector3.ONE*.48
	for body in mouse.find_children("*","CollisionObject3D",true,false):body.collision_layer=0;body.collision_mask=0
	box.hide();mouse.hide()
	for definition in [["d1","D1CareSheet","nightstand","MasterBedroom",Vector3(0,.44,.25)],["d3","D3TransferFolder","desk","Study",Vector3(-.20,.787,.28)],["d4","D4ReportDraft","work_desk","Workshop",Vector3(-.42,.786,.34)]]:
		var anchor=Props.furniture(chapter.game,definition[2],definition[3])
		assert(is_instance_valid(anchor),"Missing document furniture: "+definition[3])
		var document=preload("res://story_branches/scenes/clue_document.tscn").instantiate()
		document.document_id=definition[0];document.name=definition[1];add_child(document)
		document.global_transform=anchor.global_transform*Transform3D(Basis.IDENTITY,definition[4])
		if definition[0]=="d1":document.rotation.x=-.16
		document.set_meta("bound_furniture",anchor);documents[definition[0]]=document;document.hide()

func restore(facts: Dictionary) -> void:
	var number: int=int(facts.get("current_day",1))
	if number!=last_day:cameo_played=false;last_day=number
	box.visible=number>=6 and number<=10
	for document in documents.values():document.visible=number>=7 and int(facts.get("br_phase",0))==0
	box.apply_visual_state(facts)
	chest.apply_visual_state(facts)
	# The same world actor is reused, never a second caught mouse at the camera.
	mouse.visible=int(facts.get("br_mouse",0))==2 and number in [10,11] and int(facts.get("br_phase",0))==0
	if number==10:mouse.position=Vector3(1.15,.025,-4.12)
	elif number==11 and not cameo_played:
		if not mouse.visible:return
		mouse.position=Vector3(1.85,-2.665,-2.55)
		if facts.get("a11_enter",false):
			cameo_played=true
			var destination: Vector3=chapter.game.get_node("Ending").world.items.vent.global_position+Vector3(.29,-.235,.08)
			if int(facts.get("br_route",0))==2:
				guide_motion=create_tween();guide_motion.tween_property(mouse,"global_position",destination,1.4)
			else:mouse.global_position=destination

func reset_session() -> void:
	if guide_motion and guide_motion.is_valid():guide_motion.kill()
	last_day=0;cameo_played=false;mouse.hide()

func nearest_document() -> String:
	if not chapter.day.active_play():return ""
	var player=chapter.game.player
	var best:="";var score:=3.0
	for id in documents:
		var document: Node3D=documents[id]
		if not document.is_visible_in_tree():continue
		var pos: Vector3=document.aim.global_position;var delta: Vector3=pos-player.camera.global_position
		if delta.length()>1.65 or (-player.camera.global_basis.z).dot(delta.normalized())<.65:continue
		var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.camera.global_position,pos,1,[player.get_rid()]))
		if not hit.is_empty() and hit.position.distance_to(pos)>.10:continue
		var weight: float=delta.length()*.1+1-(-player.camera.global_basis.z).dot(delta.normalized())
		if weight<score:score=weight;best=id
	return best

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
