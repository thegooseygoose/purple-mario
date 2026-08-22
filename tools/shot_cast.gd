extends SceneTree
func _snap(name: String) -> void:
	for i in range(3): await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("D:/best game/mario_godot/_shots/%s.png" % name)
func _initialize(): call_deferred("_run")
func _run() -> void:
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(40): await physics_frame
	print("has sonic_wait_r0? ", main.tex.has("sonic_wait_r0"))
	main._start_credits()
	for i in range(1920): await physics_frame   # ~32s
	await _snap("cast_end1")
	for i in range(300): await physics_frame     # ~37s
	await _snap("cast_end2")
	print("credits_t=", main.credits_t, " done=", main.credits_done)
	quit()
