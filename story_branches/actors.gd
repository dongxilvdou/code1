extends RefCounted
const Art=preload("res://furniture_pack/quest_props/refined_props.gd")

static func layers(node: Node, mask_: int) -> void:
	for mesh in node.find_children("*","GeometryInstance3D",true,false):mesh.layers=mask_
	for body in node.find_children("*","CollisionObject3D",true,false):body.collision_layer=0;body.collision_mask=0

static func person(parent: Node3D, title: String, mask_: int) -> Node3D:
	var actor:=Node3D.new();actor.name="Investigator" if title=="调查" else "Director";parent.add_child(actor)
	var cloth:=Art.material("branch_uniform_"+title,Color("c5d0ca") if title=="研究员" else Color("405b67"),.9)
	var skin:=Art.material("branch_skin",Color("b9a18a"),.9)
	var mesh:=BoxMesh.new();mesh.size=Vector3(.38,.62,.22);Art.mesh_node(actor,"Uniform",mesh,cloth,Vector3(0,.98,0))
	Art.ellipsoid(actor,"Head",Vector3(0,1.48,0),Vector3(.19,.24,.19),skin)
	for side in [-1,1]:
		Art.rod(actor,"Leg",Vector3(side*.10,.70,0),Vector3(side*.12,.08,.02),.065,cloth)
		Art.rod(actor,"Sleeve",Vector3(side*.22,1.24,0),Vector3(side*.30,.76,.07),.055,cloth)
	var label:=Label3D.new();label.text=title;label.font_size=30;label.pixel_size=.002;label.position=Vector3(0,1.10,.119);actor.add_child(label)
	var torch:=SpotLight3D.new();torch.position=Vector3(.29,.8,.08);torch.rotation_degrees.x=-35;torch.light_cull_mask=mask_;torch.light_energy=.55;torch.spot_range=4;torch.spot_angle=35;actor.add_child(torch)
	layers(actor,mask_);return actor

static func hands(parent: Node3D, mask_: int) -> Node3D:
	var node:=Node3D.new();node.name="ResearcherHands";parent.add_child(node)
	var skin:=Art.material("branch_hand",Color("b9a18a"),.9)
	var sleeve:=Art.material("branch_sleeve",Color("c5d0ca"),.9)
	for side in [-1,1]:
		Art.rod(node,"Sleeve",Vector3(side*.20,-.32,-.12),Vector3(side*.15,-.22,-.36),.043,sleeve)
		Art.ellipsoid(node,"Hand",Vector3(side*.14,-.20,-.41),Vector3(.070,.035,.13),skin)
	layers(node,mask_);return node
