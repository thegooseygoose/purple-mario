# Purple Mario (Godot) — Session Notes / Resume

Handoff notes for continuing work on the Godot Mario port at `D:\best game\mario_godot`.

> A new Claude Code chat opened in this folder auto-loads my persistent memory
> (`mario-godot-port`, `mario-godot-build`, etc.), so it will already have most
> of this context. This file is a human-readable summary + open items.

## ⏵ RESUME HERE — state as of 2026-08-01

**Level chain is now 1-1 → 1-2 → 1-3 → 1-4 → 1-5** (1-5 is the final COURSE CLEAR).
- **1-5** = empty starter for hand-editing (`tools/build_level5.gd`): 250 tiles wide,
  2 solid rows of ORANGE (non-purple) ground (atlas 0), flag@242 / castle@245. NOT
  underground → keeps the night-sky starfield. Editable like the others (Terrain /
  EnemyTiles / CoinTiles layers + FlagpolePreview). Wired in main.gd (`LEVEL5_SCENE`,
  `_instance_level` level_num==5, `LEVEL_COUNT=5`, `on_enter_castle` level_num<5) and
  intro debug text now "PRESS 1-5". `underground` stays `level_num==4` only.
- **1-3** = recreated from `sprites/new player/level 3.png` art (388 tiles). Built by `tools/build_level3.gd` + `tools/level3_spec.txt`.
- **1-4** = starts as an empty 250-tile PURPLE-ground level (`tools/build_level4.gd`); **the user has REMADE 1-4 with their own layout in the editor and it's SAVED to disk (641 tiles). DO NOT re-run build_level4.gd — it would wipe their level.**
- **1-4 is UNDERGROUND:** black background, no starfield (`main.underground = level_num==4`). Every other level keeps the night-sky starfield.

**Debug stage-select (REMOVE before public release — see `mario-debug-stage-select` memory):**
title screen "PRESS 1-4 FOR STAGE" + in-game keys **1/2/3/4** warp to that world instantly.

**Purple tile set added (atlas 15-22, paintable in editor):** 15 ground, 16 stair, 17-20 pipe,
21 used, 22 brick — behave like their orange/green counterparts. From `more more.png`/`PIPES.png`/`underblock.png`.

**Alt ? blocks (atlas 23-24, paintable in editor):** identical orange `?` face + A1/A2/A3 pulse as
the base coin/mushroom blocks, but they turn into the PURPLE used block (21) when hit instead of the
orange one (3). **23 = alt COIN block, 24 = alt MUSHROOM block** (24 gives a fire flower if already
big, same as the orange mushroom block). A1 face from `underblock.png`. Base orange blocks (2 coin /
12 mushroom) are unchanged. Code: `ATLAS_QUESTION_PURPLE`/`ATLAS_MUSHROOM_PURPLE` in `main.gd`,
handled in `_collect_qblocks` (pulse) + `bump_block` (`used_x` picks the purple used tile).

**Jump/movement feel — heavily retuned this session (all in `main.gd` consts):**
- Tap = ~16px low hop (`JUMP_VELOCITY -259`, `JUMP_HOLD_GRAV 0.225`).
- Running jump: momentum earns BOTH ~+17px height (`JUMP_VELOCITY_RUN -290`, launch lerps by
  ACTUAL speed) AND ~8-tile floaty reach (`JUMP_RUN_GRAV_SCALE 1.15`). Standing+run = no boost.
- Softer SMB1 descent (`MAX_FALL 440`, `FALL_GRAV_SCALE 0.93`).
- Ducking: enter only on the ground; a duck-jump stays ducked until it LANDS (`duck_locked`).
- **Small Mario collision is now `(12,14)` (was 16)** so he fits through 1-tile gaps SMB1-style.

**Two clip bugs FIXED** (`player._handle_head_bump`): small Mario could (a) slip through a block
corner and (b) jump up through a 1-tile brick lip (the brick-hop tile-erase let a fast riser
through). Fix = detect the ceiling by TILE (not move_and_slide) and ZERO the upward velocity the
instant a bump is detected, before `bump_block` erases the tile. Run-under a 1-tile ceiling still
works (no false bumps); ? bump / brick break unaffected.

**Other:** coin sitting on a bumped block is now collected + plays the coinpop animation;
already-fire + fire-flower plays the power-up sound (not coin); death now cuts any in-flight SFX
(no jump sound bleeding through the death jingle).

**macOS build exists:** `dist\Mac Mario.zip` = universal `.app` (built cross-platform from Windows,
ad-hoc signed). Slightly behind latest source. See `mario-godot-build` memory for the export/run steps.

**⚠️ dist\Mario.exe is STALE and the USER ASKED NOT TO RE-EXPORT IT until they say so** — it is
missing ALL of the above. F5/source has everything. Re-export ONLY when the user explicitly asks.

**Where the user left off:** actively editing/testing 1-4 in the Godot editor. Last topic was
confirming Godot doesn't auto-save (use Ctrl+S; F5 also saves).

---

## Duck-slide UNDER blocks (big/fire) — DONE this session
Big/fire Mario running + duck now SLIDES under a 1-tile gap (SMB1). `player.gd`: ducking
resizes the collision to `DUCK`=(12,14) via `_set_stance` (feet planted) so he fits under a
1-tile ceiling; movement stays gated while ducked so he coasts on momentum. Duck deceleration is now an
ABSOLUTE `DUCK_DECEL`=120 px/s² (~6-tile slide from full run) — NOT `FRICTION×0.15`, because
once FRICTION dropped to the gentle SMB1 coast (133) the scaled duck friction (~20) went full
ice. (Was 240/~3 tiles; user wanted ~2× → 120.) Lower DUCK_DECEL = longer slide. `_blocked_above`
keeps him crouched while a ceiling is overhead (can't stand up under blocks); he stands once
clear. Small Mario never ducks. Minor: the 22px crouch sprite pokes ~6px above the 1-tile
ceiling (cosmetic). Run start required (can't walk while ducked, SMB1).

## Sharp-turn (skid) frame — DONE this session
Added the "sharp turn" skid pose from `new new new.png` (top-right A1/A2/A3 = small/big/fire,
one frame each, art faces LEFT). Extracted tight+transparent to `sprites/player/{small,big,
fire}_skid.png` (14x16 / 16x32 / 16x32); no player-slicing tool exists, cut via System.Drawing
from sheet coords small@(509,59) big@(539,43) fire@(568,43). Loaded in `main._load_textures`
(`t+"_skid"`). Shown in `player._animate` when `skid_timer>0` (after the jump/air check, before
walk), mirrored when `skid_dir>0` (turning right) like the duck frame.
- Trigger: the reversing branch in `_update_alive` — on the ground, MOVING (`>SKID_MIN_SPEED`
  20) and input opposite to velocity. Standstill+opposite does NOT skid (velocity.x==0).
  Re-armed every sliding frame, so it tracks the whole slide; `SKID_TIME`=0.04s is just a
  short tail. Reset on spawn.
- FACING (fixed): skid faces his MOMENTUM (old direction he's sliding), NOT the input —
  `_apply_frame(..., skid_dir < 0)`. (v1 faced the new input dir = wrong per user ref.)
  GOTCHA: in the sheet small_skid faces LEFT but big/fire_skid faced RIGHT (mirrored) —
  flipped big/fire PNGs horizontally so all three share the left native facing the code expects.
- SLIDE: `TURN_ACC` 2600→1150→**380** (main.gd). Researched real SMB1 (SMBpedia/disasm):
  max run 40 subpix/f=2.5px/f=150px/s, max walk 24=1.5=90; accel = FrictionData
  0xe4/0x98/0xd0 (÷256÷16) ≈180 px/s² running; SKID = accel DOUBLED (facing opposite move)
  ≈370 px/s². So TURN_ACC 380 → full-run skid ~24 frames / ~2 tiles = authentic Mario 1.
- FULL SMB1 accel/friction (user chose it): `WALK_ACC` 900→**133**, `RUN_ACC` 1200→**183**,
  `AIR_ACC` 650→**150**, `FRICTION` 1600→**133** (main.gd). Now Mario builds speed gradually
  (~50 frames to full run) and coasts ~1s to a stop = authentic momentum feel. TURN_ACC 380
  ≈ 2× RUN_ACC (SMB1 doubles accel when facing opposite = the skid). Speeds left at 93.75/
  153.75 (≈SMB1). If too slippery for platforming, dial FRICTION/accel up toward a middle.

## Physics: stomp bounce is now a FIXED arc — DONE this session
The real bug: pressing/holding jump after a stomp let the variable-jump hold-grav (0.225)
float the rebound to ~8 tiles. Fix (`player.gd`): new `stomp_bounce` flag set in `bounce()`
disables the hold-float during the rebound and blocks a fresh mid-air jump (`jump_held=true`);
cleared at apex (velocity.y>=0) + on spawn. `STOMP_BOUNCE` -250→**-360** (main.gd) so the
now-floatless arc is ~1.5–1.75 tiles. Verified (sim): held vs not-held bounce = identical
27.9px; old held = 134px. Chained stomps still work; jump input no longer inflates it.

## Physics: SMB1-accurate speed pass — DONE this session
Restored movement to Mario-1 values (was ~10% slow + heavy falls): `WALK_MAX` 85.5→**93.75**,
`RUN_MAX` 148.5→**153.75**, `MAX_FALL` 440→**300** (SMB1 terminal ≈270). Accel/friction/jump
left as-is (felt right). `GAP_MIN_SPEED` (110) still sits between the new walk/run so the
run-over-gaps mechanic is unchanged. All in `main.gd` physics-tuning block.

## RUN over 1-tile gaps (SMB1) — DONE this session
Running fast, Mario glides across single-tile gaps (block/gap/block, e.g. early 1-5); but
if he's slow or STOPPED over one he FALLS straight in (the gaps are real, not invisible
floors). `player.gd`: `_foot_support_top()` probes terrain under his centre + both foot
corners (±`FOOT_SPAN`=8). The support/carry only counts **while `absf(velocity.x) >
GAP_MIN_SPEED` (110, between walk 85.5 and run 148.5)** — so you must be running. After
`move_and_slide`, the carry lifts him back onto the ledge (`CARRY_FALL`=10 window) unless
rising. `on_floor` (movement/jump) + the `grounded` member (walk anim / `_animate` jump
pose) both use the speed-gated support.
- v1 BUG (fixed): the check was NOT speed-gated → Mario stood on gaps like invisible
  boxes and couldn't fall. Speed gate = the fix.
- REGRESSION (fixed): `_animate` now reads `grounded` (was `is_on_floor()`), but `grounded`
  is only maintained in `_update_alive` — so the flagpole castle-walk (`_update_win` phase 3)
  showed the jump/"glide" pose, no walk cycle, on EVERY level. Fix: `grounded = is_on_floor()`
  each frame of phase 3 before `_animate()`.
- GOTCHA hit: `var top := float(r)*main.TILE` fails type inference (main untyped) → must
  be `var top: float = ...`. Tune feel via GAP_MIN_SPEED / FOOT_SPAN / CARRY_FALL.

## How to run / verify
- **Play:** press **F5** in the Godot editor (live source — every change is in effect).
  Or double-click `Play Mario.bat`.
- **Godot exe:** `C:\Users\kenne\Downloads\Godot_v4.7-stable_win64.exe\` (GUI +
  `_console.exe` for headless CLI).
- **After editing any PNG/WAV/asset:** Godot must reimport. F5 in the editor does
  it; from CLI: `Godot_console.exe --headless --path . --import`.
- **dist\Mario.exe is STALE** (last export 2026-07-30, before all the 07-31 work
  below). Re-export to update it: ensure `dist/` exists, then
  `Godot_console.exe --headless --path . --import` then
  `Godot_console.exe --headless --path . --export-release "Windows Desktop"`.
  F5/source always has everything without re-exporting.

## Boot flow
`Intro.tscn` (`intro.gd`) is the project's main scene now (not Main.tscn):
1. GOOSE PRANDINI MEDIA logo (`intro/1500.png`, used exactly, drawn at real window
   resolution via `CONTENT_SCALE_MODE_CANVAS_ITEMS` so it's crisp) fades in/out on
   black over 10s while `intro/apog.mp3` plays.
2. PURPLE MARIO title + controls + blinking PRESS P TO START.
3. **P** → restores the NES viewport mode and loads `Main.tscn` (the game).

## Session 2026-07-30 → 07-31 (latest — all verified in-engine)
Continued from the list further down. Most recent work first:

**Blocks / bumps**
- **Bump sound + hop:** head-bumping a `?`/mushroom block or a brick (small Mario)
  → block **hops up 6px & back** (0.156s) + sound; used block (A4) = sound only, no
  hop. `bump.wav` plays; per-coord `bump_lock` (140ms) debounces double-sound.
- **One block per hit:** `player._handle_head_bump` bumps only the single most-
  overlapped solid tile (no straddle double). GOTCHA that crashed the game: `var
  x := col*main.TILE` fails type inference (main untyped) — must type it.
- **Coin from block** = `COINS2.png` art → `sprites/coin_pop.png` (4 frames A1-A4).
  SMB1-style: arcs up (peak `COINPOP_PEAK=52`) & back to `COINPOP_END=16` (a tile
  above the block), spinning fast (`int(e/0.04)%4`), size 16px nudged +1px right.
  Red edge frames are intentional (from the official sheet) — do NOT recolor.
- **? block reveal delayed:** the mushroom/flower now appears only AFTER the block
  finishes its hop (deferred `on_done` callback in `_start_block_bump`).

**Enemies / items on bumped blocks (SMB3 style)** — `main._hit_things_on_block`:
  goomba → flips & dies (`knock_out`); **koopa → upside-down stunned shell that
  rights itself and walks after `FLIP_STUN_DUR=2.6s`** (`enemy.flip_stun`/`_end_flip`);
  mushroom → hops `MUSHROOM_HOP_H=22px` then floats down slowly (`HOP_FALL_SCALE=0.15`).

**Mushroom emerge:** rises out of the block with the flower's clip-reveal, and only
  starts walking once fully up (`mushroom.gd`).

**Ducking (big/fire):** running-duck **slides** (`DUCK_FRICTION_SCALE=0.15`), can
  **jump out of a duck AND stays ducked in the air** (ducking no longer needs on_floor;
  `_animate` checks ducking before the jump pose).

**Pause:** 1-second unpause lockout (`UNPAUSE_BUFFER_MS=1000`) — no rapid pause spam.

**Pixel-perfect:** window 1024x960 (exact 4x), camera snaps to whole px.

**Flagpole (rebuilt from `sprites/new player/flag pole.png` → `flagpole_ball/flag/base.png`):**
  ball + 2px green pole + A2 flag + A4 base block (drawn by `tile_renderer._draw_flag`).
  Flag **slides smoothly from the top** on grab (`main._update_flag_slide`,
  `FLAG_SLIDE_SPEED=114.5`, keeps going even after Mario enters the castle) to rest on
  the base edge. Mario **clings to the pole with tier poses** (`FPA.png` → `pole_{small,
  big,fire}_{1,2}.png`, alternate 0.1s), **stops on the brick, waits for the flag to
  land, flips to the far side of the pole for `WIN_FLIP_HOLD=30` frames, then walks off**.

**World 1-2 (`Level2.tscn` — an EDITABLE scene, built by `tools/build_level2.gd`):**
- 200 tiles wide, 2 ground rows, end staircase + flag + castle. `LW`/`FLAG_X`/`CASTLE_X`
  are now VARS set per level in `_instance_level` (level 1 = Level1.tscn 214/198/202;
  level 2 = Level2.tscn 200/192/195). `world_label` drives the HUD.
- **Paint-a-tile workflow:** `EnemyTiles` layer (goomba/koopa via `enemy_tiles.tileset.tres`)
  + `CoinTiles` layer (coin via `coin_tiles.tileset.tres`). `_read_spawns` reads their
  cells → real enemies/coins spawn, then hides the icon layers. `FlagpolePreview`
  (`@tool` node) shows the pole/castle in the EDITOR only.
- **GOTCHA that broke it:** the user dragged the Terrain layer → `position=(-1515,0)`,
  shifting all rendering+collision left (bricks/pipes vanished off-screen, `?` blocks
  drawn by overlay had no collision). Fix: reset each TileMapLayer `position` to (0,0).
  `build_level2.gd` now paints a starter layout (3 ? / 4 brick / pipe / 3 coins /
  goomba+koopa) so 1-2 has working content.

**Between-level transition (`main._update_advance`):** beat 1-1 → full stage-clear
  fanfare (waits for it to finish) → hold 40 frames → **black card with just "1-2"** →
  load 1-2. Beating 1-2 is the final COURSE CLEAR.

**Stage-start freeze + fade-in:** every stage fades in from black over `START_DELAY=0.5s`
  with Mario + clock frozen; clock starts at 0 each stage. Hides the between-level flash.

**Hidden "I LOVE YOU" 1-up block:** level 1 ONLY now (`hidden_blocks` gated on level_num).

---
## What changed the previous session (all verified in-engine)
- **Tiles from art sheets** (`sprites/new player/`): brick/?/used from `blocks.png`;
  ground + stair from `more more.png`; green pipes sliced from `PIPES.png`.
  Painted into `tiles.png` by `tools/gen_tiles.gd` (`_blit_block`, takes a sheet arg).
- **? blocks + coins pulse** A1→A2→A3 every 0.2s (shared `main.qanim_phase`),
  drawn as overlays in `tile_renderer.gd` — never touches tile atlas index / collision.
- **Castle** = sprite `sprites/castle.png` (TR variant of `more more.png`); baked
  castle tiles erased at load (`main._clear_castle_tiles`).
- **Flagpole win:** Mario walks to the castle **door center** and vanishes there
  (`player.gd _update_win`, target `CASTLE_X*16+24`, `z_index=2` during win).
- **Physics:** walk/run 10% slower; jump ~16px lower. Walking into a wall now
  strides at a steady 0.2s/frame (see `wall_push` + the `_animate` fix).
- **Fireball:** on hitting a wall/enemy it flashes a 2x burst then disappears
  (offset 10px in travel dir).
- **Background:** black→dark gray `Color(0.16,0.16,0.19)` night sky + parallax
  pixel starfield (`tile_renderer._draw_stars`); clouds/hills removed.
- **HUD** = bitmap font `sprites/new player/LETTERS 1.png` via shared
  `PixelFont` class (`pixel_font.gd`), used by `hud.gd` AND `intro.gd`.
- **Timer:** counts **up in real seconds**, `SS.cc` then `M:SS.cc` past a minute;
  **freezes the instant the flagpole is touched** (`main.timing` flag). COURSE
  CLEAR overlay shows `TIME <clear time>`. HUD coin is the spinning A1/A2/A3 coin.
- **Resolution:** window **1024x960** (`project.godot`) = an exact **4x** of the
  256x240 internal viewport (same aspect → no letterbox, perfectly uniform pixels).
  Was 1440x1080 (4.5x, non-integer) which made pixel-art edges wobble.
- **Pixel-perfect camera:** `main._update_camera` snaps the camera to whole pixels
  (`roundf(cam_x)`) so static tiles rasterize identically each frame — fixes a block
  appearing to change size (15/16px) as you scroll. `cam_x` stays fractional for logic.
- **Bump sound:** `bump.wav` now plays on used-block (A4, any size) + brick (B1, small
  Mario) head-bumps. A per-coord `bump_lock` (140ms) in `main.bump_block` debounces
  so a single block can't double-sound (capsule head can re-contact next frame).
- **Block hop:** bumping a ? block (A1/A2/A3), mushroom ? block, or a brick (B1, small
  Mario) makes the block hop **up 5px and snap back** (0.13s, `bump_offset`). A4 used
  block does NOT hop (sound only). Impl: `main.block_bumps` + `tile_renderer.
  _draw_block_bumps` (the real cell is erased for the hop and restored after).
- **One block per hit:** `player._handle_head_bump` bumps only the single solid tile
  the head overlaps most, so straddling two blocks never bumps both (verified: Mario
  centred on the 132/133 boundary bumps exactly 1).

## Verify gotcha (bit me)
- Headless boot loads **Intro.tscn** (the project main scene), so a plain
  `--headless --quit-after N` NEVER compiles `main.gd`/`player.gd` and misses their
  parse errors. Always error-check against the game scene:
  `Godot_console.exe --path . res://Main.tscn --quit-after N` and grep `SCRIPT ERROR`.
- **Power-down sound:** `audio/mario sound/extra/pwd.wav` plays on power-down
  (big/fire→small, never when small). It was silent → fixed by normalizing volume
  + forcing uncompressed PCM import (`compress/mode=0`); Godot 4.4+ defaults WAV
  to lossy QOA which crushed the quiet clip.

## Key gotchas (bit me this session)
- **Reimport after PNG/WAV edits** or the game uses a stale imported asset (blurry
  logo, silent/old sound, smeared tiles).
- **Fractional dest + NEAREST at 1x scale garbles** bitmap-font glyphs — `PixelFont`
  `floorf()`s all draw coords.
- **Row-3 font letters (Q-Z) are 6px tall**, not 7 (the y39 pixels are the Q tail).
- **`main` is untyped** → `var x := main.CONST/2.0` fails inference; type it.
- **Headless timing:** `await get_tree().process_frame` counts RENDER frames (faster
  than 60Hz physics in headless) — use `physics_frame` to measure game-time cadence.
- **Quiet WAVs**: force PCM import, don't leave as QOA.

## Brick-break debris → B2 sprite shatter (DONE this session)
Big Mario breaking a brick now bursts into FOUR tumbling B2 chunks (was four plain 6px
rects). Matches SMB1: top pair launches higher, all fly outward (left col left / right col
right), spin continuously, then fall the WHOLE way down and off the bottom — none culled
early or on the sides. Colour follows the brick: orange chunk for the
orange brick, purple chunk for purple brick #22.
- Each flying piece is a SINGLE 8x8 chunk (from `underblock.png` **B3** @114,106 — the
  "separated pieces" art), NOT the whole B2 cluster. (v1 wrongly drew the entire B2 ring
  at all 4 positions → looked like 4 clusters tumbling. Fixed to one chunk per piece.)
- Atlas: indices **25 = orange chunk (blocks.png B3), 26 = purple chunk (underblock.png
  B3)** (gen_tiles.gd `_debris_chunk`/`_blit_chunk`; drawn particles, NOT in the tileset —
  no collision). The 8x8 chunk is centred in its 16px cell. Both sheets now have hand-drawn
  B3 art (no more recolour). tiles.png now 432x16 (27 cells). Renderer draws the cell at
  sz=16 → ~8px chunk.
- **GOTCHA:** after editing a source PNG (blocks.png/underblock.png), run `--import`
  BEFORE `-s tools/gen_tiles.gd`, else gen_tiles' `load()` reads the STALE imported sheet
  and bakes an empty/old chunk. Order: import → gen_tiles → import (for tiles.png).
- `main.gd`: `_spawn_debris(tx,ty,purple)` seeds 4 particles {pos,vel,ang,spin,atlas_x};
  consts DEBRIS_GRAV 900 / VX 70 / VY_TOP 430 / VY_BOT 300 / SPIN 9. `_update_particles`
  integrates + culls debris only when `pos.y > VIEW_H+24`. `bump_block` passes
  `ax == ATLAS_BRICK_PURPLE`.
- `tile_renderer._draw_particles`: debris now draws the rotated B2 region via
  `draw_set_transform(pos, ang, 1)` at 12px, then resets the transform.
- Verified: headless sim → all 4 exit the bottom (top 1.18s, bottom 0.95s), apex ~108px
  above the block, symmetric ±88px spread. No script errors on Main.tscn.

## Possibly open / next ideas
- **Re-export `dist\Mario.exe`** — STALE (many changes since 2026-07-30). Do this
  when you want the standalone updated (see run/verify section for the command).
- **Design 1-2** in the editor — `Level2.tscn` has a starter layout; paint Terrain /
  EnemyTiles / CoinTiles to build it out. (Only use paint/erase, not the move tool, or
  a layer shifts — see the 1-2 gotcha above.)
- Flag/castle X for 1-2 are code values (`_instance_level`: 192/195). If you resize the
  level's end, ask to move them (and the FlagpolePreview flag_x/castle_x export).
- Possible polish: `+points` popups, a score sparkle on the coin, a "WORLD 1-2" that
  matches SMB's card layout, sound for the between-level card.
- Unused sheet pieces (B1/B2 purple blocks, C/D brick-door variants, purple castle).
