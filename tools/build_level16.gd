extends SceneTree
## Builds res://Level16.tscn — WORLD 3-3: an "eerily too easy" OVERWORLD.
## Flat unbroken ground (no pits, no hazards), ONE lonely goomba then total silence,
## a freely-given power-up, generous coin trails, and empty abandoned pipes — the
## unnatural calm before the final level (3-4).
##   Godot_console.exe --headless --path . -s tools/build_level16.gd
const T := 16
const LW := 168
const FLOOR := 13          # ground top row (surface); row 14 is the second ground row

# terrain atlases
const GROUND := 0
const QUESTION := 2        # ? block (coin)
const MUSH_BLOCK := 12     # ? block that gives a mushroom / fire flower
const BRICK := 1
const STAIR := 4           # hard "staircase" block
const PIPE_LIPL := 8
const PIPE_LIPR := 9
const PIPE_BODYL := 10
const PIPE_BODYR := 11

var terrain: TileMapLayer
var etiles: TileMapLayer
var ctiles: TileMapLayer
var tsid: int
var esid: int
var csid: int

func _init() -> void:
	var ts: TileSet = load("res://tiles.tileset.tres")
	var ets: TileSet = load("res://enemy_tiles.tileset.tres")
	var cts: TileSet = load("res://coin_tiles.tileset.tres")
	tsid = ts.get_source_id(0)
	esid = ets.get_source_id(0)
	csid = cts.get_source_id(0)

	var root := Node2D.new()
	root.name = "Level16"

	terrain = TileMapLayer.new(); terrain.name = "Terrain"; terrain.tile_set = ts
	root.add_child(terrain)
	etiles = TileMapLayer.new(); etiles.name = "EnemyTiles"; etiles.tile_set = ets
	root.add_child(etiles)
	ctiles = TileMapLayer.new(); ctiles.name = "CoinTiles"; ctiles.tile_set = cts
	root.add_child(ctiles)

	# --- unbroken ground the whole way (nowhere to fall, nothing to fear) ---
	for x in range(LW):
		terrain.set_cell(Vector2i(x, FLOOR), tsid, Vector2i(GROUND, 0))
		terrain.set_cell(Vector2i(x, FLOOR + 1), tsid, Vector2i(GROUND, 0))

	# --- the ONE lonely goomba (the last thing that moves for a long while) ---
	_goomba(15)

	# --- a freely-handed-out reward cluster early: coin / POWER-UP / coin ---
	_block(22, 9, QUESTION)
	_block(24, 9, MUSH_BLOCK)     # a free mushroom (or fire flower if already big)
	_block(26, 9, QUESTION)

	# --- generous, inviting coin trails floating along the path ---
	_coin_row(32, 37, 9)
	_coin_row(46, 51, 10)
	_coin_row(62, 68, 9)
	_coin_row(82, 88, 10)
	_coin_row(100, 106, 9)
	_coin_row(118, 124, 10)

	# --- empty abandoned pipes (no piranhas — nothing lives here) ---
	_pipe(42)
	_pipe(92)
	_pipe(132, 3)     # a taller lonely pipe

	# --- a classic pre-flag staircase, trivially easy ---
	for i in range(4):
		for h in range(i + 1):
			terrain.set_cell(Vector2i(150 + i, FLOOR - 1 - h), tsid, Vector2i(STAIR, 0))

	# --- spawns ---
	var spawns := Node2D.new(); spawns.name = "Spawns"; root.add_child(spawns)
	var pstart := Marker2D.new(); pstart.name = "PlayerStart"
	pstart.position = Vector2(3 * T + T / 2.0, FLOOR * T)
	spawns.add_child(pstart)
	spawns.add_child(_named("Enemies"))
	spawns.add_child(_named("Coins"))

	_own(root, root)
	var packed := PackedScene.new(); packed.pack(root)
	var err := ResourceSaver.save(packed, "res://Level16.tscn")
	print("build_level16: saved Level16.tscn (err=%d) terrain=%d coins=%d enemies=%d" %
		[err, terrain.get_used_cells().size(), ctiles.get_used_cells().size(), etiles.get_used_cells().size()])
	quit()

func _block(x: int, y: int, atlas: int) -> void:
	terrain.set_cell(Vector2i(x, y), tsid, Vector2i(atlas, 0))

func _goomba(x: int) -> void:
	etiles.set_cell(Vector2i(x, FLOOR - 1), esid, Vector2i(0, 0))   # feet on the ground surface

func _coin_row(x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1 + 1):
		ctiles.set_cell(Vector2i(x, y), csid, Vector2i(0, 0))

func _pipe(x: int, height := 2) -> void:
	# a green pipe 2 tiles wide, `height` tall, resting on the ground
	var top := FLOOR - height
	terrain.set_cell(Vector2i(x, top), tsid, Vector2i(PIPE_LIPL, 0))
	terrain.set_cell(Vector2i(x + 1, top), tsid, Vector2i(PIPE_LIPR, 0))
	for y in range(top + 1, FLOOR):
		terrain.set_cell(Vector2i(x, y), tsid, Vector2i(PIPE_BODYL, 0))
		terrain.set_cell(Vector2i(x + 1, y), tsid, Vector2i(PIPE_BODYR, 0))

func _named(n: String) -> Node2D:
	var nd := Node2D.new(); nd.name = n; return nd

func _own(n: Node, o: Node) -> void:
	for c in n.get_children():
		c.owner = o
		_own(c, o)
