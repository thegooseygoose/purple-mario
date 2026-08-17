extends SceneTree
## Adds enemies to res://Level8.tscn IN PLACE (preserves the user's terrain edits) —
## only on a real standable floor with 2 empty rows above (never inside a block / over lava).
func _initialize(): call_deferred("_go")

func _solid(terr, x, y) -> bool:
	if y < 0 or y > 14: return false
	var c = Vector2i(x, y)
	if terr.get_cell_source_id(c) == -1: return false
	var a = terr.get_cell_atlas_coords(c).x
	return a != 28 and a != 29          # lava isn't standable

func _empty(terr, x, y) -> bool:
	if y < 0 or y > 14: return true
	return terr.get_cell_source_id(Vector2i(x, y)) == -1

# lowest floor in this column with 2 clear rows above -> the enemy CELL row (feet on floor)
func _stand(terr, x) -> int:
	for fr in range(14, 3, -1):
		if _solid(terr, x, fr) and _empty(terr, x, fr - 1) and _empty(terr, x, fr - 2):
			return fr - 1
	return -1

func _go():
	var root = load("res://Level8.tscn").instantiate()
	var terr = root.get_node("Terrain")
	var et = root.get_node("EnemyTiles")
	var esid = et.tile_set.get_source_id(0)
	# columns already holding an enemy (keep clear of them)
	var taken = []
	for c in et.get_used_cells(): taken.append(c.x)
	var placed = 0; var i = 0; var report = []
	var last = -999
	for x in range(12, 148, 6):
		var cy = _stand(terr, x)
		if cy < 0: continue
		if x - last < 9: continue                 # spacing so they don't clump
		var clash = false
		for tx in taken:
			if absf(tx - x) < 6: clash = true
		if clash: continue
		var atlas = 5 if (i % 3 == 1) else 3      # ~1 hammer bro per 2 koopas
		et.set_cell(Vector2i(x, cy), esid, Vector2i(atlas, 0))
		report.append("%s @col%d row%d (stands on floor row %d)" % ["hammerbro" if atlas == 5 else "pkoopa", x, cy, cy + 1])
		placed += 1; i += 1; last = x
	var packed = PackedScene.new(); packed.pack(root)
	var err = ResourceSaver.save(packed, "res://Level8.tscn")
	print("ADDED %d enemies (err=%d):" % [placed, err])
	for r in report: print("  ", r)
	quit()
