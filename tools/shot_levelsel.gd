extends SceneTree
func _snap(name: String) -> void:
	for i in range(3): await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("D:/best game/mario_godot/_shots/%s.png" % name)
func _initialize(): call_deferred("_run")
func _run() -> void:
	var intro = load("res://Intro.tscn").instantiate()
	get_root().add_child(intro)
	for i in range(10): await physics_frame
	Main.save_slot = 0
	Main.save_names[0] = "KENNY"
	var b: Array = []
	for l in Main.LEVEL_COUNT: b.append(0.0)
	b[0]=38.44; b[6]=45.0
	Main.save_best[0] = b
	# locked menu (game not beaten)
	Main.save_beat[0] = false
	intro.menu_sel = 0
	intro.phase = "menu"; intro.t = 0.1
	for i in range(4): await physics_frame
	await _snap("menu_locked")
	# unlocked menu, highlight LEVEL SELECT
	Main.save_beat[0] = true
	intro.menu_sel = 2
	for i in range(4): await physics_frame
	await _snap("menu_unlocked")
	# the LEVEL SELECT grid
	intro.levelsel_idx = 6
	intro.phase = "levelsel"
	for i in range(4): await physics_frame
	await _snap("levelsel")
	print("SNAP levelsel done")
	quit()
