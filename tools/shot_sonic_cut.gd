extends SceneTree
## Screenshots of the scripted 1-2 Sonic cutscene.
##   Godot.exe --path . -s tools/shot_sonic_cut.gd
var main
func _initialize(): call_deferred("_run")
func _snap(name):
	for i in range(3): await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("D:/best game/mario_godot/_shots/%s.png" % name)
	print("snap ", name, " phase=", main.sonic_cut_phase, " mario=", main.player.global_position.round(), " sx=", int(main.sonic_x))

func _run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(20): await physics_frame
	var slot := 2
	for pos in range(1, main.LEVEL_COUNT + 1):
		if main._file_at(pos) == 4: slot = pos
	main.level_num = slot
	main._want_12_intro = false
	main.reset(true)
	main.start_delay = 0.0
	main.fade_alpha = 0.0
	main.player.big = true
	for i in range(3): await physics_frame

	# stand Mario up on the roof just past the trigger x
	main.player.global_position = Vector2(main._sonic_trigger_x + 8.0, float(2 * main.TILE) - main.player.col_size.y / 2.0)
	main.player.velocity = Vector2.ZERO
	# let the play loop fire the trigger
	var guard := 0
	while main.game_state == "play" and guard < 120:
		await physics_frame; guard += 1
	print("triggered? game_state=", main.game_state)

	await _snap("s0_roofwalk")                       # phase 0
	while main.sonic_cut_phase < 1: await physics_frame
	await _snap("s1_fall")                            # phase 1
	while main.sonic_cut_phase < 2: await physics_frame
	for i in range(20): await physics_frame
	await _snap("s2_walk_to_pipe")                   # phase 2
	while not (main.sonic_cut_phase == 3 and main.player.global_position.y < 150): await physics_frame
	await _snap("s3_jump")                            # phase 3 (mid-jump onto pipe)
	while main.sonic_cut_phase < 4: await physics_frame
	while main.sonic_cut_phase == 4 and main.sonic_x > 4515: await physics_frame
	await _snap("s4_crash")                           # phase 4 (Sonic bursting the wall)
	while main.sonic_cut_phase < 7: await physics_frame
	for i in range(40): await physics_frame
	await _snap("s5_speech")                          # phase 7 (congratulations line near Sonic)
	while main.sonic_cut_phase < 8: await physics_frame
	for i in range(20): await physics_frame
	await _snap("s6_downpipe")                        # phase 8 (Mario sinking into the pipe)
	while main.sonic_cut_phase < 9: await physics_frame
	for i in range(220): await physics_frame          # into the foot-tap
	await _snap("s7_foottap")                         # phase 9 (Sonic foot-tap, Mario gone)

	print("SHOTS SAVED")
	quit()
