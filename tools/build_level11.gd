extends SceneTree
## Build tool (run headless): generates res://Level11.tscn.
## A blank starter: 30 tiles wide, two solid rows of ground (atlas 0). No flag/enemies/
## coins — paint your own on the EnemyTiles / CoinTiles layers in the editor.
##   godot --headless --path <proj> -s tools/build_level11.gd
const T := 16
const FLOOR := 13
const SID := 0
const LW := 30
const GROUND := 0            # atlas 0 = standard ground tile

func _init() -> void:
	var ts = load("res://tiles.tileset.tres")
	var ets = load("res://enemy_tiles.tileset.tres")
	var cts = load("res://coin_tiles.tileset.tres")

	var root := Node2D.new()
	root.name = "Level11"

	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = ts
	root.add_child(terrain)

	var enemy_tiles := TileMapLayer.new()   # paint enemies here in the editor
	enemy_tiles.name = "EnemyTiles"
	enemy_tiles.tile_set = ets
	root.add_child(enemy_tiles)

	var coin_tiles := TileMapLayer.new()    # paint coins here in the editor
	coin_tiles.name = "CoinTiles"
	coin_tiles.tile_set = cts
	root.add_child(coin_tiles)

	# two solid rows of ground across the whole 30-tile width
	for x in range(LW):
		terrain.set_cell(Vector2i(x, FLOOR), SID, Vector2i(GROUND, 0))
		terrain.set_cell(Vector2i(x, FLOOR + 1), SID, Vector2i(GROUND, 0))

	# spawns (player start; enemies/coins are painted on their tile layers above)
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
	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://Level11.tscn")
	print("build_level11: saved (err=%d) LW=%d cells=%d" % [err, LW, terrain.get_used_cells().size()])
	quit()

func _own(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_own(c, owner)
