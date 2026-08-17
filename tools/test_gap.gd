extends SceneTree
## Verifies koopas don't jitter in a 1-tile gap:
##   green koopa dropped into a 1-tile pit falls cleanly (no rapid dir flips),
##   purple ledge-shy koopa on a 1-tile perch gives up and falls to its death.
##   godot --headless --path . -s tools/test_gap.gd

var fails := 0
var log: FileAccess

func say(s: String) -> void:
	print(s)
	if log:
		log.store_line(s)
		log.flush()

func ok(c: bool, m: String) -> void:
	say(("  PASS " if c else "  FAIL ") + m)
	if not c:
		fails += 1

func _initialize(): call_deferred("_run")

func _make_walls(main, gap_left: float, gap_w: float, top: float) -> void:
	# two tall walls with a `gap_w` gap between them, tops at `top`
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for c in [Vector2(gap_left - 40, top + 60), Vector2(gap_left + gap_w + 40, top + 60)]:
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(80, 120)
		cs.shape = r
		cs.position = c
		body.add_child(cs)
	main.add_child(body)

func _run():
	log = FileAccess.open("user://test_gap.log", FileAccess.WRITE)
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(15): await physics_frame
	var Enemy = load("res://enemy.gd")

	# NOTE: rigs sit at negative x — empty space away from the real Level1 ground,
	# so a koopa that leaves its perch falls into the void (a stand-in for a pit).
	say("[A] green koopa dropping into a narrow gap (walls on both sides)")
	_make_walls(main, -210.0, 20.0, 120.0)     # walls' tops at y=120, gap x -210..-190
	var g = Enemy.new()
	g.main = main; g.kind = "koopa"; g.purple = false
	main.add_child(g)
	g.spawn(Vector2(-200, 118))                # in the gap; drifts into a wall as it falls
	g.active = true
	var flips := 0
	var last: int = g.dir
	var maxy := -1e9
	for i in range(120):
		await physics_frame
		if not is_instance_valid(g): break
		if g.dir != last: flips += 1; last = g.dir
		maxy = maxf(maxy, g.global_position.y)
	ok(maxy > 180.0, "green koopa fell down the gap (reached y=%.0f)" % maxy)
	ok(flips <= 1, "green koopa did NOT jitter while falling (dir flips=%d)" % flips)

	say("[B] purple ledge-shy koopa on a 1-tile perch")
	# a single 16px-wide pillar top at y=120, drops on both sides
	var pillar := StaticBody2D.new()
	pillar.collision_layer = 1; pillar.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new(); r.size = Vector2(16, 80)
	cs.shape = r; cs.position = Vector2(-400, 160)    # top at y=120, x -408..-392
	pillar.add_child(cs)
	main.add_child(pillar)
	var p = Enemy.new()
	p.main = main; p.kind = "koopa"; p.purple = true; p.ledge_shy = true
	main.add_child(p)
	p.spawn(Vector2(-400, 118))
	p.active = true
	var pfell := false
	var gave_up := false
	for i in range(150):
		await physics_frame
		if not is_instance_valid(p): break
		if not p.ledge_shy: gave_up = true
		if p.global_position.y > 220.0: pfell = true
	ok(gave_up, "purple koopa gave up ledge-shyness on the tiny perch")
	ok(pfell, "purple koopa then fell off to its death")

	say("[C] moving shell wedged in a 1-tile (16px) floored slot")
	# two side walls 16px apart + a floor at the bottom of the slot (x -708..-692)
	var slot := StaticBody2D.new()
	slot.collision_layer = 1; slot.collision_mask = 0
	for spec in [Vector2(-748, 180), Vector2(-652, 180)]:   # side walls, gap x -708..-692
		var c := CollisionShape2D.new()
		var rr := RectangleShape2D.new(); rr.size = Vector2(80, 120)
		c.shape = rr; c.position = spec; slot.add_child(c)
	var fc := CollisionShape2D.new()                        # slot floor, top at y=128
	var fr := RectangleShape2D.new(); fr.size = Vector2(16, 40)
	fc.shape = fr; fc.position = Vector2(-700, 148); slot.add_child(fc)
	main.add_child(slot)
	var s = Enemy.new()
	s.main = main; s.kind = "koopa"; s.purple = true
	main.add_child(s); main.enemies.append(s)
	s.spawn(Vector2(-700, 126))
	s.active = true
	s.to_shell()                 # kicked shell, ricocheting
	s.shell_moving = true; s.dir = 1; s.velocity.x = 200.0
	var sflips := 0
	var slast: int = s.dir
	var dropped := false
	for i in range(180):
		await physics_frame
		if not is_instance_valid(s): break
		if s.dir != slast: sflips += 1; slast = s.dir
		if s.collision_mask == 0: dropped = true
	ok(dropped, "wedged shell gave up and dropped through (didn't buzz forever)")
	ok(sflips <= 12, "wedged shell stopped after a few hits, not endless (flips=%d)" % sflips)

	say("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	if log: log.close()
	quit(fails)
