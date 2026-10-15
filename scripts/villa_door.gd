extends Node3D
@export var door_title := "房门"
@export var leaf_width := .88
@export var open_angle := -100.0
@export var starts_open := false
var is_open := false
var moving := false
var blocked := false
var target_angle := 0.0
var leaf: AnimatableBody3D
var collider: CollisionShape3D

func _ready() -> void:
	add_to_group("villa_doors")
	leaf = $Leaf
	collider = $Leaf/CollisionShape3D
	leaf.sync_to_physics = false
	set_open(starts_open,true)

func interaction_position() -> Vector3:
	# After opening, the clear doorway remains an intuitive target for closing.
	var center := Vector3(leaf_width*.5,.28,0)
	return to_global(center) if is_open else leaf.to_global(center)

func set_open(value: bool, immediate: bool = false) -> void:
	is_open = value
	target_angle = deg_to_rad(open_angle) if value else 0.0
	blocked = false
	if immediate:
		leaf.rotation.y = target_angle
		moving = false
	else:moving = true

func toggle() -> void:
	set_open(not is_open)

func _physics_process(delta: float) -> void:
	if not moving:return
	var next_angle := move_toward(leaf.rotation.y,target_angle,delta*2.2)
	var pose := global_transform*Transform3D(Basis(Vector3.UP,next_angle),Vector3.ZERO)*collider.transform
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = pose
	query.collision_mask = 2
	# Allow a leaf to start opening away from a cat touching the closed panel.
	query.margin = .003
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		blocked = true
		return
	blocked = false
	leaf.rotation.y = next_angle
	moving = not is_equal_approx(next_angle,target_angle)
