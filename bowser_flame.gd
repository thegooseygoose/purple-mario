extends Node2D
class_name BowserFlame
## Bowser's fire breath. Spawns at his mouth, travels SLOWLY horizontal (SMB1 ~1.25
## px/frame) toward Mario, and drifts vertically to lock onto one of a few heights
## near him (SMB1 FlameYPosData), flickering through 3 frames. Hurts on contact and
## can't be destroyed. Lives in main.bowser_flames.

var main
var sprite: Sprite2D
var dead := false

var _dir := -1
var _target_y := 0.0
var _anim := 0.0
var life := 5.0

const SPEED := 78.0            # px/s horizontal (SMB1 ~1.25px/frame)
const DRIFT := 60.0           # px/s vertical homing toward the target height (~1px/frame)
const W := 22.0
const H := 6.0


func _ready() -> void:
	z_index = 5
	sprite = Sprite2D.new()
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	add_child(sprite)


func launch(pos: Vector2, dir: int, straight := false) -> void:
	global_position = pos
	_dir = dir
	if straight:
		# purely horizontal (the castle-approach fireballs) — no vertical homing
		_target_y = pos.y
	else:
		# Aim to HIT Mario: usually straight at his height (the flame angles down/up from
		# the mouth toward him), occasionally a touch high, occasionally dead straight out
		# of the mouth. Never below Mario, so it can't dip under the bridge.
		var my: float = main.player.global_position.y
		var opts := [my, my, my, my - 9.0, pos.y]
		_target_y = minf(opts[randi() % opts.size()], my)
	sprite.texture = main.tex["bflame0"]
	# frames are baked NORMALIZED to one orientation (see _bake_flame); the wanted look
	# mirrors that, so flip a left-moving flame (and leave a right-moving one unflipped).
	sprite.flip_h = dir < 0


func get_rect() -> Rect2:
	return Rect2(global_position - Vector2(W, H) / 2.0, Vector2(W, H))


func _physics_process(delta: float) -> void:
	if main.paused or dead or main.actors_frozen():
		return
	life -= delta
	global_position.x += _dir * SPEED * delta
	# home vertically toward the target height, capped (SMB1 ~1px/frame)
	var dy: float = _target_y - global_position.y
	global_position.y += clampf(dy, -DRIFT * delta, DRIFT * delta)
	_anim += delta
	sprite.texture = main.tex["bflame%d" % (int(_anim / 0.09) % 3)]
	if life <= 0.0 or global_position.x < main.cam_x - 28 or global_position.x > main.cam_x + main.VIEW_W + 28:
		dead = true
