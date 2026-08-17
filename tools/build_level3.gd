extends SceneTree
## Build tool (run headless): generates res://Level3.tscn — world 1-3.
## Reads tools/level3_spec.txt (produced from sprites/new player/level 3.png) and
## paints the Terrain + CoinTiles layers, adds an editable EnemyTiles layer, the
## flagpole preview, and the player spawn. Mirrors build_level2.gd.
##   godot --headless --path <proj> -s tools/build_level3.gd

const T := 16
const FLOOR := 13
const SID := 0

func _init() -> void:
	var ts = load("res://tiles.tileset.tres")
	var ets = load("res://enemy_tiles.tileset.tres")
	var cts = load("res://coin_tiles.tileset.tres")

	# --- read the spec ------------------------------------------------------
	var f := FileAccess.open("res://tools/level3_spec.txt", FileAccess.READ)
	if f == null:
		push_error("level3_spec.txt not found"); quit(); return
	var lw := 0
	var ps_col := 3
	var flag_x := 0
	var castle_x := 0
	var terrain_cells: Array = []   # [Vector2i, atlas_x]
	var coin_cells: Array = []      # Vector2i
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var p := line.split(" ")
		match p[0]:
			"W": lw = int(p[1])
			"PS": ps_col = int(p[1])
			"FLAG": flag_x = int(p[1])
			"CASTLE": castle_x = int(p[1])
			"T": terrain_cells.append([Vector2i(int(p[1]), int(p[2])), int(p[3])])
			"C": coin_cells.append(Vector2i(int(p[1]), int(p[2])))
	f.close()

	# --- scene tree ---------------------------------------------------------
	var root := Node2D.new()
	root.name = "Level3"

	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = ts
	root.add_child(terrain)

	var enemy_tiles := TileMapLayer.new()   # paint enemies in the editor
	enemy_tiles.name = "EnemyTiles"
	enemy_tiles.tile_set = ets
	root.add_child(enemy_tiles)

	var coin_tiles := TileMapLayer.new()
	coin_tiles.name = "CoinTiles"
	coin_tiles.tile_set = cts
	root.add_child(coin_tiles)

	var preview := Node2D.new()
	preview.name = "FlagpolePreview"
	preview.set_script(load("res://flagpole_preview.gd"))
	preview.set("flag_x", flag_x)
	preview.set("castle_x", castle_x)
	root.add_child(preview)

	# paint terrain
	for tc in terrain_cells:
		terrain.set_cell(tc[0], SID, Vector2i(tc[1], 0))
	# paint coins onto the CoinTiles layer
	for cc in coin_cells:
		coin_tiles.set_cell(cc, 0, Vector2i(0, 0))

	# spawns
	var spawns := Node2D.new()
	spawns.name = "Spawns"
	root.add_child(spawns)
	var pstart := Marker2D.new()
	pstart.name = "PlayerStart"
	pstart.position = Vector2(ps_col * T + T / 2.0, FLOOR * T)
	spawns.add_child(pstart)
	var enemies_node := Node2D.new()
	enemies_node.name = "Enemies"
	spawns.add_child(enemies_node)
	var coins_node := Node2D.new()
	coins_node.name = "Coins"
	spawns.add_child(coins_node)

	_own(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://Level3.tscn")
	print("build_level3: saved (err=%d) LW=%d flag=%d castle=%d terrain=%d coins=%d" % [
		err, lw, flag_x, castle_x, terrain_cells.size(), coin_cells.size()])
	quit()

func _own(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_own(c, owner)
