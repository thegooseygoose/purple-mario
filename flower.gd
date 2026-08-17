extends Node2D
class_name Flower
## Fire flower power-up. It grows up out of the block over ~1s — clipped to the
## block's width and to the area above the block's top, so it never looks wider
## than the block or pokes out the sides. Collection is resolved in Main.

var main                       # untyped to avoid a cyclic class dependency
var sprite: Sprite2D
var size := Vector2(16, 16)
var dead := false

# emerge (grow up out of the block over ~1s)
var emerging := true
var emerge_t := 0.0
const EMERGE_DUR := 1.0
var _block_top := 0.0
var _cx := 0.0


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	sprite.centered = false     # top-left anchored so we can clip the reveal
	sprite.z_index = 3
	add_child(sprite)


func get_rect() -> Rect2:
	# collectable area is the finished spot (the tile directly above the block)
	return Rect2(_cx - size.x / 2.0, _block_top - size.y, size.x, size.y)


func spawn(feet_pos: Vector2) -> void:
	_block_top = feet_pos.y     # feet_pos.y is the top edge of the block
	_cx = feet_pos.x
	global_position = Vector2(feet_pos.x, feet_pos.y)
	sprite.texture = main.tex["flower"]
	_reveal(0.0)


func _reveal(t: float) -> void:
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
	sprite.region_rect = Rect2(0, 0, tw, maxi(r, 1))
	sprite.position = Vector2(-tw / 2.0, -float(r)) # grows upward from the block top


func _physics_process(delta: float) -> void:
	if main.paused or main.actors_frozen():
		return
	if not emerging:
		return
	emerge_t += delta
	var t: float = minf(emerge_t / EMERGE_DUR, 1.0)
	_reveal(t)
	if t >= 1.0:
		emerging = false
