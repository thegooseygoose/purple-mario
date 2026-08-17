extends Node2D
class_name Hammer
## A hammer thrown by a Hammer Bro. Arcs up-and-over (gravity), spins through its 4
## frames, passes over the terrain (no world collision, SMB1-style), and hurts the
## player on contact. Player-collision + culling are resolved in Main (main.hammers).

var main                       # untyped to avoid a cyclic class dependency
var sprite: Sprite2D
var vel := Vector2.ZERO
var dead := false
var remove_me := false
var _t := 0.0

const GRAV := 620.0
const W := 12.0                # hurt-box (a bit smaller than the sprite, for fairness)


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	sprite.z_index = 5
	add_child(sprite)


func launch(pos: Vector2, v: Vector2) -> void:
	global_position = pos
	vel = v


func get_rect() -> Rect2:
	return Rect2(global_position - Vector2(W, W) / 2.0, Vector2(W, W))


func _physics_process(delta: float) -> void:
	if main.paused or dead or main.actors_frozen():
		return
	_t += delta
	vel.y += GRAV * delta
	global_position += vel * delta
	sprite.texture = main.tex["hammer%d" % (int(_t / 0.11) % 4 + 1)]   # slow C1->C4 flip
	if global_position.y > main.VIEW_H + 48 \
			or global_position.x < main.cam_x - 40 or global_position.x > main.cam_x + main.VIEW_W + 40:
		dead = true
