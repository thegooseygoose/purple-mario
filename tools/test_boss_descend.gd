extends SceneTree
# Headless test for the Sonic-boss DESCEND AI: boot the arena, force the boss active, plant
# Sonic UP on a raised platform and Mario DOWN on the floor, then step _update_boss and check
# Sonic drops down toward Mario's floor instead of hovering up top.
#   Godot.exe --headless --path . -s tools/test_boss_descend.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== boss descend test ===")
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(10): await physics_frame
	for slot in range(1, main.LEVEL_COUNT + 1):
		if main.LEVEL_ORDER[slot - 1][0] == 17:
			main.level_num = slot
			break
	main.reset(true)
	main.start_delay = 0.0
	main.fade_alpha = 0.0
	main._start_boss()

	var TILE: float = main.TILE
	# pick the HIGHEST raised platform (smallest row) as Sonic's starting perch
	var perch = null
	for p in main._boss_platforms:
		if perch == null or p.row < perch.row:
			perch = p
	if perch == null:
		print("RESULT: SKIP - no raised platforms in this arena")
		quit(); return
	print("boss_lo=%.1f (col %.1f)  boss_hi=%.1f (col %.1f)  FLOOR=%d" % [main._boss_lo, main._boss_lo/16.0, main._boss_hi, main._boss_hi/16.0, main.FLOOR])
	print("--- platforms (row, cols, leftNbr, rightNbr; SOLID=wall AIR=drop) ---")
	for p in main._boss_platforms:
		var lsolid: bool = main._boss_solid(p.c0 - 1, p.row)
		var rsolid: bool = main._boss_solid(p.c1 + 1, p.row)
		print("   row %2d cols %2d-%2d  left=%s right=%s" % [p.row, p.c0, p.c1, ("SOLID" if lsolid else "AIR"), ("SOLID" if rsolid else "AIR")])
	print("perch: row %d cols %d-%d" % [perch.row, perch.c0, perch.c1])

	# Sonic stands on the perch; Mario waits on the floor below, near the perch's x
	main.sonic_x = float(perch.c0 + perch.c1) * 0.5 * TILE
	main._boss_feet_y = float(perch.row * TILE)
	main._boss_vy = 0.0
	main._boss_grounded = true
	main._boss_phase = "pursue"
	var mario_floor := Vector2(main.sonic_x, float(main.FLOOR * TILE) - main.player.col_size.y / 2.0)

	var dt := 1.0 / 60.0
	var t := 0.0
	var start_row: int = perch.row
	var max_row: int = perch.row
	var reached_floor := false
	while t < 8.0:
		main.player.global_position = mario_floor        # hold Mario on the floor below
		main.player.velocity = Vector2.ZERO
		main.player.grounded = true
		if main._boss_phase == "rev" or main._boss_phase == "dash":
			main._boss_phase = "pursue"                   # keep testing descent, not the dash
		main._update_boss(dt)
		var srow: float = main._boss_feet_y / TILE
		max_row = max(max_row, int(round(srow)))
		if srow >= float(main.FLOOR) - 0.5:
			reached_floor = true
		if int(t * 60) % 30 == 0:
			print("  t=%4.1f sonic col=%5.1f feet_row=%4.1f grounded=%s" % [
				t, main.sonic_x / TILE, srow, str(main._boss_grounded)])
		t += dt

	print("start row %d -> lowest row reached %d (FLOOR=%d)" % [start_row, max_row, main.FLOOR])
	print("RESULT: %s" % ("PASS - Sonic descended to Mario's floor" if reached_floor else "FAIL - Sonic never got down"))
	print("=== done ===")
	quit()
