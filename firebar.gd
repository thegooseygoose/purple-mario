extends Node2D
class_name Firebar
## SMB1 castle "firebar": a chain of fire balls anchored to a pivot, spinning in a
## full circle. Touching ANY ball hurts Mario (big -> small, small -> dies). It is
## indestructible — fireballs and shells pass straight through. Placement: paint
## atlas col 6 on a level's EnemyTiles layer; the pivot sits at that tile's centre.
## Rendered procedurally (no sprite) in the user's fire-spin colours.

var main                       # untyped to avoid a cyclic class dependency

# --- tunables ---
@export var segments := 6          # number of fire balls in the bar (SMB1 = 6)
@export var spacing := 8.0         # px between ball centres along the bar
@export var inner := 6.0           # radius of the innermost ball from the pivot
@export var speed := 2.2           # rotation speed (radians / second)
@export var cw := true             # clockwise when true
const HIT_R := 3.5                 # collision radius per ball (a touch smaller = fair)

# the user's own art (sprites/new player/fire spin.png), sliced into a pivot block
# and one flame ball; the ball is drawn at each segment, the block at the centre.
var _ball_tex: Texture2D
var _block_tex: Texture2D

var angle := 0.0
var _spin := 0.0                   # ball self-spin phase (cosmetic flicker)

# --- interface Main's loops may poke generically (kept harmless) ---
var kind := "firebar"
var active := true
var dead := false


func _ready() -> void:
	z_index = 4                    # in front of terrain, around the player layer
	_ball_tex = load("res://sprites/enemies/firebar_ball.png")
	_block_tex = load("res://sprites/enemies/firebar_block.png")
	texture_filter = TEXTURE_FILTER_NEAREST


func spawn(pivot_pos: Vector2) -> void:
	global_position = pivot_pos
	angle = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	if main.paused or main.actors_frozen():
		return
	angle += (speed if cw else -speed) * delta
	_spin += delta * 12.0
	queue_redraw()


# world-space centre of ball i along the current angle
func _ball_pos(i: int) -> Vector2:
	var r := inner + i * spacing
	return global_position + Vector2(cos(angle), sin(angle)) * r


# does the bar touch the player's AABB this frame?
func hits(pr: Rect2) -> bool:
	for i in segments:
		if _circle_hits_rect(_ball_pos(i), HIT_R, pr):
			return true
	return false


static func _circle_hits_rect(c: Vector2, r: float, rect: Rect2) -> bool:
	var nx: float = clampf(c.x, rect.position.x, rect.position.x + rect.size.x)
	var ny: float = clampf(c.y, rect.position.y, rect.position.y + rect.size.y)
	return Vector2(nx, ny).distance_squared_to(c) <= r * r


func _draw() -> void:
	# pivot block, centred on the pivot
	if _block_tex:
		draw_texture(_block_tex, -_block_tex.get_size() / 2.0)
	# fire balls out along the bar, innermost first — each ball spun on its own
	# centre for a little shimmer, using the user's flame sprite
	if _ball_tex == null:
		return
	var half := _ball_tex.get_size() / 2.0
	var dir := Vector2(cos(angle), sin(angle))
	for i in segments:
		var p := dir * (inner + i * spacing)              # ball centre (local space)
		draw_set_transform(p, _spin + i * 0.7, Vector2.ONE)
		draw_texture(_ball_tex, -half)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)    # reset
