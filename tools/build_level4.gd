extends SceneTree
## Build tool (run headless): generates res://Level4.tscn — world 1-4.
## A deliberately EMPTY level for hand-editing: 250 tiles wide, two solid rows of
## PURPLE ground (atlas 15 = more more.png B1), and a flagpole + castle at the end.
## No enemies / coins / blocks — paint your own on the layers in the editor.
##   godot --headless --path <proj> -s tools/build_level4.gd

const T := 16
const FLOOR := 13
const SID := 0
const LW := 250
const GROUND_PURPLE := 15    # more more.png B1 (purple ground)
const FLAG_X := 242
const CASTLE_X := 245

func _init() -> void:
	var ts = load("res://tiles.tileset.tres")
	var ets = load("res://enemy_tiles.tileset.tres")
	var cts = load("res://coin_tiles.tileset.tres")

	var root := Node2D.new()
	root.name = "Level4"

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

	var preview := Node2D.new()
	preview.name = "FlagpolePreview"
	preview.set_script(load("res://flagpole_preview.gd"))
	preview.set("flag_x", FLAG_X)
	preview.set("castle_x", CASTLE_X)
	root.add_child(preview)

	# two solid rows of PURPLE ground across the whole 250-tile width
	for x in range(LW):
		terrain.set_cell(Vector2i(x, FLOOR), SID, Vector2i(GROUND_PURPLE, 0))
		terrain.set_cell(Vector2i(x, FLOOR + 1), SID, Vector2i(GROUND_PURPLE, 0))

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
	var err := ResourceSaver.save(packed, "res://Level4.tscn")
	print("build_level4: saved (err=%d) LW=%d flag=%d castle=%d cells=%d" % [
		err, LW, FLAG_X, CASTLE_X, terrain.get_used_cells().size()])
	quit()

func _own(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_own(c, owner)
