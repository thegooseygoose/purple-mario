extends SceneTree
## Screenshot the START GAME / LEVEL RECORDS menu and the records screen.
func _snap(name: String) -> void:
	for i in range(3): await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("D:/best game/mario_godot/_shots/%s.png" % name)
func _initialize(): call_deferred("_run")
func _run() -> void:
	Main.save_names = ["KENNY", "GOOSE", ""]
	Main.save_highest = [7, 17, 0]
	Main.save_slot = 0
	var best: Array = []
	for l in Main.LEVEL_COUNT: best.append(0.0)
	best[0] = 38.44; best[1] = 91.20; best[2] = 27.05; best[6] = 145.9
	Main.save_best = [best, [], []]
	var intro = load("res://Intro.tscn").instantiate()
	get_root().add_child(intro)
	for i in range(10): await physics_frame
	# seed AFTER _ready (which reloads from disk) so sample times show for real levels
	Main.save_names = ["KENNY", "GOOSE", ""]
	var b: Array = []
	for l in Main.LEVEL_COUNT: b.append(0.0)
	b[0]=38.44; b[1]=91.20; b[2]=27.05; b[3]=60.10   # 1-1..1-4
	b[6]=45.00; b[5]=130.5                            # 2-1, 2-2
	b[16]=88.75                                       # 3-4
	Main.save_best[0] = b
	intro.menu_sel = 1
	intro.phase = "menu"; intro.t = 0.1
	for i in range(4): await physics_frame
	await _snap("menu_screen")
	intro.phase = "records"; intro.t = 0.1
	for i in range(4): await physics_frame
	await _snap("records_screen")
	print("SNAP menu+records done")
	quit()
