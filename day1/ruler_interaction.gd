extends Node
## One small rigid sphere is simulated only during this bounded interaction.
const Hint=preload("res://ui/interaction_hint.gd")
var day
var running=false
var paused=false
var dragging=false
var body: RigidBody3D
var rig: Node3D
var ruler: Node3D
var ui
var tip=Vector3(-4.70,.11,2.01)
var goal=Vector3(-4.70,.11,2.01)
var snapshot: Dictionary={}
var pause_velocity=Vector3.ZERO
var contact_count=0
func _ready() -> void:
 ui=Hint.new();add_child(ui);ui.resume_requested.connect(toggle_pause);ui.exit_requested.connect(stop)
 set_physics_process(false)
func begin() -> bool:
 if running or not day.yarn_available() or day.flag("yarn_freed") or day.value("holding")!=2:return false
 if day.value("ruler_vertical")!=1:day.game.ui.toast("尺子横着进不去，先按 R 改成竖叼。",3);return false
 var player=day.player
 snapshot={"control":player.active,"physics":player.is_physics_processing(),"input":player.is_processing_unhandled_input(),"camera":player.camera.transform,"fov":player.camera.fov,"cinematic":day.game.cinematic_active,"mouse":Input.mouse_mode}
 running=true;paused=false;dragging=false;contact_count=0;tip=Vector3(-4.70,.11,2.01);goal=tip
 rig=Node3D.new();rig.name="BoundedYarnPhysics";day.add_child(rig)
 body=RigidBody3D.new();rig.add_child(body);body.name="YarnRigidSphere"
 body.mass=.08;body.gravity_scale=0;body.linear_damp=5;body.angular_damp=3;body.continuous_cd=true
 body.axis_lock_linear_y=true;body.axis_lock_linear_z=true;body.collision_layer=32;body.collision_mask=64
 body.global_position=Vector3(clampf(day.value("ruler_ball_x",-5180)/1000.0,-5.20,-4.60),.10,2.15)
 var collider=CollisionShape3D.new();var sphere=SphereShape3D.new();sphere.radius=.092;collider.shape=sphere;body.add_child(collider)
 var visual=day.world.items.yarn.duplicate();body.add_child(visual);visual.position=Vector3.ZERO;visual.show()
 for child in visual.find_children("*","Label3D",true,false):child.hide()
 day.world.items.yarn.hide()
 # Isolate this small toy from the sofa's coarse furniture collider.
 for wall in [[Vector3(-5.32,.12,2.15),Vector3(.04,.4,.65)],[Vector3(-4.40,.12,2.15),Vector3(.04,.4,.65)],[Vector3(-4.86,.12,1.88),Vector3(1.0,.4,.04)],[Vector3(-4.86,.12,2.42),Vector3(1.0,.4,.04)]]:
  var obstacle=StaticBody3D.new();rig.add_child(obstacle);obstacle.position=wall[0];obstacle.collision_layer=64;obstacle.collision_mask=32
  var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=wall[1];shape.shape=box;obstacle.add_child(shape)
 ruler=day.world.items.ruler.duplicate();rig.add_child(ruler);ruler.show()
 for child in ruler.find_children("*","Label3D",true,false):child.hide()
 if is_instance_valid(day.held_visual):day.held_visual.hide()
 day.game.cinematic_active=true;player.set_control(false);player.velocity=Vector3.ZERO;player.set_physics_process(false);player.set_process_unhandled_input(false)
 player.camera.global_position=Vector3(-4.02,.27,2.25);player.camera.look_at(Vector3(-4.96,.10,2.15));player.camera.fov=60
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 ui.show_hint("沙发底下的毛线球","按住左键拖动尺子：从侧面伸到球后，再向外拨。鼠标上下伸收，左右调整。Esc 暂停。")
 update_visual();set_physics_process(true);return true
func update_visual() -> void:
 var mouth=day.player.camera.global_position+day.player.camera.global_basis*Vector3(-.045,-.07,-.12)
 ruler.global_position=(mouth+tip)*.5
 ruler.look_at(tip,Vector3.UP);ruler.rotate_object_local(Vector3.UP,PI/2)
 ruler.scale=Vector3(maxf(.2,mouth.distance_to(tip)/.46),1,1)
func advance_tip(next: Vector3,delta: float) -> void:
 if not running or paused:return
 var bounded=Vector3(clampf(next.x,-5.35,-4.48),.11,clampf(next.z,1.95,2.35))
 # The narrow gap guides the ball; the tip cannot tunnel through its near surface.
 if dragging and bounded.x>tip.x and tip.x<body.global_position.x and absf(bounded.z-body.global_position.z)<.105:
  bounded.x=minf(bounded.x,body.global_position.x-.110)
 var movement=bounded-tip
 if dragging and (movement.length()>.00001 or goal.distance_to(tip)>.005):
  var closest=Geometry3D.get_closest_point_to_segment(body.global_position,tip,bounded)
  var offset=body.global_position-closest;offset.y=0
  if offset.length()<.128 and offset.length()>.001:
   var direction=offset.normalized()
   var force=clampf((.128-offset.length())*4.0+movement.length()*5.0,.002,.025)
   var budget=maxf(0,.38-body.linear_velocity.dot(direction))*body.mass
   body.sleeping=false
   body.apply_central_impulse(direction*minf(force,budget))
   contact_count+=1
 tip=bounded;update_visual()
func _physics_process(delta: float) -> void:
 if not running or paused:return
 if day.value("current_day")!=2:stop();return
 advance_tip(tip.move_toward(goal,delta*.85),delta)
 body.angular_velocity=Vector3(0,0,-body.linear_velocity.x/.092)
 ui.progress.value=clampf((body.global_position.x+5.18)/.56*100,0,100)
 if body.global_position.x>=-4.64:
  day.mark("yarn_freed");stop();day.game.ui.toast("够到了！毛线球滚出来了，可以叼回猫窝。",4)
func toggle_pause() -> void:
 if not running:return
 paused=not paused;dragging=false;goal=tip
 if paused:pause_velocity=body.linear_velocity;body.freeze=true
 else:body.freeze=false;body.linear_velocity=pause_velocity
 ui.set_paused(paused);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
func stop(persist: bool=true) -> void:
 if not running:return
 running=false;set_physics_process(false)
 if persist and is_instance_valid(body) and day.manager:
  day.manager.values["ruler_ball_x"]=roundi(body.global_position.x*1000)
  day.manager.values["ruler_ball_z"]=roundi(body.global_position.z*1000)
 ui.shell.hide();ui.set_paused(false);paused=false;dragging=false
 var player=day.player
 player.camera.transform=snapshot.camera;player.camera.fov=snapshot.fov
 player.set_physics_process(snapshot.physics);player.set_process_unhandled_input(snapshot.input)
 day.game.cinematic_active=snapshot.cinematic;player.set_control(snapshot.control);Input.mouse_mode=snapshot.mouse
 if is_instance_valid(rig):rig.queue_free()
 day.restore_world()
 if persist and day.manager.autosave:day.manager.save_game()
func _input(event: InputEvent) -> void:
 if not running:return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:toggle_pause()
 elif not paused and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  dragging=event.pressed
  if not dragging:goal=tip
 elif not paused and dragging and event is InputEventMouseMotion:
  goal.x=clampf(goal.x+event.relative.y*.0028,-5.35,-4.48);goal.z=clampf(goal.z+event.relative.x*.0028,1.95,2.35)
 if not paused or event is InputEventKey:get_viewport().set_input_as_handled()
