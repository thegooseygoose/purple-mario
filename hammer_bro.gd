extends Node2D
class_name HammerBro
## SMB1 Hammer Bro. Stands on a platform, faces Mario, lobs a stream of hammers in an
## arc, shuffles side to side, and HOPS up/down — phasing straight through the blocks
## (the SMB1 "jumps through the bricks" behaviour). Stompable and fireball-killable;
## touching it hurts. Slots into Main's enemy loops via the Enemy-like interface.

var main                       # untyped to avoid a cyclic class dependency
var sprite: Sprite2D

# --- interface Main's enemy loops read ---
var kind := "hammerbro"
var active := false
var dead := false
var flipped := false           # never (kept so the player loop can test it)
var shell := false
var shell_moving := false
var dir := -1
var remove_me := false

# --- placement / motion ---
var _base_x := 0.0             # centre of the side-to-side shuffle
var _base_y := 0.0            # standing centre Y (hops offset up from here)
var _cx := 0.0
var facing := -1               # faces Mario
var _shuffle_dir := 1
var _up := false               # currently standing on the UPPER level
var _hopping := false
var _hop_t := 0.0
var _hop_clock := 0.0
var _level_y := 0.0            # current standing centre-Y (base = lower level)
var _from_y := 0.0
var _to_y := 0.0
var _tstate := "idle"          # idle -> wind (holds the hammer up) -> release
var _tclock := 0.0
var _throw_flash := 0.0        # brief "arm forward" pose right after releasing
# SMB1 hammer toss: ONE fixed arc every time (no aiming/leading). Up ~4 px/frame, forward
# ~1.5 px/frame in the facing direction; Hammer.GRAV (620) arcs it back down — a peak of ~3
# tiles, landing a few tiles ahead, matching the real game's readable lob.
const HAMMER_VY := -240.0
const HAMMER_VX := 90.0
var held: Sprite2D             # the hammer held above the head during the wind-up
var _anim := 0.0
var _dead_t := 0.0
var _dvel := Vector2.ZERO       # death: pops up then gravity arcs it off-screen

const W := 16.0
const H := 24.0
const SHUFFLE := 20.0          # px each side of _base_x
const SHUFFLE_SPD := 16.0
const HOP_INTERVAL := 2.2      # dwell on a level (throwing) before hopping to the other
const HOP_POP := 10.0          # small extra arc during the jump
const HOP_DUR := 0.5
const HOP_REACH := 7           # how many tiles up/down it will look for a platform
# hold-then-throw: brief idle, then raise + HOLD the hammer up, then let it fly.
# faster overall than the old single 1.5s lob.
const IDLE_DUR := 0.384        # +20% slower fire rate (was 0.32)
const HOLD_DUR := 0.36         # +20% slower fire rate (was 0.30)


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	sprite.z_index = 4
	add_child(sprite)
	held = Sprite2D.new()          # hammer shown above the head during the wind-up
	held.texture_filter = TEXTURE_FILTER_NEAREST
	held.z_index = 5
	held.visible = false
	add_child(held)


func spawn(feet_pos: Vector2) -> void:
	_base_x = feet_pos.x
	_cx = feet_pos.x
	_base_y = feet_pos.y - H / 2.0
	_level_y = _base_y
	global_position = Vector2(_cx, _base_y)
	_tclock = randf() * IDLE_DUR             # stagger so a group doesn't fire in unison
	_frame()


func get_rect() -> Rect2:
	return Rect2(global_position - Vector2(W, H) / 2.0, Vector2(W, H))


func _physics_process(delta: float) -> void:
	if main.paused or main.actors_frozen():
		return
	if not active:
		if global_position.x < main.cam_x + main.VIEW_W + 32:
			active = true
		else:
			return

	if dead:
		# SMB1 death: flipped upside-down, pops up, then gravity arcs it off-screen
		_dead_t += delta
		held.visible = false
		sprite.flip_v = true
		_dvel.y = minf(_dvel.y + main.GRAVITY * 0.45 * delta, main.MAX_FALL)
		global_position += _dvel * delta
		if _dead_t > 4.0 or global_position.y > main.VIEW_H + 48:
			remove_me = true
		return

	facing = -1 if main.player.global_position.x < _cx else 1

	# side-to-side shuffle around the spawn point
	_cx += _shuffle_dir * SHUFFLE_SPD * delta
	if absf(_cx - _base_x) >= SHUFFLE:
		_cx = _base_x + signf(_cx - _base_x) * SHUFFLE
		_shuffle_dir = -_shuffle_dir

	# hop between REAL platforms — find the actual block above/below and land ON its
	# top, phasing through everything in between (SMB1). No platform there => it stays.
	_hop_clock += delta
	if not _hopping and _hop_clock >= HOP_INTERVAL:
		_hop_clock = 0.0
		var tx := int(floor(_cx / 16.0))
		var feet_row := int(round((_level_y + H / 2.0) / 16.0))   # tile whose top it stands on
		var target := -1
		if _up:
			target = _platform_below(tx, feet_row)                # come back down
			if target < 0:
				target = int(round((_base_y + H / 2.0) / 16.0))   # fall back to spawn level
			_up = false
		else:
			target = _platform_above(tx, feet_row)                # hop up onto the platform
			if target >= 0:
				_up = true
		if target >= 0:
			_hopping = true
			_hop_t = 0.0
			_from_y = _level_y
			_to_y = target * 16.0 - H / 2.0                       # centre so feet rest on `target`
	var y := _level_y
	if _hopping:
		_hop_t += delta
		var u := minf(_hop_t / HOP_DUR, 1.0)
		y = lerpf(_from_y, _to_y, u) - sin(PI * u) * HOP_POP
		if _hop_t >= HOP_DUR:
			_hopping = false
			_level_y = _to_y
			y = _to_y

	# hold-then-throw: idle briefly, raise + HOLD the hammer over the head, then let go
	_throw_flash = maxf(0.0, _throw_flash - delta)
	_tclock += delta
	if _tstate == "idle":
		held.visible = false
		if _tclock >= IDLE_DUR:
			_tstate = "wind"
			_tclock = 0.0
	else:
		held.texture = main.tex["hammer3"]   # C3 = head up / handle down, looks held in hand
		held.flip_h = facing < 0
		held.position = Vector2(facing * 2.0, -H / 2.0 - 5.0)   # above the head
		held.visible = true
		if _tclock >= HOLD_DUR:
			main.spawn_hammer(global_position + held.position, _throw_velocity())
			held.visible = false
			_throw_flash = 0.18
			_tstate = "idle"
			_tclock = 0.0

	global_position = Vector2(_cx, y)
	_anim += delta
	_frame()


# --- platform detection: it hops to the top of the nearest real block above/below ---
func _solid(tx: int, ty: int) -> bool:
	if ty < 0 or ty >= 15:
		return false
	var c := Vector2i(tx, ty)
	if main.terrain.get_cell_source_id(c) == -1:
		return false
	var ax: int = main.terrain.get_cell_atlas_coords(c).x
	return ax != main.ATLAS_LAVA_TOP and ax != main.ATLAS_LAVA   # lava isn't standable

# nearest block above whose top is clear (walkable) -> its row, or -1
func _platform_above(tx: int, from_row: int) -> int:
	for r in range(from_row - 1, maxi(from_row - HOP_REACH, -1), -1):
		if _solid(tx, r) and not _solid(tx, r - 1):
			return r
	return -1

# nearest block below whose top is clear, strictly below the current platform -> row, or -1
func _platform_below(tx: int, from_row: int) -> int:
	for r in range(from_row + 1, mini(from_row + HOP_REACH + 1, 15)):
		if _solid(tx, r) and not _solid(tx, r - 1):
			return r
	return -1


# SMB1: one fixed arc every throw — up and toward the bro's facing, never aimed at Mario.
func _throw_velocity() -> Vector2:
	return Vector2(facing * HAMMER_VX, HAMMER_VY)


func _frame() -> void:
	# the RIGHT (B) frames run in REVERSE pose order vs the LEFT (A) frames:
	#   left  -> A4 = raised (hold), A1 = arm-forward (throw)
	#   right -> B1 = raised (hold), B4 = arm-forward (throw)
	var side := "r" if facing > 0 else "l"
	var hold := 1 if facing > 0 else 4
	var thr := 4 if facing > 0 else 1
	var n := hold if _tstate == "wind" else thr
	sprite.texture = main.tex["hbro%s%d" % [side, n]]
	sprite.flip_v = false


# stomped (from Main) — flips off away from Mario
func squish() -> void:
	knock_out(1 if main.player.global_position.x < _cx else -1)

func knock_out(hit_dir := 1) -> void:
	if dead:
		return
	dead = true
	_dead_t = 0.0
	sprite.flip_v = true
	_dvel = Vector2(hit_dir * 60.0, -235.0)   # pop up + a little sideways, then it arcs off

func to_shell() -> void:
	pass
