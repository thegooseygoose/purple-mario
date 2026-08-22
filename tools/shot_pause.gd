extends SceneTree
func _snap(name: String) -> void:
	for i in range(3): await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("D:/best game/mario_godot/_shots/%s.png" % name)
func _initialize(): call_deferred("_run")
func _run() -> void:
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(30): await physics_frame
	main.level_num = 1
	main.reset(false)
	main.start_delay = 0.0
	main.fade_alpha = 0.0
	for i in range(10): await physics_frame
	main.toggle_pause()
	main.pause_sel = 3
	main.hud.refresh()
	for i in range(4): await physics_frame
	await _snap("pause_menu")
	# logic check on quit-to-menu
	main._quit_to_menu()
	print("after quit: boot_to_files=", Main.boot_to_files, " paused=", main.paused)
	print("SNAP pause done")
	quit()
