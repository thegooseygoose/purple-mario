extends SceneTree
## Runtime smoke test: boot the game, load the boss level (file 17) and let it run, then
## jump straight into the credits — screenshot both and report any errors.
##   Godot.exe --path . -s tools/smoke_playtest.gd
var main
func _snap(name: String) -> void:
	for i in range(3): await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("D:/best game/mario_godot/_shots/%s.png" % name)
func _initialize(): call_deferred("_run")
func _run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(30): await physics_frame
	# --- boss level (3-4) ---
	for slot in range(1, main.LEVEL_COUNT + 1):
		if main.LEVEL_ORDER[slot - 1][0] == 17:
			main.level_num = slot
			break
	main.reset(false)
	main.start_delay = 0.0
	main.fade_alpha = 0.0
	for i in range(180): await physics_frame   # ~3s of the arena intro/fight
	await _snap("smoke_boss")
	print("BOSS gs=", main.game_state, " boss_active=", main._boss_active)
	# --- credits ---
	main._start_credits()
	for i in range(240): await physics_frame   # ~4s into the roll
	await _snap("smoke_credits")
	print("CREDITS gs=", main.game_state, " mario.x=", main.player.global_position.x, " endsong=", main.end_player.playing)
	print("SMOKE DONE")
	quit()
