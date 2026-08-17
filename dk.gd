extends Node2D
class_name DK
## Donkey Kong boss (Level 15). Stands STILL on his bridge beating his chest (A1/a2) and
## hurling barrels that roll down toward Mario. He never moves up or down. You beat him by
## reaching the axe/switch past the bridge: the planks collapse and DK drops into the lava
## (fall_in()) — the SMB1 bridge-ending, reused. Touch hurts.
## Sprites baked in main._bake_dk_frames() from sprites/new player/dkdk.png.

var main
var sprite: Sprite2D

var kind := "dk"
var active := true
var dead := false
var ending := false            # axe grabbed: stop throwing, just stand until the bridge drops

var _facing := -1
var _anim_t := 0.0
var _throw_t := 0.0
var _wind := 0.0               # >0 = showing the throw wind-up (roll) frame
var _fall := 0.0
var _fall_v := 0.0
var _release_t := 0.0          # >0 = showing the b1 "let go" pose right as a barrel leaves his hands
var _seen := false             # false until he first comes on screen (throws immediately then)

const AUTO_THROW := false       # OFF for now — barrels come only from placed spawner markers
const THROW_PERIOD := 1.15      # hurls them fast — a steady cascade down the platforms
const W := 40.0
const H := 30.0


func _ready() -> void:
	z_index = 4
	sprite = Sprite2D.new()
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	add_child(sprite)


func spawn(pos: Vector2) -> void:
	global_position = pos
	_throw_t = 1.2               # brief beat before the first barrel
	sprite.texture = main.tex["dk_idle0"]


func get_rect() -> Rect2:
	if dead:
		return Rect2(-9999, -9999, 0, 0)
	return Rect2(global_position - Vector2(W, H) / 2.0, Vector2(W, H))


func _physics_process(delta: float) -> void:
	if main.paused or main.actors_frozen():
		return
	if dead:
		# the bridge dropped out from under him -> fall straight into the lava and fade
		_fall += delta
		_fall_v = minf(_fall_v + 300.0 * delta, 300.0)
		global_position.y += _fall_v * delta
		sprite.texture = main.tex["dk_fall%d" % (int(_fall / 0.1) % 5)]
		modulate.a = maxf(0.0, 1.0 - _fall / 1.4)
		return

	_facing = -1 if main.player.global_position.x <= global_position.x else 1
	# axe grabbed: stop throwing, just stand facing Mario until the bridge collapses
	if ending:
		sprite.texture = main.tex["dk_idle0"]
		return

	_anim_t += delta
	# POLISH: while he's ON SCREEN, DK throws his OWN barrels (separate from the placed markers).
	# On each throw he bends into the b1 rolling pose and rolls a fresh barrel out of his hands.
	if _on_screen():
		if not _seen:
			_seen = true
			_throw_t = 0.0          # roll one out the INSTANT you first lay eyes on him
		_throw_t -= delta
		if _throw_t <= 0.0:
			_throw_t = randf_range(THROW_PERIOD, THROW_PERIOD * 1.7)
			_release_t = 0.4
			main.spawn_dk_barrel(global_position + Vector2(-10.0, -4.0), -1, 0)   # roll it LEFT

	# a1/a2 standing; b1 (roll-it-out, barrel in the frame) while a throw is releasing
	if _release_t > 0.0:
		_release_t -= delta
		sprite.texture = main.tex["dk_b1"]
	else:
		sprite.texture = main.tex["dk_idle%d" % (int(_anim_t / 0.4) % 2)]


# DK is within the visible viewport (so he only throws his polish barrels when you can see him)
func _on_screen() -> bool:
	return global_position.x >= main.cam_x - 24.0 and global_position.x <= main.cam_x + main.VIEW_W + 24.0


# a barrel just left his hands (spawned near him) -> show the b1 "let go" pose for a beat
func throw_release() -> void:
	_release_t = 0.35


# bridge collapsed out from under him -> drop straight down into the lava (the axe ending)
func fall_in() -> void:
	if dead:
		return
	ending = false
	dead = true
	_fall = 0.0
	_fall_v = 0.0
	main.sfx("bowser_fall")


func squish() -> void:
	pass

func to_shell() -> void:
	pass

func knock_out(_dir := 1) -> void:
	pass
