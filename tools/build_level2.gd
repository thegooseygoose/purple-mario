extends SceneTree
## Build tool (run headless): generates res://Level2.tscn — world 1-2.
## Two solid ground rows the full width, an end staircase (brick hill), and a
## PlayerStart marker. No enemies/coins. Edit the resulting scene in the editor,
## or tweak the layout here and re-run.
##   godot --headless --path <proj> -s tools/build_level2.gd

const T := 16
const FLOOR := 13
const LW := 200
const SID := 0
const ATLAS_GROUND := 0
const ATLAS_BRICK := 1
const ATLAS_QUESTION := 2
const ATLAS_STAIR := 4
# pipe atlas x: 8 lip-left, 9 lip-right, 10 body-left, 11 body-right


func _init() -> void:
	var ts = load("res://tiles.tileset.tres")

	# ---- enemy palette tileset (goomba @0, koopa @1; no collision) ----------
	var ets := TileSet.new()
	ets.tile_size = Vector2i(T, T)
	var esrc := TileSetAtlasSource.new()
	esrc.texture = load("res://sprites/enemy_tiles.png")
	esrc.texture_region_size = Vector2i(T, T)
	ets.add_source(esrc, 0)
	esrc.create_tile(Vector2i(0, 0))   # goomba
	esrc.create_tile(Vector2i(1, 0))   # koopa
	ResourceSaver.save(ets, "res://enemy_tiles.tileset.tres")

	# ---- coin palette tileset (one coin tile; no collision) ----------------
	var cts := TileSet.new()
	cts.tile_size = Vector2i(T, T)
	var csrc := TileSetAtlasSource.new()
	csrc.texture = load("res://sprites/coin_tiles.png")
	csrc.texture_region_size = Vector2i(T, T)
	cts.add_source(csrc, 0)
	csrc.create_tile(Vector2i(0, 0))   # coin
	ResourceSaver.save(cts, "res://coin_tiles.tileset.tres")

	var root := Node2D.new()
	root.name = "Level2"

	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = ts
	root.add_child(terrain)

	# paint enemies here in the editor (goomba/koopa). Hidden in-game; the real
	# enemies spawn from these cells. Kept above Terrain so its icons show on top.
	var enemy_tiles := TileMapLayer.new()
	enemy_tiles.name = "EnemyTiles"
	enemy_tiles.tile_set = ets
	root.add_child(enemy_tiles)

	# paint collectible coins here in the editor. Hidden in-game; real coins spawn.
	var coin_tiles := TileMapLayer.new()
	coin_tiles.name = "CoinTiles"
	coin_tiles.tile_set = cts
	root.add_child(coin_tiles)

	# editor-only preview of the flagpole + castle at the end (draws nothing in-game)
	var preview := Node2D.new()
	preview.name = "FlagpolePreview"
	preview.set_script(load("res://flagpole_preview.gd"))
	root.add_child(preview)

	# two solid ground rows across the whole width
	for x in range(LW):
		terrain.set_cell(Vector2i(x, FLOOR), SID, Vector2i(ATLAS_GROUND, 0))
		terrain.set_cell(Vector2i(x, FLOOR + 1), SID, Vector2i(ATLAS_GROUND, 0))

	# --- starter content (all correctly positioned; edit freely in the editor) ---
	# ? blocks (row 9 = 4 tiles above the ground surface)
	for c in [16, 20, 24]:
		terrain.set_cell(Vector2i(c, 9), SID, Vector2i(ATLAS_QUESTION, 0))
	# a row of bricks
	for c in [28, 29, 30, 31]:
		terrain.set_cell(Vector2i(c, 9), SID, Vector2i(ATLAS_BRICK, 0))
	# a 3-tall pipe at cols 36-37 (lip row 10, body rows 11-12, sitting on the ground)
	terrain.set_cell(Vector2i(36, 10), SID, Vector2i(8, 0))
	terrain.set_cell(Vector2i(37, 10), SID, Vector2i(9, 0))
	for r in [11, 12]:
		terrain.set_cell(Vector2i(36, r), SID, Vector2i(10, 0))
		terrain.set_cell(Vector2i(37, r), SID, Vector2i(11, 0))
	# coins floating over the ground (CoinTiles layer → collectible coins in-game)
	for c in [44, 45, 46]:
		coin_tiles.set_cell(Vector2i(c, 9), 0, Vector2i(0, 0))
	# enemies on the ground (EnemyTiles layer → real enemies spawn in-game)
	enemy_tiles.set_cell(Vector2i(54, 12), 0, Vector2i(0, 0))   # goomba
	enemy_tiles.set_cell(Vector2i(68, 12), 0, Vector2i(1, 0))   # koopa

	# end staircase (brick hill): 8 ascending steps just before the flag
	for i in range(8):
		for h in range(i + 1):
			terrain.set_cell(Vector2i(183 + i, FLOOR - 1 - h), SID, Vector2i(ATLAS_STAIR, 0))

	# spawns (player; enemies/coins are painted on their tile layers above)
	var spawns := Node2D.new()
	spawns.name = "Spawns"
	root.add_child(spawns)

	var pstart := Marker2D.new()
	pstart.name = "PlayerStart"
	pstart.position = Vector2(3 * T + T / 2.0, FLOOR * T)
	spawns.add_child(pstart)

	var enemies_node := Node2D.new()
	enemies_node.name = "Enemies"
	spawns.add_child(enemies_node)

	var coins_node := Node2D.new()
	coins_node.name = "Coins"
	spawns.add_child(coins_node)

	_own(root, root)
	var ps := PackedScene.new()
	ps.pack(root)
	var err := ResourceSaver.save(ps, "res://Level2.tscn")
	print("build_level2: saved Level2.tscn (err=%d), cells=%d" % [err, terrain.get_used_cells().size()])
	quit()


func _own(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_own(c, owner)
