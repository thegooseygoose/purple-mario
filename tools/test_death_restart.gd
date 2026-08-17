extends SceneTree
## Repro + fix check: dying, then restarting (R) or warping mid-death must spawn a
## clean, alive Mario — NOT one still falling through the floor in the death anim.
##   godot --headless --path . -s tools/test_death_restart.gd

var fails := 0
var log: FileAccess
func say(s: String) -> void:
	print(s)
	if log: log.store_line(s); log.flush()
func ok(c: bool, m: String) -> void:
	say(("  PASS " if c else "  FAIL ") + m)
	if not c: fails += 1

func _initialize(): call_deferred("_run")

func _check(main, label: String, from_pit: bool) -> void:
	# let Mario settle on the ground, then kill him
	for i in range(30): await physics_frame
	main.player.kill(from_pit)
	for i in range(8): await physics_frame       # a few frames INTO the death anim
	ok(main.player.dead, "%s: Mario is dead mid-sequence" % label)
	ok(not main.player.get_collision_mask_value(1), "%s: world collision off during death" % label)
	# simulate pressing R (or a stage warp) — reset re-spawns
	main.reset(true)
	for i in range(45): await physics_frame      # let the fresh Mario settle
	ok(not main.player.dead, "%s: fresh Mario is ALIVE after restart" % label)
	ok(main.player.get_collision_mask_value(1), "%s: world collision restored" % label)
	ok(main.player.is_on_floor(), "%s: standing on the floor (didn't fall through)" % label)
	ok(main.player.global_position.y < 240, "%s: not fallen off-screen (y=%.0f)" % [label, main.player.global_position.y])

func _run() -> void:
	log = FileAccess.open("user://test_death_restart.log", FileAccess.WRITE)
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(10): await physics_frame

	say("[A] enemy-hit death, then restart")
	await _check(main, "enemy-death", false)

	say("[B] pit death, then restart")
	await _check(main, "pit-death", true)

	say("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	if log: log.close()
	quit(fails)
