extends "res://tools/playtest_map_stairs.gd"
const Catalog=preload("res://ui/notes_catalog.gd")
const Balance=preload("res://day1/balance_model.gd")
var checks:=0
var day
var second
func verify(value: bool,message: String) -> void:
 checks+=1;expect(value,message)
 if not value:printerr("V1_CHECK_FAILED ",message)
func photo_(label_: String) -> void:
 if not "--v1-capture" in OS.get_cmdline_user_args():return
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://.godot/v1_"+label_+".png")
func dismiss() -> void:
 if not day.reader.mode.is_empty():day.reader.cancel()
 day.dialog="";day.hud.overlay.hide();second.puzzle.close();game.cinematic_active=false;game.player.set_control(true)
func check_day_one_coaster() -> void:
 var chapter=game.get_node("ActTwo")
 var book: Node3D=chapter.world.items.clues
 await ticks(2)
 verify(not book.is_visible_in_tree() and not chapter.clues_unlocked(),"Day-one book appeared after reading the daily note")
 verify(not day.World.Props.interactable(book,1),"Day-one physical book can intercept interaction")
 for flag_ in ["walk","run","open_living","stool","table"]:day.mark(flag_)
 day.restore_world()
 game.player.position=day.world.items.table.global_position+Vector3(0,.49,0)
 game.player.velocity=Vector3.ZERO
 await ticks(10)
 game.player.camera.look_at(day.world.items.cup.global_position+Vector3(0,.05,0))
 verify(day.nearest_item()=="cup","Real camera cannot select the tutorial cup")
 await key(KEY_E)
 verify(day.value("holding")==1,"E cannot pick up the tutorial cup")
 game.player.camera.look_at(day.world.items.tray.global_position+Vector3(0,.05,0))
 verify(day.persistent_target()!="clues" and day.nearest_item()=="tray","Clue album intercepts the coaster target")
 verify(day.target_hint().contains("杯垫"),"Coaster interaction prompt is missing")
 await key(KEY_E)
 verify(day.flag("cup_moved") and day.value("holding")==0 and day.reader.mode.is_empty(),"E did not place the cup on the coaster")
 verify(day.world.items.cup.global_position.distance_to(day.world.items.tray.global_position+Vector3(0,.015,0))<.001,"Placed cup is not on the coaster")
 day.restore_world();await ticks(2)
 verify(not book.is_visible_in_tree(),"Restoring day-one state brings the physical book back")
func check_feeder_reader() -> void:
 second.open_puzzle("code")
 second.puzzle.code.text="24"
 var browse: Button
 for button_ in second.puzzle.detail.find_children("*","Button",true,false):
  if button_.text=="翻看已收集的纸片":browse=button_
 verify(browse!=null,"Feeder has no button for collected papers")
 if browse==null:return
 for cycle in range(3):
  browse.grab_focus();await key(KEY_SPACE)
  verify(day.reader.mode=="album" and second.puzzle.mode=="code","Feeder paper button cannot open the nested album")
  day.reader.show_entry("paper%d"%cycle)
  await key(KEY_ESCAPE)
  verify(day.reader.mode.is_empty() and second.puzzle.mode=="code" and second.puzzle.shell.visible,"First Esc must close only the papers and return to feeder")
  verify(game.cinematic_active and not game.player.active and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Returning to feeder failed to keep puzzle control")
  verify(second.puzzle.code.text=="24","Reading papers lost the partial feeder password")
  verify(root.gui_get_focus_owner()==browse,"Returning from papers did not restore the feeder button focus")
  if not day.reader.mode.is_empty() or second.puzzle.mode!="code":
   await key(KEY_ESCAPE)
   verify(game.player.active and not game.cinematic_active,"Second Esc leaves the game frozen after closing papers")
   dismiss();second.open_puzzle("code");return
 await key(KEY_ESCAPE)
 verify(day.reader.mode.is_empty() and second.puzzle.mode.is_empty() and not second.puzzle.shell.visible,"Second Esc did not leave the feeder")
 print("FEEDER_RETURN_STATE ",JSON.stringify({"display":DisplayServer.get_name(),"active_play":day.active_play(),"control":game.player.active,"cinematic":game.cinematic_active,"mouse_mode":Input.mouse_mode,"pause":game.ui.pause_panel.visible}))
 verify(day.active_play() and not game.ui.pause_panel.visible,"Exiting feeder did not restore game control")
 # Only a real window can capture the mouse; the GUI run checks this too.
 if DisplayServer.get_name()!="headless":verify(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Exiting feeder did not restore mouse capture")
 var before: Vector3=game.player.global_position
 Input.action_press("move_forward");await ticks(12);Input.action_release("move_forward")
 verify(game.player.global_position.distance_to(before)>.04,"Player cannot physically move after reading papers and exiting feeder")
 await key(KEY_C);await key(KEY_ESCAPE)
 verify(day.active_play() and day.reader.mode.is_empty(),"Standalone album cannot close after returning from feeder")
 second.open_puzzle("code")
func check_ruler_mouse_direction() -> void:
 var ruler=day.ruler_interaction
 var camera: Camera3D=game.player.camera
 for motion in [Vector2(12,0),Vector2(-12,0),Vector2(0,-12),Vector2(0,12)]:
  var before: Vector2=camera.unproject_position(ruler.tip)
  var button_=InputEventMouseButton.new();button_.button_index=MOUSE_BUTTON_LEFT;button_.pressed=true;button_.position=root.get_visible_rect().size*.5;button_.button_mask=MOUSE_BUTTON_MASK_LEFT
  root.push_input(button_,true)
  var event=InputEventMouseMotion.new();event.relative=motion;event.position=button_.position;event.button_mask=MOUSE_BUTTON_MASK_LEFT
  root.push_input(event,true);await ticks(6)
  button_.pressed=false;button_.button_mask=0;root.push_input(button_,true)
  var displacement: Vector2=camera.unproject_position(ruler.tip)-before
  verify(displacement.dot(motion)>1,"Ruler moves opposite to mouse on screen: "+str(motion)+" -> "+str(displacement))
  if motion.x!=0:verify(absf(displacement.y)<absf(displacement.x)*.1,"Horizontal ruler drag should follow screen left/right: "+str(displacement))
 print("RULER_MOUSE_DIRECTIONS verified left/right/up/down through viewport input")
func run_tests() -> void:
 game=load("res://scenes/main.tscn").instantiate();game.get_node("QuestSystem").save_enabled=false;root.add_child(game);current_scene=game
 game.start_game();await ticks(8)
 day=game.get_node("DayOne");second=game.get_node("DayTwo");dismiss()
 for id in Catalog.all_ids():verify(Catalog.texture(id)!=null,"Missing physical note asset "+id)
 day.show_dialog("note");await photo_("daily_note")
 var normal_size=day.reader.image.custom_minimum_size
 day.reader.zoomed=true;day.reader.layout()
 verify(day.reader.image.custom_minimum_size.y>normal_size.y,"Image zoom does not enlarge the paper")
 day.reader.zoomed=false;day.reader.layout()
 verify(day.reader.mode=="daily" and not day.Notes.read(day),"Opening a note acknowledged it")
 await key(KEY_ESCAPE)
 verify(not day.Notes.read(day) and game.player.active and not game.cinematic_active,"Cancelling note trapped control or changed progress")
 day.show_dialog("note");await key(KEY_E)
 verify(day.Notes.read(day) and game.player.active,"Reading physical daily note cannot start tasks")
 await check_day_one_coaster()
 day.start_balance();day.set_process(false)
 await key(KEY_E);verify(day.balancing and not day.tv_stable,"Old E shortcut completed the new balance task")
 await key(KEY_ESCAPE)
 var before: float=day.balance_model.progress
 day.balance_model.advance(2,1)
 verify(day.balance_model.paused and day.balance_model.progress==before,"Pause failed to freeze balance")
 await photo_("balance_paused");await key(KEY_ESCAPE)
 for i in range(1400):
  var axis=clampf(-day.balance_model.position*4-day.balance_model.velocity*2.5,-1,1)
  day.balance_model.advance(1.0/120.0,axis)
  if day.balance_model.status!=0:break
 verify(day.balance_model.status==1 and day.balance_model.safe_half<.5,"Continuous steering cannot solve shrinking balance")
 day.hud.update_balance(day.balance_model);await photo_("balance")
 day.finish_balance(true);day.set_process(true)
 verify(day.tv_stable and game.player.active and is_zero_approx(game.player.camera.rotation.z),"Balance completion did not restore control")
 var failed=Balance.new();failed.position=.95;failed.progress=.01;failed.advance(.3,0)
 verify(failed.status==-1,"Balance never fails when progress runs out")
 day.mark("light_off");day.restore_world()
 for key_ in Catalog.PAPER_KEYS:
  day.perform_interaction("paper_"+key_)
  verify(day.reader.mode=="sheet","Collected paper cannot be inspected")
  await key(KEY_E)
 verify(day.paper_count()==4 and day.flag("papers_done"),"Four physical papers do not complete the collection")
 await key(KEY_C);await photo_("clue_album")
 verify(day.reader.mode=="album" and Catalog.collected(day).size()>=5,"Early clue album does not retain all papers")
 verify(not game.get_node("ActTwo").world.items.clues.is_visible_in_tree(),"Collecting paper brings the day-one book back")
 day.reader.show_entry("paper2");verify(day.reader.image.texture!=null,"Clue album page has no actual image")
 await key(KEY_ESCAPE)
 second.open_puzzle("code");await photo_("feeder")
 await check_feeder_reader()
 second.puzzle.code.text="412";second.puzzle.submit_code()
 verify(not day.flag("d2_unlocked") and second.puzzle.mode=="code","Machine physical order was accepted instead of clue order")
 second.puzzle.code.text="241";second.puzzle.submit_code()
 verify(day.flag("d2_unlocked") and day.flag("feeder_cat_trace"),"Valid paper deduction cannot unlock feeder")
 day.mark("d2_cat_fed");day.mark("d2_dog_fed");second.begin_day();dismiss()
 await ticks(2)
 verify(game.get_node("ActTwo").world.items.clues.is_visible_in_tree(),"Physical clue album is missing on day two")
 for key_ in ["d2_note","daily_note_ack_2","d2_washed","ruler_found"]:day.manager.set_flag(StringName(key_),true)
 day.manager.set_value(&"holding",2);day.manager.set_value(&"ruler_vertical",0);day.restore_world()
 verify(not day.ruler_interaction.begin(),"Horizontal ruler fits through the narrow gap")
 day.manager.set_value(&"ruler_vertical",1);day.update_held_visual()
 var ruler=day.ruler_interaction
 verify(ruler.begin(),"Vertical ruler cannot begin physical interaction")
 await ticks(3);await photo_("ruler")
 await check_ruler_mouse_direction()
 await key(KEY_ESCAPE);var frozen: Vector3=ruler.body.global_position;await ticks(8)
 verify(ruler.paused and ruler.body.global_position.distance_to(frozen)<.001,"Paused rigid yarn kept moving")
 await key(KEY_ESCAPE)
 # Checkpoint a genuinely moved ball, then resume from its saved physical position.
 ruler.dragging=true
 for point in [Vector3(-5.30,.11,1.97),Vector3(-5.30,.11,2.15),Vector3(-4.98,.11,2.15)]:
  ruler.goal=point
  for frame in range(140):
   await physics_frame
   if ruler.tip.distance_to(point)<.002:break
 verify(ruler.body.global_position.x> -5.13 and not day.flag("yarn_freed"),"Partial contact did not move the ball before completion")
 ruler.stop()
 var checkpoint_x=day.value("ruler_ball_x")
 verify(checkpoint_x> -5130 and checkpoint_x< -4640,"Leaving lost the partial ball position")
 verify(ruler.begin() and absf(ruler.body.global_position.x-checkpoint_x/1000.0)<.002,"Re-entering did not restore the physical ball position")
 # Move the actual ruler tip around the ball and pull it out; no quest flag shortcuts.
 ruler.dragging=true
 for point in [Vector3(-5.30,.11,1.97),Vector3(-5.30,.11,2.15),Vector3(-4.48,.11,2.15)]:
  if not ruler.running:break
  ruler.goal=point
  for frame in range(125):
   await physics_frame
   if not ruler.running or ruler.tip.distance_to(point)<.002:break
 if ruler.running:print("RULER_TRIAL ",ruler.body.global_position," tip=",ruler.tip," contacts=",ruler.contact_count)
 await photo_("ruler_finished")
 verify(ruler.contact_count>0,"Ruler did not physically contact the ball")
 verify(day.flag("yarn_freed"),"Contacting and pulling the rigid yarn did not free it")
 if ruler.running:ruler.stop()
 # Continue the remaining regression checks even if the physics trial reports a failure.
 if not day.flag("yarn_freed"):day.mark("yarn_freed")
 day.perform_interaction("yarn");day.perform_interaction("nest");dismiss()
 verify(day.flag("yarn_home"),"Freed ball cannot be carried back to the bed")
 second.set_value("d2_holding",5);second.set_value("dish_stage",0);second.set_flag("dog_portion",false);second.restore_world()
 second.interact_item("tap")
 var rinse=second.rinse
 verify(rinse.running and second.val("dish_stage")==1,"Putting the plate in the sink does not start active washing")
 rinse.set_physics_process(false)
 verify(second.world.items.dog_bowl.global_position.y>.89,"Plate is clipped into the basin wall during dragging")
 rinse.offset=Vector2(.15,.15);rinse.update_plate();rinse.advance(2)
 verify(rinse.progress.all(func(v):return is_zero_approx(v)),"Water cleans residue that is not under its stream")
 rinse.offset=-rinse.OFFSETS[0];rinse.update_plate();rinse.advance(2)
 verify(rinse.progress[0]>.45 and rinse.progress[0]<.6 and is_zero_approx(rinse.progress[1]),"Residues do not have independent contact-based progress")
 await photo_("rinse")
 rinse.toggle_pause();var saved: Array=rinse.progress.duplicate();rinse.advance(3)
 verify(rinse.progress==saved and not second.world.stream.visible,"Paused rinse still cleans or runs water")
 rinse.stop();verify(second.val("rinse_0")>=490 and second.val("dish_stage")==1,"Leaving lost partial wash progress")
 verify(rinse.begin() and rinse.progress[0]>.45,"Re-entering does not restore partial washing")
 rinse.set_physics_process(false)
 for i in range(3):
  rinse.offset=-rinse.OFFSETS[i];rinse.update_plate();rinse.advance(rinse.DURATIONS[i]+.1)
 verify(second.val("dish_stage")==8 and not rinse.running and not second.world.stream.visible,"Cleaning all three residues did not complete the rinse")
 verify(second.world.items.dog_bowl.get_node("OldWashMarks").visible and not day.flag("d2_dishes_done"),"Clean plate omitted old marks or skipped returning it")
 second.interact_item("dog_bowl");second.place_dog_bowl()
 verify(day.flag("d2_dishes_done") and second.puzzle.description.text.contains("清水"),"Returning plate omitted completion or the scent dialogue")
 verify(second.world.items.dog.get_meta("actor").care_time>0,"Dog did not react to the returned clean plate")
 dismiss()
 game._seed_demo_day(10);dismiss()
 var fourth=game.get_node("ActFour")
 verify(fourth.DESTINATIONS==["一楼过道","二楼过道","二楼主卧","一楼厨房"] and fourth.ROUTES.size()==3,"Mouse chase contains extra rooms or runs")
 for old in range(7):
  fourth.set_value("mouse_chase_version",0);fourth.set_value("mouse_stage",old);fourth.migrate_mouse_chase()
  verify(fourth.val("mouse_stage")==[0,0,0,1,1,2,3][old],"Legacy mouse chase stage migrated incorrectly")
 fourth.set_value("mouse_stage",0);fourth.restore()
 for stage in range(3):
  fourth.chase_mouse();fourth.advance_mouse(100)
  verify(fourth.chase_path.is_empty() and fourth.val("mouse_stage")==stage+1,"Shortened mouse route cannot finish")
 fourth.chase_mouse()
 verify(fourth.flag("a10_catch") and fourth.panel.mode=="mouse_warning" and not fourth.flag("a10_eat"),"Short chase broke the existing investigation sequence")
 fourth.open_mouse_note()
 for dismiss_key in [KEY_ESCAPE,KEY_E]:
  day.reader.open_sheet("escape");await key(dismiss_key)
  verify(day.reader.mode.is_empty() and fourth.panel.mode=="mouse_note" and not fourth.flag("a10_note"),"Enlarged note input closed or advanced the underlying day-ten dialogue")
  verify(game.cinematic_active and not game.player.active,"Closing an enlarged note resumed gameplay behind the dialogue")
 await key(KEY_ESCAPE)
 verify(day.active_play() and fourth.panel.mode.is_empty(),"Exiting day-ten note after magnifying it left control locked")
 verify(not day.manager.autosave,"Tests must not write a player save")
 print("V1_PLAYTEST ",JSON.stringify({"checks":checks,"failures":failures}))
 game.stop_audio();game.queue_free();await ticks(3);quit(0 if failures.is_empty() else 1)
