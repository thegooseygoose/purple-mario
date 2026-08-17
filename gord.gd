extends Node2D
class_name Gord
## A stationary spiky hazard (Level 15 etc). Flips between its two frames (a1/a2) in place and
## never moves. INSTANT death to Mario on any touch (even big Mario). Barrels treat it like a
## solid block — they reverse off it, or pass over it if they're higher (see barrel.gd).
## Sprites baked in main._bake_gord_frames() from sprites/new player/gord.png.

var main
var sprite: Sprite2D

var kind := "gord"
var dead := false
var _t := 0.0

const W := 20.0
const H := 20.0


func _ready() -> void:
	z_index = 3
	sprite = Sprite2D.new()
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	add_child(sprite)


func spawn(pos: Vector2) -> void:
	global_position = pos
	sprite.texture = main.tex["gord0"]


func get_rect() -> Rect2:
	if dead:
		return Rect2(-9999, -9999, 0, 0)
	return Rect2(global_position - Vector2(W, H) / 2.0, Vector2(W, H))


func _physics_process(delta: float) -> void:
	if main.paused or main.actors_frozen():
		return
	_t += delta
	sprite.texture = main.tex["gord%d" % (int(_t / 0.18) % 2)]   # flip a1 <-> a2
