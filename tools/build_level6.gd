extends SceneTree
## Build tool (run headless): generates a DESIGNED res://Level6.tscn — world 1-6.
## 200 tiles wide, night-sky. A full hand-designed course: intro coins, a piranha
## pipe row, a pit with a coin arc, a ledge-shy purple koopa on a floating platform,
## a stair pyramid, a purple pipe, a brick-ceiling coin room, a pit gauntlet, and an
## SMB1-style end staircase to the flag. Uses the shared tilesets (paintable/editable
## afterward like the other levels).
##   godot --headless --path <proj> -s tools/build_level6.gd
## WARNING: re-running OVERWRITES Level6.tscn (wipes editor edits). This is the
## authoritative builder for 1-6 (supersedes build_levels_67.gd for level 6).

const T := 16
const FLOOR := 13
const LW := 200
const FLAG_X := 192
const CASTLE_X := 195

# terrain atlas x
const GROUND := 0
const BRICK := 1
const Q := 2           # ? coin block
const STAIR := 4
const MUSH := 12       # ? mushroom block
const ALTCOIN := 23
const ALTMUSH := 24
# enemy atlas x (EnemyTiles): 0 goomba, 1 koopa, 2 purple goomba, 3 purple koopa, 4 piranha

var terrain: TileMapLayer
var etiles: TileMapLayer
var ctiles: TileMapLayer
var SID := 0
var ESID := 0
var CSID := 0

# pits (no ground): each is a list of columns. HARD layout — 11 gaps, several
# 4-wide (need a running jump), enemies crowding the landings.
var PITS := [[20, 21, 22], [40, 41, 42, 43], [58, 59, 60], [66, 67, 68],
	[87, 88, 89], [104, 105, 106], [118, 119, 120, 121], [138, 139, 140],
	[146, 147, 148], [156, 157, 158, 159], [168, 169, 170]]


func _init() -> void:
	var ts = load("res://tiles.tileset.tres")
	var ets = load("res://enemy_tiles.tileset.tres")
	var cts = load("res://coin_tiles.tileset.tres")
	SID = ts.get_source_id(0)
	ESID = ets.get_source_id(0)
	CSID = cts.get_source_id(0)

	var root := Node2D.new()
	root.name = "Level6"
	terrain = TileMapLayer.new(); terrain.name = "Terrain"; terrain.tile_set = ts; root.add_child(terrain)
	etiles = TileMapLayer.new(); etiles.name = "EnemyTiles"; etiles.tile_set = ets; root.add_child(etiles)
	ctiles = TileMapLayer.new(); ctiles.name = "CoinTiles"; ctiles.tile_set = cts; root.add_child(ctiles)

	var preview := Node2D.new()
	preview.name = "FlagpolePreview"
	preview.set_script(load("res://flagpole_preview.gd"))
	preview.set("flag_x", FLAG_X)
	preview.set("castle_x", CASTLE_X)
	root.add_child(preview)

	_design()

	var spawns := Node2D.new(); spawns.name = "Spawns"; root.add_child(spawns)
	var pstart := Marker2D.new(); pstart.name = "PlayerStart"
	pstart.position = Vector2(3 * T + T / 2.0, FLOOR * T); spawns.add_child(pstart)
	var en := Node2D.new(); en.name = "Enemies"; spawns.add_child(en)      # enemies painted on EnemyTiles
	var cn := Node2D.new(); cn.name = "Coins"; spawns.add_child(cn)        # coins painted on CoinTiles

	_own(root, root)
	var packed := PackedScene.new(); packed.pack(root)
	var err := ResourceSaver.save(packed, "res://Level6.tscn")
	print("build_level6: saved (err=%d) terrain=%d enemies=%d coins=%d" % [
		err, terrain.get_used_cells().size(), etiles.get_used_cells().size(), ctiles.get_used_cells().size()])
	quit()


# ---- tile helpers --------------------------------------------------------
func up(n: int) -> int: return FLOOR - n
func t(x: int, row: int, ax: int) -> void:
	terrain.set_cell(Vector2i(x, row), SID, Vector2i(ax, 0))
func brick(x0: int, x1: int, row: int) -> void:
	for x in range(x0, x1 + 1): t(x, row, BRICK)
func pipe(x: int, h: int, purple := false) -> void:
	var ll := 17 if purple else 8
	var lr := 18 if purple else 9
	var bl := 19 if purple else 10
	var br := 20 if purple else 11
	var lip := FLOOR - h
	t(x, lip, ll); t(x + 1, lip, lr)
	for r in range(lip + 1, FLOOR):
		t(x, r, bl); t(x + 1, r, br)
func stair(x: int, h: int) -> void:
	for i in range(h): t(x, FLOOR - 1 - i, STAIR)
func en(x: int, row: int, ax: int) -> void:
	etiles.set_cell(Vector2i(x, row), ESID, Vector2i(ax, 0))
func ground_enemy(x: int, ax: int) -> void: en(x, FLOOR - 1, ax)   # feet on the ground row
func piranha_pipe(x: int, h: int, purple := false) -> void:
	pipe(x, h, purple); en(x, FLOOR - h, 4)                         # plant on the left lip
func coin(x: int, row: int) -> void:
	ctiles.set_cell(Vector2i(x, row), CSID, Vector2i(0, 0))
func coin_arc(cx: int, row: int) -> void:                          # a small ^ of 3 coins
	coin(cx - 1, row); coin(cx, row - 1); coin(cx + 1, row)


# ---- the level -----------------------------------------------------------
func _design() -> void:
	# ground everywhere except the pits
	for x in range(LW):
		var in_pit := false
		for p in PITS:
			if x in p: in_pit = true; break
		if in_pit: continue
		t(x, FLOOR, GROUND); t(x, FLOOR + 1, GROUND)

	# --- NEW START: one mushroom, then straight into a plant pipe + a fireball
	#     goomba shooting across the first gap ---
	t(6, up(4), MUSH)                            # the only easy power-up
	piranha_pipe(10, 2)
	ground_enemy(14, 0)                          # goomba
	ground_enemy(17, 2)                          # purple fireball goomba (shoots over the gap)
	# pit 20-22
	coin_arc(21, up(6))
	ground_enemy(25, 1)                          # koopa right at the landing
	piranha_pipe(30, 3)
	ground_enemy(35, 0)                          # goomba
	ground_enemy(37, 2)                          # fireball goomba before the wide gap
	# pit 40-43 (4 wide — needs a run)
	coin_arc(42, up(7))

	# --- twin pits with a koopa-patrolled platform between them ---
	ground_enemy(46, 3)                          # ledge-shy purple koopa
	piranha_pipe(52, 2)
	ground_enemy(55, 0); ground_enemy(56, 0)     # two goombas crowding the pit edge
	# pit 58-60
	coin_arc(59, up(6))
	brick(62, 64, up(5))                         # narrow landing platform...
	en(63, up(5) - 1, 3)                         # ...guarded by a purple koopa (turns at its edges)
	coin(62, up(7)); coin(64, up(7))
	# pit 66-68
	coin_arc(67, up(6))
	ground_enemy(71, 2); ground_enemy(73, 0)     # fireball goomba + goomba

	# --- stair pyramid, coin block, then a wide gap into a purple pipe ---
	stair(76, 1); stair(77, 2); stair(78, 3); stair(79, 4)
	stair(80, 4); stair(81, 3); stair(82, 2); stair(83, 1)
	t(85, up(4), Q)
	# pit 87-89
	coin_arc(88, up(6))
	piranha_pipe(94, 3, true)                    # PURPLE plant pipe
	ground_enemy(98, 2)                          # fireball goomba
	ground_enemy(100, 1); ground_enemy(102, 1)   # two koopas
	# pit 104-106
	coin_arc(105, up(6))

	# --- claustrophobic coin room: brick ceiling with goombas underneath ---
	brick(108, 116, up(8)); t(112, up(8), MUSH)  # mushroom hidden in the ceiling
	coin(109, up(6)); coin(110, up(6)); coin(114, up(6)); coin(115, up(6))
	ground_enemy(110, 0); ground_enemy(113, 0); ground_enemy(115, 0)
	# pit 118-121 (4 wide)
	coin_arc(119, up(6))
	piranha_pipe(124, 3)
	ground_enemy(128, 2)                         # fireball goomba
	ground_enemy(131, 3)                         # purple koopa
	t(134, up(4), Q); t(135, up(5), BRICK); t(136, up(6), BRICK)   # ascending bricks
	coin(137, up(7))
	# pit 138-140

	# --- final gauntlet: three more gaps, a stepping platform, a last plant ---
	t(142, up(4), MUSH)                          # last safety mushroom
	# pit 146-148
	coin_arc(147, up(6))
	brick(150, 152, up(5))                       # stepping platform
	coin(150, up(7)); coin(151, up(7)); coin(152, up(7))
	# pit 156-159 (4 wide)
	coin_arc(157, up(6))
	piranha_pipe(162, 2)
	ground_enemy(165, 2)                         # fireball goomba
	# pit 168-170
	coin_arc(169, up(6))
	brick(172, 174, up(5))
	ground_enemy(176, 3)                         # purple koopa guarding the stairs
	for i in range(8):
		stair(180 + i, i + 1)                    # SMB1-style end staircase (cols 180-187)


func _own(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_own(c, owner)
