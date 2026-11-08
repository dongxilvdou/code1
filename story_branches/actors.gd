extends RefCounted
const Art=preload("res://furniture_pack/quest_props/refined_props.gd")

static func layers(node: Node, mask_: int) -> void:
	for mesh in node.find_children("*","GeometryInstance3D",true,false):mesh.layers=mask_
	for body in node.find_children("*","CollisionObject3D",true,false):body.collision_layer=0;body.collision_mask=0

static func person(parent: Node3D, title: String, mask_: int) -> Node3D:
	var actor=preload("res://story_branches/human_actor.gd").new();actor.name="Investigator" if title=="调查" else "Researcher" if title=="研究员" else "Director";parent.add_child(actor);actor.build(title)
	layers(actor,mask_);return actor

static func hands(parent: Node3D, mask_: int) -> Node3D:
	var node:=Node3D.new();node.name="ResearcherHands";parent.add_child(node)
	var skin:=Art.material("branch_hand",Color("b9a18a"),.9)
	var sleeve:=Art.material("branch_sleeve",Color("c5d0ca"),.9)
	for side in [-1,1]:
		Art.rod(node,"Sleeve",Vector3(side*.20,-.32,-.12),Vector3(side*.15,-.22,-.36),.043,sleeve)
		Art.ellipsoid(node,"Hand",Vector3(side*.14,-.20,-.41),Vector3(.070,.035,.13),skin)
		for finger in range(4):
			var x: float=side*.14-.024+finger*.016
			Art.rod(node,"Finger",Vector3(x,-.20,-.452),Vector3(x,-.205,-.50+absf(finger-1.5)*.006),.007,skin)
		Art.rod(node,"Thumb",Vector3(side*.17,-.20,-.40),Vector3(side*.19,-.202,-.447),.009,skin)
	layers(node,mask_);return node
