extends Node3D
## Small continuous jet, falling highlights, droplets and expanding impact rings.
var elapsed := 0.0
var rings: Array[MeshInstance3D] = []
var droplets: CPUParticles3D
var jet: MeshInstance3D
var impact := Vector3.ZERO

func configure(nozzle: Vector3, surface_y: float) -> void:
	position = nozzle
	impact = Vector3(0,surface_y-nozzle.y,0)
	var height := maxf(.04,-impact.y)
	jet = MeshInstance3D.new()
	jet.name = "FlowingWater"
	var tube := CylinderMesh.new()
	tube.top_radius = .007
	tube.bottom_radius = .010
	tube.height = height
	tube.radial_segments = 16
	tube.rings = 12
	jet.mesh = tube
	jet.position.y = -height*.5
	var material := ShaderMaterial.new()
	material.shader = preload("res://day2/water_stream.gdshader")
	jet.material_override = material
	jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(jet)
	var water := StandardMaterial3D.new()
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.albedo_color = Color(.65,.85,.93,.48)
	water.roughness = .12
	water.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(3):
		var ring := MeshInstance3D.new()
		var shape := TorusMesh.new()
		shape.inner_radius = .037
		shape.outer_radius = .040
		shape.rings = 24
		shape.ring_segments = 8
		ring.mesh = shape
		ring.material_override = water.duplicate()
		ring.position = impact+Vector3.UP*.003
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		rings.append(ring)
	droplets = CPUParticles3D.new()
	droplets.name = "SplashDroplets"
	droplets.amount = 28
	droplets.lifetime = .28
	droplets.position = impact+Vector3.UP*.006
	droplets.direction = Vector3.UP
	droplets.spread = 55
	droplets.gravity = Vector3(0,-2.8,0)
	droplets.initial_velocity_min = .22
	droplets.initial_velocity_max = .45
	droplets.scale_amount_min = .7
	droplets.scale_amount_max = 1.3
	var drop := SphereMesh.new()
	drop.radius = .0025
	drop.height = .007
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = water
	droplets.mesh = drop
	droplets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(droplets)
	set_running(false)

func set_running(enabled: bool) -> void:
	visible = enabled
	set_process(enabled)
	if is_instance_valid(droplets):droplets.emitting = enabled
	if not enabled:elapsed = 0

func _process(delta: float) -> void:
	elapsed += delta
	for i in range(rings.size()):
		var phase := fposmod(elapsed*1.8+i/3.0,1)
		rings[i].scale = Vector3.ONE*lerpf(.20,1.6,phase)
		(rings[i].material_override as StandardMaterial3D).albedo_color.a = (1-phase)*.45
