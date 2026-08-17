extends SceneTree
## A walking koopa must pass UNDER a 1-tile (16px) overhang like small Mario / a
## goomba — not hit it and turn around.
##   godot --headless --path . -s tools/test_underblock.gd

var fails := 0
var log: FileAccess
func say(s: String) -> void:
	print(s)
	if log: log.store_line(s); log.flush()
func ok(c: bool, m: String) -> void:
	say(("  PASS " if c else "  FAIL ") + m)
	if not c: fails += 1

func _initialize(): call_deferred("_run")

# a long floor (top at `ground`) + a 1-tile-high overhang (its underside 16px above
# the floor) spanning a stretch in the middle. Enemies walk left, under the overhang.
func _rig(main, ground: float, cx: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1; body.collision_mask = 0
	var fc := CollisionShape2D.new()
	var fr := RectangleShape2D.new(); fr.size = Vector2(400, 40)
	fc.shape = fr; fc.position = Vector2(cx, ground + 20)      # floor, top at `ground`
	body.add_child(fc)
	var oc := CollisionShape2D.new()
	var orr := RectangleShape2D.new(); orr.size = Vector2(64, 16)
	oc.shape = orr; oc.position = Vector2(cx, ground - 16 - 8) # overhang, underside 16px up
	body.add_child(oc)
	main.add_child(body)

func _walks_under(main, kind: String, cx: float) -> bool:
	var Enemy = load("res://enemy.gd")
	var e = Enemy.new()
	e.main = main; e.kind = kind
	main.add_child(e)
	e.spawn(Vector2(cx + 70, 100))       # start right of the overhang
	e.active = true
	e.dir = -1                            # walk left, into and under the overhang
	var start_dir: int = e.dir
	var reversed := false
	for i in range(200):
		await physics_frame
		if not is_instance_valid(e): break
		if e.dir != start_dir: reversed = true
		if e.global_position.x < cx - 45: break   # made it out the far side
	var passed: bool = is_instance_valid(e) and e.global_position.x < cx - 40 and not reversed
	if is_instance_valid(e): e.queue_free()
	return passed

func _run() -> void:
	log = FileAccess.open("user://test_underblock.log", FileAccess.WRITE)
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(12): await physics_frame

	# two rigs in empty space (negative x) so the real level can't interfere
	_rig(main, 100.0, -200.0)
	_rig(main, 100.0, -600.0)

	say("[1] goomba (control) walks under the 1-tile overhang")
	var g_ok = await _walks_under(main, "goomba", -200.0)
	ok(g_ok, "goomba passed under without turning")

	say("[2] koopa walks under the 1-tile overhang (the fix)")
	var k_ok = await _walks_under(main, "koopa", -600.0)
	ok(k_ok, "koopa passed under without turning")

	say("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	if log: log.close()
	quit(fails)
