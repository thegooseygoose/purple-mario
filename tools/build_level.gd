extends SceneTree
## Build tool (run headless): generates res://tiles.tileset.tres and
## res://Level1.tscn — a TileMapLayer holding the whole first level (with
## per-tile collision) plus a Spawns node of Marker2D points for the player,
## enemies and coins.
##   godot --headless --path <proj> -s tools/build_level.gd

const T := 16
const ROWS := 15
const LW := 214
const FLOOR := 13
const FLAG_X := 198
const CASTLE_X := 202

# char -> atlas x (pipes handled separately by orientation)
const ATLAS := {
	"X": 0, "B": 1, "?": 2, "U": 3, "S": 4, "T": 5, "H": 6, "C": 7, "M": 12,
}

var grid: Array = []


func _init() -> void:
	_build_grid()

	# ---- TileSet ---------------------------------------------------------
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)   # world layer
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://tiles.png")
	src.texture_region_size = Vector2i(T, T)
	var sid := ts.add_source(src, 0)
	var box := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for i in range(13):
		var coord := Vector2i(i, 0)
		src.create_tile(coord)
		var td := src.get_tile_data(coord, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, box)
	ResourceSaver.save(ts, "res://tiles.tileset.tres")

	# ---- Level scene -----------------------------------------------------
	var root := Node2D.new()
	root.name = "Level1"

	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = ts
	root.add_child(terrain)
	for r in range(ROWS):
		for x in range(LW):
			var c: String = grid[r][x]
			if c == " ":
				continue
			var ax := _atlas_x(c, x, r)
			terrain.set_cell(Vector2i(x, r), sid, Vector2i(ax, 0))

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
	var enemy_defs := [
		[13, "goomba"], [33, "goomba"], [42, "goomba"],
		[51, "goomba"], [53, "goomba"], [62, "goomba"], [64, "goomba"],
		[78, "goomba"], [80, "goomba"], [92, "goomba"], [94, "goomba"],
		[103, "goomba"], [105, "goomba"], [121, "goomba"], [123, "goomba"],
		[127, "koopa"], [160, "goomba"], [172, "koopa"],
	]
	var ei := 0
	for d in enemy_defs:
		var m := Marker2D.new()
		m.name = "Enemy%d" % ei
		m.position = Vector2(d[0] * T + T / 2.0, FLOOR * T)
		m.set_meta("type", d[1])
		enemies_node.add_child(m)
		ei += 1

	var coins_node := Node2D.new()
	coins_node.name = "Coins"
	spawns.add_child(coins_node)
	var coin_defs := [
		[79, 9], [82, 9], [83, 9], [107, 9], [108, 9], [109, 9],
	]  # [col, tiles above ground]
	var ci := 0
	for d in coin_defs:
		var m := Marker2D.new()
		m.name = "Coin%d" % ci
		m.position = Vector2(d[0] * T, (FLOOR - d[1]) * T)
		coins_node.add_child(m)
		ci += 1

	_own(root, root)
	var ps := PackedScene.new()
	ps.pack(root)
	var err := ResourceSaver.save(ps, "res://Level1.tscn")
	print("build_level: saved Level1.tscn (err=%d), cells=%d" % [err, terrain.get_used_cells().size()])
	quit()


func _atlas_x(c: String, x: int, r: int) -> int:
	if c == "P":
		var is_right: bool = x > 0 and grid[r][x - 1] == "P"
		var is_top: bool = r == 0 or grid[r - 1][x] != "P"
		if is_top:
			return 9 if is_right else 8
		return 11 if is_right else 10
	return ATLAS[c]


func _own(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_own(c, owner)


# =========================================================================
# level construction (ported 1:1 from the original)
# =========================================================================
func _put(x: int, y: int, c: String) -> void:
	if x >= 0 and x < LW and y >= 0 and y < ROWS:
		grid[y][x] = c

func _up(n: int) -> int:
	return FLOOR - n

func _pipe(x: int, h: int) -> void:
	for i in range(h):
		_put(x, FLOOR - 1 - i, "P")
		_put(x + 1, FLOOR - 1 - i, "P")

func _stair(x: int, h: int) -> void:
	for i in range(h):
		_put(x, FLOOR - 1 - i, "S")

func _build_grid() -> void:
	grid = []
	for r in range(ROWS):
		var row := []
		for x in range(LW):
			row.append(" ")
		grid.append(row)

	var pits := [[69, 70], [86, 87, 88], [152, 153, 154]]
	for x in range(LW):
		var in_pit := false
		for p in pits:
			if x in p:
				in_pit = true
				break
		if in_pit:
			continue
		_put(x, FLOOR, "X")
		_put(x, FLOOR + 1, "X")

	_put(16, _up(4), "?")
	_put(20, _up(4), "B"); _put(21, _up(4), "?"); _put(22, _up(4), "M")
	_put(23, _up(4), "?"); _put(24, _up(4), "B")
	_put(22, _up(8), "?")

	_pipe(28, 2); _pipe(38, 3); _pipe(46, 4); _pipe(57, 4)

	_put(73, _up(4), "M")
	_put(77, _up(4), "B"); _put(78, _up(4), "?"); _put(79, _up(4), "B")
	for x in range(80, 86):
		_put(x, _up(8), "B")
	_put(89, _up(8), "B"); _put(90, _up(8), "B"); _put(91, _up(8), "B")
	_put(91, _up(4), "?")

	_put(126, _up(4), "?"); _put(127, _up(4), "?"); _put(128, _up(4), "?")
	_put(127, _up(8), "M")

	_put(106, _up(4), "B"); _put(107, _up(4), "?"); _put(108, _up(4), "B")
	_put(109, _up(4), "?"); _put(110, _up(4), "B")

	_pipe(112, 3); _pipe(116, 3)

	_stair(134, 1); _stair(135, 2); _stair(136, 3); _stair(137, 4)
	_stair(140, 4); _stair(141, 3); _stair(142, 2); _stair(143, 1)
	_stair(148, 1); _stair(149, 2); _stair(150, 3); _stair(151, 4)
	_stair(155, 4); _stair(156, 3); _stair(157, 2); _stair(158, 1)

	_pipe(163, 2)
	_put(168, _up(4), "B"); _put(169, _up(4), "?"); _put(170, _up(4), "B")

	for i in range(8):
		_stair(181 + i, i + 1)

	_put(FLAG_X, FLOOR - 1, "T")
	for r in range(2, 12):
		_put(FLAG_X, FLOOR - r, "H")

	# The castle is drawn as a sprite (tile_renderer._draw_castle), not tiles —
	# baking "C" tiles here would show through the sprite's transparent gaps.
	# (main._clear_castle_tiles() also erases any that remain in older scenes.)
