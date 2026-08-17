extends CharacterBody2D
class_name Player
## The player character. Uses CharacterBody2D + move_and_slide against the
## world StaticBody. Handles walk/run, a variable-height jump, growth/shrink,
## damage, death and the flagpole win sequence.

var main                       # Main level manager (untyped to avoid a cyclic class dependency)
var sprite: Sprite2D
var shape: CollisionShape2D
var col_size: Vector2             # AABB size used for gameplay hit tests
var _caps: CapsuleShape2D         # physics shape — a capsule glides over tile seams

const SMALL := Vector2(12, 14)   # 14 (not 16) so small Mario fits through a 1-tile gap
								 # with ~2px headroom, SMB1-style (his 16px sprite overhangs)
const BIG := Vector2(12, 28)
const DUCK := Vector2(12, 14)       # crouch collision — ~1 tile tall so big/fire Mario fits
									# UNDER a 1-tile gap and can slide through it (SMB1)
const DUCK_DECEL := 120.0           # ABSOLUTE duck-slide deceleration (px/s²). A ~6-tile slide
									# from full run. NOT derived from FRICTION (which is now the gentle
									# SMB1 coast 133 → scaling it made the duck slide on ice).
# SMB1 "RUN over 1-tile gaps": while moving fast, momentum carries Mario across a single-
# tile gap if a foot corner is still over a block — but if he's slow or stopped he FALLS
# straight in (the gaps are real, not invisible floors). Only kicks in above GAP_MIN_SPEED
# (between walk 85.5 and run 148.5, so you must be running). FOOT_SPAN = corner offset;
# CARRY_FALL = how far he can have dropped and still be caught back onto the ledge.
const FOOT_SPAN := 8.0
const CARRY_FALL := 10.0
const GAP_MIN_SPEED := 110.0

var big := false
var fire := false               # fire power (implies big); can shoot fireballs
var facing := 1
var walk_anim := 0.0
var wall_push := 0.0            # >0 while pushing into a wall (is_on_wall flickers)
var ducking := false            # big/fire Mario crouching (hold Down)
var duck_locked := false        # a duck-jump stays ducked until it lands (ignores Down release)

# sprite tier for the current power state: "small" / "big" / "fire"
func tier() -> String:
	if fire: return "fire"
	if big: return "big"
	return "small"

var dead := false
var dead_timer := 0.0
var died_by_pit := false
var death_launched := false      # enemy death: pop-up starts after a brief pose hold

var transforming := false
var transform_timer := 0.0
var transform_to_big := false
var transform_fire := false     # big -> fire flicker (no size change)
# EXACT SMB1 grow/shrink: HandleChangeSize advances one step every 4th frame for
# 10 steps = 40 frames, driven by ChangeSizeOffsetAdder (smbdis / Xkeeper0 smb1).
# Grow alternates small(0)/big(1) with an intermediate(2); shrink alternates
# small(0)/big(1). We map the SMB1 states onto the GROW.png frames.
const TRANSFORM_TIME := 40.0 / 60.0                 # 10 steps x 4 frames @ 60fps (grow)
# SMB1 halts Mario only ~15 frames on an injury shrink (TimerControl $ff→$f0), THEN he
# keeps moving while flashing — far shorter than the ~1s grow freeze, so momentum barely
# stalls. Ours matches that brief hitch instead of pinning him for the full grow length.
const SHRINK_TIME := 55.0 / 60.0                    # SMB1 injury freeze = TimerControl $ff→$c8 = 55 frames (~0.9s)
const TRANSFORM_STEP := 4.0 / 60.0                  # SMB1 change-size cadence: one flicker step per 4 frames
# fire-flower flash: SMB1 CyclePlayerPalette swaps sprite palette every 4 frames
# (FrameCounter/4 & 3), running while TimerControl counts $ff->$c0 = 63 frames,
# then forces palette 0 (fire). Palette 0 = fire; 1..3 = the fl1.png recolours.
const FIRE_TIME := 63.0 / 60.0                       # $ff-$c0 = 63 frames (~1.05s)
const FIRE_STEP := 4.0 / 60.0                        # a new palette every 4 frames
const GROW_SEQ := [0, 1, 0, 1, 0, 1, 2, 0, 1, 2]    # SMB1 growing adder pattern
const SHRINK_SEQ := [0, 1, 0, 1, 0, 1, 0, 1, 0, 1]  # SMB1 shrinking: small<->big
const GROW_FRAME := ["grow1", "grow4", "grow2"]     # 0 small, 1 big, 2 intermediate
const SHRINK_FRAME := ["shrink4", "shrink1"]        # 0 small (D), 1 big (A)

var invuln := 0.0
var jump_held := false
var was_rising := false
var grounded := false            # is_on_floor() OR a foot resting over a 1-tile gap (SMB1)
var stomp_bounce := false        # true during a stomp rebound → fixed arc, no jump-hold float
# sharp-turn (skid): shown when Mario reverses while MOVING on the ground (not from a
# standstill). Re-armed every frame he's still sliding the old way, so it tracks the whole
# slide (~8 frames at run with the slow TURN_ACC); SKID_TIME is just a short tail after.
var skid_timer := 0.0
var skid_dir := 0                # the NEW direction he's turning toward (art faces momentum)
const SKID_TIME := 0.04          # ~2-frame tail after the slide ends
const SKID_MIN_SPEED := 20.0     # must actually be moving to skid (standstill+opposite = no)

# win sequence
var winning := false
var win_phase := 0
var win_timer := 0.0
var win_flip := 0        # frames held on the far side of the pole after flipping over
const WIN_FLIP_HOLD := 30 # how many frames Mario pauses on the far side before dropping


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_caps = CapsuleShape2D.new()
	shape = CollisionShape2D.new()
	shape.shape = _caps
	add_child(shape)
	_set_col(SMALL)
	sprite = Sprite2D.new()
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	sprite.z_index = 5
	add_child(sprite)


func _set_col(sz: Vector2) -> void:
	col_size = sz
	_caps.radius = sz.x / 2.0
	_caps.height = sz.y          # height >= 2*radius (12), true for 16 and 28

func half_w() -> float:
	return col_size.x / 2.0

func get_rect() -> Rect2:
	return Rect2(global_position - col_size / 2.0, col_size)


func spawn(feet_pos: Vector2) -> void:
	visible = true            # win phase 3 hides the player when entering the castle
	z_index = 0               # restore normal draw order (win walk raises it)
	# start at the carried-over power tier (main.saved_tier): small / big / fire. Death
	# sets it back to "small", so a respawn is small; beating a level keeps the tier.
	var t: String = main.saved_tier
	fire = (t == "fire")
	big = (t == "big" or t == "fire")
	_set_col(BIG if big else SMALL)
	dead = false
	dead_timer = 0.0
	died_by_pit = false
	death_launched = false
	set_collision_mask_value(1, true)   # kill() clears this to fall through the world;
										# restore it so a mid-death restart/warp doesn't
										# spawn Mario falling straight through the floor
	transforming = false
	invuln = 0.0
	winning = false
	win_phase = 0
	win_timer = 0.0
	stomp_bounce = false
	skid_timer = 0.0
	velocity = Vector2.ZERO
	facing = 1                    # start facing right
	global_position = Vector2(feet_pos.x, feet_pos.y - col_size.y / 2.0)
	_apply_frame(main.tex[tier() + "_stand_r"])


func _physics_process(delta: float) -> void:
	if main.paused:
		return
	if main.axe_ending:
		return   # frozen while the bridge collapses (he stands on the axe ledge)
	if main.intro_12:
		return   # 1-2 surface intro — main drives Mario's stroll into the pipe
	if main.pipe_exit:
		return   # 1-2 exit — main drives Mario slipping into the giant pipe
	if main.game_state == "emerge":
		return   # EXTRA 1 arrival — main drives Mario rising out of the pipe
	if main.game_state == "trap":
		return   # Level11 reward trap — main drives Mario dropping out of the ceiling pipe
	if main.sonic_demo:
		return   # Level10 Sonic preview — Mario is hidden/idle
	if main.game_state == "sonic_cut":
		return   # 1-2 cutscene — Mario watches from the pipe while Sonic performs
	if main.start_delay > 0.0:
		return   # frozen during the brief stage-start "get ready" (Mario can't move yet)
	if transforming:
		_update_transform(delta)
		return
	if winning:
		_update_win(delta)
		return
	if dead:
		_update_dead(delta)
		return
	if main.game_state == "rescue":
		if main.rescue_walking:
			_update_rescue_walk(delta)   # scripted walk toward mac; otherwise frozen (mac talking)
		return
	if main.game_state == "clear":
		return

	_update_alive(delta)


func _update_alive(delta: float) -> void:
	# SMB1: only while RUNNING does "a foot over a block across a 1-tile gap" count as
	# grounded (so you glide across). Slow/stopped → not grounded → you fall in.
	var on_floor := is_on_floor() or (absf(velocity.x) > GAP_MIN_SPEED and _foot_support_top() > -INF)
	skid_timer = maxf(0.0, skid_timer - delta)
	var running := Input.is_action_pressed("run")
	var max_s: float = main.RUN_MAX if running else main.WALK_MAX
	var acc: float = (main.RUN_ACC if running else main.WALK_ACC) if on_floor else main.AIR_ACC

	# duck — big/fire Mario holding Down. ENTER only on the ground. A duck-jump stays
	# ducked for the WHOLE airtime until it lands (even if Down is released mid-air);
	# you can't newly enter a duck mid-air. On landing, normal rules resume (hold Down =
	# land ducked). While ducked you can't drive movement.
	var want_duck := ducking
	if on_floor:
		want_duck = (big or fire) and Input.is_action_pressed("move_down")
		duck_locked = want_duck                     # remember it as we may leave the ground
	elif duck_locked and (big or fire):
		want_duck = true                            # locked ducked until we land
	else:
		want_duck = false
		duck_locked = false
	# can't stand up under a low ceiling — stay crouched so he keeps SLIDING under the blocks
	if not want_duck and ducking and (big or fire) and _blocked_above(BIG.y):
		want_duck = true
	# crouch shrinks the collision (feet stay planted) so big/fire Mario fits under a 1-tile
	# gap; standing restores full height. Small Mario never ducks.
	if big or fire:
		_set_stance(DUCK if want_duck else BIG)
	ducking = want_duck

	var dir := 0.0
	if not ducking:
		if Input.is_action_pressed("move_left"):
			dir = -1.0
			facing = -1
		elif Input.is_action_pressed("move_right"):
			dir = 1.0
			facing = 1

	if dir != 0.0:
		if velocity.x != 0.0 and signf(dir) != signf(velocity.x):
			# reversing — strong skid so turns feel crisp, not slippery
			if on_floor and absf(velocity.x) > SKID_MIN_SPEED:
				skid_timer = SKID_TIME       # show the sharp-turn frame (not from a standstill)
				skid_dir = int(dir)
			velocity.x = move_toward(velocity.x, dir * max_s, main.TURN_ACC * delta)
		elif absf(velocity.x) > max_s:
			# above the current top speed (e.g. let go of run) — ease down, no snap
			velocity.x = move_toward(velocity.x, dir * max_s, main.FRICTION * delta)
		else:
			velocity.x = move_toward(velocity.x, dir * max_s, acc * delta)
	elif on_floor:
		# no input on the ground — friction brings Mario to a stop. Ducking uses a
		# lighter friction so a running duck slides a bit before stopping (SMB1).
		var fr: float = DUCK_DECEL if ducking else main.FRICTION
		velocity.x = move_toward(velocity.x, 0.0, fr * delta)
	# (no input in the air keeps horizontal momentum, like the real games)

	# jump — fresh press only (allowed straight out of a duck, SMB-style)
	var jump_key := Input.is_action_pressed("jump")
	if jump_key and on_floor and not jump_held:
		# jump HEIGHT rises with ACTUAL horizontal speed (momentum), not the run button —
		# SMB1: a real running jump goes ~17px higher, but standing still + run does not.
		# The sqrt(grav_scale) keeps launch/gravity consistent so DISTANCE is tuned apart.
		var st := _jump_speed_t()
		var base_v0: float = lerpf(main.JUMP_VELOCITY, main.JUMP_VELOCITY_RUN, st)
		velocity.y = base_v0 * sqrt(lerpf(1.0, main.JUMP_RUN_GRAV_SCALE, st))
		jump_held = true
		main.sfx("jump_big" if (big or fire) else "jump_small")
	elif not jump_key:
		jump_held = false

	# gravity — lighter while rising and holding jump (variable jump height); also
	# scaled by horizontal speed to tune running-jump reach (see _jump_speed_grav_scale)
	var g: float = main.GRAVITY * _jump_speed_grav_scale()
	if velocity.y < 0 and jump_key and not stomp_bounce:
		g *= main.JUMP_HOLD_GRAV          # rising + holding = floaty variable-height ascent
										  # (NOT after a stomp — a stomp bounce is a fixed arc)
	elif velocity.y >= 0.0:
		g *= main.FALL_GRAV_SCALE         # softer descent (SMB1 feel); height-neutral
	velocity.y = minf(velocity.y + g * delta, main.MAX_FALL)
	if velocity.y >= 0.0:
		stomp_bounce = false              # bounce arc peaked → normal control resumes

	was_rising = velocity.y < 0
	var pre_vx := velocity.x
	var pre_x := global_position.x
	move_and_slide()
	# a glancing head-bump on a block corner shouldn't shove Mario sideways —
	# if he only clipped a ceiling (no real wall), keep his horizontal motion
	var head_hit := false
	var wall_hit := false
	for i in range(get_slide_collision_count()):
		var n := get_slide_collision(i).get_normal()
		if n.y > 0.3:
			head_hit = true
		if absf(n.x) > 0.7:
			wall_hit = true
	if head_hit and not wall_hit:
		global_position.x = pre_x + pre_vx * delta
		velocity.x = pre_vx
	_handle_head_bump()

	# SMB1 run-over-gaps: only while running fast does a foot still on a block lift Mario
	# back onto the ledge (never while rising/jumping). Slow or stopped → he drops in.
	var fast := absf(velocity.x) > GAP_MIN_SPEED
	var carry_top := _foot_support_top() if fast else -INF
	if not is_on_floor() and velocity.y >= 0.0 and carry_top > -INF:
		global_position.y = carry_top - col_size.y / 2.0
		velocity.y = 0.0
	grounded = is_on_floor() or carry_top > -INF

	# Landing-on-a-ledge fix: if Mario dropped slightly INTO the top of a block/pipe (his feet
	# ended up a few px below its top edge), he gets wedged on the corner and can't walk off it.
	# Lift his feet back up onto the block top so he lands on it properly and can move.
	if grounded:
		var feet2: float = global_position.y + col_size.y / 2.0
		var lift := -INF
		for dx in [-(col_size.x / 2.0 - 1.0), 0.0, col_size.x / 2.0 - 1.0]:
			lift = maxf(lift, _sunk_top(global_position.x + dx, feet2))
		if lift > -INF and feet2 > lift + 0.4:
			global_position.y = lift - col_size.y / 2.0
			velocity.y = 0.0

	# track "pushing into a wall" for the strut animation. Use a real wall at BODY height,
	# NOT is_on_wall() — the latter flickers true on a block CORNER Mario is standing on,
	# which made him "moon-walk" on a ledge edge. A block under his feet no longer counts.
	if dir != 0.0 and _wall_ahead(dir):
		wall_push = 0.12
	else:
		wall_push = maxf(0.0, wall_push - delta)

	# fire Mario shoots a fireball on a fresh press of the run/fire button
	# (Z / Shift) — hold to run, tap to fire, like Mario 1's B button
	if fire and Input.is_action_just_pressed("run"):
		var muzzle := global_position + Vector2(facing * (half_w() + 3.0), -2.0)
		main.spawn_fireball(muzzle, facing)

	if invuln > 0.0:
		invuln -= delta

	# walk animation
	if grounded and wall_push > 0.0 and dir != 0.0:
		# pushing into a wall/obstacle (not actually moving) — slow, steady
		# strut at 0.2s per frame instead of the rapid speed-based cadence
		walk_anim += delta * 5.0
	elif grounded and absf(velocity.x) > 6.0:
		walk_anim += absf(velocity.x) * delta * 0.25
	else:
		walk_anim = 0.0

	_animate()

	# reached the flagpole? (the pole tiles are solid, so the body stops a hair
	# short of the exact column — trigger a few px early so it always fires).
	# has_flag == false on levels with a custom ending (1-2) — no flagpole win there.
	if main.has_flag and not winning and global_position.x + half_w() >= main.FLAG_X * main.TILE - 6:
		_start_win()

	# fell in a pit — no death pop-up, just keep falling + death sound
	if global_position.y > main.VIEW_H + 40:
		kill(true)


# 0 at walking pace → 1 at full run, from ACTUAL horizontal speed (momentum), NOT the
# run button — so standing still while holding run gives no jump boost.
func _jump_speed_t() -> float:
	var wm: float = main.WALK_MAX
	var rm: float = main.RUN_MAX
	return clampf((absf(velocity.x) - wm) / (rm - wm), 0.0, 1.0)


# Jump gravity multiplier from horizontal speed (1.0 at walk → main.JUMP_RUN_GRAV_SCALE at
# full run). Tunes running-jump air-time / horizontal reach independently of jump height.
func _jump_speed_grav_scale() -> float:
	return lerpf(1.0, main.JUMP_RUN_GRAV_SCALE, _jump_speed_t())


func _set_stance(sz: Vector2) -> void:
	# resize the collision (crouch <-> stand) keeping the FEET planted, so ducking lowers
	# the head instead of sinking/popping Mario.
	if col_size == sz:
		return
	var feet: float = global_position.y + col_size.y / 2.0
	_set_col(sz)
	global_position.y = feet - col_size.y / 2.0

func _blocked_above(stand_h: float) -> bool:
	# would standing up to stand_h overlap a solid tile? (can't un-duck under a ceiling)
	if not main or not main.terrain:
		return false
	var feet: float = global_position.y + col_size.y / 2.0
	var top_standing: float = feet - stand_h + 1.0        # where the head would be (1px margin)
	var top_now: float = global_position.y - col_size.y / 2.0
	var hw := half_w()
	var c0 := int(floor((global_position.x - hw) / main.TILE))
	var c1 := int(floor((global_position.x + hw - 0.001) / main.TILE))
	var r0 := int(floor(top_standing / main.TILE))
	var r1 := int(floor((top_now - 0.001) / main.TILE))
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			if main.terrain.get_cell_source_id(Vector2i(c, r)) >= 0:
				return true
	return false


# Top y of a solid tile at column `px` that Mario has sunk slightly INTO on landing (its top
# sits just above his feet, within SUNK_MAX px) — used to lift him back onto the surface so a
# corner-landing doesn't wedge him. -INF if his feet are cleanly on/above a tile top.
const SUNK_MAX := 8.0
func _sunk_top(px: float, feet_y: float) -> float:
	if not main or not main.terrain:
		return -INF
	var col := int(floor(px / main.TILE))
	var r := int(floor(feet_y / main.TILE))
	var c := Vector2i(col, r)
	if main.terrain.get_cell_source_id(c) >= 0:
		var ax: int = main.terrain.get_cell_atlas_coords(c).x
		if ax != main.ATLAS_LAVA_TOP and ax != main.ATLAS_LAVA:
			var top: float = float(r) * main.TILE
			if feet_y > top and feet_y - top <= SUNK_MAX:
				return top
	return -INF

# Is there a real wall in direction `d` (-1/+1)? A solid tile beside Mario at BODY height —
# sampled between just under his head and just above his feet, so the ledge/step he's standing
# ON (a block whose top is at his feet) is never mistaken for a wall.
func _wall_ahead(d: float) -> bool:
	if not main or not main.terrain:
		return false
	var col := int(floor((global_position.x + d * (col_size.x / 2.0 + 1.0)) / main.TILE))
	var top_y: float = global_position.y - col_size.y / 2.0 + 2.0
	var bot_y: float = global_position.y + col_size.y / 2.0 - 3.0    # skip the floor block at the feet
	for r in range(int(floor(top_y / main.TILE)), int(floor(bot_y / main.TILE)) + 1):
		var c := Vector2i(col, r)
		if main.terrain.get_cell_source_id(c) >= 0:
			var ax: int = main.terrain.get_cell_atlas_coords(c).x
			if ax != main.ATLAS_LAVA_TOP and ax != main.ATLAS_LAVA:
				return true
	return false

func _foot_support_top() -> float:
	# SMB1 two-corner ground check: Mario stays up while his centre OR either foot corner
	# (a full tile apart) is over a solid tile at his feet — so 1-tile gaps never swallow
	# him. Returns the supporting tile's top y, or -INF over open space (a wider gap).
	if not main or not main.terrain:
		return -INF
	var feet_y: float = global_position.y + col_size.y / 2.0
	var best := -INF
	for dx in [-FOOT_SPAN, 0.0, FOOT_SPAN]:
		best = maxf(best, _ground_top_at(global_position.x + dx, feet_y))
	return best

func _ground_top_at(px: float, feet_y: float) -> float:
	# top y of a solid tile directly under px whose top sits within the catch window
	# around the feet ([feet-CARRY_FALL .. feet+6]); -INF if none
	var col := int(floor(px / main.TILE))
	var r0 := int(floor((feet_y - CARRY_FALL) / main.TILE))
	var r1 := int(floor((feet_y + 6.0) / main.TILE))
	for r in range(r0, r1 + 1):
		if main.terrain.get_cell_source_id(Vector2i(col, r)) >= 0:
			var top: float = float(r) * main.TILE
			if top >= feet_y - CARRY_FALL and top <= feet_y + 6.0:
				return top
	return -INF


func _handle_head_bump() -> void:
	if not was_rising:
		return
	# Manual ceiling check by tile — do NOT gate on move_and_slide's collision: the
	# rounded capsule can slip up past a block's corner WITHOUT registering a hit, which
	# let small Mario clip through a solid block. Find the solid tile the head overlaps
	# most (scanning the whole head width so off-centre hits still register on either
	# side, while picking the single best overlap means straddling two never bumps both).
	# nudge up only 1px into the block row: enough to catch a clean stop / a penetration,
	# but LESS than small Mario's ~2px headroom so running UNDER a 1-tile ceiling (where
	# his head sits ~2px below it) does NOT false-trigger a bump.
	var head_y := global_position.y - col_size.y / 2.0 - 1.0
	var row := int(floor(head_y / main.TILE))
	var hw := half_w()
	var left := global_position.x - hw
	var right := global_position.x + hw
	var c0 := int(floor(left / main.TILE))
	var c1 := int(floor((right - 0.001) / main.TILE))
	var best_col := -9999
	var best_overlap := 0.0
	for col in range(c0, c1 + 1):
		if main.terrain.get_cell_source_id(Vector2i(col, row)) < 0:
			continue                                  # only solid tiles are bumpable
		var tile_l: float = col * main.TILE
		var overlap: float = minf(right, tile_l + main.TILE) - maxf(left, tile_l)
		if overlap > best_overlap:
			best_overlap = overlap
			best_col = col
	if best_col == -9999:
		return
	# STOP the rise on any head-bump (SMB1 bonk) — do this the instant a bump is detected,
	# BEFORE bump_block runs. CRITICAL: a brick/?-block bump ERASES its tile for the hop
	# animation, so if we don't halt the rise here a fast jumper sails up through the now-
	# empty space and clips onto the block (small Mario through a 1-tile brick lip).
	if velocity.y < 0.0:
		velocity.y = 0.0
	# if the head had already pushed into the block, shove it back out below.
	var min_center_y: float = float(row + 1) * main.TILE + col_size.y / 2.0
	if global_position.y < min_center_y:
		global_position.y = min_center_y
	main.bump_block(best_col, row)


# =========================================================================
# animation
# =========================================================================
func _apply_frame(t: Texture2D, flip := false) -> void:
	# Most poses use dedicated left/right art (no flip); the single duck frame is
	# mirrored to face the way Mario was already facing.
	sprite.texture = t
	sprite.flip_h = flip
	sprite.material = null
	# bottom-align the sprite to the collision box
	sprite.position.y = col_size.y / 2.0 - t.get_height() / 2.0

func _animate() -> void:
	var pre := tier()
	var kf := _pose_key_flip()
	_apply_frame(main.tex[pre + kf[0]], kf[1])

# The current pose as a [suffix, flip] pair, independent of the power tier — so the
# fire-flower flash can recolour whatever pose Mario is frozen in.
func _pose_key_flip() -> Array:
	# only big/fire Mario has a duck sprite — small Mario can't duck (guards against
	# "small_duck" when a duck-shrink leaves `ducking` set as we drop to the small tier)
	if ducking and (big or fire):
		# duck art faces left; mirror when facing right so it keeps facing
		return ["_duck", facing > 0]
	elif not grounded:
		return ["_jump_r" if facing >= 0 else "_jump_l", false]
	elif skid_timer > 0.0:
		# sharp-turn frame — art faces left, mirror when sliding right (skid_dir < 0)
		return ["_skid", skid_dir < 0]
	elif absf(velocity.x) > 9.0 or wall_push > 0.0:
		var base := 4 if facing >= 0 else 1   # walk 1-3 face left, 4-6 face right
		return ["_walk%d" % (base + int(walk_anim) % 3), false]
	return ["_stand_r" if facing >= 0 else "_stand_l", false]


# =========================================================================
# growth / damage / death
# =========================================================================
func grow() -> void:
	if big or transforming:
		return
	transforming = true
	transform_to_big = true
	transform_timer = 0.0
	# SMB1 keeps Mario's momentum through the grow freeze (Player_X_Speed untouched) —
	# velocity is inert during the flicker and carries straight through it.
	main.sfx("powerup")

var _fire_pose: Array = ["_stand_r", false]   # pose Mario is frozen in for the flash

func become_fire() -> void:
	# big Mario grabbing a flower gains fire power (no size change). SMB1 freezes him
	# and cycles his palette; we capture his current pose so the flash stays in it.
	if fire or transforming:
		return
	transforming = true
	transform_fire = true
	transform_timer = 0.0
	# momentum carries through the flash too (SMB1 leaves Player_X_Speed alone)
	_fire_pose = _pose_key_flip()
	main.sfx("powerup")

func _shrink() -> void:
	transforming = true
	transform_to_big = false
	transform_timer = 0.0
	# SMB1 has NO knockback on a hit — Mario keeps ALL his momentum. He pauses only for
	# the brief shrink flicker, then resumes moving at the same speed (velocity is left
	# untouched here; it's inert during the flicker and carries straight through it).
	fire = false                 # a hit drops fire power straight back to small
	main.sfx("powerdown")        # plays only on power-down, never when small (that's a kill)

func _update_transform(delta: float) -> void:
	transform_timer += delta
	# fire flower: exact SMB1 palette flash — cycle palette 0..3 every 4 frames while
	# frozen for 63 frames, ending on palette 0 (fire). 0 = fire sprite; 1..3 = the
	# green / gray / brown recolours from fl1.png.
	if transform_fire:
		var pal: int = int(transform_timer / FIRE_STEP) % 4
		var key: String = _fire_pose[0]
		var flip: bool = _fire_pose[1]
		if pal == 0:
			_apply_frame(main.tex["fire" + key], flip)     # real fire-tier pose
		else:
			_apply_frame(main.get_fire_flash(key, pal), flip)   # recoloured big pose
		if transform_timer >= FIRE_TIME:
			fire = true
			transforming = false
			transform_fire = false
			_animate()
		return
	# grow / shrink: exact SMB1 flicker — step every 4th frame through the 10-entry
	# adder table, mapping each SMB1 state onto a GROW.png frame. The step advances at a
	# FIXED 4-frame cadence (SMB1's change-size speed); a short shrink just shows fewer
	# steps at the same speed instead of cramming all 10 into the duration (a fast blur).
	var dur: float = TRANSFORM_TIME if transform_to_big else SHRINK_TIME
	var raw_step: int = int(transform_timer / TRANSFORM_STEP)
	var key: String
	if transform_to_big:
		key = GROW_FRAME[GROW_SEQ[mini(raw_step, 9)]]
	else:
		# keep the small<->big flicker going for the whole (longer) injury freeze instead
		# of holding on the last frame — SHRINK_SEQ alternates, so wrap it
		key = SHRINK_FRAME[SHRINK_SEQ[raw_step % SHRINK_SEQ.size()]]
	_apply_frame(main.tex[key], facing < 0)
	if transform_timer >= dur:
		var feet := global_position.y + col_size.y / 2.0
		if transform_to_big:
			big = true
			_set_col(BIG)
		else:
			big = false
			_set_col(SMALL)
			ducking = false          # small Mario can't duck — drop the crouch on shrink
			invuln = 1.5
		global_position.y = feet - col_size.y / 2.0
		transforming = false
		_animate()

func hurt() -> void:
	if invuln > 0.0 or dead or transforming:
		return
	if big:
		_shrink()
	else:
		kill()

func bounce() -> void:
	velocity.y = main.STOMP_BOUNCE
	stomp_bounce = true      # fixed rebound height — pressing/holding jump can't inflate it
	jump_held = true         # and no fresh jump can fire out of the bounce

func kill(from_pit := false) -> void:
	if dead:
		return
	dead = true
	dead_timer = 0.0
	died_by_pit = from_pit
	death_launched = false
	set_collision_mask_value(1, false)   # fall through the world
	if not from_pit:
		velocity = Vector2.ZERO               # hold the death pose in place first
		_apply_frame(main.tex["death"])       # front-facing death pose
	# pit deaths keep their downward fall and current frame — no pop-up animation
	main.stop_music_play_death()

func _update_dead(delta: float) -> void:
	dead_timer += delta
	# enemy death: show the death pose in place for 0.20s, then launch the pop-up
	if not died_by_pit:
		if dead_timer < 0.20:
			return
		if not death_launched:
			velocity.y = -568                 # pop up ~35px higher than the old -420
			death_launched = true
	# fall at half speed (half gravity + half terminal) once descending
	if velocity.y >= 0.0:
		velocity.y = minf(velocity.y + main.GRAVITY * 0.5 * delta, main.MAX_FALL * 0.5)
	else:
		velocity.y = minf(velocity.y + main.GRAVITY * delta, main.MAX_FALL)
	global_position += velocity * delta
	if dead_timer > (3.6 if not died_by_pit else 3.0):
		set_collision_mask_value(1, true)
		main.saved_tier = "small"   # dying costs your power — respawn small
		main.reset(true)


# =========================================================================
# flagpole win sequence
# =========================================================================
func _start_win() -> void:
	winning = true
	win_phase = 0
	win_timer = 0.0
	z_index = 2               # walk in front of the castle sprite (fg_renderer z=1)
	global_position.x = main.FLAG_X * main.TILE - half_w()
	velocity = Vector2.ZERO
	main.score += 2000
	main.on_reach_flag()

func _update_win(delta: float) -> void:
	win_timer += delta
	# he stops the instant his feet hit the base block (the brick), on top of it
	var stop_y: float = (main.FLOOR - 1) * main.TILE - col_size.y / 2.0
	if win_phase == 0:
		global_position.y += 130.0 * delta   # the flag lowers on its own (main._update_flag_slide)
		# cling to the pole: alternate the two flagpole-slide frames for this tier
		var f: int = int(win_timer / 0.1) % 2
		_apply_frame(main.tex[tier() + ("_pole2" if f == 1 else "_pole1")])
		# hug the pole (sprite's right edge on the pole), nudged 1px right
		global_position.x = (main.FLAG_X * main.TILE + 8) - sprite.texture.get_width() / 2.0 + 1.0
		if global_position.y >= stop_y:
			global_position.y = stop_y       # STOP the instant he hits the brick
			win_phase = 1
			win_timer = 0.0
	elif win_phase == 1:
		# stopped on the brick, still clinging — wait for the flag to finish landing
		_apply_frame(main.tex[tier() + "_pole1"])
		global_position.x = (main.FLAG_X * main.TILE + 8) - sprite.texture.get_width() / 2.0 + 1.0
		if not main.flag_sliding:
			win_phase = 2               # flag down → flip over to the other side
			win_flip = 0
			facing = -1                 # now on the RIGHT of the pole, facing it
	elif win_phase == 2:
		# flipped to the far (right) side of the pole; hold for 6 frames, then drop off
		_apply_frame(main.tex[tier() + "_pole1"], true)   # mirrored = other side
		global_position.x = (main.FLAG_X * main.TILE + 8) + sprite.texture.get_width() / 2.0 - 1.0
		win_flip += 1
		if win_flip >= WIN_FLIP_HOLD:
			win_phase = 3
			facing = 1
	elif win_phase == 3:
		velocity.x = 84.0
		velocity.y = minf(velocity.y + main.GRAVITY * delta, main.MAX_FALL)
		move_and_slide()
		grounded = is_on_floor()   # _animate() reads this; keep it fresh for the walk cycle
		walk_anim += delta * 12.0
		_animate()
		# walk all the way to the castle doorway, then vanish into it
		if global_position.x >= main.CASTLE_X * main.TILE + 29:
			win_phase = 4
			main.on_enter_castle()
	elif win_phase == 4:
		visible = false

# End of Bowser's castle: after the bridge falls Mario walks across the throne-room
# floor toward mac, stopping RESCUE_STOP_GAP tiles short. Same scripted-walk pattern as
# the flagpole finish (velocity + gravity + move_and_slide + the walk animation).
func _update_rescue_walk(delta: float) -> void:
	facing = 1
	if global_position.x < main.rescue_stop_x:
		velocity.x = 84.0
	else:
		velocity.x = 0.0
		global_position.x = main.rescue_stop_x
		main.rescue_walking = false          # arrived — main advances the rescue phase
	velocity.y = minf(velocity.y + main.GRAVITY * delta, main.MAX_FALL)
	move_and_slide()
	grounded = is_on_floor()
	walk_anim += delta * 12.0
	_animate()                               # velocity.x == 0 on arrival -> stand frame, facing mac
