extends SceneTree
## Builds res://Level12.tscn — an UNDERGROUND blank stage (dark bg + underground music are set
## in LEVEL_GEOMETRY[12]). 400 tiles wide, two solid rows of ground (atlas 0). Editable: paint
## your own enemies/coins/blocks on the layers in the Godot editor.
##   godot --headless --path <proj> -s tools/build_level12.gd
const T := 16
const FLOOR := 13
const SID := 0
const LW := 400
const GROUND := 0

func _init() -> void:
	var ts = load("res://tiles.tileset.tres")
	var ets = load("res://enemy_tiles.tileset.tres")
	var cts = load("res://coin_tiles.tileset.tres")
	var root := Node2D.new()
	root.name = "Level12"
	var terrain := TileMapLayer.new(); terrain.name = "Terrain"; terrain.tile_set = ts
	root.add_child(terrain)
	var enemy_tiles := TileMapLayer.new(); enemy_tiles.name = "EnemyTiles"; enemy_tiles.tile_set = ets
	root.add_child(enemy_tiles)
	var coin_tiles := TileMapLayer.new(); coin_tiles.name = "CoinTiles"; coin_tiles.tile_set = cts
	root.add_child(coin_tiles)
	for x in range(LW):
		terrain.set_cell(Vector2i(x, FLOOR), SID, Vector2i(GROUND, 0))
		terrain.set_cell(Vector2i(x, FLOOR + 1), SID, Vector2i(GROUND, 0))
	var spawns := Node2D.new(); spawns.name = "Spawns"; root.add_child(spawns)
	var pstart := Marker2D.new(); pstart.name = "PlayerStart"
	pstart.position = Vector2(3 * T + T / 2.0, FLOOR * T); spawns.add_child(pstart)
	var en := Node2D.new(); en.name = "Enemies"; spawns.add_child(en)
	var co := Node2D.new(); co.name = "Coins"; spawns.add_child(co)
	_own(root, root)
	var packed := PackedScene.new(); packed.pack(root)
	var err := ResourceSaver.save(packed, "res://Level12.tscn")
	print("build_level12: saved (err=%d) LW=%d cells=%d" % [err, LW, terrain.get_used_cells().size()])
	quit()

func _own(n: Node, o: Node) -> void:
	for c in n.get_children():
		c.owner = o
		_own(c, o)
