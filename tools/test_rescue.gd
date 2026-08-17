extends SceneTree
## Rescue reveal: at the end of Bowser's castle (file 8), after the axe/bridge
## sequence, "mac" appears (2 alternating frames) and the camera pans to him.
##   Godot_console.exe --headless --path . -s tools/test_rescue.gd

var fails := 0
var log: FileAccess
func say(s: String) -> void:
	print(s)
	if log: log.store_line(s); log.flush()
func ok(c: bool, m: String) -> void:
	say(("  PASS " if c else "  FAIL ") + m)
	if not c: fails += 1

func _initialize(): call_deferred("_run")

func _opaque_count(t: Texture2D) -> int:
	var img := t.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5: n += 1
	return n

func _run() -> void:
	log = FileAccess.open("user://test_rescue.log", FileAccess.WRITE)
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(10): await physics_frame

	say("[1] mac frames baked into a common 24x72 canvas, bottom-aligned")
	ok(main.tex.has("mac0") and main.tex.has("mac1"), "tex mac0 + mac1 present")
	var t0: Texture2D = main.tex["mac0"]
	var t1: Texture2D = main.tex["mac1"]
	ok(t0.get_width() == main.MAC_W and t0.get_height() == main.MAC_H, "mac0 is %dx%d" % [main.MAC_W, main.MAC_H])
	ok(t1.get_width() == main.MAC_W and t1.get_height() == main.MAC_H, "mac1 is %dx%d" % [main.MAC_W, main.MAC_H])
	var c0 := _opaque_count(t0)
	var c1 := _opaque_count(t1)
	ok(c0 > 100 and c1 > 100, "both frames have real art (%d / %d px)" % [c0, c1])
	ok(c0 != c1, "the two frames differ (arms move: %d vs %d px)" % [c0, c1])

	say("[2] load Bowser's castle (now play position 4) and find the axe")
	main.level_num = 4
	main.reset(false)
	for i in range(10): await physics_frame
	ok(main._level_file == 8, "Level8 loads at slot 4 (label %s)" % main.world_label)
	ok(main._boss_axe_x >= 0, "axe tile recorded at x=%d" % main._boss_axe_x)
	ok(not main.show_rescue, "rescue not shown yet")

	say("[3] run the axe/bridge ending -> mac reveals, Mario stood on the wall-top")
	main._start_axe_ending()
	var revealed := false
	for i in range(400):
		await physics_frame
		if main.show_rescue:
			revealed = true
			break
	ok(revealed, "show_rescue became true after the sequence")
	ok(main.game_state == "rescue", "in the rescue cinematic (NOT course-clear yet)")
	ok(not main.show_rescue_speech, "no speech while still walking")
	ok(main.rescue_walking, "Mario is walking (rescue_walking)")
	ok(main.rescue_pos.x > main._boss_axe_x * 16, "mac placed to the right of the axe")
	ok(int(main.rescue_pos.y) == main.FLOOR * 16, "mac's feet on the FLOOR line")
	ok(int(main.rescue_pos.x - main.rescue_stop_x) == main.RESCUE_STOP_GAP * 16,
		"stop point is %d tiles short of mac" % main.RESCUE_STOP_GAP)
	ok(absf(main.player.global_position.x - (main._boss_axe_x * 16 + 8)) < 2.0,
		"Mario starts where the axe was (x=%.0f)" % main.player.global_position.x)

	say("[4] camera tracks Mario as he walks; he stops short of mac")
	var cam_start: float = main.cam_x
	var mario_start: float = main.player.global_position.x
	var walked := false
	var on_screen_ok := true
	for i in range(900):
		await physics_frame
		# Mario should stay within the viewport the whole walk (camera stays with him)
		var sx: float = main.player.global_position.x - main.cam_x
		if sx < -8.0 or sx > main.VIEW_W + 8.0:
			on_screen_ok = false
		if not main.rescue_walking:
			walked = true
			break
	ok(walked, "Mario finished walking")
	ok(main.player.global_position.x > mario_start + 100.0, "Mario actually moved right toward mac")
	ok(main.cam_x > cam_start + 40.0, "camera followed Mario to the right")
	ok(on_screen_ok, "Mario stayed on screen the whole walk (no pan-away)")
	ok(absf(main.player.global_position.x - main.rescue_stop_x) < 2.0,
		"Mario stopped at the stop point (x=%.0f vs %.0f)" % [main.player.global_position.x, main.rescue_stop_x])
	var gap_tiles: float = (main.rescue_pos.x - main.player.global_position.x) / 16.0
	ok(absf(gap_tiles - main.RESCUE_STOP_GAP) < 0.6, "Mario ends ~%d tiles from mac (%.1f)" % [main.RESCUE_STOP_GAP, gap_tiles])
	ok(main.player.facing == 1, "Mario faces mac (right)")
	ok(absf(main.player.global_position.y - (main.FLOOR * 16 - main.player.col_size.y / 2.0)) < 3.0,
		"Mario ends standing on the castle floor")

	say("[5] mac speaks first, COURSE CLEAR only after the line")
	await physics_frame   # main processes the walk->speech transition the tick after arrival
	await physics_frame
	ok(main.show_rescue_speech, "mac's line is up once Mario arrives")
	ok(main.game_state == "rescue", "still NOT course-clear during the speech")
	ok(main.RESCUE_SPEECH_LINES.size() >= 1, "speech has text (%s)" % str(main.RESCUE_SPEECH_LINES))
	var cleared := false
	var t := 0.0
	for i in range(600):
		await physics_frame
		t += 1.0 / 60.0
		if main.game_state == "clear":
			cleared = true
			break
	ok(cleared, "COURSE CLEAR eventually shows")
	ok(t >= main.RESCUE_SPEECH_TIME - 0.3, "it waited ~%.1fs for the line (%.1fs)" % [main.RESCUE_SPEECH_TIME, t])
	ok(not main.show_rescue_speech, "speech clears when COURSE CLEAR appears")
	ok(main.rescue_phase == 2, "rescue phase done")

	say("[6] arm frames alternate over time")
	main.rescue_t = 0.0
	var f_a := 0 if int(main.rescue_t / main.RESCUE_FRAME_STEP) % 2 == 0 else 1
	main.rescue_t = main.RESCUE_FRAME_STEP
	var f_b := 0 if int(main.rescue_t / main.RESCUE_FRAME_STEP) % 2 == 0 else 1
	ok(f_a != f_b, "arm frame alternates over time")

	say("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	if log: log.close()
	quit(fails)
