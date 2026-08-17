extends SceneTree
## Headless test for the purple piranha plant.
##   godot --headless --path . -s tools/test_piranha.gd

var fails := 0
var log: FileAccess
func say(s: String) -> void:
	print(s)
	if log: log.store_line(s); log.flush()
func ok(c: bool, m: String) -> void:
	say(("  PASS " if c else "  FAIL ") + m)
	if not c: fails += 1

func _initialize(): call_deferred("_run")

func _run():
	log = FileAccess.open("user://test_piranha.log", FileAccess.WRITE)
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(15): await physics_frame

	say("[1] textures + class")
	ok(main.tex.has("pplant1") and main.tex.has("pplant2"), "both plant frames loaded")

	# put a piranha in empty space (away from Mario) so it runs its cycle freely
	var Piranha = load("res://piranha.gd")
	var p = Piranha.new()
	p.main = main
	main.add_child(p); main.enemies.append(p)
	p.spawn(Vector2(-400, 120))     # rim at y=120, centre x=-400 (far from Mario)

	say("[2] emerge / retract cycle")
	var max_px := 0.0
	var min_after_up := 999.0
	var was_up := false
	for i in range(360):            # ~6s — long enough for a full cycle
		await physics_frame
		max_px = maxf(max_px, p._reveal_px)
		if p._state == "up": was_up = true
		if was_up and p._state == "hidden":
			min_after_up = minf(min_after_up, p._reveal_px)
	ok(max_px >= 23.0, "plant fully emerged (max reveal=%.0fpx)" % max_px)
	ok(was_up, "plant reached the fully-up state")
	ok(min_after_up <= 0.5, "plant retracted back into the pipe (min after up=%.1f)" % min_after_up)

	say("[3] hidden plant has no hurt-box; emerged plant does")
	# drive to hidden
	p._state = "hidden"; p._t = 0.0; p._reveal(0.0)
	await physics_frame
	ok(p.get_rect().size == Vector2.ZERO, "no hurt-box while hidden")
	p._reveal(24.0)
	ok(p.get_rect().size.y > 0.0, "hurt-box present while emerged")

	say("[4] won't emerge while Mario is on the pipe")
	# the camera left-wall clamp snaps a teleported player back, so align the PIPE
	# to Mario's real x rather than moving Mario onto the pipe.
	await physics_frame
	var px: float = main.player.global_position.x
	p._cx = px; p.global_position.x = px               # pipe right under Mario
	p._state = "hidden"; p._t = 999.0                  # rested, would normally rise
	await physics_frame
	await physics_frame
	ok(p._state == "hidden", "stays down while Mario is on the pipe")
	p._cx = px + 400.0                                 # move the pipe far from Mario
	p._state = "hidden"; p._t = 999.0
	var rose := false
	for i in range(40):
		await physics_frame
		if p._state != "hidden": rose = true; break
	ok(rose, "rises once Mario is away")

	say("[5] fireball / knock_out kills it (poofs away, not stompable, no flip)")
	p.knock_out(1)
	ok(p.dead, "plant dies when knocked out")
	ok(not p.sprite.flip_v, "does NOT flip upside-down (poofs in place)")
	var gone := false
	var faded := false
	for i in range(40):
		await physics_frame
		if p.modulate.a < 0.5: faded = true
		if p.remove_me: gone = true; break
	ok(faded, "fades out as it poofs")
	ok(gone, "dead plant cleans itself up quickly")

	say("[6] paint->spawn pipeline (type string -> Piranha)")
	main._enemy_defs = [{"pos": Vector2(-500, 120), "type": "piranha"}]
	for e in main.enemies:
		if is_instance_valid(e): e.queue_free()
	main.enemies.clear()
	main._spawn_enemies()
	var got = null
	for e in main.enemies:
		if e.kind == "piranha": got = e
	ok(got != null, "a 'piranha' enemy def spawns a Piranha node")
	ok(got != null and absf(got._cx - (-500.0)) < 0.1 and absf(got._rim - 120.0) < 0.1,
		"spawned at the painted pipe spot")

	say("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	if log: log.close()
	quit(fails)
