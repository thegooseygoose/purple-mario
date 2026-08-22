extends SceneTree
## Verify best-time record + persistence round-trip.
func _initialize(): call_deferred("_run")
func _run() -> void:
	Main.save_slot = 0
	Main.load_saves()
	Main.save_best[0][0] = 0.0
	Main.record_best_time(1, 42.50)      # first record for level 1
	Main.record_best_time(1, 50.00)      # slower -> ignored
	Main.record_best_time(1, 30.25)      # faster -> replaces
	Main.record_best_time(2, 88.00)
	print("in-memory  L1=", Main.save_best[0][0], " L2=", Main.save_best[0][1])
	# reload from disk to confirm it persisted
	Main.save_best = [[], [], []]
	Main.load_saves()
	print("reloaded   L1=", Main.save_best[0][0], " L2=", Main.save_best[0][1])
	quit()
