extends "res://scripts/villa_door.gd"
## The original day-eleven relay puzzle now belongs to the real lab doorway.
## Separate group keeps tutorial/chase routines from unlocking this door.
var lock_state_initialized := false
var was_unlocked := false
var touch_cooldown := 0.0

func _ready() -> void:
	add_to_group("laboratory_lock_doors")
	leaf = $Leaf
	collider = $Leaf/CollisionShape3D
	leaf.sync_to_physics = false
	locked = true
	set_open(false,true)

func apply_lock_state(unlocked: bool, enabled: bool) -> void:
	visible = enabled
	leaf.collision_layer = 1 if enabled else 0
	locked = not unlocked
	# Repeated quest refreshes must not reopen a door the player just closed.
	if not lock_state_initialized or was_unlocked!=unlocked:
		set_open(unlocked,not lock_state_initialized or not enabled)
	was_unlocked = unlocked
	lock_state_initialized = true

func beyond_door(p: Vector3) -> bool:
	return p.y< -2.35 and to_local(p).z<-.22 and Rect2(-5.35,-5.25,8.62,6.4).has_point(Vector2(p.x,p.z))

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	touch_cooldown=maxf(0,touch_cooldown-delta)
	if not locked or touch_cooldown>0:return
	var game:=get_tree().current_scene
	if game==null or not game.started or game.cinematic_active:return
	var day:=game.get_node("DayOne")
	if day.value("current_day",1)>=11:return
	var player: CharacterBody3D=game.player
	if not player.active:return
	for i in range(player.get_slide_collision_count()):
		if player.get_slide_collision(i).get_collider()==leaf:
			game.ui.toast("门纹丝不动",3)
			touch_cooldown=3
			return
