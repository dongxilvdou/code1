extends Node
const Hint=preload("res://ui/interaction_hint.gd")
const DURATIONS=[4.0,5.0,7.0]
const OFFSETS=[Vector2(-.075,-.035),Vector2(.065,-.035),Vector2(.015,.095)]
var chapter
var running=false
var paused=false
var dragging=false
var progress: Array[float]=[0.0,0.0,0.0]
var offset=Vector2.ZERO
var snapshot: Dictionary={}
var ui
var hint_panel: PanelContainer
var paws: Array[Node3D]=[]
var water_hit=Vector2.ZERO
var base_position=Vector3.ZERO
func _ready() -> void:
 ui=Hint.new();add_child(ui);ui.resume_requested.connect(toggle_pause);ui.exit_requested.connect(stop)
 hint_panel=ui.shell.get_child(0) as PanelContainer
 hint_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 hint_panel.custom_minimum_size.x=620
 hint_panel.minimum_size_changed.connect(layout_hint)
 layout_hint()
 set_physics_process(false)
func layout_hint() -> void:
 hint_panel.position=Vector2(24,24)
 hint_panel.size=Vector2(620,hint_panel.get_combined_minimum_size().y)
func begin() -> bool:
 if running or not chapter.dishes_available() or chapter.val("dish_stage")!=1:return false
 var player=chapter.player
 snapshot={"control":player.active,"physics":player.is_physics_processing(),"input":player.is_processing_unhandled_input(),"camera":player.camera.transform,"fov":player.camera.fov,"cinematic":chapter.game.cinematic_active,"mouse":Input.mouse_mode}
 progress.clear()
 for i in range(3):progress.append(clampf(chapter.val("rinse_%d"%i)/1000.0,0,1))
 offset=Vector2(chapter.val("rinse_x"),chapter.val("rinse_z"))*.001
 var nozzle=chapter.world.stream.global_position
 water_hit=Vector2(nozzle.x,nozzle.z)
 base_position=Vector3(nozzle.x,chapter.world.sink_cabinet.global_position.y+.89,nozzle.z)
 chapter.world.stream.set_surface_height(base_position.y+.070)
 running=true;paused=false;dragging=false
 chapter.game.cinematic_active=true;player.set_control(false);player.velocity=Vector3.ZERO;player.set_physics_process(false);player.set_process_unhandled_input(false)
 player.camera.global_position=base_position+Vector3(.30,.58,.35);player.camera.look_at(base_position+Vector3(0,.055,0));player.camera.fov=60
 for paw in player.paws:
  paws.append(paw);snapshot["paw_"+str(paw.get_instance_id())]=[paw.transform,paw.visible];paw.show()
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 chapter.world.stream.set_running(true)
 ui.show_hint("把盘子洗干净","按住左键拖动盘子，让三块残渣经过水流。盘沿的残渣需要多冲一会儿。Esc 暂停 / 保留进度离开。")
 layout_hint()
 update_plate();set_physics_process(true);return true
func update_plate() -> void:
 var plate=chapter.world.items.dog_bowl
 plate.global_position=base_position+Vector3(offset.x,0,offset.y)
 chapter.world.stains.visible=true
 update_residue_visuals()
 update_meter()

 for i in range(paws.size()):
  var paw=paws[i];paw.position=Vector3(offset.x*.12,-.22+offset.y*.035,-.24)
  paw.rotation=Vector3(deg_to_rad(112),0,offset.x*.35)
func update_residue_visuals() -> void:
 for i in range(3):
  var stain=chapter.world.stains.get_child(i)
  var cleaned=progress[i] if running else clampf(chapter.val("rinse_%d"%i)/1000.0,0,1)
  var remaining=1.0-cleaned
  # Horizontal area, rather than volume, matches the displayed residue percentage.
  var extent=sqrt(remaining)
  stain.visible=remaining>0;stain.scale=Vector3(extent,1.0,extent)
  stain.position=Vector3(OFFSETS[i].x,.073,OFFSETS[i].y)
  for j in range(stain.get_child_count()):
   stain.get_child(j).position=Vector3((j-1)*.012,.0015,sin(j*3.2)*.008)
func update_meter() -> void:
 var cleaned=(progress[0]+progress[1]+progress[2])/3.0
 var percent=100 if progress.all(func(v):return v>=1) else mini(99,floori(cleaned*100))
 ui.progress.value=cleaned*100
 ui.title.text="已洗净 %d%% · 剩余残渣 %d%%"%[percent,100-percent]

func advance(delta: float) -> void:
 if not running or paused:return
 if not chapter.active_day():stop();return
 var plate=chapter.world.items.dog_bowl
 for i in range(3):
  var point=plate.global_position+Vector3(OFFSETS[i].x,.070,OFFSETS[i].y)
  var distance=water_hit.distance_to(Vector2(point.x,point.z))
  if distance<.050 and progress[i]<1:
   progress[i]=minf(1,progress[i]+maxf(0,delta)/DURATIONS[i])
 update_plate()
 if progress.all(func(value):return value>=1):
  checkpoint();chapter.set_value("dish_stage",8);stop()
  chapter.game.ui.toast("洗干净了。E 叼起送回阿嚼旁；F 可观察盘底旧痕迹。",5)
func _physics_process(delta: float) -> void:advance(delta)
func checkpoint() -> void:
 for i in range(3):chapter.day.manager.values["rinse_%d"%i]=roundi(progress[i]*1000)
 chapter.day.manager.values["rinse_x"]=roundi(offset.x*1000);chapter.day.manager.values["rinse_z"]=roundi(offset.y*1000)
func toggle_pause() -> void:
 if not running:return
 paused=not paused;dragging=false;checkpoint();ui.set_paused(paused)
 chapter.world.stream.set_running(not paused)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
func stop(persist: bool=true) -> void:
 if not running:return
 if persist:checkpoint()
 running=false;paused=false;dragging=false;set_physics_process(false)
 chapter.world.stream.set_running(false);chapter.world.stream.set_surface_height(chapter.world.basin_position.y+.072);ui.shell.hide();ui.set_paused(false)
 var player=chapter.player
 player.camera.transform=snapshot.camera;player.camera.fov=snapshot.fov
 for paw in paws:
  if is_instance_valid(paw):
   var before=snapshot["paw_"+str(paw.get_instance_id())];paw.transform=before[0];paw.visible=before[1]
 paws.clear()
 player.set_physics_process(snapshot.physics);player.set_process_unhandled_input(snapshot.input)
 chapter.game.cinematic_active=snapshot.cinematic;player.set_control(snapshot.control);Input.mouse_mode=snapshot.mouse
 chapter.restore_world()
 if persist and chapter.day.manager.autosave:chapter.day.manager.save_game()
func _input(event: InputEvent) -> void:
 if not running:return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:toggle_pause()
 elif not paused and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed
 elif not paused and dragging and event is InputEventMouseMotion:
  offset.x=clampf(offset.x+event.relative.x*.0008,-.15,.15);offset.y=clampf(offset.y+event.relative.y*.0008,-.15,.15)
  update_plate()
 if not paused or event is InputEventKey:get_viewport().set_input_as_handled()
