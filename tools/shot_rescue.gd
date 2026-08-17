extends SceneTree
## Screenshots: mac speaking (before COURSE CLEAR), then COURSE CLEAR after.
##   Godot.exe --path . -s tools/shot_rescue.gd
var main
func _initialize(): call_deferred("_run")
func _snap(name: String) -> void:
	for i in range(3): await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("D:/best game/mario_godot/_shots/%s.png" % name)
func _run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(40): await physics_frame
	main.level_num = 4          # Bowser castle is now play-slot 4
	main.reset(false)
	for i in range(40): await physics_frame
	main._start_axe_ending()
	for i in range(400):
		await physics_frame
		if main.show_rescue: break
	# wait for Mario to arrive and mac to start speaking
	for i in range(600):
		await physics_frame
		if main.show_rescue_speech: break
	for i in range(30): await physics_frame
	await _snap("speech")
	# then wait for COURSE CLEAR
	for i in range(400):
		await physics_frame
		if main.game_state == "clear": break
	for i in range(20): await physics_frame
	await _snap("clear_after")
	print("SHOTS SAVED  gs=", main.game_state)
	quit()
