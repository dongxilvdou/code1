extends SceneTree
const Catalog=preload("res://ui/notes_catalog.gd")
func _initialize() -> void:call_deferred("bake")
func bake() -> void:
 var ids=Catalog.all_ids()+["feeder_marks"]
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--note="):ids=[arg.trim_prefix("--note=")]
 for id in ids:
  var viewport=SubViewport.new();viewport.size=Vector2i(900,1200) if id!="feeder_marks" else Vector2i(600,300)
  viewport.transparent_bg=false;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
  var sheet: Control=load("res://ui/feeder_marks.gd" if id=="feeder_marks" else "res://ui/note_sheet.gd").new()
  if id!="feeder_marks":sheet.note_id=id
  sheet.size=Vector2(viewport.size);viewport.add_child(sheet)
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  var error=viewport.get_texture().get_image().save_png("res://assets/notes/%s.png"%id)
  if error!=OK:push_error("Cannot bake note "+id);quit(1);return
  viewport.queue_free();await process_frame
 print("V1_NOTE_ASSETS_BAKED ",ids.size())
 quit()
