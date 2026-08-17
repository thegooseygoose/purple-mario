extends SceneTree
## A goomba dropped straight onto another must NOT clip/stack — they push apart and
## walk away from each other.
##   godot --headless --path . -s tools/test_stack.gd

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
	log = FileAccess.open("user://test_stack.log", FileAccess.WRITE)
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(12): await physics_frame

	# a floor in empty space
	var body := StaticBody2D.new()
	body.collision_layer = 1; body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new(); r.size = Vector2(300, 40)
	cs.shape = r; cs.position = Vector2(-200, 120)     # top at y=100
	body.add_child(cs)
	main.add_child(body)

	var Enemy = load("res://enemy.gd")
	var a = Enemy.new(); a.main = main; a.kind = "goomba"
	main.add_child(a); main.enemies.append(a)
	a.spawn(Vector2(-200, 100)); a.active = true       # on the floor
	var b = Enemy.new(); b.main = main; b.kind = "goomba"
	main.add_child(b); main.enemies.append(b)
	b.spawn(Vector2(-200, 60)); b.active = true        # dropped straight above A

	# watch how much they overlap while B falls in, and where they end up
	var max_overlap := 0.0
	for i in range(60):
		await physics_frame
		if not (is_instance_valid(a) and is_instance_valid(b)): break
		var ar: Rect2 = a.get_rect(); var br: Rect2 = b.get_rect()
		if ar.intersects(br):
			var ox = minf(ar.end.x, br.end.x) - maxf(ar.position.x, br.position.x)
			max_overlap = maxf(max_overlap, ox)

	say("[1] the two goombas separate instead of clipping")
	ok(is_instance_valid(a) and is_instance_valid(b), "both goombas still alive (neither clipped away)")
	var gap: float = absf(a.global_position.x - b.global_position.x)
	ok(gap >= 13.0, "ended up side-by-side, not overlapping (x gap=%.1f, width 14)" % gap)
	ok(not a.get_rect().intersects(b.get_rect()), "their hitboxes no longer overlap")
	say("  (peak horizontal overlap during the drop was %.1fpx)" % max_overlap)

	say("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	if log: log.close()
	quit(fails)
