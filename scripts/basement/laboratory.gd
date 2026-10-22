extends Node3D
## A local camera environment: the upstairs lighting/environment is never edited.
var source_environment: Environment
var basement_environment: Environment
var camera_overrides: Dictionary = {}

func _ready() -> void:
	add_to_group("basement_laboratory")
	var world_env := get_tree().get_first_node_in_group("laboratory_world_environment")
	if world_env == null:
		var candidates := get_tree().root.find_children("VillaEnvironment","WorldEnvironment",true,false)
		if not candidates.is_empty():world_env = candidates[0]
	if world_env:
		source_environment = world_env.environment
		basement_environment = source_environment.duplicate()
	else:basement_environment = Environment.new()
	basement_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	basement_environment.ambient_light_color = Color(.44,.53,.53)
	basement_environment.ambient_light_energy = .14
	basement_environment.ambient_light_sky_contribution = 0
	basement_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	basement_environment.fog_enabled = false
	basement_environment.volumetric_fog_enabled = false
	basement_environment.glow_enabled = false

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):return
	var p := camera.global_position
	var underground := p.y<-.38 and Rect2(-5.6,-5.5,11.65,7.2).has_point(Vector2(p.x,p.z))
	if underground:
		if not camera_overrides.has(camera):camera_overrides[camera] = camera.environment
		camera.environment = basement_environment
	else:_restore(camera)

func _restore(camera: Camera3D) -> void:
	if camera_overrides.has(camera):
		camera.environment = camera_overrides[camera]
		camera_overrides.erase(camera)

func _exit_tree() -> void:
	for camera in camera_overrides:
		if is_instance_valid(camera):camera.environment = camera_overrides[camera]
