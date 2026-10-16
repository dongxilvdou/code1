extends "res://tools/playtest_map_stairs.gd"
## Exercise the real menu buttons and Escape routing, including a smaller window.
func click_button(parent: Node, caption: String) -> void:
	for button_node in parent.find_children("*","Button",true,false):
		if button_node.text!=caption or not button_node.is_visible_in_tree():continue
		var point: Vector2 = button_node.get_global_rect().get_center()
		expect(root.get_visible_rect().has_point(point),"Button outside screen: "+caption)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion,true)
		for pressed in [true,false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event,true)
			await process_frame
		return
	expect(false,"Button missing: "+caption)

func run_tests() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await ticks(8)
	expect(game.menu_camera.current and not game.player.active,"Menu camera/control incorrect")
	expect(game.ui.welcome.visible and not game.ui.hud.visible,"Initial UI mode incorrect")
	expect(game.ui.welcome.find_children("*","SubViewport",true,false).is_empty(),"Old portrait viewport remains")
	root.size = Vector2i(960,600)
	await ticks(4)
	await click_button(game.ui.welcome,"设置")
	expect(game.ui.settings_panel.visible and not game.started,"Settings button failed")
	var volume: HSlider = game.ui.settings_panel.find_children("*","HSlider",true,false)[0]
	volume.value = .35
	expect(absf(db_to_linear(AudioServer.get_bus_volume_db(0))-.35)<.01,"Settings volume not applied")
	await key(KEY_ESCAPE)
	expect(not game.ui.settings_panel.visible and game.ui.welcome.visible,"Esc did not return to main menu")
	await click_button(game.ui.welcome,"开始游戏")
	await ticks(4)
	expect(game.started and game.player.active and game.player.camera.current,"Start button failed to enter cat view")
	expect(not game.ui.welcome.visible and game.ui.hud.visible,"HUD not restored after start")
	expect(game.get_node("VillaMap/MapHUD").visible,"Minimap missing after start")
	await key(KEY_ESCAPE)
	expect(game.ui.pause_panel.visible and not game.player.active,"Pause did not stop player")
	await click_button(game.ui.pause_panel,"设置")
	expect(game.ui.settings_panel.visible,"Pause settings failed")
	await key(KEY_B)
	await key(KEY_M)
	expect(not game.inspecting and not game.get_node("VillaMap/MapHUD").big_open,"Settings leaked game shortcuts")
	await key(KEY_ESCAPE)
	expect(game.ui.pause_panel.visible and not game.ui.settings_panel.visible and not game.player.active,"Closing settings unexpectedly resumed play")
	await click_button(game.ui.pause_panel,"继续游戏")
	await ticks(3)
	expect(game.player.active and not game.ui.pause_panel.visible,"Continue button failed")
	print("UI_PLAYTEST ",JSON.stringify({"small_window":[960,600],"menu_settings_start_pause_resume":true,"failures":failures}))
	game.queue_free()
	await process_frame
	await process_frame
	game = null
	call_deferred("quit",0 if failures.is_empty() else 1)
