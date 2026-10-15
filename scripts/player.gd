extends CharacterBody3D
signal meowed
signal stepped
signal interacted
signal pause_requested
signal photo_requested
var active := false
var look_sensitivity := .0021
var pitch := -.02
var yaw := 0.0
var stride := 0.0
var step_clock := 0.0
var meow_cooldown := 0.0
var jumping_timer := 0.0
var head: Node3D
var camera: Camera3D
var model: Node3D
var collider: CollisionShape3D
var paws: Array[Node3D] = []
@export_range(.5,1.2,.05) var cat_scale := .8
var spawn := Vector3(-3.4,.02,4.2)
const MAX_STEP := .19

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = .24
	floor_max_angle = deg_to_rad(48)
	floor_constant_speed = true
	position = spawn
	collider = get_node("CollisionShape3D")
	model = get_node("Calico")
	head = get_node("CatEyes")
	camera = get_node("CatEyes/FirstPersonCamera")
	camera.near = .025
	camera.far = 80
	camera.fov = 73
	camera.cull_mask = 1|4|8|16
	camera.current = true
	model.scale = Vector3.ONE*cat_scale
	(collider.shape as CapsuleShape3D).radius = .12*cat_scale
	(collider.shape as CapsuleShape3D).height = .36*cat_scale
	collider.position = Vector3(0,.18,-.13)*cat_scale
	head.position = Vector3(0,.28,-.22)*cat_scale
	for side in [-1,1]:
		var paw := MeshInstance3D.new()
		paw.mesh = load("res://assets/models/paw_%s.res" % ("left" if side<0 else "right"))
		paw.position = Vector3(0,-.25,-.10)*cat_scale
		paw.scale = Vector3.ONE*cat_scale
		paw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		paw.layers = 8
		paw.visible = false
		camera.add_child(paw)
		paws.append(paw)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			pause_requested.emit()
		if active and event.keycode == KEY_V:photo_requested.emit()
	if not active:return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x*look_sensitivity
		pitch = clampf(pitch-event.relative.y*look_sensitivity,-1.30,1.26)
		rotation.y = yaw
		head.rotation.x = pitch
	if event.is_action_pressed("interact"):interacted.emit()
	if event.is_action_pressed("meow") and meow_cooldown <= 0:
		meow_cooldown = .9
		meowed.emit()

func _physics_process(delta: float) -> void:
	meow_cooldown -= delta
	if not active:
		velocity.x = move_toward(velocity.x,0,delta*8)
		velocity.z = move_toward(velocity.z,0,delta*8)
		return
	var low := Input.is_action_pressed("crouch")
	var desired_height := (.24 if low else .36)*cat_scale
	(collider.shape as CapsuleShape3D).height = desired_height
	collider.position.y = desired_height*.5
	if not is_on_floor(): velocity.y -= 12.0*delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = 5.25
		jumping_timer = .6
	var axis := Input.get_vector("move_left","move_right","move_forward","move_back")
	var direction := (transform.basis*Vector3(axis.x,0,axis.y)).normalized()
	var move_speed := .65 if low else 2.7 if Input.is_action_pressed("sprint") else 1.38
	var acceleration := 7.5 if is_on_floor() else 3.8
	velocity.x = move_toward(velocity.x,direction.x*move_speed,delta*acceleration)
	velocity.z = move_toward(velocity.z,direction.z*move_speed,delta*acceleration)
	var step_motion := Vector3(velocity.x,0,velocity.z)*delta
	var stepped_up := _try_step_up(step_motion)
	var horizontal := Vector2(velocity.x,velocity.z)
	if stepped_up:
		velocity.x = 0
		velocity.z = 0
		velocity.y = -.1
	move_and_slide()
	if stepped_up:
		velocity.x = horizontal.x
		velocity.z = horizontal.y
	if position.y < -2: reset_position()
	var flat_speed := Vector2(velocity.x,velocity.z).length()
	model.speed = flat_speed/cat_scale
	model.crouching = low
	model.airborne = not is_on_floor()
	stride += flat_speed*delta*9
	var bob := sin(stride*2)*.008*cat_scale if is_on_floor() else 0.0
	head.position.y = lerpf(head.position.y,(.19 if low else .28)*cat_scale+bob,delta*12)
	camera.rotation.z = lerpf(camera.rotation.z,-axis.x*.012,delta*8)
	camera.fov = lerpf(camera.fov,77.0 if move_speed>2 and flat_speed>1.5 else 73.0,delta*3)
	jumping_timer -= delta
	for i in range(paws.size()):
		paws[i].visible = jumping_timer>0.08 or pitch<-.95
		paws[i].position.y = (-.25+sin(stride+i*PI)*.012)*cat_scale
	if is_on_floor() and flat_speed>.25:
		step_clock += delta*flat_speed
		if step_clock>.40:
			step_clock = 0
			stepped.emit()

func _try_step_up(motion: Vector3) -> bool:
	# Sweep the actual capsule over a small riser. Tall walls and ceilings still block it.
	if not is_on_floor() or velocity.y>0 or motion.length_squared()<.000001:return false
	if not test_move(global_transform,motion):return false
	if test_move(global_transform,Vector3.UP*MAX_STEP):return false
	var raised := global_transform
	raised.origin += Vector3.UP*MAX_STEP
	# Look slightly past the rounded capsule nose so the downward sweep finds
	# the tread, rather than rejecting its almost-vertical edge as a tall wall.
	var radius := (collider.shape as CapsuleShape3D).radius
	var probe_motion := motion.normalized()*maxf(motion.length(),radius*.55)
	if test_move(raised,probe_motion):return false
	raised.origin += probe_motion
	var hit := KinematicCollision3D.new()
	if not test_move(raised,Vector3.DOWN*(MAX_STEP+.04),hit):return false
	if hit.get_normal().dot(Vector3.UP)<cos(floor_max_angle):return false
	var landed := raised.origin+hit.get_travel()
	var rise := landed.y-global_position.y
	if rise<.008 or rise>MAX_STEP+.005:return false
	global_position = landed
	return true

func reset_position() -> void:
	position = spawn
	velocity = Vector3.ZERO
	yaw = 0
	pitch = -.02
	rotation.y = 0
	head.rotation.x = pitch

func set_control(value: bool) -> void:
	active = value
	if not value:model.speed = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE
