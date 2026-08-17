extends CanvasLayer
class_name Hud
## Score / coins / world / time readout + COURSE CLEAR overlay, drawn with the
## hand-made bitmap font `sprites/new player/LETTERS 1.png` (uppercase A-Z, the
## digits and a period). Everything is painted by a single Control child so the
## text stays fixed while the camera scrolls.

var main                       # untyped to avoid a cyclic class dependency
var font: PixelFont
var coins_tex: Texture2D       # 3 coin spin frames (16px each), shared with the world
var _canvas: Control
var _msg_text := ""
var _msg_hide_ms := 0


func _ready() -> void:
	font = PixelFont.new()
	coins_tex = load("res://sprites/coins.png")
	_canvas = HudCanvas.new()
	_canvas.hud = self
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.size = Vector2(main.VIEW_W, main.VIEW_H)
	add_child(_canvas)


func show_message(text: String, seconds := 3.0) -> void:
	_msg_text = text
	_msg_hide_ms = Time.get_ticks_msec() + int(seconds * 1000.0)


func refresh() -> void:
	if _msg_text != "" and Time.get_ticks_msec() >= _msg_hide_ms:
		_msg_text = ""
	if _canvas:
		_canvas.queue_redraw()


func _paint(ci: CanvasItem) -> void:
	var w := float(main.VIEW_W)
	# between-level black card: full black, ONLY the next-level name centred
	if main.show_level_card:
		ci.draw_rect(Rect2(0, 0, w, float(main.VIEW_H)), Color.BLACK)
		font.draw_text(ci, Vector2(0, main.VIEW_H / 2.0 - 6), main.level_card_text, 2.0, Color.WHITE, w)
		return
	# top status row
	font.draw_text(ci, Vector2(16, 11), "MARIO", 1.0, Color.WHITE)
	font.draw_text(ci, Vector2(16, 21), str(main.score).pad_zeros(6), 1.0, Color.WHITE)
	# spinning coin icon (A1/A2/A3), same cadence as the world coins, just smaller
	var cf: int = int(main.qanim_phase / main.QANIM_STEP) % 3
	ci.draw_texture_rect_region(coins_tex, Rect2(87, 12, 7, 9),
		Rect2(cf * 16 + 3, 1, 10, 14))
	font.draw_text(ci, Vector2(97, 21), "X" + str(main.coins).pad_zeros(2), 1.0, Color.WHITE)
	font.draw_text(ci, Vector2(150, 11), "WORLD", 1.0, Color.WHITE)
	font.draw_text(ci, Vector2(159, 21), main.world_label, 1.0, Color.WHITE)
	font.draw_text(ci, Vector2(206, 11), "TIME", 1.0, Color.WHITE)
	font.draw_text(ci, Vector2(206, 21), main.time_string(), 1.0, Color.WHITE)

	# COURSE CLEAR overlay — shows how fast the stage was beaten
	if main.game_state == "clear":
		var cy: float = main.VIEW_H / 2.0 - 50.0
		# solid dark band so the busy castle behind doesn't bleed through the text
		ci.draw_rect(Rect2(0, cy - 32, w, 64), Color(0.04, 0.04, 0.06, 1.0))
		font.draw_text(ci, Vector2(0, cy - 10), "COURSE CLEAR", 2.0, Color.WHITE, w)
		font.draw_text(ci, Vector2(0, cy + 8), "TIME " + main.time_string(), 1.0, Color.WHITE, w)
		# auto-advancing to 1-2 → no restart prompt; only show it on the final clear
		if not main.advancing:
			font.draw_text(ci, Vector2(0, cy + 22), "PRESS R TO RESTART", 1.0, Color.WHITE, w)

	# Level10 Sonic preview: name the current animation at the bottom
	if main.sonic_demo:
		var nm: String = String(main.sonic_state).to_upper() + "  " + ("RIGHT" if main.sonic_face == "r" else "LEFT")
		font.draw_text(ci, Vector2(0, float(main.VIEW_H) - 12), nm, 1.0, Color(0.5, 1.0, 0.6), w)

	# mac's rescue line (Bowser's castle) — centred lines in a dark band, shown after
	# Mario reaches him and BEFORE the COURSE CLEAR card
	if main.show_rescue_speech:
		var lines: Array = main.RESCUE_SPEECH_LINES
		var lh := 12.0          # same line height / size as Sonic's speech
		var mx: float = main.rescue_pos.x - main.cam_x     # mac's on-screen centre
		var boxw := 0.0
		for ln in lines:
			boxw = maxf(boxw, font.text_w(String(ln), 1.0))
		boxw += 12.0
		mx = clampf(mx, boxw / 2.0 + 2.0, w - boxw / 2.0 - 2.0)
		# sit the block directly above mac's head (feet at rescue_pos.y, sprite MAC_H tall)
		var boxh: float = lh * lines.size() + 6.0
		var by: float = (main.rescue_pos.y - main.MAC_H) - 6.0 - boxh
		ci.draw_rect(Rect2(mx - boxw / 2.0, by, boxw, boxh), Color(0.04, 0.04, 0.06, 1.0))
		var yy := by + 10.0
		for ln in lines:
			var lw2: float = font.text_w(String(ln), 1.0)
			font.draw_text(ci, Vector2(mx - lw2 / 2.0, yy), String(ln), 1.0, Color(1.0, 0.92, 0.35))
			yy += lh

	# 1-2 Sonic cutscene: his "congratulations / take the pipe" line, floating near him
	if main.sonic_speech:
		var slines: Array = main.sonic_speech_lines
		var sx: float = main.sonic_x - main.cam_x          # Sonic's on-screen x (camera is locked)
		var lh := 12.0
		var stop := 104.0
		var boxw := 0.0
		for ln in slines:
			boxw = maxf(boxw, font.text_w(String(ln), 1.0))
		boxw += 12.0
		sx = clampf(sx, boxw / 2.0 + 2.0, w - boxw / 2.0 - 2.0)
		ci.draw_rect(Rect2(sx - boxw / 2.0, stop - 10.0, boxw, lh * slines.size() + 6.0), Color(0.05, 0.05, 0.08, 0.92))
		var syy := stop
		for ln in slines:
			var lw2: float = font.text_w(String(ln), 1.0)
			font.draw_text(ci, Vector2(sx - lw2 / 2.0, syy), String(ln), 1.0, Color(1.0, 0.92, 0.35))
			syy += lh

	# transient centred message (e.g. the hidden-block love note)
	if _msg_text != "":
		font.draw_text(ci, Vector2(0, main.VIEW_H / 3.0), _msg_text, 2.0, Color(1.0, 0.6, 0.75), w)

	# stage-start fade-in: a black veil over the whole screen that fades to clear
	if main.fade_alpha > 0.0:
		ci.draw_rect(Rect2(0, 0, w, float(main.VIEW_H)), Color(0, 0, 0, main.fade_alpha))

	# pause menu (drawn last so it sits on top of everything)
	if main.paused:
		_paint_pause(ci, w)


func _paint_pause(ci: CanvasItem, w: float) -> void:
	var h := float(main.VIEW_H)
	var sel := int(main.pause_sel)
	# dim the frozen game, then a framed panel
	ci.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.72))
	var pw := 180.0
	var px := (w - pw) / 2.0
	var py := 54.0
	var ph := 138.0
	ci.draw_rect(Rect2(px, py, pw, ph), Color(0.10, 0.10, 0.16, 0.96))
	ci.draw_rect(Rect2(px, py, pw, 2), Color.WHITE)
	ci.draw_rect(Rect2(px, py + ph - 2, pw, 2), Color.WHITE)
	ci.draw_rect(Rect2(px, py, 2, ph), Color.WHITE)
	ci.draw_rect(Rect2(px + pw - 2, py, 2, ph), Color.WHITE)

	font.draw_text(ci, Vector2(0, py + 24), "PAUSED", 2.0, Color.WHITE, w)

	_paint_vol_row(ci, py + 52, "MUSIC", main.music_volume, sel == 0)
	_paint_vol_row(ci, py + 74, "SOUND", main.sfx_volume, sel == 1)
	_paint_filter_row(ci, py + 96, sel == 2)

	# controls hint
	var hint := Color(0.7, 0.7, 0.78)
	font.draw_text(ci, Vector2(0, py + ph - 14), "UP DOWN PICK   LEFT RIGHT SET", 1.0, hint, w)
	font.draw_text(ci, Vector2(0, py + ph - 5), "ESC RESUME", 1.0, hint, w)


# One "LABEL [######----] 60" row. `by` is the text baseline.
func _paint_vol_row(ci: CanvasItem, by: float, label: String, vol: float, selected: bool) -> void:
	var lx := (float(main.VIEW_W) - 180.0) / 2.0 + 14.0
	var col := Color(1.0, 0.85, 0.2) if selected else Color.WHITE
	if selected:
		# little cursor triangle to the left of the row
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(lx - 10, by - 6), Vector2(lx - 4, by - 3), Vector2(lx - 10, by)]), col)
	font.draw_text(ci, Vector2(lx, by), label, 1.0, col)
	# 10-segment bar
	var bx := lx + 42.0
	var bw := 80.0
	var bh := 7.0
	var top := by - 7.0
	ci.draw_rect(Rect2(bx, top, bw, bh), Color(0.06, 0.06, 0.1))
	var segs := 10
	var gap := 1.0
	var sw := (bw - gap * (segs - 1)) / segs
	var lit := int(round(vol * segs))
	for i in segs:
		var sx := bx + i * (sw + gap)
		var on := i < lit
		var c := col if on else Color(0.28, 0.28, 0.34)
		ci.draw_rect(Rect2(sx, top, sw, bh), c)
	ci.draw_rect(Rect2(bx - 1, top - 1, bw + 2, bh + 2), col, false, 1.0)
	# percentage
	font.draw_text(ci, Vector2(bx + bw + 6, by), str(int(round(vol * 100))), 1.0, col)


# "FILTER  < CRT >" row — cycles the display filter instead of a volume bar.
func _paint_filter_row(ci: CanvasItem, by: float, selected: bool) -> void:
	var lx := (float(main.VIEW_W) - 180.0) / 2.0 + 14.0
	var col := Color(1.0, 0.85, 0.2) if selected else Color.WHITE
	if selected:
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(lx - 10, by - 6), Vector2(lx - 4, by - 3), Vector2(lx - 10, by)]), col)
	font.draw_text(ci, Vector2(lx, by), "FILTER", 1.0, col)
	var fname: String = main.FILTER_NAMES[int(main.filter_mode)]
	var vx := lx + 46.0             # where the value block starts
	var vw := 78.0                  # value block width (matches the bars' span)
	# left / right cycle arrows framing the current filter name
	var midy := by - 3.0
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(vx, midy), Vector2(vx + 5, midy - 4), Vector2(vx + 5, midy + 4)]), col)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(vx + vw, midy), Vector2(vx + vw - 5, midy - 4), Vector2(vx + vw - 5, midy + 4)]), col)
	# filter name centred between the arrows
	font.draw_text(ci, Vector2(vx + 8, by), fname, 1.0, col, vw - 16.0)


# The actual drawing surface: a Control so the HUD stays screen-fixed.
class HudCanvas extends Control:
	var hud
	func _draw() -> void:
		hud._paint(self)
