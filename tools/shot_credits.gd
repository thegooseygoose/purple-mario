extends SceneTree
## Screenshots of the 3-4 end-credits roll (bypasses the boss fight).
##   Godot.exe --path . -s tools/shot_credits.gd
var main
func _snap(name: String) -> void:
	for i in range(3): await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("D:/best game/mario_godot/_shots/%s.png" % name)
func _initialize(): call_deferred("_run")
func _run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(40): await physics_frame
	main._start_credits()
	print("music end_player.playing=", main.end_player.playing)
	# early: Mario running, "created by" on screen
	for i in range(330): await physics_frame   # ~5.5s
	await _snap("credits_early")
	print("early  mario.x=", main.player.global_position.x, " vx=", main.player.velocity.x, " done=", main.credits_done)
	# done: THE END settled, Mario should have stopped
	for i in range(720): await physics_frame   # ~17s total
	var x_at_done: float = main.player.global_position.x
	await _snap("credits_end")
	print("end    mario.x=", x_at_done, " vx=", main.player.velocity.x, " done=", main.credits_done)
	# give him a moment; confirm he's standing still (x not advancing)
	for i in range(60): await physics_frame
	print("standstill dx=", main.player.global_position.x - x_at_done, " vx=", main.player.velocity.x)
	# simulate pressing a button -> restart
	main._restart_game()
	for i in range(20): await physics_frame
	print("after restart gs=", main.game_state, " level_num=", main.level_num)
	print("CREDITS TEST DONE")
	quit()
