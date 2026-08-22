extends SceneTree
func _snap(name: String) -> void:
	for i in range(3): await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("D:/best game/mario_godot/_shots/%s.png" % name)
func _initialize(): call_deferred("_run")
func _run() -> void:
	Main.attract_mode = true
	Main.save_slot = -1
	Main.debug_start_level = 1
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(40): await physics_frame
	main.start_delay = 0.0
	main.fade_alpha = 0.0
	var start_x: float = main.player.global_position.x
	var deaths := 0
	var maxx: float = start_x
	for s in range(20):                       # ~20 seconds
		for i in range(60): await physics_frame
		if main.player.dead: deaths += 1
		maxx = max(maxx, main.player.global_position.x)
		print("t=%2ds  x=%.0f  dead=%s  onfloor=%s" % [s+1, main.player.global_position.x, str(main.player.dead), str(main.player.is_on_floor())])
		if s == 5: await _snap("attract_5s")
		if s == 12: await _snap("attract_12s")
	print("RESULT start_x=%.0f  furthest_x=%.0f  progress=%.0f tiles  deaths=%d" % [start_x, maxx, (maxx-start_x)/16.0, deaths])
	quit()
