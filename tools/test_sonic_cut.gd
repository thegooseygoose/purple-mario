extends SceneTree
# Headless test for the scripted 1-2 Sonic cutscene: warp to file 4, put Mario up on the chamber
# roof past the trigger x, fire it, and step the whole sequence. Logs to user:// + stdout.

var log_f: FileAccess
func _log(s: String) -> void:
	print(s)
	if log_f: log_f.store_line(s); log_f.flush()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	log_f = FileAccess.open("user://sonic_cut_test.log", FileAccess.WRITE)
	_log("=== scripted sonic cut test ===")
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(10): await physics_frame

	main._want_12_intro = false
	main.level_num = 2                     # play slot 2 == file 4 (1-2)
	main.reset(true)
	main.start_delay = 0.0
	main.fade_alpha = 0.0

	var pc: Vector2i = main._sonic_pipe_cell
	_log("level_file=%d  pipe_cell=%s  trigger_x=%.0f" % [main._level_file, str(pc), main._sonic_trigger_x])
	if pc.x < 0:
		_log("FAIL: chamber pipe not found"); quit(); return

	# put Mario up on the roof, just past the trigger x, walking right
	main.player.global_position = Vector2(main._sonic_trigger_x + 8.0, float(2 * main.TILE) - main.player.col_size.y / 2.0)
	main.player.velocity = Vector2.ZERO

	var before := _count_tunnel_bricks(main)
	_log("wall tunnel-row bricks BEFORE: %d" % before)

	main._check_sonic_cut()
	_log("after check: game_state=%s phase=%d" % [main.game_state, main.sonic_cut_phase])
	if main.game_state != "sonic_cut":
		_log("FAIL: cutscene did not trigger"); quit(); return

	var dt := 1.0 / 60.0
	var seen := {}
	var t := 0.0
	while t < 22.0 and main.sonic_cut_phase < 9:
		main._update_sonic_cut(dt)
		if not seen.has(main.sonic_cut_phase):
			seen[main.sonic_cut_phase] = true
			_log("  t=%5.2f  phase=%d  mario=(%.0f,%.0f) vis=%s  sonic_x=%.0f speech=%s" % [
				t, main.sonic_cut_phase, main.player.global_position.x, main.player.global_position.y,
				str(main.player.visible), main.sonic_x, str(main.sonic_speech)])
		t += dt
	# let phase 9 (foot-tap) run so a tap frame shows
	for i in range(260): main._update_sonic_cut(dt)
	_log("phase9 foot-tap sonic_frame=%d (3/4 = a foot-tap frame)" % main.sonic_frame)

	var after := _count_tunnel_bricks(main)
	var pipe_top: float = float(pc.y * int(main.TILE))
	var mfeet: float = main.player.global_position.y + main.player.col_size.y / 2.0
	_log("wall tunnel-row bricks AFTER: %d  (broke %d)" % [after, before - after])
	_log("Mario final: x=%.0f feet=%.0f (pipe centre=%.0f rim=%.0f)" % [main.player.global_position.x, mfeet, float(pc.x * main.TILE + main.TILE), pipe_top])
	_log("Sonic final: x=%.0f state=%s face=%s (stop=%.0f)" % [main.sonic_x, main.sonic_state, main.sonic_face, main.sonic_cut_stop_x])
	_log("final phase=%d game_state=%s (should be 7 / sonic_cut = frozen)" % [main.sonic_cut_phase, main.game_state])
	_log("=== done ===")
	quit()

func _count_tunnel_bricks(main) -> int:
	var n := 0
	for c in main.terrain.get_used_cells():
		if (c.y == main.FLOOR - 1 or c.y == main.FLOOR - 2) and c.x >= 282:
			var ax: int = main.terrain.get_cell_atlas_coords(c).x
			if ax == main.ATLAS_BRICK_PURPLE or ax == main.ATLAS_BRICK:
				n += 1
	return n
