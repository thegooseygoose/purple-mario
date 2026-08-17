extends SceneTree
## Headless behaviour test for the purple enemy variants.
##   godot --headless --path . -s tools/test_purple.gd
## Verifies: (1) purple textures load, (2) purple goomba spits an enemy fireball
## that hurts the player, (3) purple koopa turns at ledges and never walks off.

var fails: int = 0
var log: FileAccess

func say(s: String) -> void:
	print(s)
	if log:
		log.store_line(s)
		log.flush()

func ok(cond: bool, msg: String) -> void:
	say(("  PASS " if cond else "  FAIL ") + msg)
	if not cond:
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	log = FileAccess.open("user://test_purple.log", FileAccess.WRITE)
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(20):        # let _ready / reset / first spawns settle
		await physics_frame

	say("[1] textures")
	for k in ["pgoomba1", "pgoomba2", "pgoomba_flat", "pkoopa1", "pkoopa2",
			"pkoopa_shell", "pshell_left", "pshell_right1", "pshell_right2", "pshell_wake"]:
		ok(main.tex.has(k) and main.tex[k] != null, "texture %s loaded" % k)

	say("[2] spawn purple variants (self-contained, not reliant on level markers)")
	var Enemy = load("res://enemy.gd")
	var pg = Enemy.new()
	pg.main = main; pg.kind = "goomba"; pg.purple = true
	main.add_child(pg)
	pg.spawn(main.player.global_position + Vector2(30, 0))   # next to Mario, on screen
	pg.active = true
	main.enemies.append(pg)
	var pk = Enemy.new()
	pk.main = main; pk.kind = "koopa"; pk.purple = true; pk.ledge_shy = true
	main.add_child(pk)
	pk.spawn(main.player.global_position + Vector2(-30, 0))
	pk.active = true
	main.enemies.append(pk)
	ok(pg != null and pg.purple and pg.kind == "goomba", "purple goomba created")
	ok(pk != null and pk.ledge_shy, "purple koopa created and ledge_shy")

	say("[3] purple goomba fireball")
	if pg:
		# purple art actually drives the sprite
		await physics_frame
		ok(pg.sprite.texture == main.tex["pgoomba1"] or pg.sprite.texture == main.tex["pgoomba2"],
			"goomba shows purple art")
		var before: int = main.enemy_fireballs.size()
		pg.fire_timer = pg.FIRE_INTERVAL - 0.05   # push it right up to the next spit
		var fired := false
		for i in range(20):
			await physics_frame
			if main.enemy_fireballs.size() > before:
				fired = true
				break
		ok(fired, "goomba spat an enemy fireball near the 10s mark")
		# fireball hurts the player on contact. Make Mario big first so the hit
		# shrinks him (starts a transform) instead of killing small Mario -- a
		# death would kick off the 3.6s reset sequence and muddy the test.
		if main.enemy_fireballs.size() > 0:
			main.player.big = true
			main.player.fire = false
			main.player.transforming = false
			main.player.invuln = 0.0
			var hurt_seen := false
			for i in range(10):
				if main.enemy_fireballs.is_empty():
					break
				var fb = main.enemy_fireballs[0]
				if is_instance_valid(fb):
					fb.global_position = main.player.global_position
				await physics_frame
				if main.player.transforming or not main.player.big:
					hurt_seen = true
					break
			ok(hurt_seen, "fireball hurt the player on contact (big Mario shrank)")

	say("[4] purple koopa ledge behaviour")
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	for seg in [Vector2(60, 110), Vector2(200, 110)]:   # gap between x 100..160
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(80, 20)
		cs.shape = r
		cs.position = seg
		floor_body.add_child(cs)
	main.add_child(floor_body)

	var k = Enemy.new()   # Enemy loaded in [2]
	k.main = main
	k.kind = "koopa"
	k.purple = true
	k.ledge_shy = true
	main.add_child(k)
	k.spawn(Vector2(55, 100))    # feet on the left segment (top y = 100)
	k.active = true

	var minx := 1e9
	var maxx := -1e9
	var flips := 0
	var last_dir: int = k.dir
	var fell := false
	for i in range(220):         # ~3.6s
		await physics_frame
		if not is_instance_valid(k): break
		minx = minf(minx, k.global_position.x)
		maxx = maxf(maxx, k.global_position.x)
		if k.dir != last_dir:
			flips += 1
			last_dir = k.dir
		if k.global_position.y > 160.0:   # platform top is y=100; this = fell in the gap
			fell = true
	ok(not fell, "koopa never fell into the gap (stayed on the platform)")
	ok(maxx < 108.0, "koopa turned back before the right ledge (maxx=%.1f)" % maxx)
	ok(flips >= 2, "koopa reversed direction at both edges (flips=%d)" % flips)

	say("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	if log:
		log.close()
	quit(fails)
