extends "res://tools/playtest_map_stairs.gd"
const Rules=preload("res://act2/puzzle_rules_v2.gd")
const YarnRules=preload("res://act2/yarn_rules.gd")
const Catalog=preload("res://ui/notes_catalog.gd")
var day
var second
var chapter
var third
var checks=0
func verify(ok: bool,message: String) -> void:
 checks+=1;expect(ok,message)
 if not ok:printerr("V2_CHECK_FAILED ",message)
func dismiss() -> void:
 if not day.reader.mode.is_empty():day.reader.cancel()
 day.dialog="";day.hud.overlay.hide();second.puzzle.close();chapter.puzzle.close();third.panel.close()
 if third.computer.shell.visible:third.computer.close_computer()
 game.cinematic_active=false;game.player.set_control(true)
func prepare_day(number: int) -> void:
 dismiss();game._seed_demo_day(number)
 day.manager.set_flag(StringName(day.Notes.FLAGS[number]),true);day.manager.set_flag(StringName("daily_note_ack_%d"%number),true)
 if number==5:day.manager.set_flag(&"a5_letter",true)
 if number<=5:chapter.begin_day(number)
 else:third.begin_day(number)
 dismiss();await ticks(3)
func capture(label_: String) -> void:
 if not "--v2-capture" in OS.get_cmdline_user_args():return
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://.godot/v2_"+label_+".png")
func click_control(control: Control) -> void:
 await process_frame
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=control.get_global_rect().get_center();root.push_input(event,true)
 await process_frame;event.pressed=false;root.push_input(event,true);await process_frame
func click_named(parent: Node,label_: String) -> void:
 var found: BaseButton
 for button_ in parent.find_children("*","BaseButton",true,false):
  if button_.text==label_ or str(button_.name)==label_:found=button_;break
 verify(found!=null,"Missing interactive button "+label_)
 if found:
  if found is LinkButton or str(found.name)=="BrowserIcon":await click_control(found)
  else:found.grab_focus();await key(KEY_SPACE)
func click_cell(i: int,columns: int,rows: int) -> void:
 var board=chapter.puzzle.board
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
 event.position=board.get_global_rect().position+Vector2(i%columns+.5,floori(float(i)/columns)+.5)*board.size/Vector2(columns,rows)
 root.push_input(event,true);await process_frame;event.pressed=false;root.push_input(event,true);await process_frame
func face_item(id: String,position_: Vector3) -> void:
 game.player.position=position_;game.player.velocity=Vector3.ZERO;await ticks(8)
 game.player.camera.look_at(chapter.target_position(id))
 if chapter.nearest_item()!=id:
  var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(game.player.camera.global_position,chapter.target_position(id),1))
  print("V2_AIM ",id," selected=",chapter.nearest_item()," active=",day.active_play()," current=",chapter.today()," visible=",chapter.world.items[id].is_visible_in_tree()," note=",day.Notes.read(day)," hit=",hit.get("collider")," hitpos=",hit.get("position")," cine=",game.cinematic_active," control=",game.player.active," pause=",game.ui.pause_panel.visible)

 verify(chapter.nearest_item()==id,"Cannot select physical target "+id)
func run_tests() -> void:
 create_timer(95).timeout.connect(func():printerr("V2 timeout");quit(2))
 game=load("res://scenes/main.tscn").instantiate();game.get_node("QuestSystem").save_enabled=false;root.add_child(game);current_scene=game
 game.start_game();await ticks(8)
 day=game.get_node("DayOne");second=game.get_node("DayTwo");chapter=game.get_node("ActTwo");third=game.get_node("ActThree");dismiss()
 verify(day.manager.validation_errors.is_empty(),"Quest catalog does not validate")
 await prepare_day(3)
 for id in ["book0","book1","book2"]:
  var point: Vector3=chapter.world.items[id].global_position
  await face_item(id,point+Vector3(0,.02,.48));await key(KEY_E)
  verify(chapter.val("a_holding")==int(id.right(1))+1,"E cannot carry "+id)
  if id=="book1":verify(chapter.flag("photo_dropped") and chapter.world.items.photo.visible,"Moving the diary did not drop a visible photograph")
  await face_item("shelf0",chapter.world.shelves[0]+Vector3(0,.035,0));await key(KEY_E)
  verify(chapter.flag(id) and chapter.val("a_holding")==0,"First shelf did not receive "+id)
 verify(chapter.puzzle.mode=="books" and not chapter.flag("a3_books"),"Three books skipped sorting or did not open it")
 if chapter.puzzle.mode!="books":quit(1);return
 await capture("books")
 verify(chapter.puzzle.book_order.size()==7 and chapter.world.extra_shelf_books.size()==4,"Sorting did not include seven real books")
 for slot in range(Rules.BOOK_COUNT):
  var target=chapter.puzzle.book_order.find(Rules.BOOK_GOAL[slot])
  if target!=slot:await click_cell(slot,7,1);await click_cell(target,7,1)
 await click_named(chapter.puzzle.detail,"检查书序")
 verify(chapter.flag("a3_books"),"Visible height sorting cannot complete")
 dismiss();chapter.interact_item("cabinet");verify(not chapter.flag("cabinet_open"),"Plumbing unlocked before collecting the photograph")
 await face_item("photo",chapter.world.items.photo.global_position+Vector3(0,.02,.48));await key(KEY_E)
 verify(chapter.flag("a3_photo") and "photo" in Catalog.collected(day),"Dropped photograph was not collected into the album")
 await capture("dropped_photo");await key(KEY_ESCAPE)
 for i in range(9):chapter.set_value("pipe_%d"%i,3) # Legacy 3x3 rotations must not corrupt the new board.
 chapter.interact_item("cabinet");chapter.interact_item("pipes");await ticks(2)
 verify(chapter.puzzle.rotations.size()==20 and Rules.FIXED.size()==4,"Pipe board is not 4 by 5 with four fixed pipes")
 var fixed=chapter.puzzle.rotations[1];await click_cell(1,5,4)
 verify(chapter.puzzle.rotations[1]==fixed,"Fixed pipe can rotate")
 await click_cell(0,5,4);var saved=chapter.puzzle.rotations.duplicate();await key(KEY_ESCAPE);chapter.interact_item("pipes")
 verify(chapter.puzzle.rotations==saved,"Leaving lost pipe rotations")
 await click_named(chapter.puzzle.detail,"重新开始");verify(chapter.puzzle.rotations==Rules.initial_pipes(),"Pipe restart cannot restore initial state")
 verify(not Rules.water(chapter.puzzle.rotations).passed,"Initial pipe puzzle is already solved")
 await capture("pipes")
 for i in range(20):
  if i in Rules.FIXED:continue
  for turn in range(4):
   if chapter.puzzle.rotations[i]==0:break
   await click_cell(i,5,4)
 var water=Rules.water(chapter.puzzle.rotations)
 verify(water.passed and water.wet.size()==20 and water.leaks.is_empty(),"Designed pipe route cannot carry water without leaks")
 var leak=chapter.puzzle.rotations.duplicate();leak[13]=1
 verify(not Rules.water(leak).passed and not Rules.water(leak).leaks.is_empty(),"Leaking water route is accepted")
 await click_named(chapter.puzzle.detail,"检查水路");verify(chapter.flag("a3_pipes"),"Valid GUI pipe route does not complete")
 await prepare_day(4);chapter.open_panel("slide")
 var empty=chapter.puzzle.tiles.find(0)
 for i in range(9):
  if absi(i%3-empty%3)+absi(i/3-empty/3)==1:chapter.puzzle.move_tile(i);break
 var slide_saved=chapter.puzzle.tiles.duplicate();await key(KEY_ESCAPE);chapter.open_panel("slide")
 verify(chapter.puzzle.tiles==slide_saved,"Atomic board autosave lost fridge sliding progress")
 await key(KEY_ESCAPE);chapter.set_flag("toy_requested");chapter.interact_item("yarn");await ticks(2)
 await check_dense_yarn()
 await prepare_day(5);chapter.set_flag("a5_medicine");chapter.solved("voice");await capture("name_scene")
 await prepare_day(7)
 verify(third.world.emergency_light.light_energy>0 and third.world.emergency_material.emission_enabled,"Backup lamp is dark in blackout")
 for source in third.world.light_sources:verify(is_zero_approx(source[0].light_energy),"An ordinary room light remains on during blackout")
 var memes=game.get_node("HouseMemes")
 verify(not memes.start("tv") and not memes.entries.tv.playing,"TV easter egg can play without mains power")
 verify(is_instance_valid(third.world.source_book),"Same-shelf change removed the computer-room weight book")
 third.restore_power();dismiss()
 verify(is_zero_approx(third.world.emergency_light.light_energy),"Backup lamp remains on after mains is restored")
 verify(memes.start("tv"),"TV easter egg did not recover after mains power");memes.finish("tv")
 third.set_flag("a7_computer_power");third.restore();third.interact_item("computer")
 var computer=third.computer;var apps=computer.apps
 computer.password.text="C031";computer.password.grab_focus();await key(KEY_ENTER)
 verify(third.flag("a7_login") and not third.flag("a7_investigate") and not third.day_complete(),"New day seven skips investigation after login")
 await capture("desktop")
 await click_named(computer.desktop,"BrowserIcon");verify(apps.app=="browser" and third.flag("a7_read_site"),"Browser icon cannot open the laboratory website")
 await capture("website");await key(KEY_ESCAPE)
 verify(computer.shell.visible and apps.app.is_empty() and not game.player.active,"Esc should close app before computer")
 await click_named(computer.desktop,"RecycleIcon")
 verify(apps.file_tree!=null,"Recycle bin is not a real multi-column file list")
 await capture("recycle")
 apps.file_tree.grab_focus();await key(KEY_DOWN);await key(KEY_ENTER)
 verify(third.flag("a7_read_photo") and Catalog.texture("lab_photo")!=null,"Deleted laboratory photograph is missing")
 await capture("lab_photo");await click_named(apps.body,"放大照片");await key(KEY_ESCAPE)
 verify(not apps.zoomed and apps.page=="photo","Esc should restore zoom before closing the photograph")
 await key(KEY_ESCAPE);verify(apps.app=="recycle" and apps.page.is_empty(),"Esc closed recycle app before photo detail")
 await key(KEY_ESCAPE);await key(KEY_ESCAPE)
 verify(day.active_play() and not computer.shell.visible and not game.ui.pause_panel.visible,"Closing photo/app/computer left gameplay locked")
 third.interact_item("computer");await click_named(computer.desktop,"ChatIcon");await click_named(apps.body,"X主任  ·  一个月前")
 verify(third.flag("a7_read_chat"),"Chat record is not discoverable")
 await capture("chat");await click_named(apps.body,"xxxxxxxxxxxxx")
 verify(apps.app=="browser" and apps.browser_page=="news" and apps.history.size()==1,"Chat link did not navigate to browser and retain chat")
 await capture("news");await click_named(apps.body,preload("res://act3/investigation_data.gd").NEWS[0].title)
 verify(third.evidence_count()==4 and third.flag("a7_investigate") and third.day_complete(),"Four evidence pages do not complete day seven")
 for id in ["lab_photo","lab_site","lab_chat","lab_news"]:verify(id in Catalog.collected(day),"Evidence is missing from clue album: "+id)
 var snapshot=day.manager.make_save_data();day.manager.restore_save_data(snapshot)
 verify(third.evidence_count()==4,"Reload lost computer investigation evidence")
 await key(KEY_ESCAPE);verify(apps.app=="browser" and apps.page.is_empty(),"Article back did not return to news")
 await key(KEY_ESCAPE);verify(apps.app=="chat" and apps.page=="conversation","Browser back lost the previous chat conversation")
 await key(KEY_ESCAPE);await key(KEY_ESCAPE);await key(KEY_ESCAPE)
 verify(day.active_play() and not computer.shell.visible,"Repeated browser/chat Esc left player locked")
 await key(KEY_C);day.reader.show_entry("lab_photo")
 verify(day.reader.mode=="album" and day.reader.image.texture==Catalog.texture("lab_photo"),"Computer evidence cannot be revisited in the clue album")
 await capture("evidence_album");await key(KEY_ESCAPE)
 verify(day.active_play(),"Closing the computer-evidence album left gameplay locked")
 for key_ in ["photo","site","chat","news"]:third.set_flag("a7_read_"+key_,false)
 third.set_flag("a7_investigate",false);third.set_value("investigation_v2_version",0);third.restore()
 verify(third.flag("a7_investigate") and third.evidence_count()==0 and third.day_complete(),"Legacy completed login is forced to repeat the new investigation")
 verify(not day.manager.autosave,"Validation can overwrite the player save")
 print("V2_PLAYTEST ",JSON.stringify({"checks":checks,"failures":failures}))
 game.stop_audio();game.queue_free();await ticks(3);quit(0 if failures.is_empty() else 1)

func yarn_mouse(button_: MouseButton,pressed_: bool,point: Vector2) -> void:
 var event=InputEventMouseButton.new();event.button_index=button_;event.pressed=pressed_
 event.position=chapter.puzzle.board.global_position+point;root.push_input(event,true);await process_frame
func yarn_click(id: int) -> void:
 var cells: Array=YarnRules.THREADS[id].cells
 var point: Vector2=chapter.puzzle.board.screen_cell(cells[cells.size()/2])
 await yarn_mouse(MOUSE_BUTTON_LEFT,true,point);await yarn_mouse(MOUSE_BUTTON_LEFT,false,point)
func check_dense_yarn() -> void:
 var rules=YarnRules.new();var test_removed={};var occupied={};var valid=true;var bent=0;var longest=0
 for thread in YarnRules.THREADS:
  var last_direction=-999;var turns=0
  for j in range(thread.cells.size()):
   var cell: int=thread.cells[j]
   valid=valid and cell>=0 and cell<YarnRules.WIDTH*YarnRules.HEIGHT and not occupied.has(cell)
   occupied[cell]=true
   if j>0:
    var before: int=thread.cells[j-1]
    valid=valid and absi(cell%YarnRules.WIDTH-before%YarnRules.WIDTH)+absi(cell/YarnRules.WIDTH-before/YarnRules.WIDTH)==1
    var direction=cell-before
    if j>1 and direction!=last_direction:turns+=1
    last_direction=direction
  var head: int=thread.cells[-1];var before: int=thread.cells[-2]
  valid=valid and Vector2i(head%YarnRules.WIDTH-before%YarnRules.WIDTH,head/YarnRules.WIDTH-before/YarnRules.WIDTH)==YarnRules.DIRECTIONS[thread.direction]
  if turns>0:bent+=1
  longest=maxi(longest,thread.cells.size())
 verify(valid,"Dense yarn has overlapping, disconnected, or misdirected line geometry")
 verify(YarnRules.THREADS.size()>=75 and occupied.size()>=740 and bent>=55 and longest>=45,"Yarn is below the reference density and bent-path complexity")
 var opening=rules.legal_moves({});verify(opening.size()<=3 and opening.size()>0,"Opening does not require tracing blocked paths")
 var layers=0
 while test_removed.size()<YarnRules.THREADS.size():
  var moves=rules.legal_moves(test_removed)
  if moves.is_empty():break
  for id in moves:test_removed[id]=true
  layers+=1
 verify(test_removed.size()==YarnRules.THREADS.size() and layers>=30,"Yarn is unsolvable or lacks deep dependency layers")
 # Alternative legal orders must also finish: removal can only clear head rays.
 for trial in range(6):
  test_removed.clear();var count=0
  while test_removed.size()<YarnRules.THREADS.size():
   var moves=rules.legal_moves(test_removed)
   if moves.is_empty():break
   test_removed[moves[(count*7+trial*11)%moves.size()]]=true;count+=1
  verify(count==YarnRules.THREADS.size(),"Legal removal order can deadlock: "+str(trial))
 var panel=chapter.puzzle.yarn_puzzle;var canvas=panel.board
 verify(chapter.puzzle.mode=="yarn" and panel.visible and not chapter.puzzle.paper_panel.visible,"Dense yarn panel cannot open")
 if chapter.puzzle.mode!="yarn":return
 verify(canvas.paths.size()==YarnRules.THREADS.size(),"Visible polylines do not match puzzle rules")
 verify(root.get_visible_rect().encloses(panel.get_global_rect()) and canvas.size.y<root.get_visible_rect().size.y,"Dense yarn panel or controls overflow the window")
 verify(panel.history.is_empty(),"Fresh dense yarn board is not fresh")
 # Test blocked movement by clicking a non-head segment.
 var blocked_id=-1
 for i in range(YarnRules.THREADS.size()):
  if rules.blocker(i,{})>=0:blocked_id=i;break
 await yarn_click(blocked_id)
 verify(panel.history.is_empty() and panel.status.text.contains("挡住"),"Blocked bent thread crosses another thread")
 await capture("yarn_blocked")
 canvas.clear_effects();await capture("yarn")
 var free_id: int=opening[0]
 await yarn_click(free_id)
 verify(panel.removed.has(free_id) and panel.history.size()==1,"Clicking the middle of a clear folded thread cannot pull it")
 await click_named(panel,"撤销上一步");verify(panel.history.is_empty() and not panel.removed.has(free_id),"Dense yarn undo did not put back the full path")
 # Wheel and drag use the real GUI event route and coordinate transform.
 var anchor: Vector2=canvas.size*.5
 await yarn_mouse(MOUSE_BUTTON_WHEEL_UP,true,anchor)
 verify(canvas.zoom>1.0,"Mouse wheel does not zoom the yarn board")
 await yarn_mouse(MOUSE_BUTTON_RIGHT,true,anchor)
 var motion=InputEventMouseMotion.new();motion.position=canvas.global_position+anchor+Vector2(0,-60);motion.relative=Vector2(0,-60);motion.button_mask=MOUSE_BUTTON_MASK_RIGHT
 root.push_input(motion,true);await process_frame
 await yarn_mouse(MOUSE_BUTTON_RIGHT,false,anchor+Vector2(0,-60))
 verify(canvas.pan.y<0 and not canvas.dragging,"Right drag cannot move or release the yarn canvas")
 await capture("yarn_zoom")
 # All visible path cells must pick the same thread after zoom and pan.
 var hit_count=0;var hit_ok=true
 for id in range(YarnRules.THREADS.size()):
  for cell in YarnRules.THREADS[id].cells:
   var point: Vector2=canvas.screen_cell(cell)
   if Rect2(Vector2.ZERO,canvas.size).grow(-12).has_point(point):
    hit_count+=1;hit_ok=hit_ok and canvas.pick(point)==id
 verify(hit_count>200 and hit_ok,"Zoom/pan hit testing disagrees with drawn line geometry")
 var zoom_free=-1
 for id in opening:
  var cells: Array=YarnRules.THREADS[id].cells
  if Rect2(Vector2.ZERO,canvas.size).grow(-12).has_point(canvas.screen_cell(cells[cells.size()/2])):zoom_free=id;break
 if zoom_free>=0:
  await yarn_click(zoom_free);verify(panel.removed.has(zoom_free),"Actual zoomed mouse click misses the thread");await click_named(panel,"撤销上一步")
 await click_named(panel,"查看全图");verify(is_equal_approx(canvas.zoom,1.0) and canvas.pan==Vector2.ZERO,"Fit view does not restore the complete maze")
 await yarn_click(free_id);await key(KEY_ESCAPE)
 verify(day.active_play() and not panel.visible and not game.ui.pause_panel.visible,"Esc leaves dense yarn gameplay locked")
 chapter.interact_item("yarn");await ticks(3)
 verify(panel.history.size()==1 and panel.removed.has(free_id),"Reopening dense yarn loses partial progress")
 await click_named(panel,"重新开始");verify(panel.history.is_empty() and canvas.animations.is_empty(),"Reset leaves removed paths or ghost animations")
 # Legacy 5x5 partial progress must never be read as bits of this 88-line board.
 chapter.set_value("yarn_v3_version",0);chapter.set_value("yarn_v2_version",2);chapter.set_value("yarn_v2_steps",4);chapter.set_value("yarn_v2_mask",255)
 await key(KEY_ESCAPE);chapter.interact_item("yarn");await ticks(3)
 verify(panel.history.is_empty() and panel.removed.is_empty() and panel.status.text.contains("保留"),"Old nine-line save corrupts the dense board")
 # Invalid history cannot inject progress or force the bone to appear.
 await yarn_click(free_id)
 chapter.day.manager.values["yarn_v3_history_1"]=free_id;chapter.set_value("yarn_v3_steps",2)
 await key(KEY_ESCAPE);chapter.interact_item("yarn");await ticks(3)
 verify(panel.history.size()==1 and chapter.val("yarn_v3_steps")==1 and not chapter.flag("yarn_solved"),"Corrupt saved history is accepted instead of repaired")
 await click_named(panel,"重新开始")
 # Finish through real mouse clicks using a different legal order from the construction.
 var restored=false;var stalled=false
 for step in range(YarnRules.THREADS.size()):
  var moves=rules.legal_moves(panel.removed)
  if moves.is_empty():stalled=true;break
  var id: int=moves[-1]
  await yarn_click(id)
  if panel.history.size()!=step+1:stalled=true;break
  if step==72:
   var before=panel.history.duplicate();var data=day.manager.make_save_data()
   var serialized: Dictionary=JSON.parse_string(JSON.stringify(data))
   verify(day.manager.restore_save_data(serialized),"Dense yarn save cannot round-trip through JSON")
   await key(KEY_ESCAPE);chapter.interact_item("yarn");await ticks(3)
   verify(panel.history==before and panel.removed.keys().any(func(n):return n>=64),"Save loses removals above the 64-bit boundary")
   restored=true
 verify(not stalled and restored and panel.history.size()==YarnRules.THREADS.size(),"Full 88-thread solution cannot be played with actual mouse input")
 verify(chapter.flag("yarn_solved") and chapter.world.items.bone.visible and not panel.visible,"Dense yarn completion does not reveal the toy bone")
 await key(KEY_ESCAPE)
 chapter.restore();verify(chapter.flag("yarn_solved") and not chapter.world.items.yarn.visible,"Already-completed yarn progress is reset by restoring the world")
 print("DENSE_YARN_LAYOUT ",JSON.stringify({"threads":YarnRules.THREADS.size(),"bent":bent,"cells":occupied.size(),"longest":longest,"layers":layers,"opening":opening.size()}))
