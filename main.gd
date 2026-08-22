extends Node2D
class_name Main
## SMB 1-1 homage — idiomatic Godot 4.7 port of the HTML/JS original.
## The level manager: builds the tile grid, generates world collision,
## spawns the player/enemies/items, drives the camera, HUD and audio, and
## resolves entity-vs-entity gameplay collisions each physics frame.

const TILE := 16
const ROWS := 15
var LW := 214              # level width in tiles (set per level)
const FLOOR := 13          # top row of the ground (rows 13,14 solid)
const VIEW_W := 256
const VIEW_H := 240

var FLAG_X := 198          # flagpole column (set per level, or by painting the flag marker)
var CASTLE_X := 202        # castle column (set per level)
const FLAG_TO_CASTLE := 4  # tiles the castle sits right of the flagpole when placed by marker

# atlas x indices inside tiles.tileset.tres (see tools/gen_tiles.gd)
const ATLAS_GROUND := 0
const ATLAS_STAIR := 4
const ATLAS_QUESTION := 2
const ATLAS_USED := 3
const ATLAS_BRICK := 1
const ATLAS_MUSHROOM := 12
# purple variants (paintable; behave like their counterparts). Ground(15)/stair(16)/
# pipe(17-20) are plain solids (collision only, no bump code); only these two act:
const ATLAS_USED_PURPLE := 21
const ATLAS_BRICK_PURPLE := 22
# alt ? blocks: same orange ? face + pulse as ATLAS_QUESTION/ATLAS_MUSHROOM, but
# they turn into the PURPLE used block (ATLAS_USED_PURPLE) when hit.
const ATLAS_QUESTION_PURPLE := 23
const ATLAS_MUSHROOM_PURPLE := 24
# TRAP-mushroom ? blocks (one per colour): look/pulse like a normal ? block, but dispense the
# upside-down mushroom that kills on collect. 43 = orange (→ orange used), 44 = purple (→ purple).
const ATLAS_TRAP_MUSH := 43
const ATLAS_TRAP_MUSH_PURPLE := 44
# brick-break debris chunk (B2), drawn as rotating particles — not real tiles.
# orange piece for the orange brick, purple piece for the purple brick.
const ATLAS_PIECE := 25
const ATLAS_PIECE_PURPLE := 26
# castle/lava (2-4 style): 27 = castle ground block (plain solid); 28 = lava surface
# (wavy top), 29 = lava body — both NO collision (Mario falls in) + kill on contact.
const ATLAS_CASTLE := 27
const ATLAS_LAVA_TOP := 28
const ATLAS_LAVA := 29
# 30 = plain standalone block (blockc.png): solid, and when bumped from below it
# behaves like an already-spent/empty block — bump sound, no hop, no reward.
const ATLAS_BLOCKC := 30
# bridge.png tiles: 31 = plank (SOLID platform, like a floor block, no special code);
# 32 = chain, 33 = axe — both walk-through background decorations (no collision). The
# axe is the future stage-ender that drops the bridge (to be wired up later).
const ATLAS_BRIDGE := 31
const ATLAS_CHAIN := 32
const ATLAS_AXE := 33
# "pipe over" giant-pipe placeholder (col 34): a plain SOLID block with a "U in a block"
# palette icon — paint it to block out the large pipe structure. Real art/behaviour TBD.
const ATLAS_PIPEUP := 34

# ---- physics tuning (px / s) --------------------------------------------
const GRAVITY := 2100.0               # falling gravity
const MAX_FALL := 300.0               # SMB1 terminal fall ≈4.5px/frame (~270); 300 keeps a
									  # touch of headroom. Low cap = the drifty Mario-1 descent (was 440/560)
# AUTHENTIC SMB1 acceleration/friction (FrictionData 0xe4/0x98/0xd0 ÷256 ÷16 ×3600 px/s²).
# Mario builds speed GRADUALLY (~50 frames to full run) and COASTS to a stop — the signature
# momentum feel. Much gentler than arcade-snappy values.
const WALK_ACC := 133.0               # ground acceleration (walk)  ~0x98
const RUN_ACC := 183.0                # ground acceleration (run)   ~0xd0
const AIR_ACC := 150.0                # air steering (SMB1 is limited but present)
const WALK_MAX := 93.75               # SMB1 max walk ≈1.5 px/frame × 60
const RUN_MAX := 153.75              # SMB1 max run  ≈2.5 px/frame × 60
const FRICTION := 133.0               # ground friction — SMB1 gentle coast (~1s from full run)
const TURN_ACC := 380.0              # skid deceleration when reversing. AUTHENTIC SMB1: the
									 # skid is ~2x the run accel (~370 px/s²) → a full-run turn slides
									 # ~2 tiles over ~24 frames, like Mario 1 (was 1150 → only ~10px)
# SMB1-style variable jump: a GENTLE launch (so a quick tap only hops ~1 tile /
# ~16px, like Mario 1) + VERY light hold-gravity (so holding still floats up to the
# ~4-block max). The old strong launch (-389) floored even a 1-frame tap at ~36px.
const JUMP_VELOCITY := -259.0        # tap ~16px, full hold ~68px (walk, ≈4 blocks)
const JUMP_VELOCITY_RUN := -290.0    # full-SPEED launch: ~+17px higher (≈5 blocks), like SMB1.
									 # launch lerps V→V_RUN by ACTUAL speed (player.gd): momentum earns the height, standing+run does NOT
const JUMP_HOLD_GRAV := 0.225        # light rising gravity while holding = high max, low tap
# Descent-only gravity scale (SMB1's fall is softer/floatier than its sequels).
# Applied ONLY while falling, so jump peak height is untouched (the rise is unchanged).
const FALL_GRAV_SCALE := 0.93        # ~1950 effective fall gravity; 1.0 = off
# Speed-scaled jump gravity: gravity is multiplied by this at full run speed (1.0 at
# walk, lerp in between). The launch is sqrt-compensated so PEAK HEIGHT and TAP height
# stay identical at every speed — ONLY the running-jump air-time / horizontal reach
# changes. <1 = floatier & farther running jumps; >1 = snappier & shorter. 1.15 holds
# the running-jump reach at ~8.2 tiles even though the speed-based launch (above) now
# makes it +17px higher. Distance dial only — never affects any jump height.
const JUMP_RUN_GRAV_SCALE := 1.15
const STOMP_BOUNCE := -360.0         # fixed stomp rebound ≈2 tiles. player.stomp_bounce
									 # disables the jump-hold float during it, so pressing jump
									 # can NOT inflate the bounce into a big jump (it's a set arc)
const ENEMY_SPD := 34.0

# ---- level (loaded from the Level1 scene) --------------------------------
const LEVEL_SCENE := preload("res://Level1.tscn")
const LEVEL2_SCENE := preload("res://Level2.tscn")
const LEVEL3_SCENE := preload("res://Level3.tscn")
const LEVEL4_SCENE := preload("res://Level4.tscn")
const LEVEL5_SCENE := preload("res://Level5.tscn")
const LEVEL6_SCENE := preload("res://Level6.tscn")
const LEVEL7_SCENE := preload("res://Level7.tscn")
const LEVEL8_SCENE := preload("res://Level8.tscn")   # world 2-4 (castle/lava)
const LEVEL9_SCENE := preload("res://Level9.tscn")   # "EXTRA 1" — short overground bonus
const LEVEL10_SCENE := preload("res://Level10.tscn") # "SONIC" — animation preview (demo)
const LEVEL11_SCENE := preload("res://Level11.tscn") # blank flat starter (30 wide, 2 ground rows)
const LEVEL12_SCENE := preload("res://Level12.tscn") # blank UNDERGROUND stage (400 wide)
const LEVEL13_SCENE := preload("res://Level13.tscn") # blank regular stage (300 wide)
const LEVEL14_SCENE := preload("res://Level14.tscn") # blank OVERGROUND stage (30 wide)
const LEVEL15_SCENE := preload("res://Level15.tscn") # single-screen DONKEY KONG arena
const LEVEL16_SCENE := preload("res://Level16.tscn") # 3-3: "eerily too easy" overworld
const LEVEL17_SCENE := preload("res://Level17.tscn") # 3-4: the FINAL LEVEL (blank starter)
const SOURCE_ID := 0

# =========================================================================
# LEVEL LINEUP — edit this to set the PLAY ORDER and the world LABELS.
# Each row = one level, in the order it's played: [scene file #, label shown].
# e.g. [4, "1-2"] means "play Level4.tscn second, shown as 1-2". A scene's
# geometry (width, flagpole, dark bg, music) follows its FILE via LEVEL_GEOMETRY
# below — so you only touch this list to reorder/relabel.
# =========================================================================
const LEVEL_ORDER := [
	[1, "1-1"],   # 1st — Level1.tscn
	[4, "1-2"],   # 2nd — Level4.tscn, relabelled 1-2 (right after 1-1)
	[7, "1-3"],   # 3rd — Level7.tscn, moved here + renamed 1-3 (easier level earlier)
	[8, "1-4"],   # 4th — Level8.tscn (Bowser castle + mac ending), labelled 1-4
	[5, "3-2"],
	[12, "2-2"],  # 6th — Level12.tscn, promoted into the sequence as 2-2
	[2, "2-1"],   # 7th — Level2.tscn, moved here + renamed 2-1 (the harder level, later)
	[3, "3-1"],   # 8th — Level3.tscn, relabelled 3-1
	[9, "1-2"],   # 9th — Level9.tscn: the END SEQUENCE of 1-2 (pipe warp target), shown as "1-2"
	[10, "SONIC"],   # 10th — Level10.tscn: Sonic animation preview (debug key 0)
	[11, "1-2"],     # 11th — Level11.tscn: the SHORTCUT-TRAP room, still "part of" 1-2 (debug key -)
	[6, "1-6"],      # 12th — Level6.tscn: parked here after 2-2 took its old slot 6 (debug key =)
	[13, "2-3"],     # 13th — Level13.tscn: World 2-3, comes after 2-2, leads to 2-4 (debug key BACKSPACE)
	[14, "2-2"],     # 14th — Level14.tscn: the 2nd Sonic cutscene, the TAIL of 2-2 (pipe warp target), shown as "2-2" (debug key \)
	[15, "2-4"],     # 15th — Level15.tscn: the DONKEY KONG stage, labelled 2-4 (debug key ])
	[16, "3-3"],     # 16th — Level16.tscn: the "eerily too easy" overworld (debug key [)
	[17, "3-4"],     # 17th — Level17.tscn: the FINAL LEVEL (debug key ')
]
# per-FILE geometry (intrinsic to each level's layout, keyed by scene file #):
#   lw = width in tiles, flag/castle = flagpole & castle columns, dark = black bg,
#   under = play the underground music (else the overworld song)
const LEVEL_GEOMETRY := {
	1: {"lw": 214, "flag": 198, "castle": 202, "dark": false, "under": false},
	2: {"lw": 200, "flag": 192, "castle": 195, "dark": false, "under": false},
	3: {"lw": 388, "flag": 379, "castle": 382, "dark": false, "under": false},
	4: {"lw": 318, "flag": 242, "castle": 245, "dark": true,  "under": true, "noflag": true, "camlock": 268},   # 1-2: no flag; camera stops at tile 268 to frame the ending chamber (one tile further left)
	5: {"lw": 250, "flag": 242, "castle": 245, "dark": true,  "under": true},   # 3-2: underground, 1-2-style surface intro
	6: {"lw": 200, "flag": 192, "castle": 195, "dark": false, "under": false},
	7: {"lw": 200, "flag": 192, "castle": 195, "dark": false, "under": false},
	8: {"lw": 200, "flag": 192, "castle": 195, "dark": true,  "under": false, "cas": true},  # 1-4 castle/lava — cas.mp3
	9: {"lw": 33,  "flag": 24,  "castle": 26,  "dark": false, "under": false},  # EXTRA 1 (short overground): flag past the block hill (hill ends x15)
	10: {"lw": 16, "flag": 14,  "castle": 15,  "dark": false, "under": false, "noflag": true},  # SONIC demo (fixed one-screen camera)
	11: {"lw": 30, "flag": 26,  "castle": 28,  "dark": true,  "under": true,  "noflag": true},  # 1-2 shortcut-trap room (underground look, no flag)
	12: {"lw": 400, "flag": 392, "castle": 395, "dark": true,  "under": true},  # 2-2 (400 wide): flagpole finish at col 392 → advances to 2-3
	13: {"lw": 300, "flag": 292, "castle": 295, "dark": false, "under": false, "noflag": true},  # blank regular stage (300 wide)
	14: {"lw": 30,  "flag": 26,  "castle": 28,  "dark": false, "under": false, "noflag": true},  # blank OVERGROUND stage (30 wide)
	15: {"lw": 302, "flag": 259, "castle": 262, "dark": true,  "under": false, "noflag": true, "cas": true},  # DONKEY KONG stage: 1-4 castle theme; climb to DK + axe (drops him in lava) → Amazon reveal down the corridor past the axe (lw covers the corridor)
	16: {"lw": 168, "flag": 160, "castle": 163, "dark": false, "under": false},  # 3-3: eerily-easy overworld, flagpole finish → advances to 3-4
	17: {"lw": 220, "flag": 212, "castle": 215, "dark": false, "under": false},  # 3-4: the final level (blank overworld starter, edit in Godot)
}
# After completing certain FILES, jump to a specific PLAY-SLOT instead of the next one in order.
#   file 9 = EXTRA 1, the BIG-pipe warp tail of 1-2 that ends at a flagpole = 1-2's real finish
#   → so beating it advances to 1-3 (play-slot 3), not the SONIC demo.
#   file 2 = 2-1 (play-slot 7) → advances to 2-2 (play-slot 6), not the next slot (2-4).
#   file 12 = 2-2 (play-slot 6): its PROPER exit → 2-3 (play-slot 13).
#   file 14 = 2-2 TAIL (play-slot 14): the overground continuation reached by 2-2's pipe. Its
#            flag (walk RIGHT) is the PROPER exit → 2-3; the Sonic cutscene (walk LEFT) is the
#            false path that restarts 2-2 via _l14_goto_next.
#   file 13 = 2-3 (play-slot 13) → 2-4 = the DK stage (play-slot 15).
#   file 15 = 2-4, the DK stage → 3-1 (play-slot 8).
#   file 5 = 3-2 -> 3-3 (play-slot 16, the eerily-easy overworld).
#   file 16 = 3-3 -> 3-4 (play-slot 17, the final level).
const ADVANCE_TO_SLOT := { 9: 3, 2: 6, 12: 13, 14: 13, 13: 15, 15: 8, 3: 5, 5: 16, 16: 17 }   # 3-1->3-2->3-3->3-4
var _advance_next := 0          # play-slot the current advance is heading to
var _level_file := 1            # which LevelN.tscn is currently loaded
var level                       # Level1.tscn instance (TileMapLayer + markers)
var terrain                     # the TileMapLayer holding the terrain + collision
var _player_start := Vector2(3 * TILE + TILE / 2.0, FLOOR * TILE)
var _enemy_defs: Array = []     # [{pos:Vector2, type:String}]
var _coin_defs: Array = []      # [Vector2]

# ---- runtime state -------------------------------------------------------
var player                      # untyped — see note on node holders below
var enemies: Array = []
var items: Array = []           # mushrooms + fire flowers
var fireballs: Array = []       # active Fireball projectiles (Mario's)
var enemy_fireballs: Array = [] # purple-goomba fireballs (hurt the player)
var hammers: Array = []         # Hammer Bro projectiles (hurt the player)
var coins_list: Array = []      # {pos:Vector2, got:bool, anim:float}
var lava_rects: Array = []      # Rect2 deadly zones (2-4 lava tiles) — touch = death
var firebars: Array = []        # rotating castle firebars (indestructible; touch = hurt)
var podoboos: Array = []        # lava bubbles (erupt straight up; indestructible; touch = hurt)
var bowsers: Array = []         # castle boss(es): touch hurts, 5 fireballs topple
var bowser_flames: Array = []   # Bowser's fire breath (indestructible; touch = hurt)
var dks: Array = []             # Donkey Kong boss(es) (Level 15): touch hurts, 5 fireballs topple
var barrels: Array = []         # barrels DK hurls (roll toward Mario; touch = hurt, jump over)
var barrel_spawners: Array = [] # placed barrel emitters {pos, t} (EnemyTiles atlas 19) — the origins you paint
var _barrel_spawner_defs: Array = []   # positions read from the level (rebuilt each reset)
var gords: Array = []           # Gord: stationary spiky hazards (EnemyTiles atlas 23) — instant death, block barrels
# a barrel spawner fires once Mario is APPROACHING it and it's a decent lead ahead — so the
# barrel has room to roll down at him. Fires while the spawner is between these many px ahead.
const BARREL_LEAD_MIN := 56.0        # don't drop it right on top of / behind Mario (~3.5 blocks)
const BARREL_LEAD_MAX := 264.0       # fire when it's within ~16.5 blocks ahead (a sensible lead)
var particles: Array = []       # {type, pos, vel, life, base}
var hidden_blocks: Array = []   # invisible bump-blocks: {col, row, triggered}
var bump_lock: Dictionary = {}  # Vector2i coord -> ticks_msec until it may bump again
var block_bumps: Array = []     # in-flight block hops: {coord, atlas_x, t}

# ? / mushroom block cells that pulse A1->A2->A3; drawn by fg_renderer
var qblock_cells: Array = []    # Array[Vector2i] of animated block coords
var pipeover_cells: Array = []  # Array[Vector2i] of ATLAS_PIPEUP anchors → draw the giant pipe sprite
var sign_cells: Array = []      # Array[Vector2i] of sign-marker anchors → draw the blinking bg sign (no collision)
var pipeover_solid_offsets: Array = []   # tile offsets (from anchor) the pipe sprite fills → solid
var _pipeover_body: StaticBody2D = null  # runtime collision for all placed pipes
var qanim_phase := 0.0          # advances with time; frame = int(phase/0.2)%3
const QANIM_FRAMES := [2, 13, 14]   # atlas x of the three ? frames in tiles.png
const QANIM_STEP := 0.2         # seconds per frame

var cam_x := 0.0
var score := 0
var coins := 0
var elapsed := 0.0              # real seconds since the level started (counts up)
var timing := true             # false once the flagpole is touched (freezes elapsed)
var game_state := "play"        # play | clear
var saved_tier := "small"       # power tier Mario STARTS the next level as (carries over; death -> small)
var level_num := 1              # 1 = world 1-1, 2 = world 1-2
const LEVEL_COUNT := 17         # number of levels in LEVEL_ORDER (debug stage select; 10=key 0, 11=key -, 12=key =, 13=key Backspace, 14=key \, 15=key ], 16=key [, 17=key ')
static var debug_start_level := 1   # DEBUG: level the intro's stage-select boots into

# --- SAVE FILES: 3 slots, each a name, the highest world reached, and a best time per level ---
static var save_slot := 0                 # which of the 3 files is active this run
static var save_names: Array = ["", "", ""]
static var save_highest: Array = [0, 0, 0]   # highest level_num reached per slot (0 = brand new)
static var save_best: Array = [[], [], []]   # per slot: LEVEL_COUNT best clear times (0 = none yet)
static var save_beat: Array = [false, false, false]  # per slot: has this file beaten 3-4? (unlocks LEVEL SELECT)
static var boot_to_files := false            # set when quitting to menu → intro opens at the file list
const SAVES_PATH := "user://saves.cfg"

static func load_saves() -> void:
	var cfg := ConfigFile.new()
	var ok := cfg.load(SAVES_PATH) == OK
	for i in 3:
		save_names[i] = String(cfg.get_value("slot%d" % i, "name", "")) if ok else ""
		save_highest[i] = int(cfg.get_value("slot%d" % i, "highest", 0)) if ok else 0
		save_beat[i] = bool(cfg.get_value("slot%d" % i, "beat", false)) if ok else false
		var a: Array = []
		for l in LEVEL_COUNT:
			a.append(float(cfg.get_value("slot%d" % i, "best%d" % l, 0.0)) if ok else 0.0)
		save_best[i] = a

static func save_saves() -> void:
	var cfg := ConfigFile.new()
	for i in 3:
		cfg.set_value("slot%d" % i, "name", save_names[i])
		cfg.set_value("slot%d" % i, "highest", save_highest[i])
		cfg.set_value("slot%d" % i, "beat", save_beat[i])
		var a: Array = save_best[i]
		for l in LEVEL_COUNT:
			cfg.set_value("slot%d" % i, "best%d" % l, (a[l] if l < a.size() else 0.0))
	cfg.save(SAVES_PATH)

# call as levels load — bumps the active slot's furthest-reached world and persists it
static func record_progress(lvl: int) -> void:
	if save_slot >= 0 and save_slot < 3 and lvl > int(save_highest[save_slot]):
		save_highest[save_slot] = lvl
		save_saves()

# call on a level clear — store the finish time if it beats the slot's record for that
# level. Returns true when a NEW best was set (first-ever time, or a quicker one).
static func record_best_time(lvl: int, secs: float) -> bool:
	if save_slot < 0 or save_slot >= 3:
		return false
	var a: Array = save_best[save_slot]
	if a.size() < LEVEL_COUNT:
		return false
	var idx := lvl - 1
	if idx < 0 or idx >= LEVEL_COUNT:
		return false
	var cur := float(a[idx])
	if cur <= 0.0 or secs < cur:
		a[idx] = secs
		save_saves()
		return true
	return false
var world_label := "1-1"        # shown in the HUD
var underground := false         # true = black bg, no starfield (1-4 is underground)
const SKY_COLOR := Color(0.16, 0.16, 0.19)   # night-sky clear colour for surface levels
var advancing := false          # 1-1 beaten → running the between-level sequence
var advance_timer := 0.0
var advance_phase := 0          # 0 wait fanfare, 1 hold 10 frames, 2 black card

# axe / bridge-collapse ending (SMB1): touch the axe (atlas 33) -> bridge planks
# (atlas 31) vanish one-by-one right→left, Bowser falls, then COURSE CLEAR.
var axe_ending := false
var axe_phase := 0              # 0 collapsing bridge, 1 waiting for Bowser to fall
var axe_t := 0.0
var _axe_cells: Array = []      # painted axe tiles (Vector2i)
var _bridge_cells: Array = []   # painted bridge planks, sorted RIGHT→LEFT
var _axe_wall_x := 0.0          # invisible right wall at the axe (Mario can't pass it)
var _cam_locked := false        # true once a boss area (bridge+axe) is present
var _cam_lock_x := 0.0          # camera stops here so Bowser+bridge+axe stay framed
var _boss_axe_x := -1           # tile x of the axe (Mario stands here for the rescue walk)
var _boss_axe_y := 0            # tile y of the axe (its wall-top is the row below)
const BRIDGE_ERASE_STEP := 0.11 # seconds between each plank vanishing
# Castle approach hazard (Bowser's-castle levels): before you reach the arena, a flame
# fires horizontally at you every few seconds from off the right edge, at a fixed height
# a couple tiles above the bridge — like SMB1's fire coming down the corridor.
var _bridge_row := -1           # the plank row (set in reset); -1 = no bridge in this level
var _bridge_left_col := -1      # leftmost plank column (for the fire start trigger)
var _castle_fire_t := 0.0       # countdown to the next approach flame
const CASTLE_FIRE_PERIOD := 5.0 # seconds between approach flames
const CASTLE_FIRE_TILES_OVER := 2      # how many tiles above the bridge they fly
const CASTLE_FIRE_START_TILES_LEFT := 75  # they only begin once Mario is this many tiles left of the bridge

# rescue reveal (Bowser's castle only, one-time): once the bridge is gone and Bowser
# has fallen, "mac" appears on the ledge past the axe, arms raised, and the camera
# pans over to frame him. Replaces SMB1's Toad. Not used on any other level.
var show_rescue := false
var rescue_phase := 0           # 0 = Mario walking, 1 = mac speaking, 2 = COURSE CLEAR
var rescue_t := 0.0             # frame-alternation timer (A1 <-> A2)
var rescue_speech_t := 0.0      # how long mac's line has been up
var show_rescue_speech := false # HUD draws mac's line while true
var rescue_pos := Vector2.ZERO  # mac's feet position (world)
var rescue_walking := false     # true while Mario auto-walks toward mac (player reads it)
var rescue_stop_x := 0.0        # Mario's centre stops here (5 tiles short of mac)
var _rescue_is_am := false      # true = the DK stage (2-4) "am" reveal instead of mac
var _am_a2 := false             # am switches from A1 to the A2 pose after the beat
const AM_STOP_GAP := 4          # tiles Mario stops short of Amazon (detected past the drop)
const AM_WAIT := 1.0            # seconds Amazon holds A1 once Mario arrives, then -> A2
const AM_RAISE_HOLD := 3.0      # seconds Amazon holds the raised A2 pose BEFORE COURSE CLEAR
const RESCUE_MAC_OFFSET := 25   # tiles right of the axe that mac stands
const RESCUE_STOP_GAP := 5      # tiles Mario stops short of mac
const RESCUE_FRAME_STEP := 0.35 # seconds per arm-raise frame
const RESCUE_CAM_FOLLOW := 130.0 # px/s the camera tracks Mario as he walks (> his 84 walk)
const RESCUE_SPEECH_TIME := 3.6  # seconds mac's line stays up before COURSE CLEAR
const RESCUE_SPEECH_LINES := ["PURPLE MARIO!!", "MY HERO!", "YOU DID IT!"]
const AM_SPEECH_LINES := ["A WINNER", "IS YOU!"]   # Amazon's line on the DK stage (2-4) ending

# 1-2 intro cutscene: when the underground stage (file 4) starts, Mario steps out of a
# castle on the surface, walks right and enters the "end pipe", then we drop into the
# underground level proper. Scripted (main drives the player); one-shot per arrival.
var intro_12 := false            # cutscene playing
var _want_12_intro := false      # armed when we ARRIVE at 1-2 / 1-7 (not on death-respawn)
var _intro_moonwalk := false     # true for 1-7 (Level12): Mario MOONWALKS into the pipe (faces away)
var _intro_32 := false           # true for 3-2 (Level5): its own cloned copy of the 1-2 surface intro
var _intro_sonic := false        # 3-2 intro: draw Sonic (he jumps in onto the pipe after Mario enters)
var _intro_sonic_landed := false # 3-2 intro: Sonic has landed on the pipe and is foot-tapping
var _intro_oneup: AudioStreamPlayer = null  # 3-2 intro: the 1-up jingle (played AFTER the SEGA sound finishes)
var _intro_oneup_started := false           # 3-2 intro: 1-up jingle has been kicked off
var _intro_tap_t := 0.0                      # 3-2 intro: seconds Sonic has spent foot-tapping (starts after the 1-up ends)
const INTRO_SONIC_TAP_TIME := 3.0  # seconds Sonic foot-taps on the pipe before the level drops in

# --- 3-4 (Level17) BOSS-ARENA INTRO CUTSCENE ---
# Mario auto-walks in from the left edge; the screen locks; then a wall of purple blocks
# crashes down (plus a gordo). The WALL POSITION IS DATA-DRIVEN: the user paints ? blocks
# (atlas 2) where the wall should land and a pipe tile (atlas 8-11) where a gordo drops —
# at cutscene start those markers are removed (opening the way), and on the trigger purple
# blocks + the gordo fall onto exactly those cells. Re-edit the level and it just adapts.
const ATLAS_ARENA_WALL := 16                       # the purple block the 3-4 arena is built from
var _arena_phase := 0                              # 0 walk-in, 1 drop the wall, 2 wait for it to land, 3 done
var _arena_sealed := false                         # wall has been triggered (one-shot); cleared in reset()
const ARENA_WALK_SPD := 92.0                       # cutscene walk-in speed (px/s)
var _arena_wall_cells: Array = []                  # cells the wall fills (detected from the ? markers)
var _arena_gordo_cells: Array = []                 # cells a gordo drops onto (detected from the pipe markers)
var _arena_trap_x := 0.0                           # Mario past this (right of the wall) drops it — computed at arm
var _arena_stop_x := 0.0                           # where Mario halts, just right of the wall — computed at arm
var _arena_cam_lock_x := 0.0                       # screen locks here, framing the wall — computed at arm
const SEAL_DROP := 12.0 * TILE                     # blocks start this far above their slot — a big, tall fall
const SEAL_G := 1150.0                             # falling-block gravity
var _seal_blocks: Array = []                       # things in flight: [{kind, node, vy, target_y, cell}]
var _cam_shake := 0.0                              # decaying screen-shake magnitude (px)
# Sonic boss entrance: after the wall lands he crashes in through the right wall (one row
# above the right gordo), the smashed blocks fall back, and he stops face-to-face with Mario.
var _arena_sonic := false                          # Sonic is on-stage (draw + drive him)
var _arena_broken: Array = []                      # cells Sonic smashed through (they fall back)
var _arena_fellback := false                       # the smashed blocks have been sent falling back
var _arena_crash_row := 11                         # the row Sonic tunnels through (one above the right gordo)
var _arena_sonic_stop_x := 0.0                     # where Sonic halts, just right of Mario
var _arena_crash_start_x := 0.0                    # off-screen right, PAST the right wall (so he breaks through it)
var _arena_crash_break_from := 999                 # only smash cells at/right of this col (the right wall)
const SONIC_CRASH_SPD := 250.0                     # Sonic's dash-in speed (px/s)
const ARENA_FACEOFF_GAP := 5 * TILE                # tiles between Mario and Sonic at the standoff (fits on-screen with Mario centred)
const SONIC_DROP_SPD := 260.0                      # Sonic settling from the crash height to the floor
var _arena_t := 0.0                                # timer for the standoff hold before the fight
# THE BOSS FIGHT: Sonic spin-dashes at Mario; Mario jumps over; Sonic smashes a gordo (self-hit,
# gordo removed); 4 gordos gone -> Sonic death. Runs inside game_state "play" with `_boss_active`.
var _boss_active := false
var _boss_dead := false
var _boss_phase := "pursue"                        # pursue -> rev -> dash -> recoil (loop) ; then death
var _boss_t := 0.0
var _boss_dash_dir := -1
var _boss_descend_dir := 0                          # locked step-off direction while dropping off a ledge (0 = not descending)
var _boss_descend_from_row := 0                     # the row Sonic stepped off from (keep pushing until he lands lower)
var _boss_dash_from := 0.0                          # sonic_x where the current spin-dash began (capped at BOSS_DASH_MAX)
var _boss_hits := 0                                # gordos smashed (4 = defeat)
var _boss_lo := 0.0                                # left/right dash limits
var _boss_hi := 0.0
var _boss_cam_lo := 0.0                            # camera bounds: 1 tile out from the gordos each side
var _boss_cam_hi := 0.0
var _boss_vx := 0.0                                # Sonic's velocity (he walks/runs/jumps with real physics)
var _boss_vy := 0.0
var _boss_feet_y := 0.0                            # Sonic's feet world-y (he stands on floor/platforms)
var _boss_grounded := true
const BOSS_WALK_SPD := 58.0
const BOSS_RUN_SPD := 104.0                        # runs when Mario is far
const BOSS_GRAV := 720.0
const BOSS_JUMP_V := -335.0                        # ~4.7-tile hop (Mario-sized) so he climbs step platforms, not overshoots
const BOSS_REV_TIME := 0.85                        # rev-up telegraph before a spin-dash (longer = fairer tell)
const BOSS_DASH_SPD := 285.0                       # spin-dash speed
const BOSS_DASH_RANGE := 12 * TILE                 # walks to Mario until ~12 tiles away, THEN spin-dashes (matches the roll cap so a dash can still reach him)
const BOSS_DASH_MAX := 12 * TILE                   # a spin-dash travels at most 12 tiles before he stops (harder to bait into a distant gordo)
const BOSS_RECOIL_TIME := 0.7
const BOSS_RECOIL_SPD := 130.0                     # px/s he reels backward after smashing a gordo (~5-6 tiles over the recoil)
const BOSS_DEATH_TIME := 2.2
# --- Sonic's stepping-stone climb brain (auto-derived from the arena geometry) ---
var _boss_platforms: Array = []                    # standable segments {row,c0,c1} above the floor, for laddering up
var _boss_step = null                              # the rung Sonic is currently hopping to (locked until he lands)
const BOSS_CLIMB_RISE := 4                          # max tiles a single hop can gain (jump clears ~4.7t)
const BOSS_LAUNCH_WINDOW := 1.6 * TILE             # hop onto a rung once its near edge is this close horizontally
var intro_phase := 0             # 0 walk to pipe, 1 enter (fade), 2 fade to black
var intro_t := 0.0
const INTRO_CASTLE_X := -12.0    # castle sprite left (its door ~x28)
const INTRO_PIPE_X := 186.0      # end-pipe sprite left; its mouth faces left
const INTRO_START_X := 28.0      # Mario steps out of the castle door here
const INTRO_WALK_TO := 178.0     # walks until his centre reaches the pipe mouth
const INTRO_ENTER_TO := 206.0    # then slips into the pipe (fading) to here
const INTRO_WALK_SPD := 58.0     # px/s stroll

# 1-2 EXIT: walking into the side of the giant pipe (ATLAS_PIPEUP) at the end of 1-2 makes
# Mario enter it (behind the pipe + the shrink sound, like the intro) and warp to EXTRA 1.
var pipe_exit := false
var pipe_exit_phase := 0         # 0 slip in, 1 fade + warp
var pipe_exit_t := 0.0
var pipe_exit_target_x := 0.0
const PIPE_EXIT_WARP_TO := 9     # play-slot the 1-2 pipe leads to (EXTRA 1)
# level FILE → play-slot its enterable L-pipe (ATLAS_PIPEUP) warps to.
#   file 4  = 1-2      → EXTRA 1 (slot 9)
#   file 12 = 2-2      → the 2nd Sonic cutscene stage, Level14 (slot 14)
const PIPE_EXIT_MAP := {4: 9, 12: 14}
const PIPE_EXIT_WALK := 40.0     # px/s Mario slips into the pipe

# EMERGE: arriving in EXTRA 1 (file 9), Mario rises up OUT of the start pipe (SMB1 warp
# arrival) before gameplay begins — occluded by the pipe until he clears the rim.
var _want_emerge := false
var emerge_target_y := 0.0       # feet stop here (the pipe rim)
const EMERGE_SPEED := 26.0       # px/s slow rise

# END CREDITS (after the 3-4 Sonic boss): COURSE CLEAR holds a beat, fades to black, then a
# separate overworld cutscene rolls — Mario runs along two rows of ground while the credits
# scroll up. A mock-up finale, self-contained (drawn by the HUD, no level scene needed).
var _boss_finale := false        # the 3-4 boss was beaten → run the finale after COURSE CLEAR
var _finale_t := 0.0             # timer for the hold → fade-out before credits
var credits_t := 0.0             # seconds the credits roll has been running
var _credits_ground_x := 0.0     # 0..TILE scroll offset for the ground (the running illusion)
var credits_mario_frame := 0.0   # Mario's leg-cycle accumulator
const FINALE_HOLD := 3.0         # seconds COURSE CLEAR stays up before the fade
const FINALE_FADE := 1.2         # seconds to fade to black, then credits begin
const CREDITS_SCROLL_SPD := 20.0 # px/s the credit lines crawl upward
const CREDITS_LINE_H := 22.0     # vertical spacing between lines
const CREDITS_START_Y := 168.0   # y the first line enters at (just above Mario's lane)
const CREDITS_REST_Y := 84.0     # y the final line ("THE END") settles at
var credits_done := false        # the roll has finished — Mario stops; any button restarts
var _recorded_clear := false     # save-file: guard so a level's best time is recorded once
var _new_record := false         # true if this clear set a new best time (shows "NEW RECORD")
# Each entry: [text, scale, [r,g,b]]. Blank strings are spacer rows. Font is A-Z/0-9/.!:- only.
const CREDITS_LINES := [
	["GOOSE PRANDINI MEDIA", 2.0, [1.0, 0.82, 0.30]],
	["", 1.0, [1,1,1]], ["", 1.0, [1,1,1]],
	["CREATED BY", 1.0, [0.8, 0.85, 1.0]],
	["KENNETH ALIPRANDINI", 2.0, [1.0, 1.0, 1.0]],
	["", 1.0, [1,1,1]], ["", 1.0, [1,1,1]],
	["THANKS FOR PLAYING.", 1.0, [0.8, 0.85, 1.0]],
	["", 1.0, [1,1,1]], ["", 1.0, [1,1,1]],
	["THE END", 2.0, [1.0, 0.82, 0.30]],
]

func _credits_scroll_max() -> float:
	return CREDITS_START_Y + float(CREDITS_LINES.size() - 1) * CREDITS_LINE_H - CREDITS_REST_Y

# REWARD TRAP (Level11): Mario drops OUT of the upside-down ceiling pipe (flipped-lip tiles)
# then falls straight down into the lava below and dies — Sonic's "reward" is a death trap.
var _want_reward_trap := false
var trap_phase := 0              # 0 slide out of pipe, 1 fall, 2 Sonic runs in, 3 taunt, 4 fade→restart 1-2
var _trap_v := 0.0
var _trap_open_y := 0.0          # y of the pipe opening (bottom of the flipped lip)
var trap_t := 0.0                # phase timer (run-in / taunt / fade)
var _trap_sonic_stop_x := 0.0    # world x Sonic halts at (just right of the lava)
const TRAP_EMERGE_SPEED := 34.0  # px/s slow slide out of the pipe mouth
const TRAP_FALL_G := 640.0       # gravity once he's clear and plummeting
const TRAP_TAUNT_TIME := 4.2     # how long Sonic's taunt holds before 1-2 restarts
const SONIC_TAUNT_SPEECH := ["HA HA HA!", "YOU LOSER!!", "THERE ARE NO", "SHORTCUTS"]
const SONIC_BOSS_SPEECH := ["WE MEET AGAIN", "FOR THE LAST TIME!!", "YOU WILL PERISH!"]  # 3-4 standoff
const L14_TAUNT := ["HA HA HA!", "WHAT A JERK!"]   # Level 14: Sonic's taunt after the trap kills Mario
const L14_PRIZE := ["HERE'S YOUR", "PRIZE, PAL!"]  # Level 14: Sonic's line just before he jumps at the block
const L14_PRIZE_HOLD := 2.0                        # seconds the prize line shows before he jumps
var sonic_speech_lines: Array = []   # which lines the HUD shows near Sonic (congrats vs taunt)
var _carry_elapsed := -1.0       # >=0 = keep the running clock across the next reset (1-2 -> EXTRA 1)

# SONIC demo (Level10): Mario hidden, Sonic auto-plays wait/walk/run/jump both facings so
# the art can be previewed. Purely visual; no gameplay.
var sonic_demo := false
var sonic_x := 0.0
var sonic_state := "wait"        # wait / walk / run / jump
var sonic_face := "r"            # l / r
var sonic_phase := 0             # 0..7 demo script step
var sonic_state_t := 0.0
var sonic_frame_t := 0.0
var sonic_frame := 0
var sonic_jump_off := 0.0
const SONIC_LEFT := 56.0
const SONIC_MID := 150.0
const SONIC_RIGHT := 208.0
const SONIC_WALK_SPD := 42.0
const SONIC_RUN_SPD := 100.0
# idle (Sonic Chaos style): stand still for a beat, THEN tap the foot impatiently on a loop
# idle sequence (user's labels): A1(0) stand held → A2(1) → A3(2) raises eyebrow → A4(3)/A5(4)
# alternate to tap the foot. (6th wait frame is unlabelled/unused.)
const IDLE_STAND_TIME := 2.8     # A1 held (impatience delay, ~classic 3s)
const IDLE_LEAD := 0.28          # A2 then A3 each held this long before the tap
const IDLE_TAP_FPS := 3.0        # A4<->A5 alternation (foot tap) — 50% slower
const SONIC_WAIT_TIME := 7.0     # total wait phase
# spin dash: crouch (duck), rev up in place (spin-start frames loop), then dash off (ball)
const SPIN_DUCK_TIME := 0.45     # crouch before revving
const SPIN_CHARGE_TIME := 1.3    # revving in place
const SPIN_DASH_SPD := 285.0     # px/s once released (50% faster)
const SPIN_REV_FPS := 14.0       # spin-start rev animation speed
const SPIN_BALL_FPS := 18.0      # spinning-ball animation speed

# 1-2 SONIC CUTSCENE (file 4): Mario jumps on top of the small chamber pipe → Sonic charges
# in from off-screen right as a spin-ball, tunnels a 2-tile-high hole through the bottom of the
# right-wall bricks, bursts into the chamber, jumps, then settles into the foot-tap idle. Reuses
# the sonic_* animation vars/frames. Control returns to Mario after the idle; Sonic stays put.
var sonic_cut := false           # cutscene is running (drawn; game_state=="sonic_cut" freezes play)
var sonic_cut_phase := 0         # 0-3 Mario (walk/fall/walk/jump), 4-7 Sonic (crash/settle/jump/standoff)
var _l14_cut := false            # Level 14 cutscene: Sonic spin-dashes through the wall (routes _update_l14_cut)
var _l14_break_col := 0          # next wall column Sonic's dash breaks
var _l14_stop_x := 0.0           # world x Sonic halts at (just left of Mario)
var _l14_cam_target := 0.0       # where the camera slowly pans to (frames Sonic + the wall)
var _l14_cam_locked := false     # once the pan arrives, the screen locks (no follow during the dash)
var _l14_sega_done := false      # SEGA sound has finished — Sonic waits for this before dashing
const L14_CAM_PAN_SPD := 90.0    # px/s slow pan-over toward Sonic
var _l14_brick_col := -1         # cached trigger-brick column (computed once per level load)
var _l14_qblock := Vector2i(-1, -1)  # the ? block Sonic jumps up to hit (found near his landing)
var _l14_bumped := false         # one-shot so he only bumps it once
var _l14_prejump := false        # Sonic holds & says his line just before jumping at the block
var _l14_prejump_t := 0.0        # timer for that pre-jump line
# Level 14 audio sequence: SEGA sound at cutscene start, 1-up when Sonic finishes dashing, then
# the sonic.mp3 gloat song once Mario has died and his death jingle has finished.
#   0 = idle   1 = Mario died, waiting for the death jingle to end   2 = gloat song looping
var _l14_audio := 0
var _l14_jump_h := 72.0          # jump height (auto-set to reach the block)
var _l14_kill_t := 0.0           # timer while the trap mushroom closes in on Mario
var _l14_death_v := 0.0          # Mario's death-jump vertical speed
var _sonic_spin_snd := false     # one-shot guard so the spin-rev sound plays once per spin-dash
var _l14_walk_in := false        # Mario walks the last stretch onto the brick (no snap)
var _l14_walk_target := 0.0      # brick-center x he walks to
var _sonic_cut_done := false     # one-shot guard so it only fires once per life
var _sonic_pipe_cell := Vector2i(-1, -1)   # top-left cell of the chamber pipe (atlas 17), file 4
var _sonic_trigger_x := 0.0      # Mario crossing this x (while up on the roof) starts the cutscene
var _mario_cut_v := 0.0          # Mario's scripted fall speed (phase 1)
var sonic_cut_stop_x := 0.0      # world x Sonic halts at, in the open chamber
var _sonic_break_col := 9999     # left-most column already tunnelled through
var sonic_speech := false        # "congratulations! take the pipe" line shows near Sonic
const SONIC_CUT_SETTLE := 0.45   # brief stand as he uncurls out of the wall
const SONIC_CUT_JUMP_T := 0.8    # Sonic's jump-arc duration
const SONIC_CUT_SEGA_T := 1.1    # how long Mario faces LEFT (sega sound) before turning to face Sonic
const SONIC_SPEECH_TIME := 3.6   # how long the speech holds before Mario takes the pipe
const SONIC_CUT_SPEECH := ["CONGRATULATIONS!", "NOW TAKE THE PIPE", "AND BE REWARDED!"]
const SONIC_CUT_FOOTTAP_T := 8.0 # foot-tap duration before the pipe warps to the reward level
const SONIC_CUT_REWARD_SLOT := 11  # play-slot the pipe warps to (Level11 = the reward)
const MARIO_CUT_WALK := 90.0     # px/s Mario's scripted stroll along the roof / to the pipe
const MARIO_CUT_FALL_G := 700.0  # gravity for Mario's scripted drop through the gap
const MARIO_CUT_JUMP_T := 0.55   # Mario's jump-onto-pipe duration
const MARIO_CUT_JUMP_ARC := 42.0 # extra arc height so he clears the pipe rim
const MARIO_PIPE_SINK := 44.0    # px/s Mario sinks down into the pipe

var advance_frames := 0
var advance_ct := 0.0
var show_level_card := false    # full-black "1-2" card between levels
var level_card_text := ""
const FANFARE_WAIT := 4.0       # muted fallback: seconds to treat the fanfare as done
const CARD_TIME := 2.0          # how long the black next-level card is held
var paused := false             # ESC / P toggles the pause menu (a full freeze)
var pause_sel := 0              # pause-menu row: 0 = MUSIC, 1 = SOUND
const VOL_STEP := 0.1          # how much Left/Right nudges a volume slider
var flag_y := 0.0
var has_flag := true            # false on levels with no flagpole/castle finish (custom ending)
var flag_sliding := false       # true once the pole is grabbed → flag lowers smoothly
const FLAG_SLIDE_SPEED := 114.5  # px/s the flag lowers (smooth, ~pixel-by-pixel)
var start_delay := 0.0          # brief "get ready" freeze at each stage start (fades in)
var fade_alpha := 0.0           # 0 = clear, 1 = black; fades the stage in from black
const START_DELAY := 0.5        # seconds Mario + clock are frozen while the stage fades in

# ---- nodes ---------------------------------------------------------------
# These back-referenced node holders are intentionally untyped: the child
# classes hold a typed `main: Main`, so typing them here would create a cyclic
# class dependency that GDScript can't resolve at parse time.
var camera: Camera2D
var bg_renderer                 # clouds + hills (behind the terrain)
var fg_renderer                 # flag, castle, coins, particles (in front)
var hud

# ---- textures (shared) ---------------------------------------------------
var tex := {}

# ---- audio ---------------------------------------------------------------
var music_player: AudioStreamPlayer
var overworld_music: AudioStream    # default overground song
var intro_music: AudioStream        # beat.wav — plays during the surface intro cutscene (1-2 / 1-7)
var underground_music: AudioStream  # under.mp3 — levels with "under": true (1-2 etc.)
var castle_music: AudioStream       # cas.mp3 — levels with "cas": true (1-4 Bowser castle)
var boss_music: AudioStream         # boss.mp3 — the 3-4 Sonic boss stage
var fanfare_player: AudioStreamPlayer
var victory_player: AudioStreamPlayer    # victory.mp3 — plays when Sonic is defeated (3-4)
var end_player: AudioStreamPlayer        # "end m.mp3" — the song over the end credits
var mac_player: AudioStreamPlayer        # the "mac" ending song (1-4 rescue), replaces the fanfare
var am_player: AudioStreamPlayer         # amam.wav — plays when Amazon raises his arms (2-4 ending)
var sonic_song_player: AudioStreamPlayer  # sonic.mp3 — the gloat song when the Level11 trap kills Mario
var sega_player: AudioStreamPlayer        # sega-hd.mp3 — Mario's pipe pose; Sonic waits for it to finish
var death_player: AudioStreamPlayer
var muted := false
var music_off := false

# Two dedicated buses so the pause menu can set music and sound-effect volume
# independently. Each per-shot SFX player, plus the fanfare/death jingles, route
# to SFX_BUS; the looping level music routes to MUSIC_BUS. Both send to Master,
# so the M-key mute (which mutes Master) still silences everything.
var music_bus := -1
var sfx_bus := -1
var music_volume := 1.0    # 0..1 user multiplier, on top of MUSIC_VOL (pause menu)
var sfx_volume := 1.0      # 0..1 user multiplier, on top of SFX_VOL  (pause menu)
const SETTINGS_PATH := "user://settings.cfg"

# full-screen display filter picked in the pause menu (see filter.gdshader)
var filter_mode := 0       # 0 = REGULAR, 1 = CRT, 2 = INVERTED
const FILTER_NAMES := ["REGULAR", "CRT", "INVERTED"]
var filter_layer: CanvasLayer
var filter_rect: ColorRect

const MUSIC_VOL := 0.75    # song level
const SFX_VOL := 0.6
const MUSIC_PITCH := 0.75  # 25% slower than natural speed


func _ready() -> void:
	_load_textures()

	# background scenery (behind the terrain)
	bg_renderer = TileRenderer.new()
	bg_renderer.main = self
	bg_renderer.mode = "bg"
	bg_renderer.z_index = -10
	add_child(bg_renderer)

	# the level scene: TileMapLayer terrain + spawn markers
	_instance_level()

	# foreground deco: flag, castle, coins, particles (in front of terrain)
	fg_renderer = TileRenderer.new()
	fg_renderer.main = self
	fg_renderer.mode = "fg"
	fg_renderer.z_index = 1
	add_child(fg_renderer)

	# camera
	camera = Camera2D.new()
	camera.enabled = true
	camera.zoom = Vector2.ONE
	add_child(camera)
	camera.make_current()

	# HUD
	hud = Hud.new()
	hud.main = self
	add_child(hud)

	_setup_audio()
	_setup_filter()

	# player
	player = Player.new()
	player.main = self
	add_child(player)

	level_num = clampi(debug_start_level, 1, LEVEL_COUNT)   # DEBUG: boot into the picked stage
	_want_12_intro = _file_at(level_num) in [4, 5, 12]              # play the surface intro if booting into 1-2
	_want_emerge = _file_at(level_num) in [9, 14]               # rise out of the pipe if booting into EXTRA 1
	_want_reward_trap = _file_at(level_num) == 11         # drop out of the ceiling pipe if booting into Level11
	reset(false)
	_play_music(true)   # belt-and-suspenders; autoplay also starts it



## SMB1 "TimerControl" world freeze: while Mario is growing / shrinking (a power-up or
## a hit) or playing his death animation, the enemies, the clock and scrolling all hold
## still — only Mario's own change-size / death animation keeps running. Every self-driven
## actor node checks this in its _physics_process, and the clock + gameplay updates below
## are skipped while it's true.
func actors_frozen() -> bool:
	return player != null and (player.transforming or player.dead)

func _physics_process(delta: float) -> void:
	if paused:
		return
	qanim_phase += delta          # ? / mushroom blocks always pulse (SMB1 FrameCounter), even mid-freeze
	if _level_file == 14:
		_update_l14_audio()
	if game_state == "clear":
		if not _recorded_clear:
			_new_record = record_best_time(level_num, elapsed)   # save-file: log time; true = new best
			_recorded_clear = true
		# 3-4 finale: after COURSE CLEAR, hold, fade to black, then roll the end credits
		if _boss_finale:
			_update_finale(delta)
			hud.refresh()
			return
		# level beaten — keep the HUD live, but let the flag finish dropping even
		# after Mario has entered the castle (it was freezing mid-slide otherwise)
		_update_flag_slide(delta)
		if advancing:
			_update_advance(delta)
		if show_rescue:
			_update_rescue(delta)
		hud.refresh()
		return
	# 3-4 end credits: the overworld run-and-scroll finale (drawn entirely by the HUD)
	if game_state == "credits":
		_update_credits(delta)
		hud.refresh()
		return
	# Bowser's-castle rescue: Mario walks to mac, mac speaks — all before COURSE CLEAR.
	# The timer stays frozen up top; gameplay is paused (Bowser already fell).
	if game_state == "rescue":
		_update_rescue(delta)
		hud.refresh()
		return
	# 1-2 surface intro: Mario strolls out of the castle into the pipe (main drives him)
	if game_state == "intro":
		_update_intro12(delta)
		hud.refresh()
		return
	# 3-4 boss-arena intro: Mario walks in, screen locks, a big block wall crashes down
	if game_state == "arena_intro":
		_update_arena_intro(delta)
		_update_particles(delta)
		_update_camera()
		bg_renderer.queue_redraw()
		fg_renderer.queue_redraw()
		hud.refresh()
		return
	# 1-2 exit: Mario slips into the giant end pipe, then warps to EXTRA 1
	if game_state == "pipe_exit":
		_update_pipe_exit(delta)
		hud.refresh()
		return
	# EXTRA 1 arrival: Mario rises up out of the start pipe before play begins
	if game_state == "emerge":
		_update_emerge(delta)
		hud.refresh()
		return
	# Level11 reward trap: Mario drops out of the ceiling pipe and falls into the lava
	if game_state == "trap":
		_update_reward_trap(delta)
		hud.refresh()
		return
	# axe/bridge ending in progress: Mario + normal gameplay are frozen; just run the
	# collapse (Bowser animates via his own _physics_process as a child node)
	if axe_ending:
		_update_axe_ending(delta)
		_update_camera()
		bg_renderer.queue_redraw()
		fg_renderer.queue_redraw()
		hud.refresh()
		return
	# Level10 Sonic preview: no gameplay, just cycle Sonic's animations
	if sonic_demo:
		_update_sonic_demo(delta)
		bg_renderer.queue_redraw()
		fg_renderer.queue_redraw()
		hud.refresh()
		return
	# 1-2 Sonic cutscene: Mario frozen on the pipe while Sonic dashes in and performs
	if game_state == "sonic_cut":
		if _l14_cut:
			_update_l14_cut(delta)
		else:
			_update_sonic_cut(delta)
		hud.refresh()
		return
	# stage-start "get ready" freeze + fade-in from black (Mario + clock are frozen)
	if start_delay > 0.0:
		start_delay = maxf(0.0, start_delay - delta)
	fade_alpha = (start_delay / START_DELAY) if start_delay > 0.0 else 0.0
	if actors_frozen():
		# hit / power-up / death: hold the whole world (enemies + clock + scroll) while
		# Mario's animation plays, like SMB1. Only keep the view + HUD live.
		_update_camera()
		bg_renderer.queue_redraw()
		fg_renderer.queue_redraw()
		hud.refresh()
		return
	_update_gameplay_collisions()
	_check_pipe_exit()
	_check_sonic_cut()
	_check_l14_cut()
	_update_hidden_blocks()
	_update_fireballs()
	_update_enemy_fireballs()
	_update_bowsers()
	_update_dk()
	_update_boss(delta)
	_update_barrel_spawners(delta)
	_update_gords()
	_update_castle_fire(delta)
	_update_hammers()
	_update_coins(delta)
	_update_particles(delta)
	_update_block_bumps(delta)
	_update_flag_slide(delta)
	_update_camera()
	_update_timer(delta)
	bg_renderer.queue_redraw()
	fg_renderer.queue_redraw()
	hud.refresh()


# =========================================================================
# LEVEL SCENE (Level1.tscn — TileMapLayer terrain + Spawns markers)
# =========================================================================
func _scene_for_file(f: int) -> PackedScene:
	match f:
		2: return LEVEL2_SCENE
		3: return LEVEL3_SCENE
		4: return LEVEL4_SCENE
		5: return LEVEL5_SCENE
		6: return LEVEL6_SCENE
		7: return LEVEL7_SCENE
		8: return LEVEL8_SCENE
		9: return LEVEL9_SCENE
		10: return LEVEL10_SCENE
		11: return LEVEL11_SCENE
		12: return LEVEL12_SCENE
		13: return LEVEL13_SCENE
		14: return LEVEL14_SCENE
		15: return LEVEL15_SCENE
		16: return LEVEL16_SCENE
		17: return LEVEL17_SCENE
		_: return LEVEL_SCENE

func _instance_level() -> void:
	if level and is_instance_valid(level):
		level.queue_free()
	# look up this play position in the lineup -> which file + which label
	var entry: Array = LEVEL_ORDER[level_num - 1]
	_level_file = int(entry[0])
	world_label = String(entry[1])
	var g: Dictionary = LEVEL_GEOMETRY[_level_file]
	LW = int(g["lw"]); FLAG_X = int(g["flag"]); CASTLE_X = int(g["castle"])
	has_flag = not bool(g.get("noflag", false))   # false = no flagpole/castle finish (custom ending)
	level = _scene_for_file(_level_file).instantiate()
	add_child(level)
	# dark levels (1-4 underground, 2-4 castle) use a pure-black backdrop, no starfield
	underground = bool(g["dark"])
	RenderingServer.set_default_clear_color(Color.BLACK if underground else SKY_COLOR)
	terrain = level.get_node("Terrain")
	if _level_file == 14:
		# sandbox: the level width follows the painted terrain so the camera never clamps
		# short of Mario (and the two-way scroll can reach the whole thing) as you extend it
		var _ur: Rect2i = terrain.get_used_rect()
		LW = maxi(LW, _ur.position.x + _ur.size.x)
		_l14_brick_col = _find_l14_trigger_brick()   # cache once (don't scan every frame)
	else:
		_l14_brick_col = -1
	_read_spawns()
	if has_flag:
		_clear_castle_tiles()   # only levels that actually draw the castle sprite; 1-2 has a
								# custom ending there, so don't erase the player's tiles
	_collect_qblocks()
	_collect_lava()
	_collect_pipeovers()

func _clear_castle_tiles() -> void:
	# the castle is now a sprite (tile_renderer._draw_castle); drop the baked
	# 5x5 "C" tiles so the sprite's transparent crenel gaps show sky, not brick
	for cx in range(5):
		for cy in range(5):
			terrain.erase_cell(Vector2i(CASTLE_X + cx, FLOOR - 1 - cy))

func _collect_qblocks() -> void:
	# gather every ? / mushroom block so fg_renderer can pulse them
	qblock_cells.clear()
	for coord in terrain.get_used_cells():
		var ax: int = terrain.get_cell_atlas_coords(coord).x
		if ax == ATLAS_QUESTION or ax == ATLAS_MUSHROOM \
				or ax == ATLAS_QUESTION_PURPLE or ax == ATLAS_MUSHROOM_PURPLE \
				or ax == ATLAS_TRAP_MUSH or ax == ATLAS_TRAP_MUSH_PURPLE:
			qblock_cells.append(coord)

func _collect_lava() -> void:
	# lava tiles have no collision — cache their rects so touching one = death (2-4)
	lava_rects.clear()
	for coord in terrain.get_used_cells():
		var ax: int = terrain.get_cell_atlas_coords(coord).x
		if ax == ATLAS_LAVA_TOP or ax == ATLAS_LAVA:
			# shrink the deadly zone a touch so a pixel-grazing jump over it is fair
			lava_rects.append(Rect2(coord.x * TILE + 2, coord.y * TILE + 4, TILE - 4, TILE - 4))

func _collect_pipeovers() -> void:
	# each ATLAS_PIPEUP tile is an anchor: the fg renderer draws the whole pipe-over sprite
	# there (a large structure from one placed tile), and we build solid collision to match.
	pipeover_cells.clear()
	for coord in terrain.get_used_cells():
		if terrain.get_cell_atlas_coords(coord).x == ATLAS_PIPEUP:
			pipeover_cells.append(coord)
	_build_pipeover_collision()

# Sample the (trimmed) pipe sprite per 16px tile, bottom-left aligned to the anchor, and
# record which tiles it fills — so the collision matches the drawn shape (the L/pipe), auto-
# updating if the art changes. Computed once and cached.
func _compute_pipeover_offsets() -> void:
	pipeover_solid_offsets.clear()
	var img: Image = load("res://sprites/new player/pipe over.png").get_image()
	img.convert(Image.FORMAT_RGBA8)
	img = img.get_region(img.get_used_rect())     # trim transparent padding (foot at bottom-left)
	var w := img.get_width()
	var h := img.get_height()
	var tw := int(ceil(w / float(TILE)))
	var th := int(ceil(h / float(TILE)))
	for dy in range(th):                          # dy 0 = bottom row (the anchor row)
		for dx in range(tw):
			var sx0 := dx * TILE
			var sy1 := h - dy * TILE               # bottom of this tile in sprite space
			var sy0 := sy1 - TILE
			var opaque := 0
			var total := 0
			for yy in range(maxi(0, sy0), mini(h, sy1)):
				for xx in range(sx0, mini(w, sx0 + TILE)):
					total += 1
					if img.get_pixel(xx, yy).a > 0.4:
						opaque += 1
			if total > 0 and float(opaque) / total > 0.4:
				pipeover_solid_offsets.append(Vector2i(dx, -dy))   # -dy = rows above the anchor

func _build_pipeover_collision() -> void:
	if _pipeover_body and is_instance_valid(_pipeover_body):
		_pipeover_body.queue_free()
	_pipeover_body = null
	if pipeover_cells.is_empty():
		return
	if pipeover_solid_offsets.is_empty():
		_compute_pipeover_offsets()
	var body := StaticBody2D.new()
	body.collision_layer = 1                       # same layer as the terrain the player hits
	body.collision_mask = 0
	for cell in pipeover_cells:
		for off in pipeover_solid_offsets:
			var t: Vector2i = cell + off
			var cs := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			r.size = Vector2(TILE, TILE)
			cs.shape = r
			cs.position = Vector2(t.x * TILE + TILE / 2.0, t.y * TILE + TILE / 2.0)
			body.add_child(cs)
	add_child(body)
	_pipeover_body = body

func _read_spawns() -> void:
	_enemy_defs.clear()
	_coin_defs.clear()
	_barrel_spawner_defs.clear()
	sign_cells.clear()
	var spawns = level.get_node("Spawns")
	_player_start = spawns.get_node("PlayerStart").position
	for m in spawns.get_node("Enemies").get_children():
		_enemy_defs.append({"pos": m.position, "type": m.get_meta("type")})
	for m in spawns.get_node("Coins").get_children():
		_coin_defs.append(m.position)
	# painted enemy tiles (Level2 "EnemyTiles" layer): goomba @ atlas x0, koopa @ x1.
	# Paint on the row whose bottom rests on the ground; the icons are editor-only.
	var etiles = level.get_node_or_null("EnemyTiles")
	if etiles:
		for cell in etiles.get_used_cells():
			var ax: int = etiles.get_cell_atlas_coords(cell).x
			# atlas col 17 = FLAG-PLACEMENT marker (editor-only): put the flagpole at this
			# column, derive the castle a few tiles right, and enable the flag ending —
			# overriding LEVEL_GEOMETRY so levels are easy to build by just painting it.
			if ax == 17:
				FLAG_X = cell.x
				CASTLE_X = cell.x + FLAG_TO_CASTLE
				has_flag = true
				continue
			# atlas col 18 = SIGN marker (editor-only): a blinking background sign, no collision
			if ax == 18:
				sign_cells.append(cell)
				continue
			# atlas col -> enemy type: 0 goomba, 1 koopa, 2 purple goomba,
			# 3 purple koopa, 4 piranha (on pipe top-LEFT tile), 5 hammer bro,
			# 6-9 firebars (pivot at the painted tile's centre): 6 = / clockwise,
			# 7 = \ clockwise, 8 = / counter-clockwise, 9 = \ counter-clockwise.
			# 10-14 = podoboo (lava bubble; erupts from the painted tile's centre) at
			# five jump heights: 10 = base (~6 tiles), then +2 / +4 / +6 / +8 tiles.
			var etype := "goomba"
			match ax:
				1: etype = "koopa"
				2: etype = "purple_goomba"
				3: etype = "purple_koopa"
				4: etype = "piranha"
				5: etype = "hammerbro"
				6, 7, 8, 9: etype = "firebar"
				10, 11, 12, 13, 14: etype = "podoboo"
				15: etype = "bowser"
				16: etype = "piranha"   # UPSIDE-DOWN piranha (hangs from a ceiling pipe)
				19, 20, 21, 22: etype = "barrel_spawner"   # Level 15 barrel emitters (19 normal, 20 fast, 21 bounce, 22 bounce-slow)
				23: etype = "gord"                          # stationary spiky hazard (instant death; blocks barrels)
			var pos: Vector2
			if etype == "piranha":
				# centre on the 2-wide pipe. Normal (atlas 4): rim at the TOP of the painted
				# lip tile, grows up. Inverted (atlas 16): a CEILING pipe — rim at the BOTTOM
				# of the tile, plant hangs DOWN.
				var pinv := (ax == 16)
				var rimy: float = float((cell.y + 1) * TILE) if pinv else float(cell.y * TILE)
				pos = Vector2(float(cell.x * TILE + TILE), rimy)
				_enemy_defs.append({"pos": pos, "type": "piranha", "inverted": pinv})
				continue
			elif etype == "firebar":
				# pivot at the centre of the painted tile (the bar rotates around it).
				# / = start pointing up-right (-45°), \ = down-right (+45°); the marker
				# dot in the icon shows spin (green cw / orange ccw).
				pos = Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0)
				var fstart := -PI / 4.0 if (ax == 6 or ax == 8) else PI / 4.0   # / vs \
				var fcw := (ax == 6 or ax == 7)                                  # cols 6/7 cw
				_enemy_defs.append({"pos": pos, "type": "firebar", "start": fstart, "cw": fcw})
				continue
			elif etype == "podoboo":
				# erupts from the centre of the painted tile (place it on the lava surface).
				# higher launch speed = higher peak (same gravity): base / +2 / +4 tiles.
				pos = Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0)
				var plaunch := -300.0                      # base ~6 tiles
				match ax:
					11: plaunch = -348.0    # ~ +2 tiles
					12: plaunch = -390.0    # ~ +4 tiles
					13: plaunch = -428.0    # ~ +6 tiles
					14: plaunch = -463.0    # ~ +8 tiles
				_enemy_defs.append({"pos": pos, "type": "podoboo", "launch": plaunch})
				continue
			elif etype == "barrel_spawner":
				# a barrel emitter: barrels start from the CENTRE of the painted tile. The atlas
				# col picks the barrel type (19->0 normal, 20->1 fast, 21->2 bounce, 22->3 bounce-slow)
				_barrel_spawner_defs.append({
					"pos": Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0),
					"btype": ax - 19})
				continue
			elif etype == "gord":
				# stationary hazard centred on the painted tile
				_enemy_defs.append({"pos": Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0), "type": "gord"})
				continue
			elif etype == "bowser":
				# 32-tall sprite, centred; drop him so his feet rest on the painted tile
				pos = Vector2(cell.x * TILE + TILE / 2.0, (cell.y + 1) * TILE - 16.0)
			else:
				pos = Vector2(cell.x * TILE + TILE / 2.0, float((cell.y + 1) * TILE))
			_enemy_defs.append({"pos": pos, "type": etype})
		etiles.visible = false
	# painted coin tiles (Level2 "CoinTiles" layer): one collectible coin per cell
	var ctiles = level.get_node_or_null("CoinTiles")
	if ctiles:
		for cell in ctiles.get_used_cells():
			_coin_defs.append(Vector2(cell.x * TILE + 2, cell.y * TILE))
		ctiles.visible = false


# =========================================================================
# RESET / SPAWN
# =========================================================================
func reset(preserve_progress := true) -> void:
	var saved_score := score if preserve_progress else 0
	var saved_coins := coins if preserve_progress else 0

	# a fresh level instance restores every used / broken block
	_instance_level()
	record_progress(level_num)          # save-file: remember the furthest world reached
	_recorded_clear = false             # arm best-time recording for this level
	_new_record = false
	# 1-2 Sonic cutscene: re-arm and locate the trigger pipe (file 4 only)
	sonic_cut = false
	sonic_speech = false
	_sonic_cut_done = false
	sonic_cut_phase = 0
	_l14_cut = false
	_l14_audio = 0                # don't let the gloat song carry over into a fresh Level 14
	_l14_walk_in = false
	_l14_prejump = false
	# 3-4 boss-arena intro: re-arm (fresh level = open wall) and clear any blocks in flight
	_arena_sealed = false
	_arena_phase = 0
	_arena_sonic = false
	_arena_fellback = false
	_arena_broken.clear()
	_cam_shake = 0.0
	_clear_seal_blocks()
	_sonic_pipe_cell = _find_chamber_pipe() if _level_file == 4 else Vector2i(-1, -1)
	# trigger fires when Mario crosses onto the chamber roof (~18 tiles left of the pipe)
	_sonic_trigger_x = float((_sonic_pipe_cell.x - 18) * TILE) if _sonic_pipe_cell.x >= 0 else 0.0
	flag_y = (FLOOR - 11) * TILE + 3   # flag starts just under the ball at the pole top
	flag_sliding = false
	show_level_card = false

	# clear entities
	for e in enemies:
		e.queue_free()
	for it in items:
		it.queue_free()
	for fb in fireballs:
		fb.queue_free()
	for fb in enemy_fireballs:
		fb.queue_free()
	for hm in hammers:
		hm.queue_free()
	for fbar in firebars:
		fbar.queue_free()
	for pod in podoboos:
		pod.queue_free()
	for bw in bowsers:
		bw.queue_free()
	for fl in bowser_flames:
		fl.queue_free()
	for dk in dks:
		dk.queue_free()
	for b in barrels:
		b.queue_free()
	for g in gords:
		g.queue_free()
	enemies.clear()
	items.clear()
	fireballs.clear()
	enemy_fireballs.clear()
	hammers.clear()
	firebars.clear()
	podoboos.clear()
	bowsers.clear()
	bowser_flames.clear()
	dks.clear()
	barrels.clear()
	gords.clear()
	particles.clear()
	block_bumps.clear()   # level re-instances fresh tiles, so just drop in-flight hops
	bump_lock.clear()

	_spawn_enemies()
	_spawn_coins()

	# hidden 1-up block ("I LOVE YOU"), ~50px above spawn — level 1 only
	hidden_blocks = [{"col": 3, "row": 9, "triggered": false}] if _level_file == 1 else []

	# scan the terrain for the painted axe (33) and bridge planks (31), sorted right→left
	axe_ending = false
	axe_phase = 0
	axe_t = 0.0
	_axe_cells.clear()
	_bridge_cells.clear()
	var min_axe_x := 1 << 30
	var axe_y := 0
	for c in terrain.get_used_cells():
		var ax: int = terrain.get_cell_atlas_coords(c).x
		if ax == ATLAS_AXE:
			_axe_cells.append(c)
			if c.x < min_axe_x:
				min_axe_x = c.x
				axe_y = c.y
		elif ax == ATLAS_BRIDGE:
			_bridge_cells.append(c)
	_bridge_cells.sort_custom(func(a, b): return a.x > b.x)   # rightmost first
	_bridge_row = _bridge_cells[0].y if not _bridge_cells.is_empty() else -1
	_bridge_left_col = -1
	for c in _bridge_cells:
		_bridge_left_col = c.x if _bridge_left_col < 0 else mini(_bridge_left_col, c.x)
	_castle_fire_t = CASTLE_FIRE_PERIOD
	# invisible wall just inside the axe: you can reach/touch it but never pass it
	# (jump over it and you're blocked mid-air, then drop onto it)
	_axe_wall_x = float(min_axe_x * TILE + 8) if not _axe_cells.is_empty() else 0.0
	_boss_axe_x = min_axe_x if not _axe_cells.is_empty() else -1
	_boss_axe_y = axe_y
	show_rescue = false
	_rescue_is_am = false
	_am_a2 = false
	rescue_phase = 0
	rescue_walking = false
	show_rescue_speech = false
	rescue_t = 0.0
	rescue_speech_t = 0.0
	# lock the camera on the boss area so Bowser + the bridge + the axe all fit on
	# screen: centre the span of every bridge plank and axe tile in the viewport
	_cam_locked = not _axe_cells.is_empty()
	if _cam_locked:
		var lo := min_axe_x
		var hi := min_axe_x
		for c in _bridge_cells + _axe_cells:
			lo = mini(lo, c.x)
			hi = maxi(hi, c.x)
		if (hi + 1 - lo) * TILE <= VIEW_W:
			# the whole span fits: centre it (Bowser's small castle bridge)
			var center := (lo * TILE + (hi + 1) * TILE) / 2.0
			_cam_lock_x = clampf(center - VIEW_W / 2.0, 0.0, float(LW * TILE - VIEW_W))
		else:
			# span wider than the screen (DK's long bridge): frame the AXE end (the
			# goal) at the right of the view so the axe is always visible
			_cam_lock_x = clampf((hi + 1) * TILE - VIEW_W + 16.0, 0.0, float(LW * TILE - VIEW_W))
	# a level can also declare a fixed camera stop (1-2's ending chamber): the camera
	# scrolls normally until its left edge reaches this tile, then holds — framing the room
	var camlock: int = int(LEVEL_GEOMETRY[_level_file].get("camlock", -1))
	if camlock >= 0:
		_cam_locked = true
		_cam_lock_x = clampf(float(camlock * TILE), 0.0, float(LW * TILE - VIEW_W))

	# Level 14 starts the camera centred on the PlayerStart (it free-scrolls both ways);
	# every other level starts pinned at the left edge.
	cam_x = clampf(_player_start.x - VIEW_W * 0.42, 0.0, float(LW * TILE - VIEW_W)) if _level_file == 14 else 0.0
	if camera:
		camera.position = Vector2(roundf(cam_x) + VIEW_W / 2.0, VIEW_H / 2.0)
	score = saved_score
	coins = saved_coins
	elapsed = 0.0
	if _carry_elapsed >= 0.0:      # 1-2 -> EXTRA 1 pipe warp: keep the clock running
		elapsed = _carry_elapsed
		_carry_elapsed = -1.0
	timing = true
	game_state = "play"
	pipe_exit = false
	start_delay = START_DELAY   # brief frozen "get ready" while the stage fades in from black
	fade_alpha = 1.0

	player.spawn(_player_start)

	# pick the right track for this stage (1-4 = underground theme)
	_apply_level_music()

	# resume music after a death/win
	if music_off:
		music_off = false
		if fanfare_player: fanfare_player.stop()
		if death_player: death_player.stop()
		if sonic_song_player: sonic_song_player.stop()
		if sega_player: sega_player.stop()
		_play_music(true)

	_maybe_start_intro12()   # 1-2 only: override into the surface cutscene
	_maybe_start_emerge()    # EXTRA 1 only: rise out of the start pipe on arrival
	_maybe_start_reward_trap()  # Level11 only: drop out of the ceiling pipe into the lava
	_maybe_start_sonic_demo()  # Level10 only: hide Mario, run the Sonic preview
	_maybe_start_dk()          # Level15 only: Donkey Kong on his ledge hurling barrels
	_maybe_start_arena_intro() # Level17 only: walk-in cutscene + the sealing block wall

func _spawn_enemies() -> void:
	# placed barrel emitters (Level 15): each starts spitting barrels on its own staggered timer
	barrel_spawners.clear()
	for d in _barrel_spawner_defs:
		barrel_spawners.append({"pos": d["pos"], "btype": int(d["btype"]), "t": randf_range(0.3, 1.6)})
	for d in _enemy_defs:
		var t: String = d["type"]
		# Gord: stationary spiky hazard (its own node, not a walking Enemy)
		if t == "gord":
			var g = Gord.new()
			g.main = self
			add_child(g)
			g.spawn(d["pos"])
			gords.append(g)
			continue
		# piranha plant: a pipe dweller with its own script (not a walking Enemy)
		if t == "piranha":
			var pl = Piranha.new()
			pl.main = self
			pl.inverted = d.get("inverted", false)
			add_child(pl)
			pl.spawn(d["pos"])
			enemies.append(pl)
			continue
		if t == "hammerbro":
			var hb = HammerBro.new()
			hb.main = self
			add_child(hb)
			hb.spawn(d["pos"])
			enemies.append(hb)
			continue
		if t == "firebar":
			var fbar = Firebar.new()
			fbar.main = self
			fbar.cw = d.get("cw", true)
			add_child(fbar)
			fbar.spawn(d["pos"])
			fbar.angle = d.get("start", 0.0)   # / or \ starting orientation
			firebars.append(fbar)   # own list — indestructible, custom collision
			continue
		if t == "podoboo":
			var pod = Podoboo.new()
			pod.main = self
			pod.launch = d.get("launch", -300.0)   # jump-height variant
			add_child(pod)
			pod.spawn(d["pos"])
			podoboos.append(pod)   # own list — indestructible, custom collision
			continue
		if t == "bowser":
			var bw = Bowser.new()
			bw.main = self
			add_child(bw)
			bw.spawn(d["pos"])
			bowsers.append(bw)
			continue
		var e = Enemy.new()
		e.main = self
		# "purple_goomba" / "purple_koopa" share the base kind's physics + stomp
		# rules, but flip on the purple art and their special AI.
		e.purple = t.begins_with("purple")
		e.kind = "koopa" if t.ends_with("koopa") else "goomba"
		if e.purple and e.kind == "koopa":
			e.ledge_shy = true          # SMB1 red-koopa: won't walk off ledges
		add_child(e)
		e.spawn(d["pos"])
		enemies.append(e)

func _spawn_coins() -> void:
	coins_list.clear()
	for pos in _coin_defs:
		coins_list.append({"pos": pos, "got": false, "anim": randf() * 6.0})


# =========================================================================
# BLOCK BUMP
# =========================================================================
func bump_block(tx: int, ty: int) -> void:
	if ty < 0 or ty >= ROWS or tx < 0 or tx >= LW:
		return
	var coord := Vector2i(tx, ty)
	if terrain.get_cell_source_id(coord) < 0:
		return
	# Debounce: one bump event per block. The capsule head can re-contact a flat
	# block underside on the next frame (was_rising stays true) which would fire
	# the sound twice; a short per-coord lockout collapses that to one.
	var now := Time.get_ticks_msec()
	if bump_lock.get(coord, 0) > now:
		return
	bump_lock[coord] = now + 140
	var ax: int = terrain.get_cell_atlas_coords(coord).x
	# Only a LIVE bumpable block (?, mushroom, trap, brick) disturbs what's standing on
	# top of it (goomba dies, koopa flips to a stunned shell, a mushroom hops). A spent/
	# plain solid — used block, blockc, giant-pipe anchor — is INERT: SMB1 lets you head-
	# butt it for a bump sound but it can't re-bounce an item resting on top.
	var is_live := ax == ATLAS_QUESTION or ax == ATLAS_QUESTION_PURPLE \
		or ax == ATLAS_MUSHROOM or ax == ATLAS_MUSHROOM_PURPLE \
		or ax == ATLAS_TRAP_MUSH or ax == ATLAS_TRAP_MUSH_PURPLE \
		or ax == ATLAS_BRICK or ax == ATLAS_BRICK_PURPLE
	if is_live:
		_hit_things_on_block(tx, ty)
	# alt ? blocks turn into the PURPLE used block; the plain ones into the orange used block
	var used_x: int = ATLAS_USED_PURPLE if (ax == ATLAS_QUESTION_PURPLE or ax == ATLAS_MUSHROOM_PURPLE or ax == ATLAS_TRAP_MUSH_PURPLE) else ATLAS_USED
	if ax == ATLAS_QUESTION or ax == ATLAS_QUESTION_PURPLE:
		terrain.set_cell(coord, SOURCE_ID, Vector2i(used_x, 0))
		qblock_cells.erase(coord)
		_spawn_coin_pop(tx, ty)
		coins += 1
		score += 200
		sfx("coin")
		_start_block_bump(coord, used_x)          # spent block hops up 5px and back
	elif ax == ATLAS_MUSHROOM or ax == ATLAS_MUSHROOM_PURPLE:
		terrain.set_cell(coord, SOURCE_ID, Vector2i(used_x, 0))
		qblock_cells.erase(coord)
		score += 1000
		sfx("powerup_appear")                     # sound plays the instant it's hit
		# but the item only appears once the block has hopped up and snapped back:
		# already-big Mario gets a fire flower, otherwise a REAL mushroom
		var spawn_item: Callable = _spawn_flower.bind(tx, ty) if player.big \
			else _spawn_item.bind(tx, ty)
		_start_block_bump(coord, used_x, spawn_item)
	elif ax == ATLAS_TRAP_MUSH or ax == ATLAS_TRAP_MUSH_PURPLE:
		# dedicated TRAP block (both colours) → the upside-down mushroom that kills on collect
		terrain.set_cell(coord, SOURCE_ID, Vector2i(used_x, 0))
		qblock_cells.erase(coord)
		score += 1000
		sfx("powerup_appear")
		_start_block_bump(coord, used_x, _spawn_trap_mushroom.bind(tx, ty))
	elif ax == ATLAS_BRICK or ax == ATLAS_BRICK_PURPLE:
		if player.big:
			terrain.erase_cell(coord)        # removes the tile and its collision
			_spawn_debris(tx, ty, ax == ATLAS_BRICK_PURPLE)   # purple pieces for the purple brick
			score += 50
			sfx("brick")
		else:
			sfx("bump")                       # small Mario can't break it — just bump
			_start_block_bump(coord, ax)      # brick hops up 5px and back (keeps its colour)
	elif ax == ATLAS_USED or ax == ATLAS_USED_PURPLE or ax == ATLAS_BLOCKC or ax == ATLAS_PIPEUP:
		# solid, already-spent / plain block: bump sound only, no hop (per request)
		sfx("bump")

const MUSHROOM_HOP_H := 22.0    # how high (px) a mushroom hops when its block is bumped

func _hit_things_on_block(tx: int, ty: int) -> void:
	# knock whatever is standing on top of block (tx,ty) — when it's bumped/broken
	var bx0: float = tx * TILE
	var bx1: float = bx0 + TILE
	var btop: float = ty * TILE
	for e in enemies:
		if not e.active or e.dead:
			continue
		var er: Rect2 = e.get_rect()
		var feet: float = er.position.y + er.size.y
		if absf(feet - btop) > 6.0:                     # not resting on this block's top
			continue
		if er.position.x + er.size.x <= bx0 or er.position.x >= bx1:   # no x overlap
			continue
		if e.kind == "koopa":
			e.flip_stun()                               # SMB3 upside-down stunned shell
		else:
			e.knock_out(1)                              # goomba etc: flip over and die
			score += 100
		sfx("kick")
	for it in items:
		if it.dead or not (it is Mushroom) or it.emerging:
			continue
		var ir: Rect2 = it.get_rect()
		var ifeet: float = ir.position.y + ir.size.y
		if absf(ifeet - btop) > 6.0:
			continue
		if ir.position.x + ir.size.x <= bx0 or ir.position.x >= bx1:
			continue
		# launch velocity for a MUSHROOM_HOP_H peak under the mushroom's gravity-first
		# Euler step (v = (g*dt + sqrt((g*dt)^2 + 8*g*h))/2)
		var gdt: float = GRAVITY / 60.0
		it.velocity.y = -(gdt + sqrt(gdt * gdt + 8.0 * GRAVITY * MUSHROOM_HOP_H)) / 2.0
		it.hopping = true                               # gentler gravity on the way down
	# a coin resting on top of this block gets collected when the block is bumped/broken
	for c in coins_list:
		if c.got:
			continue
		var cbot: float = c.pos.y + 16.0                # coin rect is 12x16 (see _update_coins)
		if absf(cbot - btop) > 6.0:                     # not sitting on this block's top
			continue
		if c.pos.x + 12.0 <= bx0 or c.pos.x >= bx1:     # no x overlap
			continue
		c.got = true
		coins += 1
		score += 200
		sfx("coin")
		# same pop animation as a coin from a ? block: arc up + spin from the coin's spot
		particles.append({"type": "coinpop", "cx": c.pos.x + 6.0, "top": c.pos.y, "life": COINPOP_DUR})

const COINPOP_DUR := 0.5       # SMB1-style: pops up in an arc and back down
const COINPOP_PEAK := 52.0     # peak height of the arc (px above the block ~3 tiles)
const COINPOP_END := 16.0      # coin vanishes this high above the block (one tile), not at the block
const COINPOP_SIZE := 16.0     # drawn coin size in px (full source size)

func _spawn_coin_pop(tx: int, ty: int) -> void:
	# the COINS2 coin: arcs up off the block (peak ~40px) and falls back while
	# spinning fast through A1->A4 (drawn in tile_renderer._draw_particles)
	particles.append({"type": "coinpop", "cx": tx * TILE + TILE / 2.0,
		"top": float(ty * TILE), "life": COINPOP_DUR})

const BUMP_DUR := 0.156     # seconds for the up-6px-and-back hop (20% slower than 0.13)
const BUMP_RISE := 6.0      # peak pixels the block rises

func _start_block_bump(coord: Vector2i, atlas_x: int, on_done := Callable()) -> void:
	# Hop the block up 6px and back. The real tilemap cell is hidden for the hop
	# (so we don't see a static tile behind the moving one) and drawn as a moving
	# overlay by tile_renderer; the cell is restored when the hop ends. `on_done`
	# (optional) fires the moment the block snaps back — used to reveal the item
	# only after the hop, not on impact.
	terrain.erase_cell(coord)
	block_bumps.append({"coord": coord, "atlas_x": atlas_x, "t": 0.0, "on_done": on_done})

func _update_block_bumps(delta: float) -> void:
	for i in range(block_bumps.size() - 1, -1, -1):
		var b = block_bumps[i]
		b.t += delta
		if b.t >= BUMP_DUR:
			# restore the solid tile (and its collision) at rest
			terrain.set_cell(b.coord, SOURCE_ID, Vector2i(b.atlas_x, 0))
			var cb: Callable = b.on_done
			block_bumps.remove_at(i)
			if cb.is_valid():
				cb.call()   # e.g. spawn the mushroom/flower now that the block is back

func bump_offset(t: float) -> float:
	# 0 -> 6 -> 0 over BUMP_DUR: a smooth pop up and back down
	return BUMP_RISE * sin(PI * clampf(t / BUMP_DUR, 0.0, 1.0))

# SMB1 brick shatter: 4 chunks burst from the block, tumbling. The top pair launches
# higher; every piece flies OUTWARD (left column left, right column right) and then falls
# all the way down and off the bottom of the screen (none vanish early). Colour follows
# the brick — orange piece for the orange brick, purple piece for the purple brick.
const DEBRIS_GRAV := 900.0        # px/s^2 pulling the chunks back down
const DEBRIS_VX := 70.0           # outward horizontal speed
const DEBRIS_VY_TOP := 430.0      # upward launch of the top pair
const DEBRIS_VY_BOT := 300.0      # upward launch of the bottom pair (shorter arc)
const DEBRIS_SPIN := 9.0          # rad/s tumble

func _spawn_debris(tx: int, ty: int, purple := false) -> void:
	var cx: float = tx * TILE + TILE / 2.0
	var cy: float = float(ty * TILE)
	var ax: int = ATLAS_PIECE_PURPLE if purple else ATLAS_PIECE
	# [dx, dy, vx, vy, spin]  — top-left, top-right, bottom-left, bottom-right
	var seeds := [
		[-4.0, -2.0, -DEBRIS_VX, -DEBRIS_VY_TOP, -DEBRIS_SPIN],
		[ 4.0, -2.0,  DEBRIS_VX, -DEBRIS_VY_TOP,  DEBRIS_SPIN],
		[-4.0,  5.0, -DEBRIS_VX, -DEBRIS_VY_BOT, -DEBRIS_SPIN],
		[ 4.0,  5.0,  DEBRIS_VX, -DEBRIS_VY_BOT,  DEBRIS_SPIN],
	]
	for s in seeds:
		particles.append({"type": "debris", "atlas_x": ax,
			"pos": Vector2(cx + s[0], cy + s[1]),
			"vel": Vector2(s[2], s[3]),
			"ang": 0.0, "spin": s[4], "life": 1.0})

func _spawn_item(block_row_tx: int, block_row: int) -> void:
	# same convention as _spawn_flower: pass the block's row; it emerges from its top
	var m = Mushroom.new()
	m.main = self
	add_child(m)
	m.spawn(Vector2(block_row_tx * TILE + TILE / 2.0, block_row * TILE))
	items.append(m)

func _spawn_flower(block_row_tx: int, block_row: int) -> void:
	# feet rest on the block's top surface, so it sits in the tile just above it
	var f = Flower.new()
	f.main = self
	add_child(f)
	f.spawn(Vector2(block_row_tx * TILE + TILE / 2.0, block_row * TILE))
	items.append(f)

func _spawn_green_mushroom(block_row_tx: int, block_row: int) -> void:
	var m = Mushroom.new()
	m.main = self
	m.green = true
	add_child(m)
	m.spawn(Vector2(block_row_tx * TILE + TILE / 2.0, block_row * TILE))
	items.append(m)

func _spawn_trap_mushroom(block_row_tx: int, block_row: int) -> void:
	# the upside-down "trap" mushroom: emerges + walks like a normal one, but kills on collect
	var m = Mushroom.new()
	m.main = self
	m.trap = true
	add_child(m)
	m.spawn(Vector2(block_row_tx * TILE + TILE / 2.0, block_row * TILE))
	items.append(m)


# =========================================================================
# HIDDEN BLOCKS — invisible, no collision, triggered by a rising head bump
# =========================================================================
func _update_hidden_blocks() -> void:
	if player.dead or player.winning or player.velocity.y >= 0:
		return
	var p_top: float = player.global_position.y - player.col_size.y / 2.0
	var p_left: float = player.global_position.x - player.half_w()
	var p_right: float = player.global_position.x + player.half_w()
	for hb in hidden_blocks:
		if hb.triggered:
			continue
		var b_top: int = hb.row * TILE
		var b_bot: int = b_top + TILE
		var b_left: int = hb.col * TILE
		var b_right: int = b_left + TILE
		# the head has risen into the block's band and overlaps it horizontally
		if p_top <= b_bot + 1 and p_top >= b_top - 8 and p_left < b_right and p_right > b_left:
			hb.triggered = true
			_trigger_hidden(hb)

func _trigger_hidden(hb) -> void:
	var coord := Vector2i(hb.col, hb.row)
	terrain.set_cell(coord, SOURCE_ID, Vector2i(ATLAS_USED, 0))   # becomes a solid, visible block
	bump_lock[coord] = Time.get_ticks_msec() + 140   # don't let the reveal double as a bump
	_spawn_green_mushroom(hb.col, hb.row)
	hud.show_message("I LOVE YOU")
	sfx("powerup")
	# bump the player: stop the rise and drop just below the new block
	player.global_position.y = (hb.row + 1) * TILE + player.col_size.y / 2.0
	player.velocity.y = 40.0


# =========================================================================
# ENTITY-VS-ENTITY GAMEPLAY COLLISIONS
# =========================================================================
func _update_gameplay_collisions() -> void:
	if player.dead or player.winning:
		return
	var pr: Rect2 = player.get_rect()

	# touch the axe -> trigger the bridge-collapse ending
	for c in _axe_cells:
		if pr.intersects(Rect2(c.x * TILE, c.y * TILE, TILE, TILE)):
			_start_axe_ending()
			return

	# lava: NOT an instant kill on contact — the lava tiles have no collision, so Mario
	# sinks straight through them and falls down the pit, dying from the fall (the pit-fall
	# death fires once he drops below the screen). So "fall through the lava and die", not
	# "die the instant you touch it". (lava_rects kept for possible future use.)

	# rotating firebars (castle): any ball touch hurts — big shrinks, small dies.
	# Skipped during the brief stage-start freeze so a bar can't graze the spawn.
	if start_delay <= 0.0:
		for fbar in firebars:
			if fbar.hits(pr):
				player.hurt()
				break
		for pod in podoboos:
			if pod.hits(pr):
				player.hurt()
				break
		for b in bowsers:
			if not b.dead and pr.intersects(b.get_rect()):
				player.hurt()
				break
		for fl in bowser_flames:
			if not fl.dead and pr.intersects(fl.get_rect()):
				player.hurt()
				break

	# player vs enemies
	for e in enemies:
		if not e.active or e.dead:
			continue
		if not pr.intersects(e.get_rect()):
			continue
		var stomping: bool = player.velocity.y > 0 and (pr.position.y + pr.size.y) - e.get_rect().position.y < 12
		if e.kind == "piranha":
			player.hurt()          # piranha plant can't be stomped — any touch hurts
			continue
		if e.kind == "koopa" and e.shell and not e.shell_moving:
			# a still shell gets kicked away from you on any touch — but not during the
			# brief grace after it was made/stopped (that would re-trigger on one overlap)
			if e.shell_cd <= 0.0:
				e.shell_moving = true
				e.dir = 1 if player.global_position.x < e.global_position.x else -1
				e.velocity.x = e.dir * 200.0
				e.shell_cd = 0.1
				player.invuln = 0.1
				sfx("kick")
			continue
		if e.kind == "koopa" and e.shell and e.shell_moving:
			if stomping:
				# landing on a sliding shell stops it (SMB1) — but only once it's clear of
				# the kick that started it, so a single overlap can't oscillate it stop/go
				if e.shell_cd <= 0.0:
					e.shell_moving = false
					e.velocity.x = 0
					e.shell_cd = 0.1
					sfx("stomp")
				player.bounce()          # bounce off the top either way (stop, or grace)
			else:
				player.hurt()
			continue
		if stomping:
			if e.kind == "goomba" or e.kind == "hammerbro":
				e.squish()          # goomba flattens; hammer bro topples and dies
			else:
				e.to_shell()
			player.bounce()
			score += 100
			sfx("stomp")
		else:
			player.hurt()

	# moving shell vs other enemies
	for e in enemies:
		if e.kind == "koopa" and e.shell and e.shell_moving and not e.dead:
			for o in enemies:
				if o == e or o.dead or (o.kind == "koopa" and o.shell):
					continue
				if e.get_rect().intersects(o.get_rect()):
					o.knock_out(e.dir)          # knocked the way the shell is sliding
					score += 100

	# walking enemies bump each other: turn away AND push apart so they never clip or
	# stack (e.g. a goomba falling onto another in 1-2). The push is capped per frame
	# so they slide apart smoothly instead of snapping. Rooted piranhas are exempt.
	for i in range(enemies.size()):
		var a = enemies[i]
		if not a.active or a.dead or a.kind == "piranha" or (a.kind == "koopa" and a.shell):
			continue
		for j in range(i + 1, enemies.size()):
			var b = enemies[j]
			if not b.active or b.dead or b.kind == "piranha" or (b.kind == "koopa" and b.shell):
				continue
			var ar: Rect2 = a.get_rect()
			var br: Rect2 = b.get_rect()
			if not ar.intersects(br):
				continue
			# separate along x by the overlap (each moves half, capped at 2px/frame)
			var overlap_x: float = minf(ar.end.x, br.end.x) - maxf(ar.position.x, br.position.x)
			var push: float = minf(overlap_x * 0.5 + 0.5, 2.0)
			if a.global_position.x <= b.global_position.x:
				a.global_position.x -= push; b.global_position.x += push
				a.dir = -1; b.dir = 1
			else:
				a.global_position.x += push; b.global_position.x -= push
				a.dir = 1; b.dir = -1

	# player vs mushrooms
	for it in items:
		if it.dead:
			continue
		if pr.intersects(it.get_rect()):
			it.dead = true
			if it is Flower:
				if not player.big and not player.transforming:
					player.grow()      # small Mario: a flower just makes him big
				elif not player.fire:
					player.become_fire()
				else:
					sfx("powerup")     # already fire — no change, but play the power-up jingle
				score += 1000
			elif it.green:             # green (1-up) mushroom — just a bonus
				sfx("coin")
				score += 4000
			elif it.trap:              # upside-down trap mushroom — collecting it kills you
				player.kill()
			else:                      # red mushroom
				if not player.big and not player.transforming:
					player.grow()      # grow() plays the power-up sound
				else:
					sfx("coin")        # already big — just a pickup blip
				score += 1000
	# remove collected / fallen mushrooms (free the node, not just the array entry)
	var kept_items := []
	for it in items:
		if it.dead:
			it.queue_free()
		else:
			kept_items.append(it)
	items = kept_items

	# cull dead enemies handled in enemy scripts / here
	var kept := []
	for e in enemies:
		if e.remove_me:
			e.queue_free()
		else:
			kept.append(e)
	enemies = kept


const FIREPOP_DUR := 6.0 / 60.0     # SMB1 fireball explosion: 3 frames x 2 game-frames

func spawn_fireball(pos: Vector2, dir: int) -> void:
	if fireballs.size() >= 2:            # SMB caps to two on screen
		return
	var fb = Fireball.new()
	fb.main = self
	add_child(fb)
	fb.launch(pos, dir)
	fireballs.append(fb)
	sfx("fireball")

func _update_fireballs() -> void:
	for fb in fireballs:
		if fb.dead:
			continue
		var fr: Rect2 = fb.get_rect()
		for e in enemies:
			if not e.active or e.dead:
				continue
			if fr.intersects(e.get_rect()):
				e.knock_out(signi(fb.velocity.x))   # knocked in the fireball's direction
				score += 100
				sfx("kick")                          # fireball kill uses the kick-shell sound
				fb.dead = true
				fb.burst = true
				break
	var kept_fb := []
	for fb in fireballs:
		if fb.dead:
			if fb.burst:                 # impact -> flash a 2x fireball, then gone
				# nudge 10px in the travel dir so a point-blank wall hit
				# lands the burst on the wall, not on top of Mario
				particles.append({"type": "fireburst",
					"pos": fb.global_position + Vector2(fb.facing * 10, 0),
					"vel": Vector2.ZERO, "life": FIREPOP_DUR})
			fb.queue_free()
		else:
			kept_fb.append(fb)
	fireballs = kept_fb


func enemy_shoot_fireball(pos: Vector2, dir: int) -> void:
	if enemy_fireballs.size() >= 3:      # keep the screen sane
		return
	var fb = Fireball.new()
	fb.main = self
	fb.enemy = true
	add_child(fb)
	fb.launch(pos, dir)
	enemy_fireballs.append(fb)
	sfx("fireball")

func _update_enemy_fireballs() -> void:
	var pr: Rect2 = player.get_rect()
	for fb in enemy_fireballs:
		if fb.dead:
			continue
		if not player.dead and not player.winning and fb.get_rect().intersects(pr):
			player.hurt()                # small Mario dies, big Mario shrinks
			fb.dead = true
			fb.burst = true
	var kept := []
	for fb in enemy_fireballs:
		if fb.dead:
			if fb.burst:
				particles.append({"type": "fireburst",
					"pos": fb.global_position + Vector2(fb.facing * 10, 0),
					"vel": Vector2.ZERO, "life": FIREPOP_DUR})
			fb.queue_free()
		else:
			kept.append(fb)
	enemy_fireballs = kept


func _update_castle_fire(delta: float) -> void:
	# Bowser-castle approach hazard: while you're still making your way toward Bowser, a
	# flame fires straight at you every few seconds from off the right edge, a couple tiles
	# above the bridge. Stops once you actually reach him — his own fire takes over there.
	if _bridge_row < 0 or axe_ending or bowsers.is_empty():
		return
	# don't begin until Mario reaches the trigger point — N tiles left of the bridge
	if player.global_position.x < float(_bridge_left_col - CASTLE_FIRE_START_TILES_LEFT) * TILE:
		return
	var bz = bowsers[0]
	# stop the free-spawning fire the moment Bowser is actually visible on screen —
	# from there his own fire breath is the hazard.
	if bz.dead or bz.global_position.x < cam_x + VIEW_W:
		return
	_castle_fire_t -= delta
	if _castle_fire_t > 0.0:
		return
	_castle_fire_t = CASTLE_FIRE_PERIOD
	# spawn just off the right edge, a couple tiles above the bridge, flying straight left
	var y := float(_bridge_row - CASTLE_FIRE_TILES_OVER) * TILE + TILE / 2.0
	spawn_bowser_flame(Vector2(cam_x + VIEW_W + 8.0, y), -1, true)

func spawn_bowser_flame(pos: Vector2, dir: int, straight := false) -> void:
	if bowser_flames.size() >= 4:
		return
	var fl = BowserFlame.new()
	fl.main = self
	add_child(fl)
	fl.launch(pos, dir, straight)
	bowser_flames.append(fl)
	sfx("bowser_fire")          # Bowser's fire sound (the caller no longer double-plays it)

func _update_bowsers() -> void:
	# fireballs chip Bowser's 5 hit points
	for fb in fireballs:
		if fb.dead:
			continue
		var fr: Rect2 = fb.get_rect()
		for b in bowsers:
			if b.dead:
				continue
			if fr.intersects(b.get_rect()):
				b.knock_out(signi(fb.velocity.x))
				score += 100
				fb.dead = true
				fb.burst = true
				break
	# reap toppled (faded-out) bowsers and expired flames
	var keptb := []
	for b in bowsers:
		if b.dead and b.modulate.a <= 0.0:
			b.queue_free()
		else:
			keptb.append(b)
	bowsers = keptb
	var keptf := []
	for fl in bowser_flames:
		if fl.dead:
			fl.queue_free()
		else:
			keptf.append(fl)
	bowser_flames = keptf


# ---- Donkey Kong (Level 15): boss + the barrels he hurls ----
func spawn_dk_barrel(pos: Vector2, dir: int, btype := 0) -> void:
	var b = Barrel.new()
	b.main = self
	add_child(b)
	b.spawn(pos, dir, btype)
	barrels.append(b)

func _update_dk() -> void:
	if dks.is_empty() and barrels.is_empty():
		return
	var pr := Rect2(player.global_position - player.col_size / 2.0, player.col_size)
	if not player.dead:
		# DK's body hurts on touch (you get PAST him, you don't stomp him — the bridge does it)
		for dk in dks:
			if not dk.dead and pr.intersects(dk.get_rect()):
				player.hurt()
		# his barrels always hurt — Mario must jump over them
		for b in barrels:
			if not b.dead and pr.intersects(b.get_rect()):
				player.hurt()
	# reap spent barrels and toppled (faded) DKs
	var kb := []
	for b in barrels:
		if b.dead:
			b.queue_free()
		else:
			kb.append(b)
	barrels = kb
	var kd := []
	for dk in dks:
		if dk.dead and dk.modulate.a <= 0.0:
			dk.queue_free()
		else:
			kd.append(dk)
	dks = kd

# Placed barrel emitters (EnemyTiles atlas 19): each spits a barrel on its own staggered timer,
# rolling toward Mario. When any are placed, DK stops auto-throwing (these are the origins you paint).
func _update_barrel_spawners(delta: float) -> void:
	if barrel_spawners.is_empty() or player.dead:
		return
	for sp in barrel_spawners:
		if sp.get("done", false):
			continue                     # each marker drops ONE barrel, then it's spent
		var pos: Vector2 = sp.pos
		var dx: float = pos.x - player.global_position.x   # + = spawner is ahead of Mario
		if dx < BARREL_LEAD_MIN:
			sp.done = true               # Mario reached/passed it without a sensible lead — skip it
			continue
		if dx <= BARREL_LEAD_MAX:
			# he's approaching and it's a decent lead ahead → drop the barrel so it rolls at him
			spawn_dk_barrel(pos, -1 if player.global_position.x <= pos.x else 1, int(sp.btype))
			sp.done = true

# Gord: stationary spiky hazards — any touch is INSTANT death (even big Mario). Barrels bounce
# off them (handled in barrel.gd); here we only check the player.
func _update_gords() -> void:
	if gords.is_empty() or player.dead or player.winning:
		return
	var pr: Rect2 = player.get_rect()
	for g in gords:
		if not g.dead and pr.intersects(g.get_rect()):
			player.kill()
			return

# Level 15 only: drop Donkey Kong onto his top ledge to start hurling barrels.
func _maybe_start_dk() -> void:
	if _level_file != 15:
		return
	var dk = DK.new()
	dk.main = self
	add_child(dk)
	# stand on the BRIDGE (the collapsing planks over lava), a bit back from the far/axe end so
	# Mario has to jump past him — and so he drops into the lava when the bridge falls.
	var col := 36
	var row := FLOOR
	if not _bridge_cells.is_empty():
		var hi: int = _bridge_cells[0].x           # planks are sorted right→left; [0] = far end
		var lo: int = _bridge_cells[0].x
		for c in _bridge_cells:
			hi = maxi(hi, c.x)
			lo = mini(lo, c.x)
		col = clampi(hi - 2, lo, hi)               # just before the hammer at the far end of the bridge
		row = _bridge_cells[0].y
	dk.spawn(Vector2(float(col) * TILE, float(row) * TILE - float(DK_FEET_Y - DK_CANVAS / 2)))
	dks.append(dk)


func spawn_hammer(pos: Vector2, vel: Vector2) -> void:
	if hammers.size() >= 6:
		return
	var hm = Hammer.new()
	hm.main = self
	add_child(hm)
	hm.launch(pos, vel)
	hammers.append(hm)

func _update_hammers() -> void:
	var pr: Rect2 = player.get_rect()
	for hm in hammers:
		if hm.dead:
			continue
		if not player.dead and not player.winning and hm.get_rect().intersects(pr):
			player.hurt()
			hm.dead = true
	var kept := []
	for hm in hammers:
		if hm.dead:
			hm.queue_free()
		else:
			kept.append(hm)
	hammers = kept


func _update_coins(delta: float) -> void:
	var pr: Rect2 = player.get_rect()
	var can_collect: bool = not player.dead   # no grabbing coins during the death animation / pit fall
	for c in coins_list:
		if c.got:
			continue
		c.anim += delta * 15.0
		var cr := Rect2(c.pos, Vector2(12, 16))
		if can_collect and pr.intersects(cr):
			c.got = true
			coins += 1
			score += 200
			sfx("coin")


func _update_particles(delta: float) -> void:
	for p in particles:
		if p.type == "debris":
			p.pos += p.vel * delta
			p.vel.y += DEBRIS_GRAV * delta
			p.ang += p.spin * delta
		else:
			p.life -= delta   # "coinpop"/"fireburst" are time-based, no integration
	# debris lives until it falls off the BOTTOM (all 4 fall the whole way, never culled
	# on the sides); other particles die when their life runs out
	particles = particles.filter(func(p):
		if p.type == "debris":
			return p.pos.y < VIEW_H + 24.0
		return p.life > 0)


# =========================================================================
# CAMERA / TIMER
# =========================================================================
func _update_flag_slide(delta: float) -> void:
	# smooth, continuous lowering from the top to the base edge — independent of
	# where Mario grabbed the pole and of his own descent (no snapping)
	if not flag_sliding:
		return
	var flag_bottom: float = float((FLOOR - 2) * TILE)
	flag_y = minf(flag_y + FLAG_SLIDE_SPEED * delta, flag_bottom)
	if flag_y >= flag_bottom:
		flag_sliding = false

func _update_camera() -> void:
	# 3-4 intro cutscene drives its own camera (follows Mario in, then Sonic's crash, then the standoff)
	if game_state == "arena_intro":
		camera.position = Vector2(roundf(cam_x) + VIEW_W / 2.0, VIEW_H / 2.0)
		return
	# Level 14 ONLY: the camera follows Mario in BOTH directions — he can backtrack and it
	# scrolls left with him (no SMB1 one-way scroll, no left wall).
	if _level_file == 14:
		cam_x = clampf(player.global_position.x - VIEW_W * 0.42, 0.0, float(LW * TILE - VIEW_W))
		camera.position = Vector2(roundf(cam_x) + VIEW_W / 2.0, VIEW_H / 2.0)
		return
	# 3-4 boss fight: follow Mario BOTH ways (centred), EASED so it slides smoothly out of the
	# standoff framing at the start (and trails him gently) instead of snapping.
	if _boss_active:
		# follow Mario but never scroll past 1 tile outside the gordos on either side
		var target: float = clampf(player.global_position.x - VIEW_W / 2.0, _boss_cam_lo, _boss_cam_hi)
		cam_x = lerp(cam_x, target, clampf(10.0 * get_physics_process_delta_time(), 0.0, 1.0))
		camera.position = Vector2(roundf(cam_x) + VIEW_W / 2.0, VIEW_H / 2.0)
		return
	var target: float = player.global_position.x - VIEW_W * 0.42
	if target > cam_x:
		cam_x = target
	cam_x = clampf(cam_x, 0.0, float(LW * TILE - VIEW_W))
	# boss area: stop scrolling so Bowser, the bridge and the axe stay on screen
	if _cam_locked:
		cam_x = minf(cam_x, _cam_lock_x)
	# Snap the camera to whole pixels. cam_x stays fractional for the scroll logic,
	# but a sub-pixel camera makes static tiles rasterize to 15/16px depending on
	# scroll (the block appears to change size as you walk); a pixel-snapped camera
	# renders integer-positioned world tiles identically every frame.
	var shake := Vector2.ZERO
	if _cam_shake > 0.05:
		shake = Vector2(randf_range(-_cam_shake, _cam_shake), randf_range(-_cam_shake, _cam_shake))
	camera.position = Vector2(roundf(cam_x) + VIEW_W / 2.0 + shake.x, VIEW_H / 2.0 + shake.y)
	# one-way left wall at the camera edge
	var min_x: float = cam_x + player.half_w()
	if player.global_position.x < min_x:
		player.global_position.x = min_x
		if player.velocity.x < 0:
			player.velocity.x = 0
	# invisible right wall at the axe: full-height, so you can't jump past it — you're
	# stopped and drop back down onto the axe (which triggers the ending on contact)
	if not _axe_cells.is_empty() and not axe_ending:
		var max_x: float = _axe_wall_x - player.half_w()
		if player.global_position.x > max_x:
			player.global_position.x = max_x
			if player.velocity.x > 0:
				player.velocity.x = 0

func _update_timer(delta: float) -> void:
	# real-time stopwatch counting up; frozen the instant the flagpole is touched,
	# and during the brief stage-start freeze (so it starts from 0)
	if game_state != "play" or not timing or start_delay > 0.0:
		return
	elapsed += delta

## Elapsed run time for the HUD / clear screen: SS.cc under a minute,
## M:SS.cc once it passes one minute (the ":" is drawn by the HUD font code).
func time_string() -> String:
	var t := minf(elapsed, 5999.99)
	var m := int(t) / 60
	if m > 0:
		return "%d:%05.2f" % [m, t - m * 60]
	return "%.2f" % t

func on_reach_flag() -> void:
	timing = false          # freeze the stopwatch the instant the pole is touched
	flag_sliding = true     # flag starts lowering from the top, smoothly, on its own
	# stop the music and play the flagpole sound (fanfare waits for the castle)
	music_off = true
	music_player.stop()
	sfx("flag")

func on_enter_castle() -> void:
	game_state = "clear"
	if not muted:
		fanfare_player.play()   # stage-clear fanfare
	# after each level, run the between-level sequence (full fanfare → hold →
	# black next-level card → load the next level). The last level in the lineup ends —
	# UNLESS it has an explicit ADVANCE_TO_SLOT override (e.g. the 2-2 tail at the last slot
	# still leads onward to 2-3).
	if level_num < LEVEL_COUNT or ADVANCE_TO_SLOT.has(_level_file):
		advancing = true
		# where this level leads: an explicit override (e.g. EXTRA 1 → 1-3) or just the next slot
		_advance_next = int(ADVANCE_TO_SLOT.get(_level_file, level_num + 1))
		advance_timer = 0.0
		advance_phase = 0
		advance_frames = 0
		advance_ct = 0.0







func _update_advance(delta: float) -> void:
	advance_timer += delta
	if advance_phase == 0:
		# wait for the ending audio to finish — the stage-clear fanfare, or (Bowser castle)
		# the mac song (muted → fixed fallback)
		var done := (not fanfare_player.playing) and (not mac_player.playing) and (not am_player.playing) and advance_timer > 0.3
		if muted:
			done = advance_timer >= FANFARE_WAIT
		if done:
			advance_phase = 1
			advance_frames = 0
	elif advance_phase == 1:
		# hold 40 frames after the jingle
		advance_frames += 1
		if advance_frames >= 40:
			advance_phase = 2
			advance_ct = 0.0
			# black card shows the NEXT level's label from the lineup (honouring the override)
			level_card_text = String(LEVEL_ORDER[_advance_next - 1][1])
			show_level_card = true
	elif advance_phase == 2:
		# black next-level card, then load it
		advance_ct += delta
		if advance_ct >= CARD_TIME:
			show_level_card = false
			advancing = false
			level_num = _advance_next    # advance (override-aware; preserves score)
			saved_tier = player.tier()   # carry the power tier into the next level
			_want_12_intro = _file_at(level_num) in [4, 5, 12]   # surface intro when arriving at 1-2
			_want_emerge = _file_at(level_num) in [9, 14]     # pipe emerge when arriving at EXTRA 1
			reset(true)


# =========================================================================
# AXE / BRIDGE-COLLAPSE ENDING (SMB1)
# =========================================================================
func _start_axe_ending() -> void:
	axe_ending = true
	axe_phase = 0
	axe_t = 0.0
	timing = false                       # freeze the stopwatch
	player.velocity = Vector2.ZERO
	# the axe vanishes the instant Mario grabs it
	for c in _axe_cells:
		terrain.erase_cell(c)
	_axe_cells.clear()
	# stop the level music; Bowser stops fighting and just marches in place
	music_off = true
	music_player.stop()
	for fl in bowser_flames:
		fl.queue_free()
	bowser_flames.clear()
	for b in bowsers:
		if not b.dead:
			b.ending = true
	for dk in dks:
		if not dk.dead:
			dk.ending = true              # DK stops throwing, stands until the bridge drops
	sfx("bump")

func _update_axe_ending(delta: float) -> void:
	axe_t += delta
	if axe_phase == 0:
		# erase the bridge planks one-by-one, right → left, with a sound each
		if _bridge_cells.size() > 0:
			if axe_t >= BRIDGE_ERASE_STEP:
				axe_t = 0.0
				var c: Vector2i = _bridge_cells.pop_front()   # rightmost first
				terrain.erase_cell(c)
				sfx("brick")                                  # temp per-plank sound
		else:
			# last plank gone -> the boss drops into the lava
			axe_phase = 1
			axe_t = 0.0
			for b in bowsers:
				if not b.dead:
					b.fall_in()
			for dk in dks:
				if not dk.dead:
					dk.fall_in()
	elif axe_phase == 1:
		# give Bowser a beat to fall, then finish the course
		if axe_t >= 1.1:
			_finish_course()

func _finish_course() -> void:
	axe_ending = false
	if _boss_axe_x >= 0 and _level_file == 8:
		# Bowser's castle (1-4) ONLY: run the rescue cinematic first (walk -> mac speaks), and
		# only THEN show COURSE CLEAR (see _reveal_rescue / _update_rescue).
		game_state = "rescue"
		_reveal_rescue()
	elif _boss_axe_x >= 0 and _level_file == 15:
		# DK stage (2-4): "am" appears just past the axe; Mario walks to him (am on A1), am
		# waits a beat then raises to A2, THEN COURSE CLEAR → 3-1 (see _reveal_am).
		game_state = "rescue"
		_reveal_am()
	else:
		game_state = "clear"             # HUD shows COURSE CLEAR (any other axe ending lands here)
		if not muted:
			fanfare_player.play()        # end-of-level sound
		# unlike Bowser's terminal castle, DK's stage leads onward (2-4 → 3-1): run the
		# same between-level advance sequence a flagpole finish would (see on_enter_castle)
		if level_num < LEVEL_COUNT or ADVANCE_TO_SLOT.has(_level_file):
			advancing = true
			_advance_next = int(ADVANCE_TO_SLOT.get(_level_file, level_num + 1))
			advance_timer = 0.0
			advance_phase = 0
			advance_frames = 0
			advance_ct = 0.0

# mac appears on the castle floor well past the axe, arms raised. Mario is stood where
# the axe was (on top of the castle wall) and walks right toward mac — off the wall, down
# into the throne room, stopping a few tiles short — with the camera tracking HIM the whole
# way (no pan-away). One-time, Bowser's-castle-only reveal.
func _reveal_rescue() -> void:
	if _boss_axe_x < 0:
		return
	show_rescue = true
	rescue_phase = 0
	rescue_t = 0.0
	rescue_speech_t = 0.0
	show_rescue_speech = false
	start_delay = 0.0                                         # never freeze the cinematic
	var mac_tile: int = _boss_axe_x + RESCUE_MAC_OFFSET       # on the open castle floor
	rescue_pos = Vector2(mac_tile * TILE + TILE / 2.0, float(FLOOR * TILE))
	rescue_stop_x = float((mac_tile - RESCUE_STOP_GAP) * TILE + TILE / 2.0)  # Mario's centre
	# stand Mario where the axe was, on the wall-top (row below the axe), facing mac
	player.velocity = Vector2.ZERO
	player.global_position = Vector2(_boss_axe_x * TILE + TILE / 2.0,
		float((_boss_axe_y + 1) * TILE) - player.col_size.y / 2.0 - 1.0)
	player.facing = 1
	rescue_walking = true

# DK stage (2-4) ending: "am" stands a short way past the axe, on a throne-room walkway that
# we inject at the surface row (the axe row + 1). Mario is placed just past the axe and walks
# right to am. am shows A1 until Mario arrives + a beat, then raises to A2 (see _update_rescue).
func _reveal_am() -> void:
	if _boss_axe_x < 0:
		return
	show_rescue = true
	_rescue_is_am = true
	_am_a2 = false
	rescue_phase = 0
	rescue_t = 0.0
	rescue_speech_t = 0.0
	show_rescue_speech = false
	start_delay = 0.0
	# Mario grabs the axe on the wall-top (row axe_y+1); past it the level DROPS to a lower
	# corridor floor where Amazon waits. Walk him right off the wall — gravity carries him down
	# into the corridor (see _update_rescue_walk) — then on to Amazon. (No injected geometry;
	# the level itself has the wall → corridor drop.)
	var top_row: int = _boss_axe_y + 1
	# scan right for the BACK WALL: the first column past the axe that is solid at the wall-top
	# row again (the corridor columns are open there). Amazon stands a few tiles before it.
	var wall_end: int = _boss_axe_x + 6
	var sx: int = _boss_axe_x + 2
	while sx < _boss_axe_x + 80:
		if terrain.get_cell_source_id(Vector2i(sx, top_row)) >= 0:
			wall_end = sx
			break
		sx += 1
	var am_col: int = maxi(wall_end - 3, _boss_axe_x + 5)
	# the corridor floor Amazon stands on = first solid tile below the open gap at her column
	var floor_row: int = FLOOR
	var fy: int = top_row + 1
	while fy < 20:
		if terrain.get_cell_source_id(Vector2i(am_col, fy)) >= 0:
			floor_row = fy
			break
		fy += 1
	rescue_pos = Vector2(am_col * TILE + TILE / 2.0, float(floor_row * TILE))
	rescue_stop_x = float((am_col - AM_STOP_GAP) * TILE + TILE / 2.0)  # Mario's centre
	# stand Mario on the wall-top where the axe was, facing right (he walks off it and drops)
	player.velocity = Vector2.ZERO
	player.global_position = Vector2(float((_boss_axe_x + 1) * TILE) + TILE / 2.0,
		float(top_row * TILE) - player.col_size.y / 2.0 - 1.0)
	player.facing = 1
	rescue_walking = true

func _update_rescue(delta: float) -> void:
	rescue_t += delta                    # mac keeps pumping his arms throughout
	if rescue_phase == 0:
		if rescue_walking:
			# keep the camera on Mario as he walks the length of the throne room to mac
			var target: float = clampf(player.global_position.x - VIEW_W * 0.42,
				0.0, float(LW * TILE - VIEW_W))
			cam_x = move_toward(cam_x, target, RESCUE_CAM_FOLLOW * delta)
			camera.position = Vector2(roundf(cam_x) + VIEW_W / 2.0, VIEW_H / 2.0)
		else:
			# Mario has arrived — begin the beat (mac speaks; am just waits on A1)
			rescue_phase = 1
			rescue_speech_t = 0.0
			if not _rescue_is_am:
				show_rescue_speech = true      # mac speaks on arrival; Amazon waits until his arms go up
				if not muted:
					mac_player.play()      # the "mac" song plays on arrival (not the fanfare)
	elif rescue_phase == 1:
		rescue_speech_t += delta
		var beat: float = AM_WAIT if _rescue_is_am else RESCUE_SPEECH_TIME
		if rescue_speech_t >= beat:
			if _rescue_is_am:
				# Amazon RAISES his hands (A2) — now show "A WINNER IS YOU!". Still "rescue",
				# so COURSE CLEAR's border does NOT cover him yet (that waits AM_RAISE_HOLD).
				_am_a2 = true
				show_rescue_speech = true
				if not muted and am_player.stream != null:
					am_player.play()       # amam.wav on the arm-raise (instead of the fanfare)
				rescue_phase = 2
				rescue_speech_t = 0.0
			else:
				# mac: line read, show COURSE CLEAR and advance to 2-1 (play-slot 7). No fanfare
				# for the Bowser-castle ending; the mac song is the only ending music.
				rescue_phase = 2
				show_rescue_speech = false
				game_state = "clear"
				advancing = true
				_advance_next = 7
				advance_timer = 0.0
				advance_phase = 0
				advance_frames = 0
				advance_ct = 0.0
	elif rescue_phase == 2 and _rescue_is_am:
		# Amazon holds the raised A2 pose so it is fully visible, THEN COURSE CLEAR comes out
		rescue_speech_t += delta
		if rescue_speech_t >= AM_RAISE_HOLD:
			rescue_phase = 3
			show_rescue_speech = false
			game_state = "clear"
			# no fanfare — amam.wav (played when his arms went up) is the ending sound
			advancing = true
			_advance_next = int(ADVANCE_TO_SLOT.get(_level_file, level_num + 1))
			advance_timer = 0.0
			advance_phase = 0
			advance_frames = 0
			advance_ct = 0.0
	bg_renderer.queue_redraw()
	fg_renderer.queue_redraw()

func _file_at(pos: int) -> int:
	return int(LEVEL_ORDER[clampi(pos, 1, LEVEL_COUNT) - 1][0])




func _maybe_start_intro12() -> void:
	if not(_level_file in [4, 5, 12] and _want_12_intro):
		return
	_want_12_intro = false
	intro_12 = true
	_intro_moonwalk = (_level_file == 12)   # 2-2 (Level12): Mario moonwalks (backs) into the pipe
	_intro_32 = (_level_file == 5)          # 3-2 (Level5): its own cloned 1-2-style intro
	_intro_sonic = false
	_intro_sonic_landed = false
	_intro_oneup = null
	_intro_oneup_started = false
	_intro_tap_t = 0.0
	intro_phase = 0
	intro_t = 0.0
	game_state = "intro"
	underground = false
	RenderingServer.set_default_clear_color(SKY_COLOR)
	if level and is_instance_valid(level):
		level.visible = false
	for e in enemies:
		if is_instance_valid(e):
			e.visible = false
	cam_x = 0.0
	camera.position = Vector2(VIEW_W / 2.0, VIEW_H / 2.0)
	fade_alpha = 0.0
	start_delay = 0.0
	timing = false
	player.spawn(Vector2(INTRO_START_X, float(FLOOR * TILE)))
	player.modulate.a = 1.0



	player.z_index = -6

	var want_music: AudioStream = intro_music if (_intro_moonwalk and intro_music != null) else overworld_music
	if music_player.stream != want_music:
		music_player.stream = want_music
	if not muted and not music_off:
		music_player.play()

func _update_intro12(delta: float) -> void:
	intro_t += delta

	player.facing = -1 if _intro_moonwalk else 1   # moonwalk = face away while moving right into the pipe
	player.grounded = true
	player.global_position.y = float(FLOOR * TILE) - player.col_size.y / 2.0
	if intro_phase == 0:

		player.global_position.x += INTRO_WALK_SPD * delta
		player.velocity.x = INTRO_WALK_SPD
		player.walk_anim += delta * 8.0
		player._animate()
		if player.global_position.x >= INTRO_WALK_TO:
			intro_phase = 1
			sfx("powerdown")
	elif intro_phase == 1:


		player.global_position.x += INTRO_WALK_SPD * delta
		player.velocity.x = INTRO_WALK_SPD
		player.walk_anim += delta * 8.0
		player._animate()
		if player.global_position.x >= INTRO_ENTER_TO:
			player.visible = false
			intro_t = 0.0
			if _intro_32:
				# 3-2: Sonic jumps in from the right onto the pipe before the level drops in
				intro_phase = 3
				_intro_sonic = false
				_intro_sonic_landed = false
				if not muted:
					sega_player.play()      # SEGA entry as Sonic leaps in
			else:
				intro_phase = 2
	elif intro_phase == 3:
		# 3-2 ONLY: Sonic leaps in from off-screen right, lands on top of the pipe, foot-taps
		_intro_sonic = true
		sonic_face = "l"
		var land_x: float = INTRO_PIPE_X + 42.0     # middle of the pipe, nudged a little to the right
		var top_off := -64.0                        # pipe top = floor - 64px (endpipe is 64 tall)
		sonic_frame_t += delta
		if not _intro_sonic_landed:
			var u: float = clampf(intro_t / 0.7, 0.0, 1.0)
			sonic_state = "jump"
			sonic_x = lerp(float(VIEW_W) + 24.0, land_x, u)
			sonic_jump_off = lerp(0.0, top_off, u) - 40.0 * sin(PI * u)   # arc up, land on the pipe
			_sonic_compute_frame()
			if u >= 1.0:
				_intro_sonic_landed = true
				sonic_x = land_x
				sonic_jump_off = top_off
				intro_t = 0.0
				sonic_state_t = 0.0         # land on a neutral stand (no tapping / no sound yet)
		else:
			sonic_state = "wait"; sonic_x = land_x; sonic_jump_off = top_off
			if not _intro_oneup_started:
				# hold a neutral stand until the SEGA sound finishes, THEN play the 1-up jingle
				# (so the two never overlap)
				sonic_state_t = 0.0
				if not sega_player.playing:
					_intro_oneup = sfx("one_up")
					_intro_oneup_started = true
			elif _intro_oneup != null and is_instance_valid(_intro_oneup) and _intro_oneup.playing:
				# 1-up jingle still playing — keep standing, don't start tapping over it
				sonic_state_t = 0.0
			else:
				# 1-up has finished — NOW Sonic foot-taps
				sonic_state_t = IDLE_STAND_TIME + 2.0 * IDLE_LEAD + _intro_tap_t
				_intro_tap_t += delta
			_sonic_compute_frame()          # neutral stand, then foot-tap idle
			if _intro_tap_t >= INTRO_SONIC_TAP_TIME:
				intro_phase = 2
				intro_t = 0.0
	elif intro_phase == 2:

		fade_alpha = clampf((intro_t - 0.3) / 0.5, 0.0, 1.0)
		if intro_t >= 0.9:
			_begin_underground()
	bg_renderer.queue_redraw()
	fg_renderer.queue_redraw()

func _begin_underground() -> void:
	intro_12 = false
	_intro_sonic = false
	game_state = "play"
	underground = true
	RenderingServer.set_default_clear_color(Color.BLACK)
	if level and is_instance_valid(level):
		level.visible = true
	for e in enemies:
		if is_instance_valid(e):
			e.visible = true
	player.visible = true
	player.modulate.a = 1.0
	player.spawn(_player_start)
	cam_x = 0.0
	_update_camera()
	timing = true
	elapsed = 0.0
	start_delay = START_DELAY
	fade_alpha = 1.0
	_apply_level_music()
	_play_music(true)






# 3-4 boss arena: arm the walk-in cutscene (Mario starts at the left edge, frozen).
# Detect the user's markers — ? blocks (atlas 2) = where the wall lands, pipe tiles
# (atlas 8-11) = where a gordo drops — and clear them so the way in is open.
func _maybe_start_arena_intro() -> void:
	if _level_file != 17:
		return
	game_state = "arena_intro"
	_arena_phase = 0
	_arena_sealed = false
	_cam_shake = 0.0
	_clear_seal_blocks()
	_arena_sonic = true          # Sonic is already IN the arena, standing; he'll walk over after the wall drops
	_arena_fellback = false
	_arena_broken.clear()
	_arena_t = 0.0
	_boss_active = false
	_boss_dead = false
	_boss_hits = 0
	_arena_wall_cells.clear()
	_arena_gordo_cells.clear()
	var minc := 1 << 30
	var maxc := -(1 << 30)
	if terrain:
		for cell in terrain.get_used_cells():
			var a: int = terrain.get_cell_atlas_coords(cell).x
			if a == ATLAS_QUESTION:                       # the wall markers (invisible placeholders)
				_arena_wall_cells.append(cell)
				terrain.set_cell(cell)                    # open it up
				qblock_cells.erase(cell)                  # and stop the pulsing ? overlay from drawing it
				minc = mini(minc, cell.x); maxc = maxi(maxc, cell.x)
			elif a >= 8 and a <= 11:                      # pipe = gordo-drop marker
				_arena_gordo_cells.append(cell)
				terrain.set_cell(cell)
				minc = mini(minc, cell.x); maxc = maxi(maxc, cell.x)
	# Mario stops (and the wall drops behind him) just past the sealed doorway — keyed off the
	# wall itself so it stays tight no matter how the arena platforms are edited.
	_arena_stop_x = float((maxc + 3) * TILE) if maxc > -(1 << 30) else 35.0 * TILE
	_arena_trap_x = _arena_stop_x
	# Sonic crashes in through the right wall, one row above the RIGHT gordo (rightmost/lowest one)
	var rg := Vector2(-1e9, -1e9)
	for g in gords:
		var p: Vector2 = g.global_position
		if p.x > rg.x + 0.5 or (absf(p.x - rg.x) < 8.0 and p.y > rg.y):
			rg = p
	_arena_crash_row = (int(rg.y / TILE) - 2) if rg.x > -1e8 else 10
	_arena_sonic_stop_x = _arena_stop_x + ARENA_FACEOFF_GAP    # initial standoff (recomputed after Mario's walk-right)
	# he must START past the RIGHT wall so he actually smashes through it — scan the wall's right edge
	_arena_crash_break_from = int(rg.x / TILE) if rg.x > -1e8 else 47   # the right wall's left edge (right gordo col)
	var wcol := _arena_crash_break_from
	while wcol < LW - 1 and _boss_solid(wcol + 1, _arena_crash_row):
		wcol += 1
	_arena_crash_start_x = float((wcol + 3) * TILE)
	# the screen locks CENTRED between Mario and Sonic (nudged 2 tiles right so more of the arena shows)
	_arena_cam_lock_x = clampf((_arena_stop_x + _arena_sonic_stop_x) / 2.0 - VIEW_W / 2.0 + 2.0 * TILE, 0.0, float(LW * TILE - VIEW_W))
	start_delay = 0.0            # no "get ready" freeze — the cutscene drives him straight in
	fade_alpha = 0.0            # lift the black fade-in (the cutscene returns before the normal fade update)
	player.facing = 1
	player.grounded = true
	# Sonic is already standing in the arena (a few tiles right of the standoff); he walks over later
	sonic_x = _arena_sonic_stop_x + 9.0 * TILE
	sonic_jump_off = 0.0
	sonic_state = "wait"; sonic_face = "l"; sonic_state_t = 0.0

# the cutscene: walk right -> lock the screen -> drop the wall -> hand back control
func _update_arena_intro(delta: float) -> void:
	if _arena_phase == 0:
		# march Mario right across the floor, walk animation playing
		player.global_position.x += ARENA_WALK_SPD * delta
		player.velocity.x = ARENA_WALK_SPD
		player.facing = 1
		player.walk_anim += delta * 8.0
		player._animate()
		if player.global_position.x >= _arena_trap_x:
			_arena_phase = 1
	elif _arena_phase == 1:
		# he's at his mark: the wall (and a gordo) crash down behind him
		player.velocity.x = 0.0
		player._animate()
		_drop_arena_wall()
		_arena_phase = 2
	elif _arena_phase == 2:
		# wait for the wall to slam home, THEN hold a 1-second beat before Mario reacts
		_update_arena_seal(delta)
		if _seal_blocks.is_empty():
			_arena_t += delta
			if _arena_t >= 1.0:
				_arena_phase = 3; _arena_t = 0.0
		else:
			_arena_t = 0.0
	elif _arena_phase == 3:
		# TRAPPED: Mario looks LEFT at the sealed wall for one second
		player.facing = -1
		player.velocity.x = 0.0
		player._animate()
		_arena_t += delta
		if _arena_t >= 1.0:
			_arena_phase = 4; _arena_t = 0.0
	elif _arena_phase == 4:
		# then he turns to face RIGHT and WALKS right for 2 seconds (into the arena)
		player.facing = 1
		player.grounded = true
		player.velocity.x = 55.0                  # needed so _animate() plays the WALK cycle (not a glide)
		player.global_position.x += 55.0 * delta
		player.walk_anim += delta * 8.0
		player._animate()
		_arena_t += delta
		if _arena_t >= 2.0:
			# Sonic will square off a gap to Mario's right, camera re-centred on the pair
			_arena_sonic_stop_x = player.global_position.x + ARENA_FACEOFF_GAP
			_arena_cam_lock_x = clampf((player.global_position.x + _arena_sonic_stop_x) / 2.0 - VIEW_W / 2.0 + 2.0 * TILE, 0.0, float(LW * TILE - VIEW_W))
			_arena_phase = 5; _arena_t = 0.0
	elif _arena_phase == 5:
		# SONIC WALKS OVER: he's already in the arena, so he just strolls up to Mario (no crash)
		player.facing = 1                       # Mario faces him, standing neutral (not mid-stride)
		player.velocity.x = 0.0
		player.walk_anim = 0.0
		player._animate()
		sonic_jump_off = 0.0
		sonic_x = move_toward(sonic_x, _arena_sonic_stop_x, BOSS_WALK_SPD * delta)
		sonic_face = "l"
		sonic_state = "walk"; sonic_frame_t += delta
		_sonic_compute_frame()
		if is_equal_approx(sonic_x, _arena_sonic_stop_x):
			_arena_phase = 7; _arena_t = 0.0
	else:
		# FACE TO FACE: Sonic stands still and taunts Mario; after a beat, the fight begins
		sonic_state = "wait"; sonic_face = "l"; sonic_x = _arena_sonic_stop_x; sonic_jump_off = 0.0
		sonic_state_t = 0.0                    # pin the neutral stand frame (no idle foot-tap)
		player.facing = 1
		player.velocity.x = 0.0; player.walk_anim = 0.0; player._animate()   # Mario stands neutral, facing Sonic
		sonic_speech = true
		sonic_speech_lines = SONIC_BOSS_SPEECH
		_sonic_compute_frame()
		_arena_t += delta
		if _arena_t >= 2.8:
			_start_boss()
	# --- intro camera: track Mario 1:1 the WHOLE cutscene, so the screen only moves as he moves
	# (no separate standoff pan / shift). Stays put while he's still.
	cam_x = clampf(player.global_position.x - VIEW_W / 2.0, 0.0, float(LW * TILE - VIEW_W))

# drop the purple-block wall onto the ? cells, plus a gordo onto each pipe cell
func _drop_arena_wall() -> void:
	_arena_sealed = true
	sfx("bump")
	_drop_blocks(_arena_wall_cells)
	# a gordo drops in at each pipe marker
	for cell in _arena_gordo_cells:
		var target_yc := float(cell.y * TILE + TILE / 2.0)  # gord is centre-anchored
		var g = Gord.new()
		g.main = self
		add_child(g)
		g.spawn(Vector2(float(cell.x * TILE + TILE / 2.0), target_yc - SEAL_DROP))
		gords.append(g)
		_seal_blocks.append({"kind": "gord", "node": g, "vy": 0.0, "target_y": target_yc, "cell": cell})

# spawn a falling purple block onto every given empty cell (used for the wall + the fall-back)
func _drop_blocks(cells: Array) -> void:
	var src := terrain.tile_set.get_source(SOURCE_ID) as TileSetAtlasSource
	var tex: Texture2D = src.texture if src else null
	for cell in cells:
		if terrain.get_cell_source_id(cell) != -1:
			continue                                       # already solid (skip)
		var target_y := float(cell.y * TILE)
		var spr := Sprite2D.new()
		if tex:
			spr.texture = tex
			spr.region_enabled = true
			spr.region_rect = Rect2(ATLAS_ARENA_WALL * TILE, 0, TILE, TILE)
		spr.centered = false
		spr.position = Vector2(float(cell.x * TILE), target_y - SEAL_DROP - cell.x * 4.0)  # start high, staggered
		spr.z_index = 2
		add_child(spr)
		_seal_blocks.append({"kind": "block", "node": spr, "vy": 0.0, "target_y": target_y, "cell": cell})

# Sonic smashing through the right wall: erase the solid cells at his crash rows as he passes.
# Only breaks the RIGHT WALL (cols >= the right gordo) — leaves the arena's mid platforms intact.
func _arena_break_walls() -> void:
	var col := int(floor(sonic_x / TILE))
	if col < _arena_crash_break_from:
		return
	var broke := false
	for c in [col, col + 1]:
		if c < _arena_crash_break_from:
			continue
		for r in [_arena_crash_row, _arena_crash_row - 1]:   # a 2-tall tunnel
			var cell := Vector2i(c, r)
			if terrain.get_cell_source_id(cell) != -1 and not _arena_broken.has(cell):
				terrain.erase_cell(cell)
				_spawn_debris(c, r, true)                    # purple shards fly as he smashes through
				_arena_broken.append(cell)
				broke = true
	if broke:
		sfx("brick")

# ---- THE SONIC BOSS FIGHT ----
func _start_boss() -> void:
	game_state = "play"          # Mario is controllable now
	sonic_speech = false
	_boss_active = true
	_boss_dead = false
	_boss_phase = "rev"
	_boss_t = 0.0
	_boss_hits = 0
	# dash limits = the arena walls, taken from where the gordos sit (± a bit)
	_boss_lo = 1e9; _boss_hi = -1e9
	for g in gords:
		_boss_lo = minf(_boss_lo, g.global_position.x)
		_boss_hi = maxf(_boss_hi, g.global_position.x)
	# camera bounds: the view stops ONE TILE left of the left gordos and one tile right of the right
	_boss_cam_lo = (floor(_boss_lo / TILE) - 1.0) * TILE
	_boss_cam_hi = (floor(_boss_hi / TILE) + 2.0) * TILE - float(VIEW_W)
	if _boss_cam_hi < _boss_cam_lo:
		_boss_cam_hi = _boss_cam_lo                       # tiny arena fallback
	_boss_lo += 6.0        # dash limits: stop just short of the gordo so the smash reads at the wall
	_boss_hi -= 6.0
	_boss_feet_y = float(FLOOR * TILE)
	_boss_vy = 0.0
	_boss_grounded = true
	_boss_build_platforms()
	_boss_step = null
	sonic_state = "wait"; sonic_jump_off = 0.0

# true if no live gordo sits BETWEEN Sonic and Mario at Sonic's level — so a dash won't
# smack a gordo before reaching Mario (Sonic only self-hits a gordo the player baited BEYOND Mario)
func _boss_path_clear_to_mario() -> bool:
	var lo: float = minf(sonic_x, player.global_position.x)
	var hi: float = maxf(sonic_x, player.global_position.x)
	for g in gords:
		if g.dead:
			continue
		var gx: float = g.global_position.x
		if gx > lo + 4.0 and gx < hi - 4.0 and absf(g.global_position.y - _boss_feet_y) < 1.5 * TILE:
			return false
	return true

# true if the column above Sonic is open for `height` tiles — so a hop here rises (up a gap /
# beside a step) instead of bonking a platform underside right away
func _boss_clear_above(col: int, feet_row: int, height: int) -> bool:
	for r in range(feet_row - 1, feet_row - 1 - height, -1):
		if _boss_solid(col, r):
			return false
	return true

# is this tile solid ground Sonic can stand on?
func _boss_solid(col: int, row: int) -> bool:
	if row < 0 or row > 14 or terrain == null:
		return false
	if terrain.get_cell_source_id(Vector2i(col, row)) < 0:
		return false
	var ax: int = terrain.get_cell_atlas_coords(Vector2i(col, row)).x
	return ax != ATLAS_LAVA_TOP and ax != ATLAS_LAVA

# Scan the arena for every standable surface (a solid tile with open space above it) ABOVE the
# floor — the stepping stones/ledges Sonic ladders up. Auto-derives from geometry so it survives
# the user's edits. Stored as horizontal runs {row, c0, c1}.
func _boss_build_platforms() -> void:
	_boss_platforms.clear()
	if terrain == null:
		return
	var c_lo: int = int(floor(_boss_cam_lo / TILE)) - 2
	var c_hi: int = int(floor((_boss_cam_hi + float(VIEW_W)) / TILE)) + 2
	for row in range(1, FLOOR):                        # above the floor only (FLOOR is Sonic's base)
		var run_start: int = -9999
		for col in range(c_lo, c_hi + 1):
			var standable: bool = _boss_solid(col, row) and not _boss_solid(col, row - 1)
			if standable and run_start == -9999:
				run_start = col
			elif not standable and run_start != -9999:
				_boss_platforms.append({"row": row, "c0": run_start, "c1": col - 1})
				run_start = -9999
		if run_start != -9999:
			_boss_platforms.append({"row": row, "c0": run_start, "c1": c_hi})

# Pick the next rung Sonic should hop to in order to climb toward Mario, or null if none.
# Chooses the HIGHEST rung reachable in one hop from Sonic's current surface (rise <= BOSS_CLIMB_RISE)
# that doesn't overshoot Mario's level, tie-broken toward MARIO's x so he climbs the correct side.
func _boss_pick_step():
	var cur_row: int = int(round(_boss_feet_y / TILE))
	var mario_row: int = int(round(player.global_position.y / TILE))
	var best = null
	var best_key := Vector2(1e9, 1e9)
	for p in _boss_platforms:
		var prow: int = p.row
		if prow >= cur_row:
			continue                                   # not higher than Sonic
		if cur_row - prow > BOSS_CLIMB_RISE:
			continue                                   # too tall for one hop
		if prow < mario_row - 1:
			continue                                   # don't climb PAST Mario
		# distance from this rung's column span to Mario's x (0 if Mario is over it)
		var px0: float = p.c0 * TILE
		var px1: float = (p.c1 + 1) * TILE
		var mdist: float = 0.0
		var mx: float = player.global_position.x
		if mx < px0: mdist = px0 - mx
		elif mx > px1: mdist = mx - px1
		var key := Vector2(float(prow), mdist)         # highest rung first, then nearest Mario's side
		if key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y):
			best_key = key
			best = p
	return best

# The raised platform Sonic is currently standing on (feet on row `feet_row`), or null on the floor.
func _boss_current_platform(feet_row: int):
	for p in _boss_platforms:
		if p.row == feet_row and sonic_x >= float(p.c0 * TILE) and sonic_x < float((p.c1 + 1) * TILE):
			return p
	return null

# Which way to step off `plat` to drop a level: toward an edge that has AIR beside it (a real
# drop, not a wall) and is inside his movement range. Prefers Mario's side, else the nearer edge.
func _boss_pick_descend_dir(plat, feet_row: int, dx: float) -> int:
	var left_col: int = plat.c0 - 1
	var right_col: int = plat.c1 + 1
	var left_ok: bool = not _boss_solid(left_col, feet_row) and float(plat.c0 * TILE) >= _boss_lo
	var right_ok: bool = not _boss_solid(right_col, feet_row) and float(right_col * TILE) <= _boss_hi
	if left_ok and right_ok:
		if dx > 8.0: return 1
		if dx < -8.0: return -1
		return -1 if (sonic_x - float(plat.c0 * TILE)) <= (float((plat.c1 + 1) * TILE) - sonic_x) else 1
	if right_ok: return 1
	if left_ok: return -1
	return 0

func _update_boss(delta: float) -> void:
	if not _boss_active:
		return
	if _boss_dead:
		_update_boss_death(delta)
		return
	# --- Sonic's platforming physics (gravity + land on top of floor/platforms) ---
	# ...he's locked to his level only while mid spin-dash
	if _boss_phase != "dash":
		_boss_vy = minf(_boss_vy + BOSS_GRAV * delta, 640.0)
		_boss_feet_y += _boss_vy * delta
		_boss_grounded = false
		if _boss_feet_y - 30.0 < 0.0:                       # HARD CEILING — never leaves the arena
			_boss_feet_y = 30.0
			_boss_vy = maxf(_boss_vy, 0.0)
		var fcol := int(floor(sonic_x / TILE))
		# rising: BONK only on THICK structures (walls — solid tile with another solid tile above it).
		# Pass up through THIN 1-tile platforms (a solid tile with open space above), landing on top —
		# that's how he "jumps onto" the step platforms; he still can't phase through the solid walls.
		if _boss_vy < 0.0:
			var head_row := int(floor((_boss_feet_y - 26.0) / TILE))
			if _boss_solid(fcol, head_row) and _boss_solid(fcol, head_row - 1):
				_boss_feet_y = float((head_row + 1) * TILE) + 26.0
				_boss_vy = 0.0
		var frow := int(floor(_boss_feet_y / TILE))
		if _boss_vy >= 0.0 and _boss_solid(fcol, frow):     # land on top while descending
			_boss_feet_y = float(frow * TILE)
			_boss_vy = 0.0; _boss_grounded = true
		if _boss_feet_y >= float(FLOOR * TILE):             # never below the ground floor
			_boss_feet_y = float(FLOOR * TILE); _boss_vy = 0.0; _boss_grounded = true
	sonic_jump_off = _boss_feet_y - float(FLOOR * TILE)
	# Sonic's BODY is dangerous to touch (except while he reels from a gordo or is dying)
	if _boss_phase == "pursue" or _boss_phase == "rev":
		var body := Rect2(sonic_x - 9.0, _boss_feet_y - 28.0, 18.0, 28.0)
		if not player.dead and body.intersects(player.get_rect()):
			player.hurt()

	if _boss_phase == "pursue":
		# STALK Mario: match his level, close in, and only strike when it's a clean line
		_boss_t += delta
		var dx: float = player.global_position.x - sonic_x
		var far: bool = absf(dx) > 8.0 * TILE
		var mario_above: bool = player.grounded and player.global_position.y < _boss_feet_y - 2.0 * TILE
		var mario_below: bool = player.global_position.y > _boss_feet_y + 2.0 * TILE
		# CLIMB toward a higher Mario via the stepping stones: head for the next rung up (even if it's
		# off to the side — go to the stairs first), hop onto it, then re-evaluate from the higher shelf.
		# The target is LOCKED for the whole arc (only re-evaluated when grounded) so he commits to landing
		# on the intermediate stone. Note mario_above flickers false at the top of a hop (it compares
		# Mario's centre to Sonic's feet) — recomputing airborne would abort the climb, so we DON'T.
		if _boss_grounded:
			_boss_step = _boss_pick_step() if mario_above else null
		var step = _boss_step
		if step != null:
			var tx0: float = step.c0 * TILE
			var tx1: float = (step.c1 + 1) * TILE
			var aim: float = clampf(sonic_x, tx0, tx1)          # near edge, for the launch-window check
			var center: float = (tx0 + tx1) * 0.5               # steer for the middle so he lands ON the rung
			var gap: float = aim - sonic_x
			_boss_vx = 0.0
			if absf(center - sonic_x) > 2.0:
				_boss_vx = (BOSS_WALK_SPD if center > sonic_x else -BOSS_WALK_SPD)
			# hop when grounded and close enough that the arc lands on the rung (air-steer keeps aiming at it)
			if _boss_grounded and absf(gap) <= BOSS_LAUNCH_WINDOW:
				_boss_vy = BOSS_JUMP_V
		else:
			# no climb needed: chase Mario's x — unless Mario is a level (or more) BELOW and Sonic
			# is stuck up on a ledge, in which case DESCEND: step off a ledge edge that has air beside
			# it, and KEEP pushing that way (even mid-fall) until he lands a level lower, so the
			# airborne "chase Mario" drift can't yank him back onto the ledge. Repeats rung by rung.
			var feet_row: int = int(round(_boss_feet_y / TILE))
			if _boss_descend_dir != 0 and not (_boss_grounded and feet_row > _boss_descend_from_row):
				_boss_vx = float(_boss_descend_dir) * BOSS_WALK_SPD   # committed to the step-off, still dropping
			else:
				_boss_descend_dir = 0                            # landed lower (or not descending) — re-evaluate
				var plat = _boss_current_platform(feet_row) if (mario_below and _boss_grounded and feet_row < FLOOR) else null
				if plat != null:
					_boss_descend_dir = _boss_pick_descend_dir(plat, feet_row, dx)
					_boss_descend_from_row = feet_row
				if _boss_descend_dir != 0:
					_boss_vx = float(_boss_descend_dir) * BOSS_WALK_SPD
				else:
					_boss_vx = (1.0 if dx > 0.0 else -1.0) * (BOSS_RUN_SPD if far else BOSS_WALK_SPD)
		sonic_x = clampf(sonic_x + _boss_vx * delta, _boss_lo, _boss_hi)
		if absf(_boss_vx) > 1.0:
			sonic_face = "l" if _boss_vx < 0.0 else "r"
		sonic_frame_t += delta
		sonic_state = "jump" if not _boss_grounded else ("run" if far else "walk")
		_sonic_compute_frame()
		# strike ONLY with a clean shot: same level, in range, AND no gordo between us (no self-destruct).
		# Never dash mid-climb (step != null) — finish the ascent first.
		var lined_up: bool = _boss_grounded and step == null and absf(dx) <= BOSS_DASH_RANGE and absf(player.global_position.y - _boss_feet_y) < 1.5 * TILE
		if lined_up and _boss_path_clear_to_mario():
			_boss_phase = "rev"; _boss_t = 0.0
			_boss_dash_dir = -1 if dx < 0.0 else 1
			sfx("sonic_spin")                              # the tell — fires as he sets up
	elif _boss_phase == "rev":
		# plant and rev (the telegraph) before launching along his current level.
		# Keep re-aiming at Mario each frame so if he jukes to Sonic's other side during
		# the rev, the tell turns to follow and the dash never fires AWAY from him.
		_boss_t += delta
		var rev_dx: float = player.global_position.x - sonic_x
		if absf(rev_dx) > 1.0:
			_boss_dash_dir = -1 if rev_dx < 0.0 else 1
		sonic_face = "l" if _boss_dash_dir < 0 else "r"
		sonic_state = "spin"; sonic_frame_t += delta
		_sonic_compute_frame()
		if _boss_t >= BOSS_REV_TIME:
			_boss_phase = "dash"
			_boss_dash_from = sonic_x                       # remember the launch point so we can cap the roll
	elif _boss_phase == "dash":
		# spin-dash straight along his level; Mario must move/jump clear or eat it
		sonic_x += float(_boss_dash_dir) * BOSS_DASH_SPD * delta
		sonic_state = "ball"; sonic_frame_t += delta
		_sonic_compute_frame()
		var ball := _boss_ball_rect()
		if not player.dead and ball.intersects(player.get_rect()):
			player.hurt()                                  # caught -> hurt, dash spent (no gordo)
			_boss_end_dash(false)                          # just stop where he is (no reel-back)
		elif _boss_check_gordo_hit(ball):                  # smashed the gordo he actually touches
			_boss_end_dash(true)                           # self-hit on the spikes -> reel back
		elif absf(sonic_x - _boss_dash_from) >= BOSS_DASH_MAX:  # travelled the cap -> stop short (bait him closer)
			sonic_x = clampf(_boss_dash_from + float(_boss_dash_dir) * BOSS_DASH_MAX, _boss_lo, _boss_hi)
			_boss_end_dash(false)                          # just stop, then resume the chase
		elif (_boss_dash_dir < 0 and sonic_x <= _boss_lo) or (_boss_dash_dir > 0 and sonic_x >= _boss_hi):
			sonic_x = clampf(sonic_x, _boss_lo, _boss_hi)
			_boss_end_dash(false)                          # ran into the wall -> just stop
	elif _boss_phase == "recoil":
		# reel back from the spiky gordo (Z1/Z2), then resume the chase (gravity drops him off a ledge)
		_boss_t += delta
		sonic_state = "hit"; sonic_face = "l" if _boss_dash_dir < 0 else "r"
		_sonic_compute_frame()
		sonic_x = clampf(sonic_x - float(_boss_dash_dir) * BOSS_RECOIL_SPD * delta, _boss_lo, _boss_hi)
		if _boss_t >= BOSS_RECOIL_TIME:
			if _boss_hits >= 4:
				_start_boss_death()
			else:
				_boss_phase = "pursue"; _boss_t = 0.0

# Sonic's spin-ball hitbox at his current height
func _boss_ball_rect() -> Rect2:
	var cy := float(FLOOR * TILE) + sonic_jump_off
	return Rect2(sonic_x - 11.0, cy - 22.0, 22.0, 22.0)

# destroy the gordo the ball actually overlaps (the one he HITS); return true if one was hit
func _boss_check_gordo_hit(ball: Rect2) -> bool:
	for g in gords:
		if g.dead:
			continue
		if ball.intersects(g.get_rect()):
			var gc := Vector2i(int(g.global_position.x / TILE), int(g.global_position.y / TILE))
			g.dead = true
			g.queue_free()
			gords.erase(g)
			_boss_hits += 1
			_spawn_debris(gc.x, gc.y, true)    # the gordo bursts
			sfx("gord")                        # Sonic smacking the gordo
			return true
	return false

func _boss_end_dash(recoil: bool = true) -> void:
	# recoil = true only when he smashed a gordo (reel back from the spikes); otherwise he just
	# stops where he is and goes straight back to stalking Mario (no backward slide).
	_boss_phase = "recoil" if recoil else "pursue"
	_boss_t = 0.0

func _start_boss_death() -> void:
	_boss_dead = true
	_boss_t = 0.0
	sonic_state = "death"
	sonic_speech = false
	timing = false                # 3-4: freeze the clock the moment Sonic is beaten
	if save_slot >= 0 and save_slot < 3:
		save_beat[save_slot] = true   # game cleared → unlock LEVEL SELECT for this file
		save_saves()
	# victory! stop the boss music and play the victory song (not the normal fanfare)
	music_off = true
	music_player.stop()
	if not muted:
		victory_player.play()

func _update_boss_death(delta: float) -> void:
	_boss_t += delta
	sonic_state = "death"
	_sonic_compute_frame()
	# classic Sonic death: pop up, then drop off the bottom
	if _boss_t < 0.5:
		sonic_jump_off -= 150.0 * delta
	else:
		sonic_jump_off += 260.0 * delta
	if _boss_t >= BOSS_DEATH_TIME:
		_arena_sonic = false                # Sonic's death arc is done — he's gone from view
		# hold here until the full victory jingle has finished, THEN reveal COURSE CLEAR
		if muted or victory_player == null or not victory_player.playing:
			_boss_active = false
			if game_state != "clear":
				game_state = "clear"        # COURSE CLEAR — the final boss is beaten
				_boss_finale = true         # …and this clear rolls the end credits
				_finale_t = 0.0

# 3-4 finale: hold COURSE CLEAR a beat, fade the screen to black, then start the credits roll.
func _update_finale(delta: float) -> void:
	_finale_t += delta
	if _finale_t <= FINALE_HOLD:
		return                                    # let COURSE CLEAR sit for a moment
	fade_alpha = clampf((_finale_t - FINALE_HOLD) / FINALE_FADE, 0.0, 1.0)
	if fade_alpha >= 1.0:
		_start_credits()

func _start_credits() -> void:
	# Load a real overworld (dark sky + starfield + the actual tileset), then repave it
	# into one long flat runway so Mario can genuinely RUN to the right the whole time
	# with nothing to bump into or fall through. The real player + camera do the work.
	level_num = 1
	reset(false)
	_build_credits_runway()
	# strip anything that could interrupt the run
	for e in enemies: e.queue_free()
	for it in items: it.queue_free()
	enemies.clear(); items.clear()
	game_state = "credits"
	_boss_finale = false                          # finale handoff done
	credits_t = 0.0
	credits_done = false
	timing = false                                # no clock during the credits
	start_delay = 0.0                             # skip the "get ready" freeze
	fade_alpha = 0.0                              # reveal the scene
	# swap the level music for the end-credits song
	music_off = true
	if music_player: music_player.stop()
	if end_player and not muted:
		end_player.play()

func _build_credits_runway() -> void:
	# wipe the loaded level's tiles and lay two solid ground rows across a wide, flat
	# runway, plus a few decorative floating block clusters high above Mario's head.
	LW = 400
	has_flag = false                              # no random flagpole/castle mid-runway
	_cam_locked = false
	terrain.clear()
	for col in range(LW):
		terrain.set_cell(Vector2i(col, FLOOR), SOURCE_ID, Vector2i(ATLAS_GROUND, 0))
		terrain.set_cell(Vector2i(col, FLOOR + 1), SOURCE_ID, Vector2i(ATLAS_GROUND, 0))
	var top := FLOOR - 4                          # 4 tiles up — well clear of a running Mario
	for cx in [12, 30, 52, 74, 100, 128, 160, 196, 236, 280, 330]:
		terrain.set_cell(Vector2i(cx, top), SOURCE_ID, Vector2i(ATLAS_BRICK, 0))
		terrain.set_cell(Vector2i(cx + 1, top), SOURCE_ID, Vector2i(ATLAS_QUESTION, 0))
		terrain.set_cell(Vector2i(cx + 2, top), SOURCE_ID, Vector2i(ATLAS_BRICK, 0))
	_collect_qblocks()                            # so the ? blocks still pulse
	pipeover_cells.clear()
	lava_rects.clear()

func _restart_game() -> void:
	# leave the credits and start a fresh playthrough from world 1-1
	if end_player: end_player.stop()
	credits_done = false
	_boss_finale = false
	level_num = 1
	reset(false)

func _update_credits(delta: float) -> void:
	credits_t += delta
	# once the roll has fully scrolled ("THE END" settled), Mario stops and any button restarts
	if not credits_done and credits_t * CREDITS_SCROLL_SPD >= _credits_scroll_max():
		credits_done = true
	# stop him a few tiles short of the runway's end so he never runs off into nothing
	player.global_position.x = minf(player.global_position.x, float((LW - 3) * TILE))
	_update_camera()                              # normal SMB scroll follows him right
	bg_renderer.queue_redraw()
	fg_renderer.queue_redraw()

func _update_arena_seal(delta: float) -> void:
	if _seal_blocks.is_empty():
		return
	var still: Array = []
	for b in _seal_blocks:
		var node = b.node
		if not is_instance_valid(node):
			continue
		b.vy += SEAL_G * delta
		node.position.y += b.vy * delta
		if node.position.y >= b.target_y:
			node.position.y = b.target_y
			if b.kind == "block":
				# landed: a permanent solid purple block just settles into place, with a bump
				terrain.set_cell(b.cell, SOURCE_ID, Vector2i(ATLAS_ARENA_WALL, 0))
				sfx("bump")
				node.queue_free()
			else:
				# gordo landed: leave it in place as a live hazard, with a bump
				sfx("bump")
		else:
			still.append(b)
	_seal_blocks = still

func _clear_seal_blocks() -> void:
	for b in _seal_blocks:
		if is_instance_valid(b.node) and b.kind == "block":
			b.node.queue_free()   # gords are owned by gords[] and freed there
	_seal_blocks.clear()

func _check_pipe_exit() -> void:
	if pipe_exit or not PIPE_EXIT_MAP.has(_level_file) or pipeover_cells.is_empty():
		return
	if not player.grounded or player.facing != 1:
		return
	var half: Vector2 = player.col_size / 2.0
	var left: float = player.global_position.x - half.x
	var right: float = player.global_position.x + half.x
	var top: float = player.global_position.y - half.y
	var bot: float = player.global_position.y + half.y
	for cell in pipeover_cells:
		for off in pipeover_solid_offsets:
			if off.x != 0:
				continue      # only the MOUTH (foot's left opening at floor level) lets Mario in, not the shaft face
			var t: Vector2i = cell + off
			var tx: float = t.x * TILE
			var ty: float = t.y * TILE

			if right >= tx - 2.0 and left < tx and bot > ty + 3.0 and top < ty + TILE - 3.0:
				_start_pipe_exit()
				return

func _start_pipe_exit() -> void:
	pipe_exit = true
	pipe_exit_phase = 0
	pipe_exit_t = 0.0
	game_state = "pipe_exit"
	timing = false
	player.velocity = Vector2.ZERO
	player.z_index = -6
	player.facing = 1
	pipe_exit_target_x = player.global_position.x + 20.0
	sfx("powerdown")

func _update_pipe_exit(delta: float) -> void:
	pipe_exit_t += delta
	if pipe_exit_phase == 0:

		player.facing = 1
		player.grounded = true
		player.global_position.y = float(FLOOR * TILE) - player.col_size.y / 2.0
		player.global_position.x += PIPE_EXIT_WALK * delta
		player.velocity.x = PIPE_EXIT_WALK
		player.walk_anim += delta * 8.0
		player._animate()
		if player.global_position.x >= pipe_exit_target_x:
			player.visible = false
			pipe_exit_phase = 1
			pipe_exit_t = 0.0
	elif pipe_exit_phase == 1:

		fade_alpha = clampf((pipe_exit_t - 0.2) / 0.5, 0.0, 1.0)
		if pipe_exit_t >= 0.9:
			_warp_from_pipe()
	bg_renderer.queue_redraw()
	fg_renderer.queue_redraw()

func _warp_from_pipe() -> void:
	pipe_exit = false
	player.visible = true
	player.z_index = 0
	saved_tier = player.tier()
	_carry_elapsed = elapsed
	level_num = int(PIPE_EXIT_MAP.get(_level_file, PIPE_EXIT_WARP_TO))   # 1-2 -> EXTRA 1 (slot 9); 2-2 -> Level14 (slot 14)
	_want_12_intro = false
	_want_emerge = true
	reset(true)





func _maybe_start_emerge() -> void:
	if not(_level_file in [9, 14] and _want_emerge):
		return
	_want_emerge = false
	var pcell:= _find_start_pipe()
	if pcell.x < 0:
		return
	game_state = "emerge"
	timing = false
	start_delay = 0.0
	var cx: float = pcell.x * TILE + TILE
	emerge_target_y = float(pcell.y * TILE)                 # rim (pipe top) — Mario rises to here
	player.spawn(Vector2(cx, float((pcell.y + 2) * TILE)))  # start 2 tiles down inside/below the pipe
	player.facing = 1
	player.velocity = Vector2.ZERO
	player.z_index = -10
	# frame the pipe Mario emerges from, using the SAME offset the play camera uses
	# (player.x - VIEW_W*0.42) so the view doesn't snap sideways when play begins
	cam_x = clampf(cx - VIEW_W * 0.42, 0.0, float(LW * TILE - VIEW_W))
	camera.position = Vector2(roundf(cam_x) + VIEW_W / 2.0, VIEW_H / 2.0)
	fade_alpha = 0.0
	sfx("powerdown")


func _find_start_pipe() -> Vector2i:
	var want: int = 8 if _level_file == 14 else 17   # green pipe in Level14, purple pipe elsewhere
	var best:= Vector2i(-1, -1)
	for c in terrain.get_used_cells():
		if terrain.get_cell_atlas_coords(c).x == want:
			if best.x < 0 or c.x < best.x:
				best = c
	return best

func _update_emerge(delta: float) -> void:
	player.facing = 1
	player.grounded = true
	player.velocity = Vector2.ZERO
	var feet: float = player.global_position.y + player.col_size.y / 2.0
	feet = maxf(emerge_target_y, feet - EMERGE_SPEED * delta)
	player.global_position.y = feet - player.col_size.y / 2.0
	player._animate()
	if feet <= emerge_target_y + 0.5:

		player.z_index = 0
		game_state = "play"
		timing = true
		_update_camera()
	bg_renderer.queue_redraw()
	fg_renderer.queue_redraw()






func _find_ceiling_pipe_lip() -> Vector2i:
	if terrain == null:
		return Vector2i(-1, -1)
	for c in terrain.get_used_cells():
		if terrain.get_cell_atlas_coords(c).x == 39:
			return c
	return Vector2i(-1, -1)

func _maybe_start_reward_trap() -> void:
	if not(_level_file == 11 and _want_reward_trap):
		return
	_want_reward_trap = false
	var lip:= _find_ceiling_pipe_lip()
	if lip.x < 0:
		return
	game_state = "trap"
	trap_phase = 0
	timing = false
	start_delay = 0.0
	fade_alpha = 0.0
	_trap_v = 0.0
	trap_t = 0.0
	var cx: float = float((lip.x + 1) * TILE)
	_trap_open_y = float((lip.y + 1) * TILE)
	player.spawn(Vector2(cx, _trap_open_y))
	player.facing = 1
	player.velocity = Vector2.ZERO
	player.z_index = -10
	sfx("powerdown")


	var sc: int = lip.x
	while sc < LW - 1:
		if _floor_ground(sc) and _floor_ground(sc + 1):
			break
		sc += 1
	_trap_sonic_stop_x = float(sc * TILE + 8)


func _floor_ground(c: int) -> bool:
	var a: Vector2i = terrain.get_cell_atlas_coords(Vector2i(c, FLOOR))
	return terrain.get_cell_source_id(Vector2i(c, FLOOR)) >= 0 and a.x != ATLAS_LAVA_TOP and a.x != ATLAS_LAVA

func _update_reward_trap(delta: float) -> void:
	trap_t += delta
	match trap_phase:
		0:

			player.global_position.y += TRAP_EMERGE_SPEED * delta
			player.grounded = false
			player._animate()
			if player.global_position.y - player.col_size.y / 2.0 > _trap_open_y + 2.0:
				player.z_index = 0
				trap_phase = 1
				_trap_v = TRAP_EMERGE_SPEED
			_update_camera()
		1:

			_trap_v = minf(_trap_v + TRAP_FALL_G * delta, 480.0)
			player.global_position.y += _trap_v * delta
			player.grounded = false
			player._animate()
			_update_camera()
			if player.global_position.y > VIEW_H + 40.0:
				player.kill(true)
				player.visible = false
				trap_phase = 5 ; trap_t = 0.0    # wait for the death jingle before Sonic gloats
		2:

			sonic_state = "run" ; sonic_face = "l"
			sonic_state_t += delta ; sonic_frame_t += delta
			sonic_x -= SONIC_RUN_SPD * delta
			if sonic_x <= _trap_sonic_stop_x:
				sonic_x = _trap_sonic_stop_x
				trap_phase = 3 ; trap_t = 0.0
				sonic_state_t = 0.0 ; sonic_frame_t = 0.0
			_sonic_compute_frame()
		3:

			sonic_state = "wait" ; sonic_face = "l" ; sonic_frame = 0
			sonic_speech = true
			sonic_speech_lines = SONIC_TAUNT_SPEECH
			# hold the taunt until the gloat song finishes (muted -> fixed fallback time)
			var taunt_done: bool = (trap_t >= TRAP_TAUNT_TIME) if muted else ((not sonic_song_player.playing) and trap_t > 0.5)
			if taunt_done:
				trap_phase = 4 ; trap_t = 0.0
		4:

			fade_alpha = clampf(trap_t / 0.6, 0.0, 1.0)
			if fade_alpha >= 1.0:
				_restart_1_2()
				return
		5:
			# Mario just died in the lava: hold until the death jingle finishes, THEN Sonic
			# runs in from the right and his gloat song (sonic.mp3) plays
			if trap_t >= 5.0 or (trap_t > 0.5 and not death_player.playing):
				music_off = true
				music_player.stop()
				if not muted:
					sonic_song_player.play()
				sonic_cut = true
				sonic_x = cam_x + float(VIEW_W) + 16.0
				sonic_state = "run" ; sonic_face = "l"
				sonic_state_t = 0.0 ; sonic_frame_t = 0.0 ; sonic_jump_off = 0.0
				trap_phase = 2 ; trap_t = 0.0
	_update_particles(delta)
	bg_renderer.queue_redraw()
	fg_renderer.queue_redraw()

func _restart_1_2() -> void:
	sonic_cut = false
	sonic_speech = false
	player.visible = true
	player.z_index = 0
	saved_tier = "small"
	_want_12_intro = false
	level_num = 2
	reset(true)





func _maybe_start_sonic_demo() -> void:
	sonic_demo =(_level_file == 10)
	if not sonic_demo:
		return
	player.visible = false
	start_delay = 0.0
	fade_alpha = 0.0
	timing = false
	sonic_phase = 0
	sonic_state = "wait" ; sonic_face = "r"
	sonic_x = SONIC_LEFT
	sonic_state_t = 0.0 ; sonic_frame_t = 0.0 ; sonic_jump_off = 0.0
	cam_x = 0.0
	camera.position = Vector2(VIEW_W / 2.0, VIEW_H / 2.0)

func _sonic_next() -> void:
	sonic_phase =(sonic_phase + 1) % 10
	sonic_state_t = 0.0
	sonic_frame_t = 0.0
	sonic_jump_off = 0.0

func _update_sonic_demo(delta: float) -> void:
	sonic_state_t += delta
	sonic_frame_t += delta
	match sonic_phase:
		0:
			sonic_state = "wait" ; sonic_face = "r"
			if sonic_state_t >= SONIC_WAIT_TIME:
				_sonic_next()
		1:
			sonic_state = "walk" ; sonic_face = "r"
			sonic_x += SONIC_WALK_SPD * delta
			if sonic_x >= SONIC_MID:
				_sonic_next()
		2:
			sonic_state = "run" ; sonic_face = "r"
			sonic_x += SONIC_RUN_SPD * delta
			if sonic_x >= SONIC_RIGHT:
				sonic_x = SONIC_RIGHT
				_sonic_next()
		3:
			sonic_state = "jump" ; sonic_face = "r"
			sonic_jump_off = -60.0 * sin(PI * clampf(sonic_state_t / 0.8, 0.0, 1.0))
			if sonic_state_t >= 0.8:
				_sonic_next()
		4:
			sonic_state = "wait" ; sonic_face = "l"
			if sonic_state_t >= SONIC_WAIT_TIME:
				_sonic_next()
		5:
			sonic_state = "walk" ; sonic_face = "l"
			sonic_x -= SONIC_WALK_SPD * delta
			if sonic_x <= SONIC_MID:
				_sonic_next()
		6:
			sonic_state = "run" ; sonic_face = "l"
			sonic_x -= SONIC_RUN_SPD * delta
			if sonic_x <= SONIC_LEFT:
				sonic_x = SONIC_LEFT
				_sonic_next()
		7:
			sonic_state = "jump" ; sonic_face = "l"
			sonic_jump_off = -60.0 * sin(PI * clampf(sonic_state_t / 0.8, 0.0, 1.0))
			if sonic_state_t >= 0.8:
				_sonic_next()
		8:

			sonic_face = "r"
			if sonic_state_t < SPIN_DUCK_TIME:
				sonic_state = "duck"
			elif sonic_state_t < SPIN_DUCK_TIME + SPIN_CHARGE_TIME:
				sonic_state = "spin"
			else:
				sonic_state = "ball"
				sonic_x += SPIN_DASH_SPD * delta
				if sonic_x >= SONIC_RIGHT:
					sonic_x = SONIC_RIGHT
					_sonic_next()
		9:

			sonic_face = "l"
			if sonic_state_t < SPIN_DUCK_TIME:
				sonic_state = "duck"
			elif sonic_state_t < SPIN_DUCK_TIME + SPIN_CHARGE_TIME:
				sonic_state = "spin"
			else:
				sonic_state = "ball"
				sonic_x -= SPIN_DASH_SPD * delta
				if sonic_x <= SONIC_LEFT:
					sonic_x = SONIC_LEFT
					_sonic_next()
	_sonic_compute_frame()




func _sonic_compute_frame() -> void:
	if sonic_state == "wait":

		var t:= sonic_state_t
		if t < IDLE_STAND_TIME:
			sonic_frame = 0
		elif t < IDLE_STAND_TIME + IDLE_LEAD:
			sonic_frame = 1
		elif t < IDLE_STAND_TIME + 2.0 * IDLE_LEAD:
			sonic_frame = 2
		else:
			var k:= int((t - IDLE_STAND_TIME - 2.0 * IDLE_LEAD) * IDLE_TAP_FPS)
			sonic_frame = 3 if(k % 2 == 0) else 4
	elif sonic_state == "duck":
		sonic_frame = 0
	elif sonic_state == "spin":
		sonic_frame = int(sonic_frame_t * SPIN_REV_FPS) % 3
	elif sonic_state == "ball":
		sonic_frame = int(sonic_frame_t * SPIN_BALL_FPS) % 4
	elif sonic_state == "hit" or sonic_state == "death":
		sonic_frame = 0                       # Z1/Z2 and the death pose are single frames
	else:
		var counts:= {"walk": 6, "run": 4, "jump": 5}
		var fps:= {"walk": 9.0, "run": 13.0, "jump": 7.0}
		sonic_frame = int(sonic_frame_t * float(fps[sonic_state])) % int(counts[sonic_state])









func _find_chamber_pipe() -> Vector2i:
	if terrain == null:
		return Vector2i(-1, -1)
	var best:= Vector2i(-1, -1)
	for cell in terrain.get_used_cells():
		if terrain.get_cell_atlas_coords(cell).x == 17 and cell.x > best.x:
			best = cell
	return best



func _check_sonic_cut() -> void:
	if sonic_cut or _sonic_cut_done or _level_file != 4 or _sonic_pipe_cell.x < 0:
		return
	# trigger on LANDING in the chamber (Mario drops through the roof gap himself), not on
	# crossing a line up on the roof: must be grounded with his feet down near the floor...
	if not player.grounded:
		return
	if player.global_position.y + player.col_size.y / 2.0 < float((FLOOR - 1) * TILE):
		return
	# ...and standing in the zone just right of the pipe
	var pc: Vector2i = _sonic_pipe_cell
	var fx: float = player.global_position.x
	if fx < float((pc.x + 2) * TILE) or fx > float((pc.x + 2 + 16) * TILE):
		return
	_start_sonic_cut()

func _start_sonic_cut() -> void:
	sonic_cut = true
	_sonic_cut_done = true
	sonic_cut_phase = 2                    # start at walk-to-pipe; the roof walk/fall (0/1) is player-driven now
	game_state = "sonic_cut"
	timing = false
	music_off = true                       # cut the level music for the cutscene
	music_player.stop()
	player.velocity = Vector2.ZERO
	player.facing = -1
	_mario_cut_v = 0.0
	var pc: Vector2i = _sonic_pipe_cell
	sonic_cut_stop_x = float((pc.x + 8) * TILE + 8)
	sonic_x = float((pc.x + 19) * TILE + 8)
	sonic_face = "l" ; sonic_state = "wait"
	sonic_state_t = 0.0 ; sonic_frame_t = 0.0 ; sonic_jump_off = 0.0


func _break_tunnel_col(c: int) -> void:
	if c < 0 or c >= LW:
		return
	var broke:= false
	for ty in[FLOOR - 2, FLOOR - 1]:
		var coord:= Vector2i(c, ty)
		if terrain.get_cell_source_id(coord) < 0:
			continue
		var ax: int = terrain.get_cell_atlas_coords(coord).x
		if ax != ATLAS_BRICK_PURPLE and ax != ATLAS_BRICK:
			continue
		terrain.erase_cell(coord)
		_spawn_debris(c, ty, ax == ATLAS_BRICK_PURPLE)
		broke = true
	if broke:
		sfx("brick")




# ---- Level 14 Sonic cutscene helpers (rebuilt; see notes) ----
func _update_l14_audio() -> void:
	# 0 = idle, 2 = Sonic's gloat song looping after the trap kills Mario
	if _l14_audio == 2:
		if not muted and not sonic_song_player.playing:
			sonic_song_player.play()

func _find_l14_trigger_brick() -> int:
	# the trap ? block (atlas 43) anchors the Sonic-trap chamber on the left; walking left past
	# it springs the cutscene
	var used: Rect2i = terrain.get_used_rect()
	for x in range(used.position.x, used.position.x + used.size.x):
		for y in range(used.position.y, used.position.y + used.size.y):
			var coord := Vector2i(x, y)
			if terrain.get_cell_source_id(coord) < 0:
				continue
			if terrain.get_cell_atlas_coords(coord).x == ATLAS_TRAP_MUSH:
				return x
	return -1

# Level 14 (2-2 tail): walking LEFT into the trap chamber springs the Sonic cutscene (the false
# path); walking RIGHT to the flag is the real exit to 2-3.
func _check_l14_cut() -> void:
	if _l14_cut or sonic_cut or _level_file != 14 or _l14_brick_col < 0:
		return
	if player.grounded and player.facing == -1 and player.global_position.x <= float((_l14_brick_col + 4) * TILE):
		_start_l14_cut()

func _start_l14_cut() -> void:
	_l14_cut = true
	sonic_cut = true                       # reuse the sonic_cut game_state + draw path
	game_state = "sonic_cut"
	sonic_cut_phase = 0
	timing = false
	music_off = true
	music_player.stop()
	player.velocity = Vector2.ZERO
	var bc: int = _l14_brick_col
	# Mario steps onto his mark just right of the block, then holds facing left, watching
	_l14_walk_in = true
	_l14_walk_target = float((bc + 3) * TILE + 8)
	player.grounded = true
	player.facing = -1
	# Sonic starts off-screen LEFT, spin-dashes RIGHT through the wall to under the block
	sonic_x = float((bc - 20) * TILE)
	_l14_stop_x = float(bc * TILE + 8)
	_l14_break_col = int(sonic_x / TILE)
	_l14_qblock = Vector2i(bc, 7)          # the trap ? block he bumps → trap mushroom
	_l14_jump_h = 60.0                     # same hop amplitude as the 1-2 cutscene jump
	_l14_cam_target = clampf(float(bc * TILE) - VIEW_W / 2.0, 0.0, float(LW * TILE - VIEW_W))
	_l14_cam_locked = false
	_l14_sega_done = false
	_l14_bumped = false
	_l14_prejump = false
	_l14_kill_t = 0.0
	_l14_death_v = 0.0
	_l14_audio = 0
	_sonic_spin_snd = false
	sonic_face = "r"; sonic_state = "duck"
	sonic_state_t = 0.0; sonic_frame_t = 0.0; sonic_jump_off = 0.0

func _update_l14_cut(delta: float) -> void:
	if _l14_walk_in:
		# walk the last step onto his mark (from wherever he tripped the trigger), then hold
		player.grounded = true
		player.global_position.y = float(FLOOR * TILE) - player.col_size.y / 2.0
		var dx: float = _l14_walk_target - player.global_position.x
		if absf(dx) > 1.5:
			player.facing = 1 if dx > 0.0 else -1
			player.global_position.x += SONIC_WALK_SPD * delta * signf(dx)
			player.walk_anim += delta * 10.0
			player._animate()
		else:
			player.global_position.x = _l14_walk_target
			player.velocity.x = 0.0
			player.facing = -1
			_l14_walk_in = false
		camera.position = Vector2(roundf(cam_x) + VIEW_W / 2.0, VIEW_H / 2.0)
		bg_renderer.queue_redraw()
		fg_renderer.queue_redraw()
		return
	# PRE-JUMP: Sonic pauses at the block and says his line, THEN jumps (phase 1). Held on the
	# plain stand frame (no foot-tap) while the speech bubble shows.
	if _l14_prejump:
		if not player.dead:
			player.facing = -1; player.grounded = true; player._animate()
		sonic_state = "wait"; sonic_face = "r"; sonic_frame = 0
		sonic_speech = true
		sonic_speech_lines = L14_PRIZE
		_l14_prejump_t += delta
		if _l14_prejump_t >= L14_PRIZE_HOLD:
			_l14_prejump = false
			sonic_speech = false
			sonic_cut_phase = 1
			sonic_state_t = 0.0; sonic_frame_t = 0.0
			sfx("sonic_jump")               # jump sound as he actually leaps at the block
		camera.position = Vector2(roundf(cam_x) + VIEW_W / 2.0, VIEW_H / 2.0)
		_update_particles(delta); _update_block_bumps(delta); _update_coins(delta)
		bg_renderer.queue_redraw()
		fg_renderer.queue_redraw()
		return
	sonic_state_t += delta
	sonic_frame_t += delta          # drive the spin/ball/jump frame cycling (_sonic_compute_frame)
	# Mario holds on the brick, facing left — but ONCE DEAD, stop animating so his death pose
	# (and death-jump, driven below) isn't overwritten each frame
	if not player.dead:
		player.facing = -1
		player.grounded = true
		player._animate()
	match sonic_cut_phase:
		0:
			# hold crouched until the screen has LOCKED and the SEGA sound has played in full,
			# THEN rev in place and spin-dash RIGHT through the wall.
			if not _l14_cam_locked or not _l14_sega_done:
				sonic_state = "duck"; sonic_face = "r"
				sonic_state_t = 0.0                          # freeze the rev/dash timer until ready
			elif sonic_state_t < SPIN_CHARGE_TIME:
				sonic_state = "spin"; sonic_face = "r"
				if not _sonic_spin_snd:
					_sonic_spin_snd = true; sfx("sonic_spin")   # revving-up sound
			else:
				sonic_state = "ball"; sonic_face = "r"
				sonic_x += SPIN_DASH_SPD * delta
				var cc: int = int(sonic_x / TILE)
				while _l14_break_col <= cc:
					_break_tunnel_col(_l14_break_col)   # bottom two rows only (rows FLOOR-2, FLOOR-1)
					_l14_break_col += 1
				if sonic_x >= _l14_stop_x:
					sonic_x = _l14_stop_x
					sfx("one_up")                   # 1-up sound now that Sonic's done dashing
					_l14_prejump = true             # hold & say his line before jumping at the block
					_l14_prejump_t = 0.0
		1:
			# landed — jump straight up and BUMP the ? block above (if one's placed), then land
			sonic_state = "ball"; sonic_face = "r"      # spin as a ball while jumping at the block
			var u: float = clampf(sonic_state_t / SONIC_CUT_JUMP_T, 0.0, 1.0)
			sonic_jump_off = -_l14_jump_h * sin(PI * u)
			if not _l14_bumped and u >= 0.5 and _l14_qblock.x >= 0:
				_l14_bumped = true
				bump_block(_l14_qblock.x, _l14_qblock.y)
			if u >= 1.0:
				sonic_jump_off = 0.0
				sonic_cut_phase = 2
				sonic_state_t = 0.0; sonic_frame_t = 0.0
		2:
			# the trap mushroom emerges & walks; when it touches Mario he dies (timeout fallback)
			sonic_state = "wait"; sonic_face = "r"; sonic_frame = 0
			_l14_kill_t += delta
			var kill := _l14_kill_t >= 6.0
			var mr := Rect2(player.global_position - player.col_size / 2.0, player.col_size)
			for it in items:
				if not it.dead and it.get("trap") and mr.intersects(it.get_rect()):
					kill = true
			if kill:
				player.kill()                    # death jingle + death pose
				if not muted:
					sonic_song_player.play() # gloat song right after Mario dies
				_l14_audio = 2                   # keep it looping until we leave for 2-2
				_l14_death_v = -300.0            # pop up, then fall (SMB death jump)
				# the trap mushroom vanishes as Mario dies (freed here since _update_items
				# doesn't run during the cutscene)
				var kept := []
				for it in items:
					if it.get("trap"):
						it.dead = true
						it.queue_free()
					else:
						kept.append(it)
				items = kept
				sonic_cut_phase = 3
				sonic_state_t = 0.0
		3:
			# Mario's death jump: pop up, then fall off-screen (death frame kept, no animate).
			# The taunt shows 0.5s into the death jump; Mario keeps falling under the bubble.
			sonic_state = "wait"; sonic_face = "r"; sonic_frame = 0
			if sonic_state_t >= 0.5:
				sonic_speech = true
				sonic_speech_lines = L14_TAUNT
			_l14_death_v = minf(_l14_death_v + 700.0 * delta, 480.0)
			player.global_position.y += _l14_death_v * delta
			# once off the bottom, hold the taunt (timer keeps running so the window counts
			# from the death-jump start)
			if player.global_position.y > VIEW_H + 32.0:
				sonic_cut_phase = 4
		4:
			# Sonic keeps taunting until 3.5s (0.5s delay + ~3s visible), measured from phase 3
			sonic_state = "wait"; sonic_face = "r"; sonic_frame = 0
			sonic_speech = true
			sonic_speech_lines = L14_TAUNT
			if sonic_state_t >= 3.5:
				sonic_speech = false
				sonic_cut_phase = 5
				sonic_state_t = 0.0; sonic_frame_t = 0.0
		5:
			# turn LEFT and walk a couple steps
			sonic_state = "walk"; sonic_face = "l"
			sonic_x -= SONIC_WALK_SPD * delta
			if sonic_state_t >= 0.75:            # ~2 tiles at walk pace
				sonic_cut_phase = 6
				sonic_state_t = 0.0; sonic_frame_t = 0.0
				_sonic_spin_snd = false          # arm the spin-rev sound for the exit dash
		6:
			# crouch → rev → spin-dash away to the LEFT, off the screen
			if sonic_state_t < SPIN_DUCK_TIME:
				sonic_state = "duck"; sonic_face = "l"
			elif sonic_state_t < SPIN_DUCK_TIME + SPIN_CHARGE_TIME:
				sonic_state = "spin"; sonic_face = "l"
				if not _sonic_spin_snd:
					_sonic_spin_snd = true; sfx("sonic_spin")   # revving-up sound
			else:
				sonic_state = "ball"; sonic_face = "l"
				sonic_x -= SPIN_DASH_SPD * delta
				if sonic_x < cam_x - 40.0:       # cleared the left edge of the screen
					sonic_cut_phase = 7
					sonic_state_t = 0.0; sonic_frame_t = 0.0
					_l14_audio = 0               # stop looping the gloat song so it can finish
		7:
			# wait for the gloat song to finish, THEN fade to black and load 2-2
			sonic_state = "ball"; sonic_face = "l"
			if not muted and sonic_song_player.playing:
				sonic_state_t = 0.0          # hold the fade at 0 until the music stops
			else:
				fade_alpha = clampf(sonic_state_t / 0.6, 0.0, 1.0)
				if fade_alpha >= 1.0:
					_l14_goto_next()
					return
	# animate Sonic during his motion phases (spin/ball/jump/walk); while waiting, dying,
	# or taunting he holds the plain stand frame (sonic_frame = 0) — NO foot-tap idle
	if sonic_cut_phase < 2 or sonic_cut_phase >= 5:
		_sonic_compute_frame()
	# slowly pan the camera over to frame Sonic + the wall, then LOCK it (Sonic then dashes
	# across the locked screen instead of the camera chasing him)
	if not _l14_cam_locked:
		cam_x = move_toward(cam_x, _l14_cam_target, L14_CAM_PAN_SPD * delta)
		if absf(cam_x - _l14_cam_target) < 0.5:
			cam_x = _l14_cam_target
			_l14_cam_locked = true
			if not muted:
				sega_player.play()        # screen has set on Sonic → play the SEGA sound
			else:
				_l14_sega_done = true     # muted: nothing to wait for
	# once the SEGA sound has played out, Sonic is cleared to dash
	if _l14_cam_locked and not _l14_sega_done and not sega_player.playing:
		_l14_sega_done = true
	camera.position = Vector2(roundf(cam_x) + VIEW_W / 2.0, VIEW_H / 2.0)
	_update_particles(delta)          # broken-brick debris + the coin pop from the ? block
	_update_block_bumps(delta)        # the ? block's hop animation
	_update_coins(delta)              # any coin the block spits out
	bg_renderer.queue_redraw()
	fg_renderer.queue_redraw()

# Fully scripted finale. Phases 0-3 drive Mario (walk the roof → drop into the chamber → walk to
# the pipe → jump onto it); phases 4-7 are Sonic (crash through the wall → settle → jump → freeze,
# looking at Mario). game_state stays "sonic_cut" forever at the end so it holds on the last frame.
func _warp_to_reward() -> void:
	# end the cutscene and load the reward level (Level11), fading in from black
	sonic_cut = false
	sonic_speech = false
	player.visible = true
	player.z_index = 0
	saved_tier = player.tier()           # carry Mario's power tier through the pipe
	level_num = SONIC_CUT_REWARD_SLOT
	_want_reward_trap = true             # arrive by dropping out of the ceiling pipe → into the lava
	reset(true)

# End of the Level 14 Sonic cutscene → load 2-2 (Level12 lives at play-slot 6). Mario died in
# the cutscene, so he arrives small. reset() clears sonic_cut/game_state and fades in from black.
func _l14_goto_next() -> void:
	sonic_cut = false
	sonic_speech = false
	player.visible = true
	player.z_index = 0
	saved_tier = "small"                 # Mario died in the cutscene → arrive small
	level_num = 6                        # 2-2
	_want_12_intro = false               # skip 2-2's pipe intro — spawn at its normal start point
	_want_emerge = false
	reset(true)

func _update_sonic_cut(delta: float) -> void:
	var pc: Vector2i = _sonic_pipe_cell
	var roof_feet: float = float(2 * TILE)                     # top surface of the chamber roof
	var floor_feet: float = float(FLOOR * TILE)                # chamber floor
	var gap_cx: float = float((pc.x + 10) * TILE + 8)          # centre of the roof gap (cols pc.x+9..+11)
	var pipe_top: float = float(pc.y * TILE)                   # pipe rim (feet stand here)
	var pipe_cx: float = float(pc.x * TILE + TILE)             # centre of the 2-wide pipe
	var pipe_appr: float = float((pc.x + 3) * TILE + 4)        # one tile of floor between Mario and the pipe
	match sonic_cut_phase:
		0:
			# Mario walks right along the roof to above the gap
			player.facing = 1; player.grounded = true; player.velocity.x = MARIO_CUT_WALK
			player.global_position.x = minf(player.global_position.x + MARIO_CUT_WALK * delta, gap_cx)
			player.global_position.y = roof_feet - player.col_size.y / 2.0
			player.walk_anim += delta * 8.0
			player._animate()
			if player.global_position.x >= gap_cx:
				sonic_cut_phase = 1; _mario_cut_v = 0.0
		1:
			# Mario drops through the gap into the chamber
			player.grounded = false
			_mario_cut_v += MARIO_CUT_FALL_G * delta
			player.global_position.y += _mario_cut_v * delta
			player._animate()
			if player.global_position.y + player.col_size.y / 2.0 >= floor_feet:
				player.global_position.y = floor_feet - player.col_size.y / 2.0
				player.grounded = true
				sonic_cut_phase = 2
		2:
			# Mario walks left to the pipe
			player.facing = -1; player.grounded = true; player.velocity.x = -MARIO_CUT_WALK
			player.global_position.x = maxf(player.global_position.x - MARIO_CUT_WALK * delta, pipe_appr)
			player.global_position.y = floor_feet - player.col_size.y / 2.0
			player.walk_anim += delta * 8.0
			player._animate()
			if player.global_position.x <= pipe_appr:
				sonic_cut_phase = 3
				sonic_state_t = 0.0                            # reuse as the jump timer
				sfx("jump_big" if (player.big or player.fire) else "jump_small")  # size-correct jump sfx
		3:
			# Mario jumps up onto the pipe
			sonic_state_t += delta
			var u: float = clampf(sonic_state_t / MARIO_CUT_JUMP_T, 0.0, 1.0)
			player.facing = -1; player.grounded = false
			player.global_position.x = lerp(pipe_appr, pipe_cx, u)
			var by: float = lerp(floor_feet, pipe_top, u) - MARIO_CUT_JUMP_ARC * sin(PI * u)
			player.global_position.y = by - player.col_size.y / 2.0
			player._animate()
			if u >= 1.0:
				player.global_position = Vector2(pipe_cx, pipe_top - player.col_size.y / 2.0)
				player.grounded = true; player.velocity = Vector2.ZERO
				player.facing = -1                            # land facing LEFT first
				player._animate()
				if not muted:
					sega_player.play()                        # the "sega" pose sound (full length)
				sonic_cut_phase = 11
				sonic_state_t = 0.0
		11:
			# Mario stands on the pipe facing LEFT, turns to face RIGHT partway through, and
			# Sonic only crashes in once the FULL sega sound has finished playing.
			sonic_state_t += delta
			player.facing = 1 if sonic_state_t >= SONIC_CUT_SEGA_T else -1   # change stance to face Sonic
			player._animate()
			if sonic_state_t >= SONIC_CUT_SEGA_T and not sega_player.playing:
				# spin-dash windup at his crash start, THEN the dash (phase 4)
				sonic_cut_phase = 12
				sonic_x = float((pc.x + 19) * TILE + 8)
				_sonic_break_col = int(sonic_x / TILE) + 1
				sonic_face = "l"; sonic_state = "duck"
				sonic_state_t = 0.0; sonic_frame_t = 0.0; sonic_jump_off = 0.0
				_sonic_spin_snd = false
		12:
			# spin-dash windup: crouch, then rev in place, THEN crash through the wall (phase 4)
			sonic_state_t += delta; sonic_frame_t += delta
			sonic_face = "l"
			if sonic_state_t < SPIN_DUCK_TIME:
				sonic_state = "duck"
			elif sonic_state_t < SPIN_DUCK_TIME + SPIN_CHARGE_TIME:
				sonic_state = "spin"
				if not _sonic_spin_snd:
					_sonic_spin_snd = true; sfx("sonic_spin")
			else:
				sonic_cut_phase = 4
				sonic_state = "ball"
				sonic_state_t = 0.0; sonic_frame_t = 0.0
			_sonic_compute_frame()
		4:
			# Sonic crashes out — spin-dash in from the right, tunnelling the wall bricks
			sonic_state_t += delta; sonic_frame_t += delta
			sonic_face = "l"; sonic_state = "ball"
			sonic_x -= SPIN_DASH_SPD * delta
			var cc: int = int(sonic_x / TILE)
			while _sonic_break_col > cc:
				_sonic_break_col -= 1
				_break_tunnel_col(_sonic_break_col)
			if sonic_x <= sonic_cut_stop_x:
				sonic_x = sonic_cut_stop_x
				sfx("one_up")                                 # 1-up jingle once he's smashed through
				sonic_cut_phase = 5; sonic_state_t = 0.0; sonic_frame_t = 0.0
			_sonic_compute_frame()
		5:
			# uncurl / settle onto his feet
			sonic_state_t += delta; sonic_frame_t += delta
			sonic_face = "l"; sonic_state = "wait"
			_sonic_compute_frame()
			if sonic_state_t >= SONIC_CUT_SETTLE:
				sonic_cut_phase = 6; sonic_state_t = 0.0; sonic_frame_t = 0.0
				sfx("sonic_jump")                          # Sonic's jump sound
		6:
			# a jump as he squares up (no foot-tap)
			sonic_state_t += delta; sonic_frame_t += delta
			sonic_face = "l"; sonic_state = "jump"
			sonic_jump_off = -60.0 * sin(PI * clampf(sonic_state_t / SONIC_CUT_JUMP_T, 0.0, 1.0))
			_sonic_compute_frame()
			if sonic_state_t >= SONIC_CUT_JUMP_T:
				sonic_jump_off = 0.0
				sonic_cut_phase = 7; sonic_state_t = 0.0; sonic_frame_t = 0.0
		7:
			# Sonic stands looking at Mario; the "congratulations / take the pipe" speech shows
			sonic_face = "l"; sonic_state = "wait"; sonic_frame = 0   # hold the stand frame (no tap yet)
			sonic_jump_off = 0.0
			sonic_speech = true
			sonic_speech_lines = SONIC_CUT_SPEECH
			sonic_state_t += delta
			if sonic_state_t >= SONIC_SPEECH_TIME:
				sonic_cut_phase = 8
				player.z_index = -10                  # sink behind the terrain pipe
				player.grounded = false
				sfx("powerdown")                      # pipe-entry sound
		8:
			# Mario sinks down into the pipe (occluded by the pipe front), then vanishes
			sonic_frame = 0
			player.global_position.y += MARIO_PIPE_SINK * delta
			player._animate()
			if player.global_position.y + player.col_size.y / 2.0 >= float(FLOOR * TILE) + 6.0:
				player.visible = false
				sonic_speech = false
				sonic_cut_phase = 9
				sonic_state_t = 0.0; sonic_frame_t = 0.0
		9:
			# Sonic does the foot-tap waiting idle; after 3s, the pipe warps to Level 11
			sonic_face = "l"; sonic_state = "wait"
			sonic_state_t += delta; sonic_frame_t += delta
			_sonic_compute_frame()
			if sonic_state_t >= SONIC_CUT_FOOTTAP_T:
				sonic_cut_phase = 10       # keep sonic_state_t running so the tap carries into the fade.0
		10:
			# Sonic KEEPS tapping his foot as the screen fades to black, then warp down the
			# pipe to the reward level. sonic_state_t keeps running past the foot-tap duration
			# so the tap animation continues seamlessly through the fade.
			sonic_face = "l"; sonic_state = "wait"; sonic_frame_t += delta
			sonic_state_t += delta
			_sonic_compute_frame()
			fade_alpha = clampf((sonic_state_t - SONIC_CUT_FOOTTAP_T) / 0.6, 0.0, 1.0)
			if fade_alpha >= 1.0:
				_warp_to_reward()
				return
	_update_particles(delta)          # let the broken-brick debris tumble as he smashes through
	_update_camera()                  # follow Mario, then hold at the level's camlock (proper locked view)
	bg_renderer.queue_redraw()
	fg_renderer.queue_redraw()


# =========================================================================
# AUDIO
# =========================================================================
func _setup_audio() -> void:
	# The music is a plain (non-looping) stream played through the same path as
	# the working SFX; we loop it ourselves by replaying on `finished`. This
	# avoids relying on WAV internal looping, whose loop region can end up empty
	# and produce total silence.
	_load_settings()
	_init_audio_buses()
	overworld_music = load("res://audio/newsong.mp3")
	# beat.wav is the intro-cutscene song; guarded so a missing/not-yet-imported file just
	# falls back to the overworld theme instead of erroring at boot
	var beat_path := "res://audio/mario sound/extra/beat.wav"
	intro_music = load(beat_path) if ResourceLoader.exists(beat_path) else null
	underground_music = load("res://audio/mario sound/extra/under.mp3")   # 1-2 underground theme
	castle_music = load("res://audio/mario sound/extra/cas.mp3")          # 1-4 Bowser castle theme
	boss_music = load("res://audio/mario sound/sonic/boss.mp3")           # 3-4 Sonic boss theme
	music_player = AudioStreamPlayer.new()
	music_player.stream = overworld_music
	music_player.pitch_scale = 1.0     # play the song at its natural speed
	music_player.volume_db = linear_to_db(MUSIC_VOL)
	music_player.bus = "Music"
	add_child(music_player)
	music_player.finished.connect(_on_music_finished)

	# The stage-clear and death jingles count as "other sounds", not level music,
	# so they follow the SFX volume slider.
	fanfare_player = AudioStreamPlayer.new()
	fanfare_player.stream = load("res://audio/mario sound/stage clear.wav")
	fanfare_player.volume_db = linear_to_db(0.85)
	fanfare_player.bus = "SFX"
	add_child(fanfare_player)
	# victory song for the 3-4 Sonic boss (plays when he's defeated)
	victory_player = AudioStreamPlayer.new()
	victory_player.stream = load("res://audio/mario sound/victory.mp3")
	victory_player.volume_db = linear_to_db(0.9)
	victory_player.bus = "Music"
	add_child(victory_player)
	# the end-credits song
	end_player = AudioStreamPlayer.new()
	end_player.stream = load("res://audio/mario sound/end m.mp3")
	end_player.volume_db = linear_to_db(0.9)
	end_player.bus = "Music"
	add_child(end_player)
	# the "mac" rescue song for 1-4 (Bowser castle) — plays when Mario reaches mac instead
	# of the stage-clear fanfare
	mac_player = AudioStreamPlayer.new()
	mac_player.stream = load("res://audio/mario sound/mac.mp3")
	mac_player.volume_db = linear_to_db(0.9)
	mac_player.bus = "Music"
	add_child(mac_player)
	# amam.wav — plays when Amazon raises his arms in the DK stage (2-4) ending (replaces the fanfare)
	am_player = AudioStreamPlayer.new()
	var amam_path := "res://audio/mario sound/amam.wav"
	if ResourceLoader.exists(amam_path):
		am_player.stream = load(amam_path)
	am_player.volume_db = linear_to_db(0.9)
	am_player.bus = "Music"
	add_child(am_player)
	# sonic.mp3 — the full gloat song when the Level11 shortcut-trap kills Mario; the room
	# holds until it finishes, then 1-2 restarts
	sonic_song_player = AudioStreamPlayer.new()
	sonic_song_player.stream = load("res://audio/mario sound/sonic/sonic.mp3")
	sonic_song_player.volume_db = linear_to_db(0.9)
	sonic_song_player.bus = "Music"
	add_child(sonic_song_player)
	# sega-hd.mp3 — dedicated so the cutscene can wait for the FULL sound before Sonic crashes
	sega_player = AudioStreamPlayer.new()
	sega_player.stream = load("res://audio/mario sound/sonic/sega-hd.mp3")
	sega_player.volume_db = linear_to_db(0.9)
	sega_player.bus = "SFX"
	add_child(sega_player)

	death_player = AudioStreamPlayer.new()
	death_player.stream = load("res://audio/mario sound/death.wav")
	death_player.volume_db = linear_to_db(0.9)
	death_player.bus = "SFX"
	add_child(death_player)

# Create the Music / SFX buses (both routed to Master) and apply the saved
# volumes. Runs once before any player is created.
func _init_audio_buses() -> void:
	# Prefer the buses defined in default_bus_layout.tres (they exist at startup, which is what
	# makes them audible on the single-threaded WEB export — runtime-added buses stay silent
	# there). Fall back to creating them if the layout is ever missing.
	music_bus = AudioServer.get_bus_index("Music")
	if music_bus < 0:
		music_bus = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(music_bus, "Music")
		AudioServer.set_bus_send(music_bus, "Master")
	sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus < 0:
		sfx_bus = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(sfx_bus, "SFX")
		AudioServer.set_bus_send(sfx_bus, "Master")
	_apply_bus_volumes()

func _apply_bus_volumes() -> void:
	_set_bus_volume(music_bus, music_volume)
	_set_bus_volume(sfx_bus, sfx_volume)

func _set_bus_volume(bus: int, v: float) -> void:
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, v <= 0.001)   # true silence at the low end
	AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(v, 0.0001, 1.0)))

# ---- display filter (full-screen post shader) ---------------------------
# A ColorRect on a high CanvasLayer reads the finished frame via the screen
# texture and rewrites it (CRT / invert). Hidden entirely for REGULAR.
func _setup_filter() -> void:
	filter_layer = CanvasLayer.new()
	filter_layer.layer = 100          # above the game world (0) and HUD
	add_child(filter_layer)
	filter_rect = ColorRect.new()
	filter_rect.size = Vector2(VIEW_W, VIEW_H)
	filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://filter.gdshader")
	mat.set_shader_parameter("screen_size", Vector2(VIEW_W, VIEW_H))
	filter_rect.material = mat
	filter_layer.add_child(filter_rect)
	_apply_filter()

func _apply_filter() -> void:
	if filter_rect == null:
		return
	filter_rect.visible = filter_mode != 0    # REGULAR = no overlay at all
	(filter_rect.material as ShaderMaterial).set_shader_parameter("mode", filter_mode)

# ---- settings persistence (user://settings.cfg) -------------------------
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_volume = clampf(cfg.get_value("audio", "music", 1.0), 0.0, 1.0)
	sfx_volume = clampf(cfg.get_value("audio", "sfx", 1.0), 0.0, 1.0)
	filter_mode = clampi(int(cfg.get_value("video", "filter", 0)), 0, FILTER_NAMES.size() - 1)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "filter", filter_mode)
	cfg.save(SETTINGS_PATH)

func _on_music_finished() -> void:
	# replay to loop the level music
	if not muted and not music_off:
		music_player.play()

func _apply_level_music() -> void:
	# underground ("under") levels get under.mp3, the 1-4 castle ("cas") gets cas.mp3,
	# everything else keeps the overworld song.
	if music_player == null:
		return
	var g: Dictionary = LEVEL_GEOMETRY[_level_file]
	var want: AudioStream = overworld_music
	if _level_file == 17:
		want = boss_music                     # 3-4 Sonic boss stage
	elif bool(g["under"]):
		want = underground_music
	elif bool(g.get("cas", false)):
		want = castle_music
	if music_player.stream == want:
		return
	var was_playing := music_player.playing
	music_player.stream = want
	if was_playing and not muted and not music_off:
		music_player.play()   # setting .stream stops playback — restart the new one

func _play_music(restart := false) -> void:
	if muted or music_off:
		return
	if restart or not music_player.playing:
		music_player.play()

func start_music_on_input() -> void:
	if not music_off and not music_player.playing:
		_play_music(false)

func toggle_mute() -> void:
	muted = not muted
	music_player.volume_db = linear_to_db(0.0001 if muted else MUSIC_VOL)
	if muted:
		AudioServer.set_bus_mute(0, true)
	else:
		AudioServer.set_bus_mute(0, false)

func sfx(name: String) -> AudioStreamPlayer:
	if muted:
		return null
	var path := ""
	match name:
		"jump_small": path = "res://audio/mario sound/jump small.mp3"
		"jump_big": path = "res://audio/mario sound/jump big.wav"
		"stomp": path = "res://audio/mario sound/stromp.wav"
		"powerup": path = "res://audio/mario sound/power up collect.wav"
		"powerup_appear": path = "res://audio/mario sound/power up apear.wav"
		"coin": path = "res://audio/mario sound/coin.mp3"
		"brick": path = "res://audio/mario sound/break block.wav"
		"shrink": path = "res://audio/shrink.wav"
		"powerdown": path = "res://audio/mario sound/extra/pwd.wav"
		"fireball": path = "res://audio/mario sound/fireball.wav"
		"kick": path = "res://audio/mario sound/kick shell.wav"
		"bump": path = "res://audio/mario sound/bump.wav"
		"flag": path = "res://audio/mario sound/flag.wav"
		"pause": path = "res://audio/mario sound/extra/smb_pause.wav"
		"bowser_fire": path = "res://audio/mario sound/fire.wav"          # Bowser's fire breath (not Mario's fireball)
		"bowser_fall": path = "res://audio/mario sound/bowser-falls.mp3"  # Bowser drops when the bridge collapses
		"one_up": path = "res://audio/mario sound/sonic/1-up.mp3"         # 1-2 cutscene: after Sonic smashes through
		"sonic_jump": path = "res://audio/mario sound/sonic/jump.wav"     # Sonic's jump in his cutscenes
		"sonic_spin": path = "res://audio/mario sound/sonic/spin.wav"     # Sonic revving up a spin-dash
		"gord": path = "res://audio/mario sound/gord.wav"                 # Sonic's spin-dash smashing a gordo
	if path == "":
		return null
	var gain := 9.0 if name == "coin" else 1.0   # coin plays much louder
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = linear_to_db(SFX_VOL * gain)
	p.bus = "SFX"                            # follows the pause-menu sound slider
	p.add_to_group("sfx")                    # so death can cut off in-flight SFX
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p

func _stop_all_sfx() -> void:
	# silence every in-flight one-shot SFX (e.g. a jump sound started the frame before
	# death) — leaves music/fanfare/death players alone (they aren't in the group)
	for p in get_tree().get_nodes_in_group("sfx"):
		p.stop()
		p.queue_free()

func stop_music_play_fanfare() -> void:
	music_off = true
	music_player.stop()
	if muted:
		return
	fanfare_player.play()

func stop_music_play_death() -> void:
	music_off = true
	music_player.stop()
	_stop_all_sfx()              # cut off any sound in progress (e.g. a jump just before dying)
	if muted:
		return
	death_player.play()


# =========================================================================
# TEXTURES + INPUT
# =========================================================================
const WALK_FRAMES := 6

func _load_textures() -> void:
	var files := {
		"death": "player/death",
		"fireball_l": "player/fireball_l", "fireball_r": "player/fireball_r",
		"goomba1": "enemies/goomba_walk1", "goomba2": "enemies/goomba_walk2",
		"goomba_flat": "enemies/goomba_flat",
		"koopa1": "enemies/koopa_walk1", "koopa2": "enemies/koopa_walk2",
		"koopa_shell": "enemies/koopa_shell",
		"shell_left": "enemies/shell_left", "shell_right1": "enemies/shell_right1",
		"shell_right2": "enemies/shell_right2", "shell_wake": "enemies/shell_wake",
		# purple enemy variants (sprites/new player/purpen.png): ledge-shy koopa
		# (SMB1 red-koopa behaviour) + fireball-spitting goomba. "p"-prefixed keys.
		"pgoomba1": "enemies/purple_goomba_walk1", "pgoomba2": "enemies/purple_goomba_walk2",
		"pgoomba_flat": "enemies/purple_goomba_flat",
		"pkoopa1": "enemies/purple_koopa_walk1", "pkoopa2": "enemies/purple_koopa_walk2",
		"pkoopa_shell": "enemies/purple_koopa_shell",
		"pshell_left": "enemies/purple_shell_left", "pshell_right1": "enemies/purple_shell_right1",
		"pshell_right2": "enemies/purple_shell_right2", "pshell_wake": "enemies/purple_shell_wake",
		"pplant1": "enemies/purple_piranha1", "pplant2": "enemies/purple_piranha2",
		# hammer bro: 4 frames each way (l = faces left, r = faces right) + 4 spin frames
		"hbrol1": "enemies/hbro_l1", "hbrol2": "enemies/hbro_l2",
		"hbrol3": "enemies/hbro_l3", "hbrol4": "enemies/hbro_l4",
		"hbror1": "enemies/hbro_r1", "hbror2": "enemies/hbro_r2",
		"hbror3": "enemies/hbro_r3", "hbror4": "enemies/hbro_r4",
		"hammer1": "enemies/hammer1", "hammer2": "enemies/hammer2",
		"hammer3": "enemies/hammer3", "hammer4": "enemies/hammer4",
		"mushroom": "items/mushroom", "green_mushroom": "items/green_mushroom",
		"flower": "items/flower", "fireball": "items/fireball",
		"pipe_lip_l": "pipes/pipe_lip_left", "pipe_lip_r": "pipes/pipe_lip_right",
		"pipe_body_l": "pipes/pipe_body_left", "pipe_body_r": "pipes/pipe_body_right",
	}
	# player tiers: small / big / fire — stand, walk1..N, jump_l/r (+ duck for big/fire)
	for t in ["small", "big", "fire"]:
		files[t + "_stand_l"] = "player/%s_stand_l" % t
		files[t + "_stand_r"] = "player/%s_stand_r" % t
		files[t + "_jump_l"] = "player/%s_jump_l" % t
		files[t + "_jump_r"] = "player/%s_jump_r" % t
		files[t + "_skid"] = "player/%s_skid" % t   # sharp-turn frame (art faces left)
		for i in range(1, WALK_FRAMES + 1):
			files["%s_walk%d" % [t, i]] = "player/%s_walk%d" % [t, i]
		if t != "small":
			files[t + "_duck"] = "player/%s_duck" % t
		# flagpole-slide poses (2 frames each, in sprites/ root)
		files[t + "_pole1"] = "pole_%s_1" % t
		files[t + "_pole2"] = "pole_%s_2" % t
	for key in files:
		tex[key] = load("res://sprites/%s.png" % files[key])
	_bake_transform_frames()

# Slice the grow/shrink animation frames out of the labelled reference sheet
# sprites/new player/GROW.png and bake each into a uniform 16x32 canvas (content
# bottom-aligned + horizontally centred) so the player Sprite2D can swap between
# them without any size/position jitter. GROW 1-4 (small->big), SHRINK A-D
# (big->small) -> tex keys grow1..grow4 / shrink1..shrink4.
func _bake_transform_frames() -> void:
	var sheet: Image = load("res://sprites/new player/GROW.png").get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	var grow := [Rect2i(25, 60, 12, 16), Rect2i(41, 52, 16, 24),
		Rect2i(59, 44, 16, 32), Rect2i(79, 44, 16, 32)]
	var shrink := [Rect2i(121, 44, 16, 32), Rect2i(139, 46, 16, 29),
		Rect2i(159, 61, 13, 15), Rect2i(177, 60, 12, 16)]
	for i in 4:
		tex["grow%d" % (i + 1)] = _bake_frame(sheet, grow[i])
		tex["shrink%d" % (i + 1)] = _bake_frame(sheet, shrink[i])
	_build_fire_maps()
	_bake_fireball_frames()
	_bake_bowser_frames()
	_bake_mac_frames()
	_bake_am_frames()
	_bake_sonic_frames()
	_bake_dk_frames()
	_bake_gord_frames()

# Bowser art (sprites/new player/bow.png). Dedicated directional frames (NOT mirrored):
# A1-A3 face LEFT, B1-B3 face RIGHT; per side 0/1 = walk, 2 = mouth-open (fire). Plus
# 3 flame frames. -> tex bowL0..2 / bowR0..2 / bflame0..2.
func _bake_bowser_frames() -> void:
	var sheet: Image = load("res://sprites/new player/bow.png").get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	var left := [Vector2i(14, 32), Vector2i(54, 32), Vector2i(94, 32)]      # A1 A2 A3
	var right := [Vector2i(139, 34), Vector2i(179, 34), Vector2i(219, 34)]  # B1 B2 B3
	for i in 3:
		tex["bowL%d" % i] = _bake_bowser_body(sheet, left[i])
		tex["bowR%d" % i] = _bake_bowser_body(sheet, right[i])
	var fy := [33, 47, 60]     # 3 flame frames stacked in the rightmost column
	for i in 3:
		tex["bflame%d" % i] = _bake_flame(sheet, Rect2i(255, fy[i], 26, 8), 28, 8)

# copy a 32x32 Bowser frame, dropping the stray green marker pixel the user left on A3
func _bake_bowser_body(sheet: Image, o: Vector2i) -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var c := sheet.get_pixel(o.x + x, o.y + y)
			if c.a < 0.5:
				continue
			if c.g > c.r + 0.15 and c.g > c.b + 0.15:   # green marker -> skip
				continue
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

# Bake one Bowser-flame frame, NORMALIZED so its bright tip always faces the SAME way
# (left, the flame's travel direction). The source sheet draws some frames mirrored, so
# cycling them made the fire flicker left<->right; we detect the bright tip and flip any
# frame that faces the wrong way, so all 3 frames point the same direction.
func _bake_flame(sheet: Image, r: Rect2i, w: int, h: int) -> ImageTexture:
	var frame := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	frame.blit_rect(sheet, r, Vector2i.ZERO)
	var best := -1.0
	var best_x := 0
	for y in r.size.y:
		for x in r.size.x:
			var c := frame.get_pixel(x, y)
			if c.a < 0.16:
				continue
			var s := c.r + c.g + c.b
			if s > best:
				best = s
				best_x = x
	if best_x >= r.size.x / 2:          # tip on the right half → mirror it to face left
		frame.flip_x()
	var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(frame, Rect2i(0, 0, r.size.x, r.size.y),
		Vector2i((w - r.size.x) / 2, (h - r.size.y) / 2))
	return ImageTexture.create_from_image(canvas)

# Mario's fireball art (sprites/new player/firep.png): TOP row = 4 spin frames (8x8,
# the flying ball rotating), BOTTOM row = 3 explosion frames (grow) for the impact
# on an enemy / block / wall. -> tex fball0..3 and fpop0..2.
func _bake_fireball_frames() -> void:
	var sheet: Image = load("res://sprites/new player/firep.png").get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	var spin := [Rect2i(21, 12, 8, 8), Rect2i(31, 12, 8, 8), Rect2i(41, 12, 8, 8), Rect2i(51, 12, 8, 8)]
	for i in 4:
		tex["fball%d" % i] = _bake_centered(sheet, spin[i], 8, 8)
	var pop := [Rect2i(25, 23, 8, 16), Rect2i(41, 23, 12, 16), Rect2i(57, 23, 16, 16)]
	for i in 3:
		tex["fpop%d" % i] = _bake_centered(sheet, pop[i], 16, 16)   # centred so it grows in place

# "mac" — the character rescued at the end of Bowser's castle (replaces SMB1's Toad).
# sprites/new player/mac.png is a labelled 2-frame sheet: A1 (arms bent up) and A2
# (arms raised high). Both are baked into a common MAC_W x MAC_H canvas, X-centred and
# bottom-aligned (feet at the canvas bottom) so alternating A1<->A2 keeps his feet
# planted and only the arms move. -> tex mac0 (A1) / mac1 (A2).
const MAC_W := 24
const MAC_H := 72
func _bake_mac_frames() -> void:
	var sheet: Image = load("res://sprites/new player/mac.png").get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	tex["mac0"] = _bake_bottom(sheet, Rect2i(43, 66, 24, 63), MAC_W, MAC_H)   # A1
	tex["mac1"] = _bake_bottom(sheet, Rect2i(121, 58, 23, 71), MAC_W, MAC_H)  # A2

# sprites/new player/AM.png — the "am" character for the DK stage (2-4) ending, a mac-style
# 2-pose reveal. A1 (arms down) and A2 (arms raised); baked X-centred + bottom-aligned into a
# common canvas so switching A1->A2 keeps his feet planted. The text labels above each figure
# (y<=524) are excluded by the figure rects (y>=534). -> tex am0 (A1) / am1 (A2).
const AM_W := 18
const AM_H := 60
func _bake_am_frames() -> void:
	var sheet: Image = load("res://sprites/new player/AM.png").get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	tex["am0"] = _bake_bottom(sheet, Rect2i(73, 539, 18, 54), AM_W, AM_H)    # A1 (arms down)
	tex["am1"] = _bake_bottom(sheet, Rect2i(118, 534, 18, 59), AM_W, AM_H)   # A2 (raised)

# "sonic" — labelled sprite sheet (sprites/new player/sonic.png). For now we bake the
# walking / running / waiting / jumping frames (both facings) for a future cut-scene; the
# duck / spin / boss frames are left for later. Each frame -> a uniform SONIC_W x SONIC_H
# canvas (X-centred, bottom-aligned) so the character stays put as frames swap.
# Keys: sonic_walk_l0..5 / _r0..5, sonic_run_l0..3 / _r0..3, sonic_wait_l0..5 / _r0..5,
#       sonic_jump_l0..4 / _r0..4  (l = facing left, r = facing right).
const SONIC_W := 32
const SONIC_H := 32
func _bake_sonic_frames() -> void:
	var sheet: Image = load("res://sprites/new player/sonic.png").get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	var anims := {
		"walk_l": [[13,53,30,81],[40,53,59,82],[65,55,95,82],[101,55,118,82],[127,54,150,82],[158,54,188,82]],
		"walk_r": [[213,53,230,81],[238,53,257,82],[264,53,294,80],[300,54,317,81],[326,53,349,81],[356,54,386,82]],
		"run_l":  [[40,105,63,130],[68,106,92,130],[98,105,121,130],[127,105,150,130]],
		"run_r":  [[230,105,253,130],[257,106,281,130],[285,105,308,130],[312,105,335,130]],
		"wait_l": [[27,168,46,195],[51,166,70,195],[74,166,93,195],[98,166,117,195],[123,166,141,195],[147,166,166,195]],
		"wait_r": [[222,166,241,195],[247,166,266,195],[270,166,289,195],[293,166,311,195],[316,166,335,195],[341,168,360,195]],
		"jump_l": [[20,351,36,382],[50,358,71,380],[78,358,100,379],[105,358,126,380],[132,358,154,379]],
		"jump_r": [[250,351,266,382],[283,358,304,380],[311,358,333,379],[338,358,359,380],[365,358,387,379]],
		# spin dash (Sonic Chaos): duck -> rev (spin-start A1/A2/A3) -> dash (while-spinning ball)
		"duck_r": [[226,237,247,256]],
		"spin_r": [[264,237,291,256],[300,237,321,255],[333,237,355,256]],
		"ball_r": [[218,299,239,321],[245,299,267,320],[274,298,295,320],[302,300,324,321]],
		# boss fight: Z1/Z2 = smashing a gordo with the spin-dash (facing left / right);
		# SONIC DEATH = the defeat pose (arms up) played after all 4 gordos are hit
		"hit_l":   [[61, 463, 90, 491]],    # Z1 (facing left)
		"hit_r":   [[273, 463, 302, 491]],  # Z2 (facing right)
		"death_l": [[118, 417, 142, 449]],
		"death_r": [[118, 417, 142, 449]],
	}
	for key in anims:
		var i := 0
		for b in anims[key]:
			var r := Rect2i(b[0], b[1], b[2] - b[0], b[3] - b[1])
			tex["sonic_%s%d" % [key, i]] = _bake_bottom(sheet, r, SONIC_W, SONIC_H)
			i += 1
	# wait/duck/spin/ball use the facing-RIGHT art (the good ones); derive facing-left by
	# mirroring (canvas symmetric → registration preserved). walk/run/jump keep dedicated L art.
	for base in ["wait", "duck", "spin", "ball"]:
		var i := 0
		while tex.has("sonic_%s_r%d" % [base, i]):
			var mimg: Image = tex["sonic_%s_r%d" % [base, i]].get_image().duplicate()
			mimg.flip_x()
			tex["sonic_%s_l%d" % [base, i]] = ImageTexture.create_from_image(mimg)
			i += 1

# copy `r` into a w x h canvas, horizontally centred and bottom-aligned
# Donkey Kong (sprites/new player/dkdk.png). Frame rects measured from the hand-arranged
# sheet: idle A1/a2, directional rolls, straight-down roll, a 5-frame fall, and 2 barrel frames.
# All DK body frames baked feet-aligned into a uniform 48x34 canvas so his stance is stable.
const DK_CANVAS := 48         # DK frames bake into a 48x48 canvas...
const DK_FEET_Y := 36        # ...with his FEET aligned to this row, so poses of different heights
							 # (e.g. b1, whose barrel hangs below his feet) don't shift his body.
							 # DK sprite CENTRE is DK_CANVAS/2 -> feet are (DK_FEET_Y - 24) below it.

# bake a DK frame with its feet (feet_row px below the rect's top) pinned to DK_FEET_Y
func _bake_dk(sheet: Image, r: Rect2i, feet_row: int) -> ImageTexture:
	var canvas := Image.create(DK_CANVAS, DK_CANVAS, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(sheet, r, Vector2i((DK_CANVAS - r.size.x) / 2, DK_FEET_Y - feet_row))
	return ImageTexture.create_from_image(canvas)

func _bake_dk_frames() -> void:
	var sheet: Image = load("res://sprites/new player/dkdk.png").get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	tex["dk_idle0"] = _bake_dk(sheet, Rect2i(174, 53, 46, 32), 32)   # a1 (standing)
	tex["dk_idle1"] = _bake_dk(sheet, Rect2i(242, 53, 46, 32), 32)   # a2 (standing)
	# b1 = the roll/throw pose (the barrel is drawn up at his hands, within his body — 32px tall,
	# same as a1/a2; the strip below it in the sheet is the "b1" label, NOT part of the sprite)
	tex["dk_b1"] = _bake_dk(sheet, Rect2i(77, 40, 43, 32), 32)
	tex["dk_rollL"] = _bake_dk(sheet, Rect2i(77, 40, 43, 32), 32)
	tex["dk_rollR"] = _bake_dk(sheet, Rect2i(382, 48, 43, 32), 32)
	tex["dk_down0"] = _bake_dk(sheet, Rect2i(158, 137, 40, 32), 32)
	tex["dk_down1"] = _bake_dk(sheet, Rect2i(208, 137, 40, 32), 32)
	var fall := [Rect2i(105, 238, 46, 29), Rect2i(154, 239, 47, 27), Rect2i(208, 237, 40, 32),
		Rect2i(254, 239, 47, 27), Rect2i(305, 238, 46, 29)]
	for i in fall.size():
		tex["dk_fall%d" % i] = _bake_dk(sheet, fall[i], fall[i].size.y)
	# the rolling barrel's 2 graphics frames D1/D2 (the roll effect)
	tex["dk_barrel0"] = _bake_centered(sheet, Rect2i(158, 329, 14, 16), 16, 16)
	tex["dk_barrel1"] = _bake_centered(sheet, Rect2i(180, 331, 16, 14), 16, 16)

# Gord (sprites/new player/gord.png): a stationary spiky hazard, 2 flip frames a1/a2.
func _bake_gord_frames() -> void:
	var sheet: Image = load("res://sprites/new player/gord.png").get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	tex["gord0"] = _bake_centered(sheet, Rect2i(11, 64, 23, 24), 24, 24)
	tex["gord1"] = _bake_centered(sheet, Rect2i(44, 64, 23, 24), 24, 24)

func _bake_bottom(sheet: Image, r: Rect2i, w: int, h: int) -> ImageTexture:
	var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(sheet, r, Vector2i((w - r.size.x) / 2, h - r.size.y))
	return ImageTexture.create_from_image(canvas)

func _bake_centered(sheet: Image, r: Rect2i, w: int, h: int) -> ImageTexture:
	var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(sheet, r, Vector2i((w - r.size.x) / 2, (h - r.size.y) / 2))
	return ImageTexture.create_from_image(canvas)

# The fire-flower flash is a PALETTE swap (SMB1), so it must recolour whatever pose
# Mario is frozen in. big-Mario uses a clean 3-colour palette; sprites/new player/
# fl1.png gives the green/gray/brown recolours of the standing frame, from which we
# derive colour->colour maps that then apply to ANY big pose (jump, walk, duck…).
var fire_maps: Array = []            # [green, gray, brown]: {rgba32 int -> Color}
var _fire_flash_cache: Dictionary = {}

func _build_fire_maps() -> void:
	var base: Image = load("res://sprites/player/big_stand_r.png").get_image()
	base.convert(Image.FORMAT_RGBA8)
	var flower: Image = load("res://sprites/new player/fl1.png").get_image()
	flower.convert(Image.FORMAT_RGBA8)
	var origin := [Vector2i(25, 5), Vector2i(57, 5), Vector2i(89, 5)]   # green/gray/brown crops
	fire_maps = [{}, {}, {}]
	for y in base.get_height():
		for x in base.get_width():
			var bc := base.get_pixel(x, y)
			if bc.a < 0.5:
				continue
			var k := bc.to_rgba32()
			for i in 3:
				fire_maps[i][k] = flower.get_pixelv(origin[i] + Vector2i(x, y))

# recolour the big-tier pose `tex["big"+key]` into palette `pal` (1 green, 2 gray,
# 3 brown), cached. Used only during the fire-flower flash.
func get_fire_flash(key: String, pal: int) -> Texture2D:
	var ck := key + str(pal)
	if _fire_flash_cache.has(ck):
		return _fire_flash_cache[ck]
	var img: Image = tex["big" + key].get_image().duplicate()   # copy — never mutate the shared texture image
	img.convert(Image.FORMAT_RGBA8)
	var mp: Dictionary = fire_maps[pal - 1]
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var nk := c.to_rgba32()
			if mp.has(nk):
				img.set_pixel(x, y, mp[nk])
	var t := ImageTexture.create_from_image(img)
	_fire_flash_cache[ck] = t
	return t

func _bake_frame(sheet: Image, r: Rect2i) -> ImageTexture:
	var canvas := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	var dst := Vector2i((16 - r.size.x) / 2, 32 - r.size.y)   # centre X, bottom-align Y
	canvas.blit_rect(sheet, r, dst)
	return ImageTexture.create_from_image(canvas)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		return
	if paused:
		_pause_menu_input(event)
		return
	# end credits: once "THE END" has settled, any button press restarts the whole game
	if game_state == "credits":
		if credits_done and (event is InputEventKey or event is InputEventJoypadButton) \
				and event.pressed and not event.echo:
			_restart_game()
		return   # swallow all other input while the credits play
	if event is InputEventKey and event.pressed and not event.echo:
		start_music_on_input()
	if event.is_action_pressed("restart"):
		reset(true)
	if event.is_action_pressed("mute"):
		toggle_mute()
	# DEBUG stage warp: 1-9 = that slot, 0 = 10, - = 11, = = 12, Backspace = 13, \ = 14, ] = 15, [ = 16, ' = 17 (remove for release)
	if event is InputEventKey and ((event.keycode >= KEY_1 and event.keycode <= KEY_9) or event.keycode == KEY_0 or event.keycode == KEY_MINUS or event.keycode == KEY_EQUAL or event.keycode == KEY_BACKSPACE or event.keycode == KEY_BACKSLASH or event.keycode == KEY_BRACKETRIGHT or event.keycode == KEY_BRACKETLEFT or event.keycode == KEY_APOSTROPHE):
		if event.keycode == KEY_APOSTROPHE:
			level_num = 17
		elif event.keycode == KEY_BRACKETLEFT:
			level_num = 16
		elif event.keycode == KEY_BRACKETRIGHT:
			level_num = 15
		elif event.keycode == KEY_BACKSLASH:
			level_num = 14
		elif event.keycode == KEY_BACKSPACE:
			level_num = 13
		elif event.keycode == KEY_EQUAL:
			level_num = 12
		elif event.keycode == KEY_MINUS:
			level_num = 11
		elif event.keycode == KEY_0:
			level_num = 10
		else:
			level_num = event.keycode - KEY_1 + 1
		level_num = clampi(level_num, 1, LEVEL_COUNT)
		advancing = false
		show_level_card = false
		_want_12_intro = _file_at(level_num) in [4, 5, 12]   # surface intro when warping to 1-2
		_want_emerge = _file_at(level_num) in [9, 14]     # pipe emerge when warping to EXTRA 1
		_want_reward_trap = _file_at(level_num) == 11  # ceiling-pipe drop when warping to Level11
		reset(false)

const UNPAUSE_BUFFER_MS := 200    # brief debounce so one keypress can't double-toggle
var _paused_at := 0

func toggle_pause() -> void:
	# no pausing once the flagpole is touched (timing freezes then) or the level
	# is beaten — the win sequence should play straight through
	if game_state != "play" or not timing:
		return
	if paused:
		if Time.get_ticks_msec() - _paused_at < UNPAUSE_BUFFER_MS:
			return
		paused = false
	else:
		paused = true
		_paused_at = Time.get_ticks_msec()
		sfx("pause")   # only on pause, not on resume
	# NOTE: the level music keeps playing while the pause menu is open so the
	# MUSIC volume slider is audible as you adjust it. Only gameplay is frozen.
	hud.refresh()

const PAUSE_ROWS := 4   # 0 = MUSIC, 1 = SOUND, 2 = FILTER, 3 = MAIN MENU

# Pause-menu navigation: Up/Down pick the row, Left/Right change that row.
func _pause_menu_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		pause_sel = (pause_sel + PAUSE_ROWS - 1) % PAUSE_ROWS
		sfx("bump")
		hud.refresh()
	elif event.is_action_pressed("move_down"):
		pause_sel = (pause_sel + 1) % PAUSE_ROWS
		sfx("bump")
		hud.refresh()
	elif event.is_action_pressed("move_left"):
		_pause_row_adjust(-1)
	elif event.is_action_pressed("move_right"):
		_pause_row_adjust(1)
	elif pause_sel == PAUSE_ROWS - 1 and (event.is_action_pressed("jump") \
			or (event is InputEventKey and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)) \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A)):
		_quit_to_menu()
	elif event.is_action_pressed("mute"):
		toggle_mute()

func _quit_to_menu() -> void:
	paused = false
	save_saves()                              # make sure progress/records are on disk
	boot_to_files = true                      # tell the intro to open straight at the file list
	get_tree().change_scene_to_file("res://Intro.tscn")

# Left/Right on the selected row: volume for the two audio rows, filter cycle for the third.
func _pause_row_adjust(dir: int) -> void:
	if pause_sel >= 3:
		return                               # MAIN MENU row has nothing to slide
	if pause_sel == 2:
		filter_mode = (filter_mode + dir + FILTER_NAMES.size()) % FILTER_NAMES.size()
		_apply_filter()
		_save_settings()
		sfx("bump")
		hud.refresh()
	else:
		_adjust_volume(dir * VOL_STEP)

func _adjust_volume(delta: float) -> void:
	if pause_sel == 0:
		music_volume = clampf(snappedf(music_volume + delta, VOL_STEP), 0.0, 1.0)
	else:
		sfx_volume = clampf(snappedf(sfx_volume + delta, VOL_STEP), 0.0, 1.0)
	_apply_bus_volumes()
	_save_settings()
	# The music slider is audible on its own (music keeps looping); for the sound
	# slider, play a blip so you hear the new SFX level.
	if pause_sel == 1:
		sfx("coin")
	hud.refresh()
