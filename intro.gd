extends Node2D
## Boot intro (this is the project's main scene). Replicates the GOOSE PRANDINI
## MEDIA splash from the wrestling game: the logo fades in/holds/out over a fixed
## 10s on black while `intro/apog.mp3` plays, then a PURPLE MARIO title card +
## controls + a blinking PRESS P TO START. Any P jumps into the game (Main.tscn).

const VIEW_W := 256
const VIEW_H := 240
const LOGO_TIME := 10.0        # total logo duration (matches the wrestling intro)
const CON_TIME := 5.0          # controls screen (con.png) shown this long after the logo

const C_PURPLE := Color(0.62, 0.24, 0.92)
const C_WHITE := Color(1, 1, 1)
const C_PROMPT := Color(1.0, 0.9, 0.3)

var font: PixelFont
var img: Texture2D
var img_rect: Rect2
var con_img: Texture2D         # the controls graphic (sprites/new player/con.png)
var con_rect: Rect2
var music: AudioStreamPlayer

var phase := "logo"            # logo -> con -> title
var t := 0.0                   # seconds spent in the current phase
var img_alpha := 0.0
var con_alpha := 1.0


func _ready() -> void:
	# Render the intro at the real window resolution (not the 256px NES viewport)
	# so the big logo stays crisp/full-size. Restored to viewport for the game.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = PixelFont.new()
	# the 1500x900 logo used EXACTLY as provided — fit to the screen, no resample
	img = load("res://intro/1500.png")
	var iw := float(img.get_width())
	var ih := float(img.get_height())
	var s: float = minf(VIEW_W / iw, VIEW_H / ih)   # fit, preserve aspect (bg is black)
	img_rect = Rect2(roundf((VIEW_W - iw * s) / 2.0), roundf((VIEW_H - ih * s) / 2.0),
		roundf(iw * s), roundf(ih * s))

	# controls graphic shown for 5s after the logo — fit to the screen, preserve aspect.
	# (NB: the source was "con.png", but CON is a reserved Windows device name that breaks file
	# APIs, so it's renamed to controls.png. If it fails to load, the con phase is skipped safely.)
	if ResourceLoader.exists("res://sprites/new player/controls.png"):
		con_img = load("res://sprites/new player/controls.png")
	if con_img != null:
		var cw := float(con_img.get_width())
		var ch := float(con_img.get_height())
		var cs: float = minf(VIEW_W / cw, VIEW_H / ch)
		con_rect = Rect2(roundf((VIEW_W - cw * cs) / 2.0), roundf((VIEW_H - ch * cs) / 2.0),
			roundf(cw * cs), roundf(ch * cs))

	music = AudioStreamPlayer.new()
	music.stream = load("res://intro/apog.mp3")
	add_child(music)
	if music.stream and music.stream is AudioStreamMP3:
		music.stream.loop = false
	music.play()


func _process(delta: float) -> void:
	t += delta
	match phase:
		"logo":
			# fade curve over 10s: in 0-2s, hold 2-8s, out 8-10s (like the CSS)
			if t < 2.0:
				img_alpha = t / 2.0
			elif t < 8.0:
				img_alpha = 1.0
			elif t < LOGO_TIME:
				img_alpha = 1.0 - (t - 8.0) / 2.0
			else:
				img_alpha = 0.0
				music.stop()
				_goto("con" if con_img != null else "title")
		"con":
			# controls screen: brief fade in, hold, brief fade out over CON_TIME seconds
			if t < 0.3:
				con_alpha = t / 0.3
			elif t < CON_TIME - 0.3:
				con_alpha = 1.0
			elif t < CON_TIME:
				con_alpha = 1.0 - (t - (CON_TIME - 0.3)) / 0.3
			else:
				con_alpha = 0.0
				_goto("title")
		"title":
			pass
	queue_redraw()


func _goto(p: String) -> void:
	phase = p
	t = 0.0


func _input(event: InputEvent) -> void:
	# gamepad: Start (or A) begins the game at world 1-1
	if event is InputEventJoypadButton and event.pressed and \
			(event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_A):
		Main.debug_start_level = 1
		_start_game()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = event.keycode
	if kc == KEY_P:
		Main.debug_start_level = 1
		_start_game()
	elif (kc >= KEY_1 and kc <= KEY_9) or kc == KEY_0 or kc == KEY_MINUS or kc == KEY_EQUAL or kc == KEY_BACKSPACE or kc == KEY_BACKSLASH or kc == KEY_BRACKETRIGHT:   # DEBUG stage select (0=10, -=11, ==12, Backspace=13, \=14, ]=15)
		var slot := 15 if kc == KEY_BRACKETRIGHT else (14 if kc == KEY_BACKSLASH else (13 if kc == KEY_BACKSPACE else (12 if kc == KEY_EQUAL else (11 if kc == KEY_MINUS else (10 if kc == KEY_0 else kc - KEY_1 + 1)))))
		Main.debug_start_level = clampi(slot, 1, Main.LEVEL_COUNT)
		_start_game()


func _start_game() -> void:
	if music:
		music.stop()
	# hand the NES pixel viewport back to the game before loading it
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().change_scene_to_file("res://Main.tscn")


func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color.BLACK)   # wrestling intro is on black
	if phase == "title":
		_draw_title()
	elif phase == "con" and con_img != null:
		draw_texture_rect(con_img, con_rect, false, Color(1, 1, 1, con_alpha))
	else:
		draw_texture_rect(img, img_rect, false, Color(1, 1, 1, img_alpha))


func _draw_title() -> void:
	var w := float(VIEW_W)
	var title_a := clampf(t / 0.8, 0.0, 1.0)
	font.draw_text(self, Vector2(0, 66), "PURPLE MARIO", 2.0,
		Color(C_PURPLE, title_a), w)

	var ctrl_a := clampf((t - 1.0) / 0.8, 0.0, 1.0)
	if ctrl_a > 0.0:
		var c := Color(C_WHITE, ctrl_a)
		font.draw_text(self, Vector2(0, 104), "ARROWS TO MOVE", 1.0, c, w)
		font.draw_text(self, Vector2(0, 118), "X TO JUMP", 1.0, c, w)
		font.draw_text(self, Vector2(0, 132), "Z TO RUN AND FIRE", 1.0, c, w)
		font.draw_text(self, Vector2(0, 146), "R RESTART    M MUTE", 1.0, c, w)
		font.draw_text(self, Vector2(0, 162), "GAMEPAD  A JUMP  X RUN  START PAUSE", 1.0,
			Color(0.55, 0.8, 1.0, ctrl_a), w)

	# DEBUG stage select (remove for release)
	if ctrl_a > 0.0:
		font.draw_text(self, Vector2(0, 178), "DEBUG  PRESS 1-8 FOR STAGE", 1.0,
			Color(0.4, 1.0, 0.4, ctrl_a), w)

	# blinking start prompt
	if t > 2.0 and fmod(t, 0.8) < 0.5:
		font.draw_text(self, Vector2(0, 198), "PRESS P OR START", 1.0, C_PROMPT, w)
