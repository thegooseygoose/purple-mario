extends SceneTree
## Screenshot the COURSE CLEARED card with the time in its box.
##   Godot.exe --path . -s tools/shot_clear.gd
var main
func _snap(name: String) -> void:
	for i in range(3): await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("D:/best game/mario_godot/_shots/%s.png" % name)
func _initialize(): call_deferred("_run")
func _run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(40): await physics_frame
	main.level_num = 1
	main.reset(false)
	main.start_delay = 0.0
	main.fade_alpha = 0.0
	for i in range(20): await physics_frame
	main.elapsed = 127.0
	main.game_state = "clear"
	for i in range(5): await physics_frame
	print("filter_mode=", main.filter_mode, " filter_rect.visible=", (main.filter_rect.visible if main.filter_rect else "no rect"))
	main.filter_mode = 0
	main._apply_filter()
	main._new_record = true
	main.qanim_phase = 0.1        # so the NEW RECORD blink is in its "on" phase
	for i in range(3): await physics_frame
	await _snap("clear_card")
	print("SNAP done  time=", main.time_string())
	quit()
