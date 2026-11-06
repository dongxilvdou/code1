extends Node3D
## Unit-scale Miso attachment. Receives ownership facts; never consumes a charge.
var device: Node3D
var straps: Node3D

func _ready() -> void:
	name="K2ChestAnchor"
	device=preload("res://story_branches/scenes/k2_device.tscn").instantiate();add_child(device)
	position=Vector3(0,.18,-.27);rotation.y=PI
	straps=Node3D.new();straps.name="Straps";add_child(straps)
	var m:=StandardMaterial3D.new();m.albedo_color=Color("535c51");m.roughness=.95
	for side in [-1,1]:
		var points: Array[Vector3]=[Vector3(side*.025,.018,0),Vector3(side*.035,.048,-.022),Vector3(side*.047,.070,-.047)]
		for i in range(2):
			var direction:=points[i+1]-points[i]
			var mesh:=BoxMesh.new();mesh.size=Vector3(.008,direction.length(),.002)
			var n:=MeshInstance3D.new();n.mesh=mesh;n.material_override=m;n.position=points[i].lerp(points[i+1],.5);n.quaternion=Quaternion(Vector3.UP,direction.normalized());straps.add_child(n)
	device.get_node("StateLabel").hide()
	for n in find_children("*","GeometryInstance3D",true,false):n.layers=2
	hide()

func apply_visual_state(state: Dictionary) -> void:
	visible=state.get("br_k2_owned",false)
	device.apply_visual_state(state)

func play_action(action: StringName) -> void:device.play_action(action)
