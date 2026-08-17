extends CharacterBody2D
class_name Fireball
## Fire Mario's projectile. Flies forward, bounces along the ground, dies on a
## wall or off-screen. Hitting enemies is resolved in Main.

var main                       # untyped to avoid a cyclic class dependency
var sprite: Sprite2D
var size := Vector2(8, 8)
var dead := false
var burst := false             # died on impact (wall/enemy) -> spawn a 2x burst
var enemy := false             # spat by a purple goomba -> hurts the player, not enemies
var facing := 1                # travel direction (set at launch)
var life := 2.5
var _anim := 0.0               # spin animation clock
const SPIN_STEP := 4.0 / 60.0  # SMB1: fireball tile changes every 4 frames

const SPEED := 240.0
const BOUNCE := -220.0
const GRAV := 900.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1          # collide with the world only
	var rect := RectangleShape2D.new()
	rect.size = size
	var cs := CollisionShape2D.new()
	cs.shape = rect
	add_child(cs)
	sprite = Sprite2D.new()
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	sprite.z_index = 5
	add_child(sprite)


func get_rect() -> Rect2:
	return Rect2(global_position - size / 2.0, size)


func launch(pos: Vector2, dir: int) -> void:
	global_position = pos
	facing = dir
	sprite.texture = main.tex["fball0"]
	velocity = Vector2(dir * SPEED, 80.0)


func _physics_process(delta: float) -> void:
	if main.paused or main.actors_frozen():
		return
	if dead:
		return
	life -= delta
	velocity.y = minf(velocity.y + GRAV * delta, 400.0)
	move_and_slide()
	if is_on_floor():
		velocity.y = BOUNCE
	if is_on_wall():        # hit the side of a block -> burst
		dead = true
		burst = true
	# spin: cycle the 4 frames, one every 4 game-frames (SMB1 tile-swap rate)
	_anim += delta
	sprite.texture = main.tex["fball%d" % (int(_anim / SPIN_STEP) % 4)]
	if life <= 0.0 or global_position.x < main.cam_x - 24 or global_position.x > main.cam_x + main.VIEW_W + 24:
		dead = true
