extends SceneTree
func _init():
	Main.debug_start_level = 15
	var m = load("res://Main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	var dk = m.dks[0]
	print("LW=", m.LW, " DK col=", int(dk.global_position.x/16), " spawners=", m.barrel_spawners.size())
	# simulate Mario walking right across the level; count barrel spawns + DK b1 activations
	var totalbarrels = 0
	var b1count = 0
	var wasb1 = false
	for col in range(0, m.LW):
		m.player.global_position.x = col*16+8
		m.player.velocity = Vector2.ZERO
		for f in range(6):   # a few frames per step
			await process_frame
			totalbarrels = max(totalbarrels, m._dk_total if false else totalbarrels)
			var isb1 = (dk.sprite.texture == m.tex["dk_b1"])
			if isb1 and not wasb1: b1count += 1
			wasb1 = isb1
	print("barrels currently alive at end=", m.barrels.size(), " DK entered b1 ", b1count, " times during the walk")
	quit()
