@tool
extends Node3D
## Per-instance colour variants; shared library materials are never mutated.
@export var room_style := "Living"
static var variants: Dictionary = {}
static var active_instances := 0
const STYLES := {
	"Living":{"cream":"d4d2c8","linen":"b9b6a8","sage_fabric":"526e74","rust":"99563f"},
	"Dining":{"sage_fabric":"626c5c","linen":"c7c4b9"},
	"Kitchen":{"sage":"4f6d64","ivory":"d9ded8","stone":"c8cbc2"},
	"MasterBedroom":{"linen":"bdccd0","cream":"d9e0dc","sage_fabric":"708890","rust":"536e82"},
	"BedroomA":{"linen":"c6bfce","cream":"dfdce5","sage_fabric":"7d7892","rust":"b69e67"},
	"BedroomB":{"linen":"c7b29b","cream":"e3dbce","sage_fabric":"ae765a","rust":"73574f"},
	"GuestBedroom":{"linen":"bcc2a9","cream":"daddd0","sage_fabric":"738466","rust":"a18353"},
	"Study":{"linen":"b9b8a6","cream":"d6d4c7","sage_fabric":"47615b","rust":"9d6944","oak":"876c50"},
	"Reading":{"sage_fabric":"b39b69","linen":"ccc4ae"},
	"Bathroom":{"linen":"b2c7cd","sage":"6f888a"},
	"Laundry":{"linen":"b8cacc"},
}

func _enter_tree() -> void:
	active_instances += 1

func _exit_tree() -> void:
	active_instances -= 1
	if active_instances==0:variants.clear()

func _ready() -> void:
	var palette: Dictionary = STYLES.get(room_style,{})
	for node in find_children("*","MeshInstance3D",true,false):
		var original: Material = node.material_override
		if original==null or not palette.has(original.resource_name):continue
		var key: String = room_style+":"+original.resource_name
		if not variants.has(key):
			var mat: Material = original.duplicate()
			var color := Color(palette[original.resource_name])
			if mat is ShaderMaterial:mat.set_shader_parameter("tint",color)
			elif mat is StandardMaterial3D:mat.albedo_color = color
			variants[key] = mat
		node.material_override = variants[key]
