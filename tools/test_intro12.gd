extends SceneTree
## 1-2 surface intro: warping to 1-2 plays the castle->pipe cutscene, then drops into
## the underground stage.
##   Godot_console.exe --headless --path . -s tools/test_intro12.gd
var fails := 0
var log: FileAccess
func say(s): print(s); if log: log.store_line(s); log.flush()
func ok(c, m): say(("  PASS " if c else "  FAIL ") + m); if not c: fails += 1
func _initialize(): call_deferred("_run")
func _run() -> void:
	log = FileAccess.open("user://test_intro12.log", FileAccess.WRITE)
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(10): await physics_frame

	# find the play-slot that hosts Level4 (1-2)
	var slot := -1
	for pos in range(1, main.LEVEL_COUNT + 1):
		if main._file_at(pos) == 4: slot = pos
	ok(slot != -1, "1-2 (Level4) is in the lineup at slot %d" % slot)

	say("[1] arriving at 1-2 starts the surface intro")
	main.level_num = slot
	main._want_12_intro = true        # what the warp/advance sites set
	main.reset(false)
	var door_x: float = main.player.global_position.x   # before any walking
	ok(absf(door_x - main.INTRO_START_X) < 2.0, "Mario spawns at the castle door (x=%.0f)" % door_x)
	for i in range(6): await physics_frame
	ok(main.intro_12, "intro_12 active")
	ok(main.game_state == "intro", "game_state == intro (not play)")
	ok(not main.underground, "sky, not the dark cave, during the intro")
	ok(not main.level.visible, "underground level hidden during the intro")
	ok(main.player.visible, "Mario visible at the castle door")
	var start_x: float = door_x

	say("[2] Mario walks right and enters the pipe")
	var moved_right := false
	var entered := false
	for i in range(600):
		await physics_frame
		if main.player.global_position.x > start_x + 60.0: moved_right = true
		if not main.player.visible: entered = true
		if main.game_state == "play": break
	ok(moved_right, "Mario walked toward the pipe")

	say("[3] cutscene hands off to the underground stage")
	ok(main.game_state == "play", "underground gameplay started")
	ok(not main.intro_12, "intro flag cleared")
	ok(main.underground, "dark cave backdrop now")
	ok(main.level.visible, "underground level shown")
	ok(main.player.visible, "Mario back in play")
	ok(main.player.modulate.a >= 0.99, "Mario fully opaque again")
	ok(absf(main.player.global_position.x - main._player_start.x) < 4.0, "Mario at the real underground start")
	ok(main.timing, "the clock is running in the stage")

	say("[4] a NORMAL (non-arrival) reload does NOT replay the intro")
	main._want_12_intro = false
	main.reset(true)                  # e.g. a death respawn
	for i in range(6): await physics_frame
	ok(not main.intro_12, "no intro on a plain respawn")
	ok(main.game_state == "play", "straight into play on respawn")

	say("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	if log: log.close()
	quit(fails)
