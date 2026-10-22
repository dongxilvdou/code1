extends Node3D
## Reusable metre-scale observation cage. E uses the house's existing door UI.
@export var door_title := "观察笼门"
@export var starts_open := false
@export var specimen_number := 31
@export_range(65,120,1) var open_angle := 105.0
var is_open := false
var moving := false
var blocked := false
var locked := false
var target_angle := 0.0
@onready var leaf: AnimatableBody3D = $Leaf
@onready var collider: CollisionShape3D = $Leaf/CollisionShape3D

func _ready() -> void:
	add_to_group("lab_cages")
	$Leaf/Sign.text = "OBSERVATION\nFELIS / %03d"%specimen_number
	leaf.sync_to_physics = false
	set_open(starts_open,true)

func interaction_position() -> Vector3:
	# The lower latch is reachable at cat eye height, from inside and outside.
	return to_global(Vector3(.0,.32,-.80)) if is_open else leaf.to_global(Vector3(.517,.275,0))

func set_open(value: bool, immediate: bool = false) -> void:
	is_open = value
	target_angle = deg_to_rad(open_angle) if value else 0.0
	blocked = false
	if immediate:
		leaf.rotation.y = target_angle
		moving = false
	else:moving = true

func toggle() -> void:
	if not locked:set_open(not is_open)

func _physics_process(delta: float) -> void:
	if not moving:return
	var angle := move_toward(leaf.rotation.y,target_angle,delta*1.65)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = global_transform*Transform3D(Basis(Vector3.UP,angle),leaf.position)*collider.transform
	query.collision_mask = 2
	query.margin = .004
	# Pause the swing while the cat occupies it. No crushing/teleporting the player.
	blocked = not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
	if blocked:return
	leaf.rotation.y = angle
	moving = not is_equal_approx(angle,target_angle)
