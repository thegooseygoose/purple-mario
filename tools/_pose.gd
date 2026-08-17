extends SceneTree
func _init():
	Main.debug_start_level = 15
	var m = load("res://Main.tscn").instantiate(); root.add_child(m)
	await process_frame; await process_frame
	while m.game_state == "emerge": await process_frame
	m._start_axe_ending()
	var f=0; var arrived_grounded=null; var arrived_pose=""
	var was_walking=false
	while m.game_state != "clear" and f<3000:
		await process_frame; f+=1
		if m.game_state=="rescue":
			if m.rescue_walking: was_walking=true
			if was_walking and not m.rescue_walking and arrived_grounded==null:
				arrived_grounded = m.player.grounded
				arrived_pose = m.player._pose_key_flip()[0]
	print("on arrival: grounded=", arrived_grounded, " pose=", arrived_pose, " (want _stand_*)")
	print("final: state=", m.game_state, " mario_y=", m.player.global_position.y)
	quit()
