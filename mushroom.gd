extends CharacterBody2D
class_name Mushroom
## Super-mushroom power-up. It grows up out of the block with the same clip-reveal
## as the fire flower, and ONLY once it has fully risen does it start walking and
## falling like an enemy (reversing at walls). Collection is resolved in Main.

var main                       # untyped to avoid a cyclic class dependency
var sprite: Sprite2D
var rect: RectangleShape2D
var dir := 1
var dead := false
var green := false            # true = 1-up (green) mushroom
var trap := false             # "trap" mushroom — looks/moves exactly like a real one, but KILLS on collect

# emerge: grow up out of the block over ~1s (matches the fire flower), THEN move
var emerging := true
var emerge_t := 0.0
const EMERGE_DUR := 1.0

var hopping := false          # true mid block-bump hop → gentler descent
const HOP_FALL_SCALE := 0.55  # gravity multiplier while dropping from a hop (lower = slower)
var _block_top := 0.0
var _cx := 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0          # no world collision while emerging
	rect = RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	var cs := CollisionShape2D.new()
	cs.shape = rect
	add_child(cs)
	sprite = Sprite2D.new()
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	sprite.centered = false     # top-left anchored so we can clip the reveal
	sprite.z_index = 3
	add_child(sprite)


func get_rect() -> Rect2:
	if emerging:
		# collectable area is the finished spot (the tile directly above the block)
		return Rect2(_cx - 8.0, _block_top - 16.0, 16.0, 16.0)
	return Rect2(global_position - rect.size / 2.0, rect.size)


func spawn(block_top_center: Vector2) -> void:
	# block_top_center = (block centre x, block TOP edge y) — same convention as the flower
	_cx = block_top_center.x
	_block_top = block_top_center.y
	global_position = Vector2(_cx, _block_top)
	var t: Texture2D = main.tex["green_mushroom"] if green else main.tex["mushroom"]
	sprite.texture = t
	sprite.flip_v = trap        # rendered upside-down, but pops out of the block with the SAME slow emerge
	_reveal(0.0)


func _reveal(t: float) -> void:
	# identical grow-up-out-of-the-block reveal as flower.gd
	var tw: float = sprite.texture.get_width()
	var th: float = sprite.texture.get_height()
	if t >= 1.0:
		sprite.region_enabled = false
		sprite.position = Vector2(-tw / 2.0, -th)   # rest in the tile above the block
		sprite.visible = true
		return
	var r: int = int(round(t * th))               # pixels grown above the block top
	sprite.visible = r > 0
	sprite.region_enabled = true
	# When flipped (trap mushroom) reveal from the BOTTOM rows so the motion mirrors
	# the regular emerge: the leading edge rises out first, the base fills in behind it.
	var ry: float = th - maxi(r, 1) if sprite.flip_v else 0.0
	sprite.region_rect = Rect2(0, ry, tw, maxi(r, 1))
	sprite.position = Vector2(-tw / 2.0, -float(r)) # grows upward from the block top


func _physics_process(delta: float) -> void:
	if main.paused or main.actors_frozen():
		return
	if dead:
		return
	if emerging:
		emerge_t += delta
		var t: float = minf(emerge_t / EMERGE_DUR, 1.0)
		_reveal(t)
		if t >= 1.0:
			# fully up — hand the visual over to a normal centred sprite and let the
			# walking body take over from here (only NOW does it start moving)
			emerging = false
			var th: float = sprite.texture.get_height()
			sprite.centered = true
			sprite.region_enabled = false
			sprite.position = Vector2.ZERO
			global_position = Vector2(_cx, _block_top - th / 2.0)   # seamless with the reveal
			collision_mask = 1     # start colliding with the world
		return

	velocity.x = dir * 66.0
	# a block-bump hop drops back down a bit slower — reduced gravity on the way
	# down (still accelerating, not floaty); the rise keeps full gravity so the
	# peak stays where main tuned it
	var g: float = main.GRAVITY
	if hopping and velocity.y > 0.0:
		g *= HOP_FALL_SCALE
	velocity.y = minf(velocity.y + g * delta, main.MAX_FALL)
	move_and_slide()
	if hopping and is_on_floor():
		hopping = false
	if is_on_wall():
		dir = -dir

	if global_position.y > main.VIEW_H + 40:
		dead = true
