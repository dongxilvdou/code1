extends Node3D
@export var document_id := "d1"
var aim: Marker3D

func _ready() -> void:
	var art=preload("res://furniture_pack/quest_props/refined_props.gd")
	var paper=art.material("evidence_paper",Color("eee2c9"),.95)
	var ink=art.material("evidence_ink",Color("5e6863"),.9)
	var cover=art.material("evidence_folder",Color("8a9c91") if document_id=="d3" else Color("b49c79"),.95)
	if document_id!="d1":
		var folder:=BoxMesh.new();folder.size=Vector3(.31,.009,.23);art.mesh_node(self,"Folder",folder,cover,Vector3.ZERO)
	for i in range(3):
		var sheet:=BoxMesh.new();sheet.size=Vector3(.27,.0015,.20)
		art.mesh_node(self,"Paper",sheet,paper,Vector3(i*.002,.006+i*.0016,i*.001))
	for i in range(6):
		var line:=BoxMesh.new();line.size=Vector3(.18 if i<4 else .10,.0006,.0015)
		art.mesh_node(self,"PrintedLine",line,ink,Vector3(-.012,.012,.005+i*.018))
	var title:=Label3D.new();title.text="C-031 / 照护交接" if document_id=="d1" else "住宅分站 / 原始操作" if document_id=="d3" else "举报材料 / 留存稿"
	title.font_size=34;title.pixel_size=.00021;title.position=Vector3(0,.013,-.068);title.rotation.x=-PI/2;title.modulate=Color("354b49");add_child(title)
	aim=Marker3D.new();aim.name="DocumentAim";aim.position=Vector3(0,.014,.09);add_child(aim)
	set_meta("document_id",document_id)
