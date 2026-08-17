extends SceneTree
## Pause menu + independent Music/SFX volume buses.
##   godot --headless --path . -s tools/test_pause.gd

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
	log = FileAccess.open("user://test_pause.log", FileAccess.WRITE)
	var main = load("res://Main.tscn").instantiate()
	get_root().add_child(main)
	for i in range(10): await physics_frame

	say("[1] Music and SFX buses exist and route to Master")
	var mb := AudioServer.get_bus_index("Music")
	var sb := AudioServer.get_bus_index("SFX")
	ok(mb >= 0, "Music bus exists")
	ok(sb >= 0, "SFX bus exists")
	ok(AudioServer.get_bus_send(mb) == "Master", "Music -> Master")
	ok(AudioServer.get_bus_send(sb) == "Master", "SFX -> Master")

	say("[2] music player on Music bus; the level music keeps playing while paused")
	ok(main.music_player.bus == "Music", "music_player routed to Music bus")
	main.toggle_pause()
	ok(main.paused, "toggle_pause() paused the game")
	ok(not main.music_player.stream_paused, "level music NOT frozen during pause")

	say("[3] Left/Right adjusts only the selected slider")
	main.pause_sel = 0
	main.music_volume = 1.0
	main.sfx_volume = 1.0
	main._adjust_volume(-main.VOL_STEP)
	ok(abs(main.music_volume - 0.9) < 0.001, "music slider -> 0.9")
	ok(abs(main.sfx_volume - 1.0) < 0.001, "sfx slider untouched")
	# bus volume reflects the new level
	var want_db: float = linear_to_db(0.9)
	ok(abs(AudioServer.get_bus_volume_db(mb) - want_db) < 0.01, "Music bus dB matches 0.9")

	say("[4] selecting SOUND adjusts sfx, clamps at 0, and mutes the bus at 0")
	main.pause_sel = 1
	for i in range(15): main._adjust_volume(-main.VOL_STEP)   # drive well past 0
	ok(main.sfx_volume <= 0.0001, "sfx clamps at 0")
	ok(AudioServer.is_bus_mute(sb), "SFX bus muted at 0 volume")
	main._adjust_volume(main.VOL_STEP)
	ok(main.sfx_volume > 0.0 and not AudioServer.is_bus_mute(sb), "raising off 0 unmutes")

	say("[5] settings persist to disk")
	main.music_volume = 0.4; main.sfx_volume = 0.7
	main._save_settings()
	var cfg := ConfigFile.new()
	ok(cfg.load(main.SETTINGS_PATH) == OK, "settings.cfg written")
	ok(abs(float(cfg.get_value("audio", "music", -1)) - 0.4) < 0.001, "music saved 0.4")
	ok(abs(float(cfg.get_value("audio", "sfx", -1)) - 0.7) < 0.001, "sfx saved 0.7")

	say("[6] ESC / P both resume (after the debounce window)")
	await physics_frame
	main._paused_at = 0   # bypass the 200ms debounce for the test
	main.toggle_pause()
	ok(not main.paused, "toggle_pause() resumed")

	say("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	if log: log.close()
	quit(fails)
