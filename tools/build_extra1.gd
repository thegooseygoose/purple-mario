extends SceneTree
## Builds res://Level9.tscn — "EXTRA 1": a short 50-wide OVERGROUND level, just 2 rows of
## ground, with the flag + castle at the end (both drawn from geometry, no tiles needed).
##   Godot_console.exe --headless --path . -s tools/build_extra1.gd
const T := 16
const ROWS := 15
const LW := 50
const FLOOR := 13

func _init() -> void:
	var ts: TileSet = load("res://tiles.tileset.tres")
	var sid: int = ts.get_source_id(0)

	var root := Node2D.new()
	root.name = "Level9"

	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = ts
	root.add_child(terrain)
	for x in range(LW):
		terrain.set_cell(Vector2i(x, FLOOR), sid, Vector2i(0, 0))       # ground row 1
		terrain.set_cell(Vector2i(x, FLOOR + 1), sid, Vector2i(0, 0))   # ground row 2

	var spawns := Node2D.new()
	spawns.name = "Spawns"
	root.add_child(spawns)
	var pstart := Marker2D.new()
	pstart.name = "PlayerStart"
	pstart.position = Vector2(3 * T + T / 2.0, FLOOR * T)
	spawns.add_child(pstart)
	var enemies := Node2D.new(); enemies.name = "Enemies"; spawns.add_child(enemies)
	var coins := Node2D.new();   coins.name = "Coins";     spawns.add_child(coins)

	_own(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://Level9.tscn")
	print("build_extra1: saved Level9.tscn (err=%d) cells=%d" % [err, terrain.get_used_cells().size()])
	quit()

func _own(n: Node, o: Node) -> void:
	for c in n.get_children():
		c.owner = o
		_own(c, o)
