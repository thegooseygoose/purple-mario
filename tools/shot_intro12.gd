extends SceneTree
## Screenshots of the 1-2 surface intro.
##   Godot.exe --path . -s tools/shot_intro12.gd
var main
func _initialize(): call_deferred("_run")
func _snap(name):
	for i in range(3): await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("D:/best game/mario_godot/_shots/%s.png" % name)
func _run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(20): await physics_frame
	var slot := 1
	for pos in range(1, main.LEVEL_COUNT + 1):
		if main._file_at(pos) == 4: slot = pos
	main.level_num = slot
	main._want_12_intro = true
	main.reset(false)
	for i in range(3): await physics_frame
	await _snap("i0_start")
	# partway to the pipe
	while main.intro_phase == 0 and main.player.global_position.x < 110: await physics_frame
	await _snap("i1_walk")
	# at the pipe mouth / entering
	while main.intro_phase < 1: await physics_frame
	for i in range(6): await physics_frame
	await _snap("i2_enter")
	# after handoff to underground
	while main.game_state != "play": await physics_frame
	for i in range(50): await physics_frame
	await _snap("i3_underground")
	print("SHOTS SAVED")
	quit()
