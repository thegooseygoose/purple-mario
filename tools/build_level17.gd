extends SceneTree
## Builds res://Level17.tscn — WORLD 3-4: the FINAL LEVEL, a blank editable overworld
## starter (2 rows of ground, full-width) for the user to build out in the Godot editor.
## Layers Terrain / EnemyTiles / CoinTiles are all present so the palettes work.
##   Godot_console.exe --headless --path . -s tools/build_level17.gd
const T := 16
const LW := 220
const FLOOR := 13

func _init() -> void:
	var ts: TileSet = load("res://tiles.tileset.tres")
	var ets: TileSet = load("res://enemy_tiles.tileset.tres")
	var cts: TileSet = load("res://coin_tiles.tileset.tres")
	var tsid: int = ts.get_source_id(0)

	var root := Node2D.new(); root.name = "Level17"

	var terrain := TileMapLayer.new(); terrain.name = "Terrain"; terrain.tile_set = ts
	root.add_child(terrain)
	var etiles := TileMapLayer.new(); etiles.name = "EnemyTiles"; etiles.tile_set = ets
	root.add_child(etiles)
	var ctiles := TileMapLayer.new(); ctiles.name = "CoinTiles"; ctiles.tile_set = cts
	root.add_child(ctiles)

	for x in range(LW):
		terrain.set_cell(Vector2i(x, FLOOR), tsid, Vector2i(0, 0))
		terrain.set_cell(Vector2i(x, FLOOR + 1), tsid, Vector2i(0, 0))

	var spawns := Node2D.new(); spawns.name = "Spawns"; root.add_child(spawns)
	var pstart := Marker2D.new(); pstart.name = "PlayerStart"
	pstart.position = Vector2(3 * T + T / 2.0, FLOOR * T)
	spawns.add_child(pstart)
	var en := Node2D.new(); en.name = "Enemies"; spawns.add_child(en)
	var co := Node2D.new(); co.name = "Coins"; spawns.add_child(co)

	_own(root, root)
	var packed := PackedScene.new(); packed.pack(root)
	var err := ResourceSaver.save(packed, "res://Level17.tscn")
	print("build_level17: saved Level17.tscn (err=%d) cells=%d" % [err, terrain.get_used_cells().size()])
	quit()

func _own(n: Node, o: Node) -> void:
	for c in n.get_children():
		c.owner = o
		_own(c, o)
