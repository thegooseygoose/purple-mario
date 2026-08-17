extends SceneTree
## Build tool (run headless): paints a 16x16-per-cell tile atlas to
## res://tiles.png, matching the procedural colours of the original renderer.
##   godot --headless --path <proj> -s tools/gen_tiles.gd
## Atlas cell order (x index):
##   0 X ground   1 B brick   2 ? block   3 U used   4 S stair
##   5 T flagbase 6 H shaft   7 C castle
##   8 pipe_lip_l 9 pipe_lip_r 10 pipe_body_l 11 pipe_body_r   12 M block
##   13,14 = the two dim ? animation frames (overlay-only, not real tiles)
##   PURPLE variants (paintable, behave like counterparts):
##   15 ground  16 stair  17-20 pipe(lipL,lipR,bodyL,bodyR)  21 used  22 brick
##   ALT ? blocks (orange A1/A2/A3 pulse, PURPLE used-state A4):
##   23 alt coin ? block   24 alt mushroom ? block
##   BRICK-BREAK debris chunk (single 8x8 B3 piece, centred; drawn as rotating
##   particles, not real tiles): 25 orange piece   26 purple piece

##   CASTLE + LAVA (for a 2-4-style castle/lava level):
##   27 castle ground block (solid)   28 lava surface (wavy top)   29 lava body
##   (28/29 are HAZARD tiles — no collision; main kills the player on contact)
const N := 30   # 0-14 + 15-22 purple + 23-24 alt ? + 25-26 pieces + 27-29 castle/lava
## WARNING: tiles.png currently has 43 cols — cols 30-42 were APPENDED after this tool
## (30 blockc, 31-33 bridge plank/chain/axe, 34 giant-pipe anchor, 35-42 UPSIDE-DOWN pipes:
## 35-38 green lipL/lipR/bodyL/bodyR flipped, 39-42 purple, via tools that widen tiles.png).
## Re-running gen_tiles.gd REGENERATES only cols 0-29 and WOULD TRUNCATE 30-42 — don't, or
## re-append them + re-register in tiles.tileset.tres afterwards.
const T := 16

func _init() -> void:
	var img := Image.create(N * T, T, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# ground (A1) + stair (A2) come from the hand-drawn sheet too
	_blit_block(img, 0, 25, 32, 16, 16, "more more.png")   # ground (A1)
	# brick / ? block / used block come from the hand-drawn sheet
	# res://sprites/new player/blocks.png. Each region (tight bbox) is scaled
	# to fill a 16x16 cell. A1/A2/A3 = the three ? frames, A4 = used, B1 = brick.
	_blit_block(img, 1, 33, 105, 16, 16)   # brick   (B1)
	_blit_block(img, 2, 33, 53, 16, 16)    # ? block frame 1 (A1, bright)
	_blit_block(img, 3, 151, 53, 16, 16)   # used    (A4)
	_blit_block(img, 4, 46, 32, 16, 16, "more more.png")   # stair (A2)
	_flagbase(img, 5)
	_shaft(img, 6)
	_castle(img, 7)
	# pipes: slice the 32x32 "A FULL" green pipe (@32,22) on the 16 grid
	_blit_block(img, 8, 32, 22, 16, 16, "PIPES.png")    # lip  left
	_blit_block(img, 9, 48, 22, 16, 16, "PIPES.png")    # lip  right
	_blit_block(img, 10, 32, 38, 16, 16, "PIPES.png")   # body left
	_blit_block(img, 11, 48, 38, 16, 16, "PIPES.png")   # body right
	_blit_block(img, 12, 33, 53, 16, 16)   # mushroom block base (A1)
	_blit_block(img, 13, 69, 53, 16, 16)   # ? block frame 2 (A2, mid)
	_blit_block(img, 14, 110, 53, 16, 16)  # ? block frame 3 (A3, dark)

	# ---- PURPLE variants (paintable in the editor; behave like their counterparts) ----
	_blit_block(img, 15, 25, 65, 16, 16, "more more.png")   # purple ground (B1)
	_blit_block(img, 16, 46, 65, 16, 16, "more more.png")   # purple stair  (B2)
	# purple pipe: slice the 32x32 "B FULL" purple pipe (@118,23) like the green one
	_blit_block(img, 17, 118, 23, 16, 16, "PIPES.png")      # lip  left
	_blit_block(img, 18, 134, 23, 16, 16, "PIPES.png")      # lip  right
	_blit_block(img, 19, 118, 39, 16, 16, "PIPES.png")      # body left
	_blit_block(img, 20, 134, 39, 16, 16, "PIPES.png")      # body right
	_blit_block(img, 21, 151, 53, 16, 16, "underblock.png") # purple solid/used block (A4)
	_blit_block(img, 22, 33, 105, 16, 16, "underblock.png") # purple brick (B1)

	# ---- ALT ? blocks: identical orange ? face (A1), but end in the PURPLE used
	# block (index 21) when hit. Two versions — one dispenses a coin, one a mushroom.
	_blit_block(img, 23, 33, 53, 16, 16, "underblock.png")  # alt coin ? block     (A1)
	_blit_block(img, 24, 33, 53, 16, 16, "underblock.png")  # alt mushroom ? block (A1)

	# ---- brick-break debris: a single 8x8 chunk (B3), centred in its cell ----
	_debris_chunk(img)

	# ---- CASTLE ground block + LAVA (2-4-style level) ----
	# castle block: the single 16x16 castle brick (transparent bg) in castle blocks.png
	_blit_block(img, 27, 32, 23, 16, 16, "castle blocks.png")
	# lava: the 16x32 strip in BACK GROUND/LAVA.png → top half = wavy surface, bottom = body
	_blit_block(img, 28, 28, 33, 16, 16, "BACK GROUND/LAVA.png")   # lava surface
	_blit_block(img, 29, 28, 49, 16, 16, "BACK GROUND/LAVA.png")   # lava body
	# the sheet's grey (204,204,204) backdrop above the wave crest → transparent so
	# the wavy lava top shows against the level background, not a grey block
	for cell in [28, 29]:
		for yy in range(T):
			for xx in range(T):
				var p := img.get_pixel(cell * T + xx, yy)
				if p.r8 == 204 and p.g8 == 204 and p.b8 == 204:
					img.set_pixel(cell * T + xx, yy, Color(0, 0, 0, 0))

	var out := ProjectSettings.globalize_path("res://tiles.png")
	var err := img.save_png(out)
	print("gen_tiles: saved %s (err=%d)" % [out, err])
	quit()


## Copy a sw x sh region from a hand-drawn sheet, scaled to a 16x16 atlas cell.
## `sheet` picks the source PNG (blocks.png by default; "more more.png" for A1/A2).
var _sheets := {}
func _blit_block(img: Image, i: int, sx: int, sy: int, sw: int, sh: int,
		sheet := "blocks.png") -> void:
	if not _sheets.has(sheet):
		# a sheet name with a "/" is a path under res://sprites/; otherwise new player/
		var path: String = ("res://sprites/%s" % sheet) if "/" in sheet else ("res://sprites/new player/%s" % sheet)
		var tx: Texture2D = load(path)
		var si: Image = tx.get_image()
		si.decompress()
		si.convert(Image.FORMAT_RGBA8)
		_sheets[sheet] = si
	var region: Image = _sheets[sheet].get_region(Rect2i(sx, sy, sw, sh))
	if sw != T or sh != T:
		region.resize(T, T, Image.INTERPOLATE_NEAREST)
	img.blit_rect(region, Rect2i(0, 0, T, T), Vector2i(i * T, 0))


## Bake the single 8x8 brick-break chunk (each sheet's B3 @114,106), centred in its
## 16x16 cell: cell 25 = orange (blocks.png), cell 26 = purple (underblock.png).
func _debris_chunk(img: Image) -> void:
	_blit_chunk(img, 25, "blocks.png")
	_blit_chunk(img, 26, "underblock.png")

func _blit_chunk(img: Image, cell: int, sheet: String) -> void:
	var tx: Texture2D = load("res://sprites/new player/%s" % sheet)
	var si: Image = tx.get_image()
	si.decompress()
	si.convert(Image.FORMAT_RGBA8)
	var chunk: Image = si.get_region(Rect2i(114, 106, 8, 8))   # B3 top-left piece
	img.blit_rect(chunk, Rect2i(0, 0, 8, 8), Vector2i(cell * T + 4, 4))   # centred (4px inset)


func _fill(img: Image, ox: int, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and xx < T and yy >= 0 and yy < T:
				img.set_pixel(ox + xx, yy, c)


func _ground(img: Image, i: int) -> void:
	var o := i * T
	_fill(img, o, 0, 0, T, T, Color("c84c0c"))
	_fill(img, o, 0, 0, T, 3, Color("e08048"))
	_fill(img, o, 0, T - 2, T, 2, Color(0, 0, 0, 0.18))
	_fill(img, o, T - 2, 0, 2, T, Color(0, 0, 0, 0.18))

func _brick(img: Image, i: int) -> void:
	var o := i * T
	_fill(img, o, 0, 0, T, T, Color("c84c0c"))
	_fill(img, o, 0, 7, T, 1, Color(0, 0, 0, 0.35))
	_fill(img, o, 0, 15, T, 1, Color(0, 0, 0, 0.35))
	_fill(img, o, 4, 0, 1, 7, Color(0, 0, 0, 0.35))
	_fill(img, o, 12, 0, 1, 7, Color(0, 0, 0, 0.35))
	_fill(img, o, 8, 8, 1, 7, Color(0, 0, 0, 0.35))
	_fill(img, o, 0, 0, T, 1, Color(1, 1, 1, 0.15))

const QMARK := [
	"011110",
	"110011",
	"000011",
	"000110",
	"001100",
	"001000",
	"000000",
	"001000",
]

func _qblock(img: Image, i: int) -> void:
	var o := i * T
	_fill(img, o, 0, 0, T, T, Color("fcac00"))
	_fill(img, o, 0, 0, T, 2, Color("e08000"))
	_fill(img, o, 0, 0, 2, T, Color("e08000"))
	_fill(img, o, T - 2, 0, 2, T, Color("e08000"))
	_fill(img, o, 0, T - 2, T, 2, Color("e08000"))
	# stamp the '?' glyph
	for r in range(QMARK.size()):
		var row: String = QMARK[r]
		for c in range(row.length()):
			if row[c] == "1":
				img.set_pixel(o + 5 + c, 4 + r, Color.BLACK)
	img.set_pixel(o + 2, 2, Color.WHITE)
	img.set_pixel(o + 13, 13, Color.WHITE)

func _used(img: Image, i: int) -> void:
	var o := i * T
	_fill(img, o, 0, 0, T, T, Color("a05a20"))
	_fill(img, o, 0, 0, T, 2, Color(0, 0, 0, 0.3))
	_fill(img, o, 0, 0, 2, T, Color(0, 0, 0, 0.3))
	_fill(img, o, T - 2, 0, 2, T, Color(0, 0, 0, 0.3))
	_fill(img, o, 0, T - 2, T, 2, Color(0, 0, 0, 0.3))

func _stair(img: Image, i: int) -> void:
	var o := i * T
	_fill(img, o, 0, 0, T, T, Color("9c5a28"))
	_fill(img, o, 0, 0, T, 3, Color("c88848"))
	_fill(img, o, 0, 0, 3, T, Color("c88848"))
	_fill(img, o, T - 2, 0, 2, T, Color(0, 0, 0, 0.25))
	_fill(img, o, 0, T - 2, T, 2, Color(0, 0, 0, 0.25))

func _flagbase(img: Image, i: int) -> void:
	var o := i * T
	_fill(img, o, 0, 0, T, T, Color("00aa00"))
	# white up-triangle
	for y in range(4, 12):
		var half := y - 4
		_fill(img, o, 8 - half, y, half * 2, 1, Color.WHITE)

func _shaft(img: Image, i: int) -> void:
	var o := i * T
	_fill(img, o, 7, 0, 2, T, Color("bcbcbc"))

func _castle(img: Image, i: int) -> void:
	var o := i * T
	_fill(img, o, 0, 0, T, T, Color("c84c0c"))
	_fill(img, o, 0, 7, T, 1, Color(0, 0, 0, 0.3))
	_fill(img, o, 8, 0, 1, T, Color(0, 0, 0, 0.3))

func _pipe(img: Image, i: int, path: String) -> void:
	var o := i * T
	var tx: Texture2D = load(path)
	var src := tx.get_image()
	src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	for y in range(min(T, src.get_height())):
		for x in range(min(T, src.get_width())):
			img.set_pixel(o + x, y, src.get_pixel(x, y))
