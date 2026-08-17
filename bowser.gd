extends Node2D
class_name Bowser
## SMB1 castle boss. Paces a short range back and forth (always facing Mario), hops
## now and then, and periodically opens his mouth to breathe a slow flame aimed at
## Mario's height. Any touch hurts. Beaten by 5 fireballs -> topples into the lava.
## Placement: paint atlas col 15 on a level's EnemyTiles layer at the bridge.

var main                       # untyped to avoid a cyclic class dependency
var sprite: Sprite2D

# --- interface Main's loops may poke generically ---
var kind := "bowser"
var active := true
var dead := false
var ending := false            # bridge-collapse ending: march feet in place facing Mario
var _straight := false         # true = drop straight down into the lava (no topple spin)

var _home_x := 0.0
var _home_y := 0.0
var _facing := -1              # art faces LEFT; faces toward Mario
var _vx := 0.0
var _range := 32.0
var _walk_t := 0.0
var _hop_t := 0.0
var _dy := 0.0                 # vertical hop offset from home_y
var _vy := 0.0
var _fire_t := 0.0
var _mouth := 0.0              # >0 = mouth open (show the breathing frame)
var _hp := 5
var _fall := 0.0
var _turn_dwell := 0.0         # brief pause at each turn so he doesn't snap back instantly

const WALK_SPEED := 34.0
const RANGE_MIN := 8.0         # small pacing so he holds his ground and never wanders
const RANGE_MAX := 18.0        # across Mario (which is what caused the facing to flip)
const FLIP_MARGIN := 26.0      # must exceed RANGE_MAX so his shuffle can't flip his view
const TURN_DWELL_MIN := 0.3
const TURN_DWELL_MAX := 0.7
const FIRE_PERIOD := 2.2       # seconds between fire breaths
# SMB1 Bowser's jump is a floaty ~3-tile arc (a -2/frame impulse under a weak gravity,
# capped slow fall). Height is fixed in the original; we vary the impulse a little so
# the arcs aren't identical. Timing between jumps is randomised (the SMB1 17-65f timer).
const HOP_V_MIN := -168.0      # strongest hop (~3.7 tiles)
const HOP_V_MAX := -138.0      # weakest hop (~2.6 tiles)
const GRAV := 230.0            # weak gravity -> floaty rise (was 520 = too fast/small)
const MAX_FALL := 120.0        # SMB1 caps the fall (2px/frame) -> slow, floaty descent
const HOP_MIN := 0.3           # SMB1 sits ~17-65 frames between hops before jumping again
const HOP_MAX := 0.85
const W := 28.0
const H := 28.0


func _ready() -> void:
	z_index = 4
	sprite = Sprite2D.new()
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	add_child(sprite)


func spawn(pos: Vector2) -> void:
	global_position = pos
	_home_x = pos.x
	_home_y = pos.y
	_vx = -WALK_SPEED
	_range = randf_range(RANGE_MIN, RANGE_MAX)
	_fire_t = FIRE_PERIOD
	_hop_t = randf_range(HOP_MIN, HOP_MAX)
	sprite.texture = main.tex["bowL0"]


func get_rect() -> Rect2:
	if dead:
		return Rect2(-9999, -9999, 0, 0)
	return Rect2(global_position - Vector2(W, H) / 2.0, Vector2(W, H))


func _physics_process(delta: float) -> void:
	if main.paused or main.actors_frozen():
		return
	if dead:
		# fall into the lava and fade out; fireball-defeat topples (spins), the bridge
		# collapse drops him straight down
		_fall += delta
		global_position.y += (230.0 if _straight else 150.0) * delta
		if not _straight:
			sprite.rotation += delta * 3.5
		modulate.a = maxf(0.0, 1.0 - _fall / 1.2)
		return

	# bridge-collapse ending: stand facing Mario and march his feet (no pace/hop/fire)
	if ending:
		_facing = -1 if main.player.global_position.x <= global_position.x else 1
		_walk_t += delta
		var epre: String = "bowR" if _facing > 0 else "bowL"
		sprite.texture = main.tex[epre + ("0" if int(_walk_t / 0.16) % 2 == 0 else "1")]
		return

	# Dormant until he's near the screen. SMB1 Bowser doesn't pace or breathe fire (so you
	# can't see OR hear it) until you approach — while he's still far off to the right, hold
	# him idle and keep the fire timer primed so his first flame comes soon after he appears
	# and travels toward you from a bit further away.
	if global_position.x >= main.cam_x + main.VIEW_W + 24.0:
		_fire_t = minf(_fire_t, 0.6)
		sprite.texture = main.tex["bowL0"]
		return

	# Sticky facing: only turn once Mario is CLEARLY past him — by more than his whole
	# pace range (FLIP_MARGIN > RANGE_MAX). That way his own back-and-forth shuffle can
	# never carry him across a standing Mario and flip his view; he only turns when
	# Mario actually walks to his other side.
	var px: float = main.player.global_position.x
	if _facing == 1 and px < global_position.x - FLIP_MARGIN:
		_facing = -1
	elif _facing == -1 and px > global_position.x + FLIP_MARGIN:
		_facing = 1
	# dedicated directional art (no mirroring): left = A frames, right = B frames

	# pace within +-range of the origin; pause briefly at each turn, then head back
	# with a fresh random range so the stride length varies (natural, not metronomic)
	if _turn_dwell > 0.0:
		_turn_dwell -= delta
	else:
		global_position.x += _vx * delta
		if global_position.x <= _home_x - _range:
			global_position.x = _home_x - _range
			_vx = WALK_SPEED
			_turn_dwell = randf_range(TURN_DWELL_MIN, TURN_DWELL_MAX)
			_range = randf_range(RANGE_MIN, RANGE_MAX)
		elif global_position.x >= _home_x + _range:
			global_position.x = _home_x + _range
			_vx = -WALK_SPEED
			_turn_dwell = randf_range(TURN_DWELL_MIN, TURN_DWELL_MAX)
			_range = randf_range(RANGE_MIN, RANGE_MAX)

	# SMB1-style hopping: sit a random beat on the ground, then a little jump; on each
	# landing pick a fresh sit time (17-65 frames in the original) so it's restless
	if _dy == 0.0 and _vy == 0.0:
		_hop_t -= delta
		if _hop_t <= 0.0:
			_vy = randf_range(HOP_V_MIN, HOP_V_MAX)   # slightly varied hop height
	else:
		_vy = minf(_vy + GRAV * delta, MAX_FALL)      # weak gravity + capped slow fall
		_dy += _vy * delta
		if _dy >= 0.0:
			_dy = 0.0
			_vy = 0.0
			_hop_t = randf_range(HOP_MIN, HOP_MAX)
	global_position.y = _home_y + _dy

	# fire breath: open the mouth and spit a flame from it toward Mario
	if _mouth > 0.0:
		_mouth -= delta
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = FIRE_PERIOD
		_mouth = 0.5
		# SMB1: Bowser's flame ALWAYS spouts the same way — left, toward the player's
		# approach side. It never reverses to track Mario, so consecutive breaths can't
		# flip back and forth as he turns. Snout tip on the left, ~8px above centre.
		main.spawn_bowser_flame(global_position + Vector2(-13.0, -7.0), -1)

	# animate with the correct directional set: mouth-open (frame 2) while breathing,
	# else a 2-frame walk cycle (frames 0/1). Feet advance only while striding.
	if _turn_dwell <= 0.0:
		_walk_t += delta
	var pre: String = "bowR" if _facing > 0 else "bowL"
	if _mouth > 0.0:
		sprite.texture = main.tex[pre + "2"]
	else:
		sprite.texture = main.tex[pre + ("0" if int(_walk_t / 0.27) % 2 == 0 else "1")]


# fireballs chip away 5 hits; the 5th topples him. Never stomped/shelled.
func knock_out(_dir := 1) -> void:
	if dead:
		return
	_hp -= 1
	main.sfx("bump")
	if _hp <= 0:
		dead = true
		_fall = 0.0
		main.sfx("kick")

# bridge collapsed out from under him -> drop straight into the lava
func fall_in() -> void:
	ending = false
	dead = true
	_straight = true
	_fall = 0.0
	main.sfx("bowser_fall")          # the drop when the bridge disappears under him

func squish() -> void:
	pass

func to_shell() -> void:
	pass
