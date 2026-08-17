extends Node2D
class_name Piranha
## Purple piranha plant. Lives in a pipe: rises out of the mouth, snaps its jaws
## open/closed a few times, then sinks back in and waits — SMB1 style. It won't
## emerge while Mario is right on top of the pipe. Can't be stomped (touching it
## hurts, from any side); a fireball or a sliding shell kills it. It never moves
## horizontally. Entity-vs-player/fireball resolution lives in Main; to slot into
## those loops it mimics the Enemy interface (active/dead/flipped/shell/kind/…).

var main                       # untyped to avoid a cyclic class dependency
var sprite: Sprite2D

# --- interface Main's enemy loops read ---
var kind := "piranha"
var active := true
var dead := false
var flipped := false           # never (kept so the player loop can test it)
var shell := false
var shell_moving := false
var dir := 0
var remove_me := false

# --- placement ---
var _cx := 0.0                 # pipe centre x
var _rim := 0.0                # pipe lip y — the plant grows up from here (or DOWN if inverted)
var inverted := false          # true = hangs DOWN out of a ceiling pipe (the sprite is flipped)

# --- cycle ---
var _state := "hidden"         # hidden -> rising -> up -> retracting -> hidden
var _t := 0.0
var _reveal_px := 0.0
var _dead_t := 0.0

const W := 16.0
const H := 24.0                # plant sprite height (full emerge)
const RISE_DUR := 0.45
const UP_DUR := 2.0            # jaws snap while it's fully out
const DOWN_DUR := 0.45
const HIDE_DUR := 1.6          # rest inside the pipe before rising again
const MOUTH_RATE := 0.25       # open/close cadence
const NEAR := 28.0             # won't rise while Mario is within this x of the mouth


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	sprite.centered = false     # top-left anchored so the reveal can clip at the rim
	sprite.z_index = 3          # in front of the pipe body, behind Mario
	add_child(sprite)


func spawn(rim_pos: Vector2) -> void:
	# rim_pos = (pipe centre x, pipe lip TOP y)
	_cx = rim_pos.x
	_rim = rim_pos.y
	global_position = Vector2(_cx, _rim)
	_reveal(0.0)


func get_rect() -> Rect2:
	# only the emerged part can hurt / be hit — above the rim normally, BELOW it if inverted
	if dead or _reveal_px <= 0.5:
		return Rect2(-9999, -9999, 0, 0)
	if inverted:
		return Rect2(_cx - W / 2.0, _rim, W, _reveal_px)
	return Rect2(_cx - W / 2.0, _rim - _reveal_px, W, _reveal_px)


func _player_near() -> bool:
	return absf(main.player.global_position.x - _cx) < NEAR


func _reveal(px: float) -> void:
	_reveal_px = px
	if px <= 0.0:
		sprite.visible = false
		return
	sprite.visible = true
	sprite.flip_v = inverted                       # inverted = flipped, hangs down from a ceiling pipe
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, W, px)        # show the top `px` px (tip leads)
	# pinned at the rim: grows UP normally, DOWN when inverted (flip_v mirrors it tip-first)
	sprite.position = Vector2(-W / 2.0, 0.0 if inverted else -px)


func _physics_process(delta: float) -> void:
	if main.paused or main.actors_frozen():
		return

	if dead:
		# SMB1: a hit plant just poofs away in place — quick fade, no flip, no sinking
		_dead_t += delta
		modulate.a = maxf(0.0, 1.0 - _dead_t / 0.15)
		if _dead_t > 0.15:
			remove_me = true
		return

	_t += delta
	# jaws: closed frame / open frame alternating
	sprite.texture = main.tex["pplant2"] if fmod(_t, MOUTH_RATE * 2.0) >= MOUTH_RATE \
		else main.tex["pplant1"]

	match _state:
		"hidden":
			_reveal(0.0)
			# only start rising once it's rested AND Mario isn't on the pipe
			if _t >= HIDE_DUR and not _player_near():
				_state = "rising"
				_t = 0.0
		"rising":
			_reveal(minf(_t / RISE_DUR, 1.0) * H)
			if _t >= RISE_DUR:
				_state = "up"
				_t = 0.0
		"up":
			_reveal(H)
			if _t >= UP_DUR:
				_state = "retracting"
				_t = 0.0
		"retracting":
			_reveal((1.0 - minf(_t / DOWN_DUR, 1.0)) * H)
			if _t >= DOWN_DUR:
				_state = "hidden"
				_t = 0.0


# killed by a fireball or a sliding shell (called from Main, like Enemy.knock_out)
func knock_out(_hit_dir := 1) -> void:
	if dead:
		return
	dead = true
	_dead_t = 0.0
	# poof away in place: freeze whatever portion is currently showing and fade it
	# out (no upside-down flip, no sinking — a rooted plant flipping looked wrong)


# never stomped/shelled, but Main may call these generically — no-op for safety
func squish() -> void:
	knock_out()

func to_shell() -> void:
	pass
