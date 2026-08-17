extends SceneTree
## Verifies a block-bumped koopa becomes an UPSIDE-DOWN but fully KICKABLE shell
## (same physics as a right-side-up shell, just drawn belly-up) — not an inert stun.
##   godot --headless --path . -s tools/test_bellyup.gd

var fails := 0
var log: FileAccess
func say(s: String) -> void:
	print(s)
	if log: log.store_line(s); log.flush()
func ok(c: bool, m: String) -> void:
	say(("  PASS " if c else "  FAIL ") + m)
	if not c: fails += 1

func _initialize(): call_deferred("_run")

func _run() -> void:
	log = FileAccess.open("user://test_bellyup.log", FileAccess.WRITE)
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(15): await physics_frame

	var Enemy = load("res://enemy.gd")
	var k = Enemy.new()
	k.main = main; k.kind = "koopa"
	main.add_child(k); main.enemies.append(k)
	k.spawn(Vector2(60, 13 * 16))       # on the ground
	k.active = true
	for i in range(6): await physics_frame

	say("[1] block-bump flips it into an upside-down shell")
	k.flip_stun()
	await physics_frame
	ok(k.shell, "it's a shell")
	ok(k.belly_up, "it's belly_up")
	ok(k.sprite.flip_v, "sprite is drawn upside-down (flip_v)")
	ok(not k.dead, "not dead/inert")

	say("[2] the upside-down shell is still KICKABLE (pushable)")
	# park Mario on top of the still shell — a still shell gets kicked into motion
	main.player.invuln = 0.0
	main.player.big = true            # avoid any accidental death muddying the test
	var kicked := false
	for i in range(12):
		main.player.global_position = k.global_position + Vector2(0, -2)
		await physics_frame
		if k.shell_moving:
			kicked = true
			break
	ok(kicked, "touching it kicked the shell into a slide")
	ok(k.belly_up and k.sprite.flip_v, "still drawn upside-down while sliding")
	ok(absf(k.velocity.x) > 50.0, "it's actually moving (|vx|=%.0f)" % absf(k.velocity.x))

	say("[3] a moving upside-down shell kills an enemy in its path")
	var g = Enemy.new()
	g.main = main; g.kind = "goomba"
	main.add_child(g); main.enemies.append(g)
	# drop the goomba just ahead of the sliding shell
	g.spawn(Vector2(k.global_position.x + k.dir * 24, 13 * 16))
	g.active = true
	main.player.global_position = Vector2(20, 100)   # get Mario out of the way
	var killed := false
	for i in range(30):
		await physics_frame
		if g.dead:
			killed = true
			break
	ok(killed, "the sliding belly-up shell knocked out the goomba")

	say("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	if log: log.close()
	quit(fails)
