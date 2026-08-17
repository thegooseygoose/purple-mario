extends SceneTree
## Build tool (run headless): generates res://Level6.tscn (world 1-6) and
## res://Level7.tscn (world 2-1). Both are deliberately EMPTY starters for hand-
## editing: 200 tiles wide, two solid rows of ORANGE ground (atlas 0), a flagpole
## + castle at the end, night-sky theme (NOT underground). No enemies / coins /
## blocks — paint your own on the layers in the editor.
##   godot --headless --path <proj> -s tools/build_levels_67.gd
## WARNING: re-running this OVERWRITES both scenes (wipes any editor edits).

const T := 16
const FLOOR := 13
const SID := 0
const LW := 200
const GROUND := 0            # orange (non-purple) ground
const FLAG_X := 192
const CASTLE_X := 195

func _init() -> void:
	_build("Level6", "res://Level6.tscn")
	_build("Level7", "res://Level7.tscn")
	quit()

func _build(scene_name: String, path: String) -> void:
	var ts = load("res://tiles.tileset.tres")
	var ets = load("res://enemy_tiles.tileset.tres")
	var cts = load("res://coin_tiles.tileset.tres")

	var root := Node2D.new()
	root.name = scene_name

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

	# two solid rows of ORANGE ground across the whole 200-tile width
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
	var err := ResourceSaver.save(packed, path)
	print("built %s: saved (err=%d) LW=%d flag=%d castle=%d cells=%d" % [
		path, err, LW, FLAG_X, CASTLE_X, terrain.get_used_cells().size()])

func _own(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_own(c, owner)
