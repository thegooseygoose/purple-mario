extends SceneTree
## Hammer Bro: throws hammers, faces Mario, hops up (through blocks), hurts on contact,
## and is stompable / fireball-killable.
##   godot --headless --path . -s tools/test_hammerbro.gd

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
	log = FileAccess.open("user://test_hammerbro.log", FileAccess.WRITE)
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(15): await physics_frame

	say("[1] spawns from the 'hammerbro' type")
	main._enemy_defs = [{"pos": Vector2(main.player.global_position.x + 60, 13 * 16), "type": "hammerbro"}]
	# clear & respawn just our bro
	for e in main.enemies: e.queue_free()
	main.enemies.clear()
	main._spawn_enemies()
	var hb = null
	for e in main.enemies:
		if e.kind == "hammerbro": hb = e
	ok(hb != null and (hb is HammerBro), "hammer bro present")
	if hb == null:
		say("RESULT: 1 FAILURE(S)"); log.close(); quit(1); return
	hb.active = true

	say("[2] faces Mario")
	main.player.global_position.x = hb.global_position.x - 40   # Mario to the left
	await physics_frame
	await physics_frame
	ok(hb.facing == -1, "faces left toward Mario")
	main.player.global_position.x = hb.global_position.x + 40   # Mario to the right
	await physics_frame; await physics_frame
	ok(hb.facing == 1, "turns to face right")

	say("[3] throws hammers + hops onto a REAL block above, then back down")
	main.player.invuln = 999.0   # aimed hammers now KILL a still Mario -> reset frees hb; keep him safe here
	var base_center: float = hb.global_position.y
	# build a solid platform 5 tiles above the bro so it has a real block to land on
	var btx: int = int(floor(hb.global_position.x / 16.0))
	for x in range(btx - 2, btx + 3):
		main.terrain.set_cell(Vector2i(x, 8), main.SOURCE_ID, Vector2i(0, 0))
	var upper_center: float = 8 * 16 - 12.0     # feet resting on row 8
	var threw := false
	var on_upper := false
	var back := false
	for i in range(420):            # ~7s -> up + back
		await physics_frame
		if not is_instance_valid(hb): break
		if main.hammers.size() > 0: threw = true
		if absf(hb.global_position.y - upper_center) < 7.0: on_upper = true
		if on_upper and absf(hb.global_position.y - base_center) < 8.0: back = true
	ok(threw, "lobbed at least one hammer")
	ok(on_upper, "hopped UP and landed on the real block (not mid-air)")
	ok(back, "hopped back down to its level")

	say("[4] a hammer hurts the player")
	main.player.big = true; main.player.fire = false; main.player.transforming = false; main.player.invuln = 0.0
	var hurt := false
	for i in range(120):
		await physics_frame
		if main.hammers.size() > 0:
			main.hammers[0].global_position = main.player.global_position
		await physics_frame
		if main.player.transforming or not main.player.big:
			hurt = true; break
	ok(hurt, "hammer hit shrank big Mario")

	say("[5] stompable + fireball-killable")
	ok(not hb.dead, "still alive before stomp")
	hb.squish()                     # what a stomp calls
	ok(hb.dead, "dies when stomped")
	var hb2 = HammerBro.new(); hb2.main = main; main.add_child(hb2)
	hb2.spawn(Vector2(-400, 200)); hb2.active = true
	hb2.knock_out(1)
	ok(hb2.dead, "dies to a fireball/knock_out")

	say("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	if log: log.close()
	quit(fails)
