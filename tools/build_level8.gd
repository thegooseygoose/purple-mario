extends SceneTree
## Build tool (run headless): generates res://Level8.tscn — world 2-4, reconstructed
## tile-for-tile from the real SMB1 2-4 map (sprites/new player/maps/level8.png) via
## the classifier that wrote tools/level8_spec.txt. Purple CASTLE block (27) for all
## brick + the firebar posts; LAVA (28 surface / 29 body) for the pits. Firebars /
## jumping lava / Bowser are assets for later — for now the fire spots are plain posts.
## Ends with a flagpole + castle instead of the Bowser bridge/Toad (per request).
##   godot --headless --path <proj> -s tools/build_level8.gd   (needs tools/level8_spec.txt)
## WARNING: re-running OVERWRITES Level8.tscn.

const T := 16
const FLOOR := 13
const CASTLE := 27
const LAVA_TOP := 28
const LAVA := 29

var LW := 160
const FLAG_X := 152
const CASTLE_X := 155
const END_FLOOR_FROM := 145   # cols from here on are a flat run to the flag (no Bowser)

var terrain: TileMapLayer
var SID := 0

func _init() -> void:
	var lines := FileAccess.get_file_as_string("res://tools/level8_spec.txt").split("\n", false)
	var hdr := lines[0].split(" ")
	var cols := int(hdr[0])
	var rows := int(hdr[1])
	LW = cols
	var grid := []
	for r in range(rows):
		grid.append(lines[1 + r])

	var ts = load("res://tiles.tileset.tres")
	var ets = load("res://enemy_tiles.tileset.tres")
	var cts = load("res://coin_tiles.tileset.tres")
	SID = ts.get_source_id(0)

	var root := Node2D.new(); root.name = "Level8"
	terrain = TileMapLayer.new(); terrain.name = "Terrain"; terrain.tile_set = ts; root.add_child(terrain)
	var etiles := TileMapLayer.new(); etiles.name = "EnemyTiles"; etiles.tile_set = ets; root.add_child(etiles)
	var ctiles := TileMapLayer.new(); ctiles.name = "CoinTiles"; ctiles.tile_set = cts; root.add_child(ctiles)
	var preview := Node2D.new(); preview.name = "FlagpolePreview"
	preview.set_script(load("res://flagpole_preview.gd"))
	preview.set("flag_x", FLAG_X); preview.set("castle_x", CASTLE_X)
	root.add_child(preview)

	# place tiles from the spec (skip HUD rows 0-1; stop main geometry before the end run)
	for r in range(2, rows):
		var line: String = grid[r]
		for x in range(min(line.length(), END_FLOOR_FROM)):
			match line[x]:
				"C", "P": t(x, r, CASTLE)      # brick + firebar posts = purple castle block
				"S": t(x, r, LAVA_TOP)
				"V": t(x, r, LAVA)
				_: pass

	# clean flat castle floor from END_FLOOR_FROM to the end → flag + castle
	for x in range(END_FLOOR_FROM, LW):
		t(x, FLOOR, CASTLE); t(x, FLOOR + 1, CASTLE)

	# --- enemies: a castle level = HAMMER BROS (atlas 5) + ledge-shy purple koopas
	# (atlas 3, which turn at the lava edges instead of walking in). Painted on the
	# EnemyTiles layer at row FLOOR-1, but only where there's real castle floor below.
	var ESID: int = ets.get_source_id(0)
	var want := [[12, 3], [18, 5], [24, 3], [40, 3], [45, 5], [50, 3], [66, 5], [72, 3],
		[78, 3], [100, 5], [106, 3], [112, 3], [132, 5], [138, 3], [143, 3]]
	for e in want:
		var col: int = e[0]
		if terrain.get_cell_source_id(Vector2i(col, FLOOR)) != -1 \
				and terrain.get_cell_atlas_coords(Vector2i(col, FLOOR)).x == CASTLE:
			etiles.set_cell(Vector2i(col, FLOOR - 1), ESID, Vector2i(e[1], 0))

	# find a safe start: the first solid tile at col 5, scanning down past the open
	# area (so Mario stands on the floor, not buried in the thick left brick block)
	var start_col := 5
	var feet_row := FLOOR
	for rr in range(6, rows):
		if grid[rr].length() > start_col and (grid[rr][start_col] == "C" or grid[rr][start_col] == "P"):
			feet_row = rr
			break

	var spawns := Node2D.new(); spawns.name = "Spawns"; root.add_child(spawns)
	var ps := Marker2D.new(); ps.name = "PlayerStart"
	ps.position = Vector2(start_col * T + T / 2.0, feet_row * T); spawns.add_child(ps)
	var en := Node2D.new(); en.name = "Enemies"; spawns.add_child(en)
	var cn := Node2D.new(); cn.name = "Coins"; spawns.add_child(cn)

	_own(root, root)
	var packed := PackedScene.new(); packed.pack(root)
	var err := ResourceSaver.save(packed, "res://Level8.tscn")
	print("build_level8: saved (err=%d) cols=%d terrain=%d" % [err, LW, terrain.get_used_cells().size()])
	quit()

func t(x: int, row: int, ax: int) -> void:
	terrain.set_cell(Vector2i(x, row), SID, Vector2i(ax, 0))

func _own(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_own(c, owner)
