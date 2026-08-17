extends Node2D
class_name Podoboo
## SMB1 castle lava bubble ("Podoboo"): launches STRAIGHT UP out of the lava, arcs
## to a peak, falls back (a touch slower — SMB1 caps the fall), and FLIPS VERTICALLY
## the instant it starts descending. Sinks back into the lava, waits, repeats. It is
## indestructible (no stomp, no fireball) — any touch hurts. Placement: paint atlas
## col 10 on a level's EnemyTiles layer at the lava surface; it erupts from there.

var main                       # untyped to avoid a cyclic class dependency
var sprite: Sprite2D

# SMB1-flavoured motion (px, px/s). SMB1 launches at -7px/frame and caps the fall at
# 3px/frame so it drops slower than it rose; the peak here is tuned to ~6 tiles.
@export var launch := -300.0       # upward launch speed
@export var gravity := 470.0       # downward accel
@export var max_fall := 180.0      # SMB1 caps the fall (3px/frame) -> slow descent
@export var wait_min := 0.7        # seconds resting in the lava between erupts
@export var wait_max := 1.8

# --- interface Main's loops may poke generically (kept harmless) ---
var kind := "podoboo"
var active := true
var dead := false

var _home_y := 0.0             # launch height (lava surface)
var _vy := 0.0
var _state := "wait"           # wait -> flight
var _timer := 0.0
const HIT_W := 12.0
const HIT_H := 14.0


func _ready() -> void:
	z_index = 4
	sprite = Sprite2D.new()
	sprite.texture = load("res://sprites/enemies/podoboo.png")
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	add_child(sprite)


func spawn(pos: Vector2) -> void:
	global_position = pos
	_home_y = pos.y
	_state = "wait"
	_timer = randf_range(wait_min, wait_max)
	sprite.visible = false


func _erupt() -> void:
	global_position.y = _home_y
	_vy = launch
	_state = "flight"
	sprite.visible = true
	sprite.flip_v = false


func _physics_process(delta: float) -> void:
	if main.paused or main.actors_frozen():
		return
	if _state == "wait":
		_timer -= delta
		if _timer <= 0.0:
			_erupt()
		return
	# flight: integrate, cap the fall, flip on descent
	_vy = minf(_vy + gravity * delta, max_fall)
	global_position.y += _vy * delta
	sprite.flip_v = _vy >= 0.0          # SMB1: vertical-flip once moving downward
	if _vy > 0.0 and global_position.y >= _home_y:
		# sank back into the lava — hide and wait for the next erupt
		global_position.y = _home_y
		_state = "wait"
		_timer = randf_range(wait_min, wait_max)
		sprite.visible = false


# per-frame overlap test with the player AABB (only while airborne)
func hits(pr: Rect2) -> bool:
	if _state != "flight":
		return false
	var r := Rect2(global_position - Vector2(HIT_W, HIT_H) / 2.0, Vector2(HIT_W, HIT_H))
	return pr.intersects(r)
