extends SceneTree
# Headless test for the Sonic-boss stepping-stone climb AI. Boot the arena (file 17), force the boss
# active, plant Mario UP on the left ledge, and step _update_boss to see if Sonic ladders up to him.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== boss climb test ===")
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(10): await physics_frame

	main.level_num = main.LEVEL_COUNT      # last slot == file 17 (3-4) if wired to the end
	# find the play slot whose file is 17
	for slot in range(1, main.LEVEL_COUNT + 1):
		if main.LEVEL_ORDER[slot - 1][0] == 17:
			main.level_num = slot
			break
	main.reset(true)
	main.start_delay = 0.0
	main.fade_alpha = 0.0
	print("level_file=%d  gords=%d" % [main._level_file, main.gords.size()])

	main._start_boss()
	print("platforms (%d):" % main._boss_platforms.size())
	for p in main._boss_platforms:
		print("   row %2d  cols %d-%d" % [p.row, p.c0, p.c1])
	print("boss_lo=%.0f boss_hi=%.0f (cols %.1f-%.1f)" % [main._boss_lo, main._boss_hi, main._boss_lo/16.0, main._boss_hi/16.0])

	# Put Sonic on the floor mid-arena, Mario up on the LEFT ledge (near the (32,6) gordo)
	main.sonic_x = 50.0 * main.TILE
	main._boss_feet_y = float(main.FLOOR * main.TILE)
	main._boss_vy = 0.0
	main._boss_grounded = true
	main._boss_phase = "pursue"
	var TILE: float = main.TILE
	var side := "left"
	for a in OS.get_cmdline_user_args():
		if a == "right": side = "right"
	var ledge_col: float = 34.5 if side == "left" else 58.0
	print("MARIO ON %s LEDGE (col %.1f)" % [side, ledge_col])
	var mario_ledge := Vector2(ledge_col * TILE, 7.0 * TILE - main.player.col_size.y / 2.0)

	var dt := 1.0 / 60.0
	var t := 0.0
	var min_row := 99
	var reached_ledge := false
	while t < 10.0:
		# hold Mario planted on the ledge, grounded, so the boss sees him "above"
		main.player.global_position = mario_ledge
		main.player.velocity = Vector2.ZERO
		main.player.grounded = true
		# don't let the dash phase end the fight during the climb test — clamp hits
		main._update_boss(dt)
		var srow: float = main._boss_feet_y / TILE
		min_row = min(min_row, int(round(srow)))
		if srow <= 7.5 and absf(main.sonic_x - mario_ledge.x) < 6.0 * TILE:
			reached_ledge = true
		if int(t * 60) % 30 == 0:      # log twice a second
			print("  t=%4.1f sonic col=%4.1f feet_row=%4.1f grounded=%s phase=%s state=%s" % [
				t, main.sonic_x / TILE, srow, str(main._boss_grounded), main._boss_phase, main.sonic_state])
		t += dt

	print("highest rung reached: row %d (7 = the ledge Mario is on)" % min_row)
	print("RESULT: %s" % ("PASS - Sonic climbed to Mario's ledge" if reached_ledge else "FAIL - Sonic never reached the ledge"))
	print("=== done ===")
	quit()
