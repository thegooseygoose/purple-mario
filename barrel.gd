extends Node2D
class_name Barrel
## A barrel DK hurls. Gravity pulls it down; it rolls along whatever floor it lands on,
## drops off ledges to the next platform (the classic DK cascade), reverses off walls, and
## hurts Mario on touch. Mario jumps over it. Spins as it rolls.
## Sprites baked in main._bake_dk_frames() from sprites/new player/dkdk.png.

var main
var sprite: Sprite2D
var dead := false

var _vx := 0.0
var _vy := 0.0
var _anim := 0.0
var _speed := 66.0
var _bounce := false

# the 4 placeable barrel types (EnemyTiles atlas 19/20/21/22):
#   0 normal, 1 faster, 2 bounces (normal speed), 3 bounces (slower)
const TYPE_SPEED := [66.0, 98.0, 66.0, 46.0]
const TYPE_BOUNCE := [false, false, true, true]
const HOP := 185.0                   # upward kick each time a bouncing barrel lands
const GRAV := 380.0
const MAX_FALL := 260.0
const W := 14.0
const H := 12.0
const TILE := 16.0


func _ready() -> void:
	z_index = 3
	sprite = Sprite2D.new()
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	add_child(sprite)


func spawn(pos: Vector2, _dir: int, btype := 0) -> void:
	global_position = pos
	btype = clampi(btype, 0, TYPE_SPEED.size() - 1)
	_speed = TYPE_SPEED[btype]
	_bounce = TYPE_BOUNCE[btype]
	_vx = -_speed                     # barrels ALWAYS roll left (down toward Mario) — never right
	_vy = -60.0                       # slight toss up out of his hands
	sprite.texture = main.tex["dk_barrel0"]


func get_rect() -> Rect2:
	return Rect2(global_position - Vector2(W, H) / 2.0, Vector2(W, H))


func _solid(px: float, py: float) -> bool:
	var c := Vector2i(int(floor(px / TILE)), int(floor(py / TILE)))
	if main.terrain.get_cell_source_id(c) < 0:
		return false
	# lava is NOT solid — barrels sink straight through it (like Mario/enemies) and fall away
	var ax: int = main.terrain.get_cell_atlas_coords(c).x
	return ax != main.ATLAS_LAVA_TOP and ax != main.ATLAS_LAVA


func _physics_process(delta: float) -> void:
	if main.paused or main.actors_frozen():
		return
	if dead:
		return

	# gravity + land on the floor below. Check the barrel's WHOLE base (left edge, centre, right
	# edge) — not just its centre — so it stays on a girder until it's fully past the edge and
	# never clips down through the corner of a platform.
	_vy = minf(_vy + GRAV * delta, MAX_FALL)
	var ny := global_position.y + _vy * delta
	var hh := H / 2.0
	var hwf := W / 2.0 - 1.0
	var grounded := false
	if _vy >= 0.0 and (_solid(global_position.x, ny + hh) \
			or _solid(global_position.x - hwf, ny + hh) \
			or _solid(global_position.x + hwf, ny + hh)):
		ny = floor((ny + hh) / TILE) * TILE - hh   # snap to the tile top
		_vy = 0.0
		grounded = true
		if _bounce:
			_vy = -HOP                # bouncing barrels kick straight back up on every landing
	global_position.y = ny

	# horizontal roll — barrels roll ONE WAY only (down toward Mario) and NEVER bounce back the
	# other direction. If a wall blocks the roll, the barrel just despawns instead of reversing.
	# (Gord has no effect — barrels roll straight through him, the sprite clips over.)
	var hw := W / 2.0
	var nx := global_position.x + _vx * delta
	if grounded and _solid(nx + (hw if _vx > 0.0 else -hw), global_position.y):
		dead = true
	else:
		global_position.x = nx

	# spin through the 2 roll frames D1/D2 (faster barrels roll-spin faster)
	_anim += delta * (5.0 + _speed * 0.09)
	sprite.texture = main.tex["dk_barrel%d" % (int(_anim) % 2)]

	# despawn once it leaves the arena
	if global_position.y > main.VIEW_H + 40.0 or global_position.x < -20.0 \
			or global_position.x > main.LW * TILE + 20.0:
		dead = true
