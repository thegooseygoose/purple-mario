extends SceneTree
## Screenshot the save-file select screen with sample data.
##   Godot.exe --path . -s tools/shot_files.gd
func _snap(name: String) -> void:
	for i in range(3): await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("D:/best game/mario_godot/_shots/%s.png" % name)
func _initialize(): call_deferred("_run")
func _run() -> void:
	# seed some save data so the screen shows names + worlds
	Main.save_names = ["KENNY", "", "GOOSE"]
	Main.save_highest = [7, 0, 17]
	var intro = load("res://Intro.tscn").instantiate()
	get_root().add_child(intro)
	for i in range(10): await physics_frame
	intro.file_sel = 1
	intro.phase = "file"
	intro.t = 0.1
	for i in range(5): await physics_frame
	await _snap("files_screen")
	print("SNAP files_screen  sel=", intro.file_sel)
	quit()
