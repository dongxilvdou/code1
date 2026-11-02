extends "res://tools/playtest_v2.gd"
const Evidence=preload("res://act3/investigation_data.gd")
var baseline: Dictionary
var completions: Array[StringName]=[]

func fixture(extra: Dictionary={},completed: bool=false) -> Dictionary:
 var data=baseline.duplicate(true)
 data.flags.merge(extra,true)
 if completed:data.quests["a7_investigate"]={"status":CalicoQuestManager.State.COMPLETED,"progress":{"a7_investigate":1}}
 return data

func load_progress(data: Dictionary) -> void:
 dismiss()
 verify(day.manager.restore_save_data(data),"Saved investigation fixture cannot load")
 third.restore()
 await ticks(3)

func full_record_flags() -> Dictionary:
 var flags={"a7_power":true,"a7_computer_power":true,"a7_login":true}
 for id in Evidence.KEYS:flags["a7_read_"+id]=true
 return flags

func run_tests() -> void:
 create_timer(45).timeout.connect(func():printerr("INVESTIGATION timeout");quit(2))
 game=load("res://scenes/main.tscn").instantiate()
 game.get_node("QuestSystem").save_enabled=false
 root.add_child(game);current_scene=game;game.start_game();await ticks(8)
 day=game.get_node("DayOne");second=game.get_node("DayTwo");chapter=game.get_node("ActTwo");third=game.get_node("ActThree")
 await prepare_day(7)
 baseline=day.manager.make_save_data()
 day.manager.quest_completed.connect(func(id: StringName):completions.append(id))
 verify(third.flag("a3_photo") and third.evidence_count()==0,"Old owner portrait should not replace the deleted laboratory photograph")

 # A photograph already in the clue album remains one of the four required records.
 await load_progress(fixture({"a7_power":true,"a7_computer_power":true,"a7_login":true,"a7_read_photo":true}))
 verify(third.evidence_count()==1 and "lab_photo" in Catalog.collected(day),"Previously collected photograph is lost from investigation count")
 verify(not third.flag("a7_investigate") and not third.day_complete(),"A single existing photograph incorrectly completes the investigation")
 third.interact_item("computer")
 var apps=third.computer.apps
 apps.open_app("recycle");apps.show_page("photo");apps.render();await ticks(2)
 verify(third.evidence_count()==1,"Viewing the same photograph adds duplicate progress")
 apps.open_app("browser");apps.open_app("chat");apps.show_page("conversation")
 apps.news_from_chat();apps.show_page("article_0");await ticks(2)
 verify(third.evidence_count()==4 and third.day_complete(),"New pages do not combine with a previously collected photograph")
 verify(day.manager.get_status(&"a7_investigate")==CalicoQuestManager.State.COMPLETED,"Quest tracker did not finish after all four records")

 # All four facts may have reached disk before the final completion event did.
 var all_records=fixture(full_record_flags())
 all_records.seen_events.append("act3:a7_investigate")
 await load_progress(all_records)
 verify(third.evidence_count()==4 and third.flag("a7_investigate") and third.day_complete(),"Four saved records still require reopening a page to finish")
 verify(day.manager.get_status(&"a7_investigate")==CalicoQuestManager.State.COMPLETED,"Deduplicated old event leaves the investigation quest active")
 var finished_count=completions.count(&"a7_investigate")
 third.restore();third.interact_item("computer");third.record_evidence("photo");third.restore();await ticks(2)
 verify(completions.count(&"a7_investigate")==finished_count,"Reconciliation repeats the quest completion notification")

 # Reopening an already logged-in computer must repair progress independently of restore().
 dismiss();verify(day.manager.restore_save_data(all_records),"Reopen fixture cannot load")
 third.open_panel();third.computer.open();await ticks(2)
 verify(third.flag("a7_investigate") and day.manager.get_status(&"a7_investigate")==CalicoQuestManager.State.COMPLETED,"Reopening the computer cannot repair saved records")

 # A saved restore operation is proof that the laboratory photo has been opened.
 var restored_flags=full_record_flags();restored_flags.erase("a7_read_photo");restored_flags["lab_photo_restored"]=true
 await load_progress(fixture(restored_flags))
 verify(third.flag("a7_read_photo") and third.evidence_count()==4 and "lab_photo" in Catalog.collected(day),"Restored laboratory photograph is not recovered into investigation/album")
 verify(third.day_complete(),"Restored photo leaves investigation stuck at three of four")
 third.interact_item("computer");apps.open_app("photos");apps.show_page("lab_photo");await ticks(2)
 verify(third.evidence_count()==4 and apps.page=="lab_photo","Reopening a restored photograph loses existing investigation progress")

 # Photo recovery alone must not award missing website/chat/news records.
 await load_progress(fixture({"a7_power":true,"a7_computer_power":true,"a7_login":true,"lab_photo_restored":true}))
 verify(third.evidence_count()==1 and not third.flag("a7_investigate"),"Photo recovery bypasses the other three pages")

 # Previously saved evidence is counted when password authentication is completed.
 var before_login=full_record_flags();before_login["a7_login"]=false
 await load_progress(fixture(before_login))
 verify(not third.flag("a7_investigate"),"Investigation completes before login")
 third.complete_login();await ticks(2)
 verify(third.flag("a7_login") and third.flag("a7_investigate") and third.day_complete(),"Login ignores evidence already collected in the save")
 verify(day.manager.get_status(&"a7_investigate")==CalicoQuestManager.State.COMPLETED,"Login repair leaves quest tracker inconsistent")

 # A completion flag can survive while its quest event was skipped/deduplicated.
 var stale_flags={"a7_power":true,"a7_computer_power":true,"a7_login":true,"a7_investigate":true}
 var stale=fixture(stale_flags);stale.seen_events.append("act3:a7_investigate")
 await load_progress(stale)
 verify(day.manager.get_status(&"a7_investigate")==CalicoQuestManager.State.COMPLETED,"Completion flag does not repair an unfinished quest objective")

 # Conversely a completed quest/day is retained even if the redundant flag is absent.
 await load_progress(fixture({"a7_power":true,"a7_computer_power":true,"a7_login":true},true))
 verify(third.flag("a7_investigate") and third.day_complete(),"Previously completed investigation is lost because its flag is absent")
 await load_progress(fixture({"a7_power":true,"a7_computer_power":true,"a7_login":true,"a7_complete":true}))
 verify(third.day_complete(),"Previously completed day seven is blocked by investigation reconciliation")

 # Actual isolated disk save/load retains repair, album entries and can reach day eight.
 await load_progress(all_records)
 var old_path=day.manager.save_path;day.manager.save_path="user://investigation_roundtrip.json"
 verify(day.manager.save_game(),"Repaired progress cannot be written to an isolated save")
 verify(day.manager.restore_save_data(baseline) and day.manager.load_game(),"Repaired progress cannot reload from disk")
 day.manager.save_path=old_path;third.restore();await ticks(2)
 verify(third.evidence_count()==4 and third.day_complete(),"Save/reload loses repaired progress")
 for id in ["lab_photo","lab_site","lab_chat","lab_news"]:verify(id in Catalog.collected(day),"Reload loses album record "+id)
 dismiss();third.interact_item("nest");verify(third.flag("a7_complete"),"Repaired investigation cannot finish day seven at the nest")
 dismiss();third.interact_item("nest");await ticks(3)
 verify(day.value("current_day")==8,"Repaired investigation cannot advance to day eight")

 # Grandfathered pre-investigation logins remain valid, without fabricating four entries.
 var legacy=fixture({"a7_power":true,"a7_computer_power":true,"a7_login":true});legacy.values.investigation_v2_version=0
 await load_progress(legacy)
 verify(third.flag("a7_investigate") and third.evidence_count()==0 and third.day_complete(),"Legacy completed login is forced to repeat the new investigation")
 verify(not day.manager.autosave and not day.quests.save_enabled,"Regression test can overwrite the player save")
 print("INVESTIGATION_PLAYTEST ",JSON.stringify({"checks":checks,"failures":failures}))
 game.stop_audio();game.queue_free();await ticks(3);quit(0 if failures.is_empty() else 1)
