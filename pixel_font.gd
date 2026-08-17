extends RefCounted
class_name PixelFont
## Shared bitmap font drawn from `sprites/new player/LETTERS 1.png` (uppercase
## A-Z, digits, a period). Used by the HUD and the intro so all text matches.
## Draw onto any CanvasItem; caller should set that item's texture_filter to
## NEAREST. Handles space, a drawn "-" and ":", and optional centering.

var tex: Texture2D
var G := {}                    # char -> Rect2i source glyph
const GAP := 1
const SPACE_W := 4
const DASH_W := 3


func _init() -> void:
	tex = load("res://sprites/new player/LETTERS 1.png")
	var digits := "1234567890"
	var dx := [16, 21, 28, 35, 42, 49, 55, 62, 70, 77]
	var dw := [3, 5, 5, 5, 5, 5, 5, 6, 5, 5]
	for i in digits.length():
		G[digits[i]] = Rect2i(dx[i], 11, dw[i], 7)
	var r2 := "ABCDEFGHIJKLMNOP"
	var r2x := [12, 17, 22, 27, 32, 37, 42, 47, 52, 54, 57, 62, 67, 73, 78, 84]
	var r2w := [4, 4, 4, 4, 4, 4, 4, 4, 1, 2, 4, 4, 5, 4, 5, 4]
	for i in r2.length():
		G[r2[i]] = Rect2i(r2x[i], 25, r2w[i], 6)
	# row 3 letters are 6px tall (the y39 pixels are only the Q tail)
	var r3 := "QRSTUVWXYZ"
	var r3x := [18, 24, 29, 34, 40, 45, 51, 59, 65, 71]
	var r3w := [5, 4, 4, 5, 4, 5, 7, 5, 5, 4]
	for i in r3.length():
		G[r3[i]] = Rect2i(r3x[i], 33, r3w[i], 6)
	G["."] = Rect2i(48, 44, 1, 1)


func text_w(s: String, scale: float) -> float:
	var w := 0
	for ch in s.to_upper():
		if ch == " ":
			w += SPACE_W + GAP
		elif ch == "-":
			w += DASH_W + GAP
		elif ch == ":":
			w += 1 + GAP
		elif ch == "!":
			w += 1 + GAP
		elif G.has(ch):
			w += G[ch].size.x + GAP
	return maxf(0.0, (w - GAP)) * scale


## Draw `s` (auto-uppercased) with its baseline at pos.y, left edge pos.x.
## Pass center_w >= 0 to centre it in a box of that width. Coords are snapped
## to whole pixels — a fractional dest garbles NEAREST sampling at 1x scale.
func draw_text(ci: CanvasItem, pos: Vector2, s: String, scale: float,
		col: Color, center_w := -1.0) -> void:
	s = s.to_upper()
	var pen := pos.x
	if center_w >= 0.0:
		pen += (center_w - text_w(s, scale)) / 2.0
	pen = floorf(pen)
	var by := floorf(pos.y)
	for ch in s:
		if ch == " ":
			pen += (SPACE_W + GAP) * scale
		elif ch == "-":
			ci.draw_rect(Rect2(floorf(pen), by - 4.0 * scale, DASH_W * scale, maxf(1.0, scale)), col)
			pen += (DASH_W + GAP) * scale
		elif ch == ":":
			var d := maxf(1.0, scale)
			ci.draw_rect(Rect2(floorf(pen), by - 5.0 * scale, d, d), col)
			ci.draw_rect(Rect2(floorf(pen), by - 2.0 * scale, d, d), col)
			pen += (1 + GAP) * scale
		elif ch == "!":
			# vertical stem + a dot at the baseline (drawn like ".")
			var d2 := maxf(1.0, scale)
			ci.draw_rect(Rect2(floorf(pen), by - 6.0 * scale, d2, 4.0 * scale), col)
			ci.draw_rect(Rect2(floorf(pen), by - 1.0 * scale, d2, d2), col)
			pen += (1 + GAP) * scale
		elif G.has(ch):
			var r: Rect2i = G[ch]
			ci.draw_texture_rect_region(tex,
				Rect2(floorf(pen), by - r.size.y * scale, r.size.x * scale, r.size.y * scale),
				Rect2(r), col)
			pen += (r.size.x + GAP) * scale
