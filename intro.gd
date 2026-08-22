extends Node2D
## Boot intro (this is the project's main scene). Replicates the GOOSE PRANDINI
## MEDIA splash from the wrestling game: the logo fades in/holds/out over a fixed
## 10s on black while `intro/apog.mp3` plays, then a PURPLE MARIO title card +
## controls + a blinking PRESS P TO START. Any P jumps into the game (Main.tscn).

const VIEW_W := 256
const VIEW_H := 240
const LOGO_TIME := 10.0        # total logo duration (matches the wrestling intro)
const CON_TIME := 5.0          # controls screen (con.png) shown this long after the logo

# The 12 "real" levels players actually see, in order → their play-slot (level_num).
# The other slots are cutscene/demo/extra rooms and are hidden from the records screen.
const RECORD_LEVELS := [
	["1-1", 1], ["1-2", 2], ["1-3", 3], ["1-4", 4],
	["2-1", 7], ["2-2", 6], ["2-3", 13], ["2-4", 15],
	["3-1", 8], ["3-2", 5], ["3-3", 16], ["3-4", 17],
]

const C_PURPLE := Color(0.62, 0.24, 0.92)
const C_WHITE := Color(1, 1, 1)
const C_PROMPT := Color(1.0, 0.9, 0.3)

var font: PixelFont
var img: Texture2D
var img_rect: Rect2
var con_img: Texture2D         # the controls graphic (sprites/new player/con.png)
var con_rect: Rect2
var file_img: Texture2D        # FILE.png — the 3-slot save-file select screen
var file_rect: Rect2
var file_sel := 0              # which of the 3 files is highlighted
var file_idle := 0.0          # seconds idle on the file screen → triggers the attract demo
const ATTRACT_IDLE := 12.0    # idle time before the self-playing demo kicks in
var menu_img: Texture2D        # main1.png — START GAME / LEVEL RECORDS / (locked) LEVEL SELECT
var menu2_img: Texture2D       # main2.png — the UNLOCKED version (LEVEL SELECT active)
var menu_rect: Rect2
var menu_sel := 0             # 0 = START GAME, 1 = LEVEL RECORDS, 2 = LEVEL SELECT
var levelsel_idx := 0        # highlighted cell on the LEVEL SELECT grid (0..11)
var levelsel_back := "menu"  # phase to return to from LEVEL SELECT ("menu" or "file" for the debug cheat)
var _n_count := 0            # consecutive "N" presses on the file screen (NNNNN = debug level select)
const MENU_FRACS := [0.273, 0.505, 0.736]   # the three option row centres in main1/main2.png
var music: AudioStreamPlayer

var phase := "logo"            # logo -> con -> file -> menu -> (records)
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

	# save-file select screen (fit to the full screen width, centred vertically)
	file_img = load("res://sprites/new player/FILE.png")
	var fw := float(file_img.get_width())
	var fh := float(file_img.get_height())
	var fscl: float = VIEW_W / fw
	file_rect = Rect2(0, roundf((VIEW_H - fh * fscl) / 2.0), VIEW_W, roundf(fh * fscl))
	# START GAME / LEVEL RECORDS menu (shown after a file is chosen)
	menu_img = load("res://sprites/new player/main1.png")
	var mw := float(menu_img.get_width())
	var mh := float(menu_img.get_height())
	var mscl: float = VIEW_W / mw
	menu_rect = Rect2(0, roundf((VIEW_H - mh * mscl) / 2.0), VIEW_W, roundf(mh * mscl))
	# the UNLOCKED menu art (LEVEL SELECT active) — only used once a file has beaten the game
	if ResourceLoader.exists("res://sprites/new player/MAIN2.png"):
		menu2_img = load("res://sprites/new player/MAIN2.png")
	Main.load_saves()

	music = AudioStreamPlayer.new()
	music.stream = load("res://intro/apog.mp3")
	add_child(music)
	if music.stream and music.stream is AudioStreamMP3:
		music.stream.loop = false

	# returning from a LEVEL SELECT run → reopen the LEVEL SELECT screen
	if Main.boot_to_levelsel:
		Main.boot_to_levelsel = false
		Main.load_saves()
		levelsel_idx = 0
		levelsel_back = String(Main.ls_back)
		_goto("levelsel")
	# returning from a game via "MAIN MENU" → skip the logo/controls, open the file list
	elif Main.boot_to_files:
		Main.boot_to_files = false
		Main.load_saves()
		_open_files()
	else:
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
				if con_img != null:
					_goto("con")
				else:
					_open_files()      # no controls image → straight to the file list
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
				_open_files()          # after the controls screen, go straight to the file list
		"title":
			pass
		"file":
			file_idle += delta
			if file_idle >= ATTRACT_IDLE:
				_start_attract()
	queue_redraw()


func _goto(p: String) -> void:
	phase = p
	t = 0.0


func _input(event: InputEvent) -> void:
	if phase == "file":
		_file_input(event)
		return
	if phase == "menu":
		_menu_input(event)
		return
	if phase == "records":
		_records_input(event)
		return
	if phase == "levelsel":
		_levelsel_input(event)
		return
	# gamepad: Start (or A) opens the file-select screen
	if event is InputEventJoypadButton and event.pressed and \
			(event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_A):
		_open_files()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = event.keycode
	if kc == KEY_P:
		_open_files()


func _open_files() -> void:
	Main.load_saves()
	file_sel = 0
	file_idle = 0.0
	_goto("file")


func _start_attract() -> void:
	Main.attract_mode = true
	Main.save_slot = -1              # demo touches no save file
	Main.debug_start_level = 1       # auto-play world 1-1
	_start_game()


func _file_input(event: InputEvent) -> void:
	file_idle = 0.0                 # any input resets the attract-demo timer
	# gamepad: D-pad up/down to pick, Start/A to confirm
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_UP:
			file_sel = (file_sel + 2) % 3
		elif event.button_index == JOY_BUTTON_DPAD_DOWN:
			file_sel = (file_sel + 1) % 3
		elif event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_A:
			_confirm_file()
		queue_redraw()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = event.keycode
	# hidden debug cheat: press N five times in a row → LEVEL SELECT (all 12 levels)
	if kc == KEY_N:
		_n_count += 1
		if _n_count >= 5:
			_n_count = 0
			_open_debug_levelsel()
			return
	else:
		_n_count = 0
	if kc == KEY_UP:
		file_sel = (file_sel + 2) % 3
	elif kc == KEY_DOWN:
		file_sel = (file_sel + 1) % 3
	elif kc == KEY_ENTER or kc == KEY_KP_ENTER:
		_confirm_file()
	elif kc == KEY_BACKSPACE:
		var n := String(Main.save_names[file_sel])
		if n.length() > 0:
			Main.save_names[file_sel] = n.substr(0, n.length() - 1)
	elif (kc >= KEY_A and kc <= KEY_Z) or (kc >= KEY_0 and kc <= KEY_9):
		# type into the highlighted file's name (uppercase; the bitmap font is A-Z/0-9)
		if String(Main.save_names[file_sel]).length() < 8:
			Main.save_names[file_sel] = String(Main.save_names[file_sel]) + char(kc)
	queue_redraw()


func _confirm_file() -> void:
	Main.save_slot = file_sel
	if String(Main.save_names[file_sel]) == "":
		Main.save_names[file_sel] = "FILE %d" % (file_sel + 1)   # default name if left blank
	Main.save_saves()
	menu_sel = 0
	_goto("menu")                       # → START GAME / LEVEL RECORDS


func _open_debug_levelsel() -> void:
	Main.save_slot = file_sel            # play/record on the highlighted file
	levelsel_idx = 0
	levelsel_back = "file"               # ESC returns to the file screen
	_goto("levelsel")


func _menu_opts() -> int:
	return 3 if bool(Main.save_beat[Main.save_slot]) else 2   # LEVEL SELECT only when the game's beaten


func _menu_input(event: InputEvent) -> void:
	var opts := _menu_opts()
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_UP:
			menu_sel = (menu_sel + opts - 1) % opts
		elif event.button_index == JOY_BUTTON_DPAD_DOWN:
			menu_sel = (menu_sel + 1) % opts
		elif event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_A:
			_menu_confirm()
		queue_redraw()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = event.keycode
	if kc == KEY_UP:
		menu_sel = (menu_sel + opts - 1) % opts
	elif kc == KEY_DOWN:
		menu_sel = (menu_sel + 1) % opts
	elif kc == KEY_ENTER or kc == KEY_KP_ENTER:
		_menu_confirm()
	elif kc == KEY_ESCAPE:
		_goto("file")                   # back to file select
	queue_redraw()


func _menu_confirm() -> void:
	match menu_sel:
		0:
			Main.debug_start_level = Main.resume_slot()    # resume at the furthest level reached
			_start_game()
		1:
			_goto("records")
		2:
			if bool(Main.save_beat[Main.save_slot]):
				levelsel_idx = 0
				levelsel_back = "menu"
				_goto("levelsel")


func _records_input(event: InputEvent) -> void:
	var back := false
	if event is InputEventJoypadButton and event.pressed:
		back = true
	elif event is InputEventKey and event.pressed and not event.echo:
		back = true
	if back:
		_goto("menu")
		queue_redraw()


func _levelsel_input(event: InputEvent) -> void:
	var col := levelsel_idx / 4      # 0..2 (world)
	var row := levelsel_idx % 4      # 0..3
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: col = (col + 2) % 3
			JOY_BUTTON_DPAD_RIGHT: col = (col + 1) % 3
			JOY_BUTTON_DPAD_UP: row = (row + 3) % 4
			JOY_BUTTON_DPAD_DOWN: row = (row + 1) % 4
			JOY_BUTTON_START, JOY_BUTTON_A: _start_level(); return
			JOY_BUTTON_B: _goto(levelsel_back); queue_redraw(); return
		levelsel_idx = col * 4 + row
		queue_redraw()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_LEFT: col = (col + 2) % 3
		KEY_RIGHT: col = (col + 1) % 3
		KEY_UP: row = (row + 3) % 4
		KEY_DOWN: row = (row + 1) % 4
		KEY_ENTER, KEY_KP_ENTER: _start_level(); return
		KEY_ESCAPE: _goto(levelsel_back); queue_redraw(); return
	levelsel_idx = col * 4 + row
	queue_redraw()


func _start_level() -> void:
	Main.debug_start_level = clampi(int(RECORD_LEVELS[levelsel_idx][1]), 1, Main.LEVEL_COUNT)
	Main.skip_intro = true          # play the full level, no surface-intro/pipe cutscene
	Main.level_select_mode = true   # on clear, return here (no advancing) — practice for times
	Main.ls_back = levelsel_back
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
	elif phase == "file":
		_draw_file()
	elif phase == "menu":
		_draw_menu()
	elif phase == "records":
		_draw_records()
	elif phase == "levelsel":
		_draw_levelsel()
	elif phase == "con" and con_img != null:
		draw_texture_rect(con_img, con_rect, false, Color(1, 1, 1, con_alpha))
	else:
		draw_texture_rect(img, img_rect, false, Color(1, 1, 1, img_alpha))


func _draw_file() -> void:
	var w := float(VIEW_W)
	draw_texture_rect(file_img, file_rect, false)             # the purple 3-slot card
	font.draw_text(self, Vector2(0, file_rect.position.y - 6), "SELECT A FILE", 1.0, C_PROMPT, w)
	var fracs := [0.218, 0.449, 0.681]                        # the three "-FILE-" row centres
	for i in 3:
		var ry: float = file_rect.position.y + fracs[i] * file_rect.size.y
		var sel: bool = (i == file_sel)
		if sel:
			_file_box(Rect2(file_rect.position.x + 4.0, ry - 15.0, file_rect.size.x - 8.0, 30.0), C_PROMPT)
		# name on the LEFT of the row (blinking cursor while it's the selected one)
		var nm := String(Main.save_names[i])
		if sel and fmod(t, 0.6) < 0.35:
			nm += "_"
		var col := C_PROMPT if sel else C_WHITE
		if nm == "":
			nm = "-"
		font.draw_text(self, Vector2(file_rect.position.x + 10.0, ry + 3.0), nm, 1.0, col)
		# highest level reached on the RIGHT (canonical progress index, -1 = never played)
		var hi: int = int(Main.save_highest[i])
		var world := "NEW"
		if hi >= 0:
			world = "WORLD " + String(Main.CANON_LEVELS[clampi(hi, 0, Main.CANON_COUNT - 1)][0])
		var wx: float = file_rect.position.x + file_rect.size.x - 10.0 - font.text_w(world, 1.0)
		font.draw_text(self, Vector2(wx, ry + 3.0), world, 1.0, col)
	font.draw_text(self, Vector2(0, file_rect.position.y + file_rect.size.y + 8.0),
		"UP DOWN PICK   TYPE NAME   ENTER START", 1.0, C_WHITE, w)


func _file_box(r: Rect2, c: Color) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), c)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), c)
	draw_rect(Rect2(r.position, Vector2(2, r.size.y)), c)
	draw_rect(Rect2(r.position + Vector2(r.size.x - 2, 0), Vector2(2, r.size.y)), c)


func _draw_menu() -> void:
	var unlocked := bool(Main.save_beat[Main.save_slot])
	var img: Texture2D = menu2_img if (unlocked and menu2_img != null) else menu_img
	var nm := String(Main.save_names[Main.save_slot])
	font.draw_text(self, Vector2(0, menu_rect.position.y - 6), nm, 1.0, C_WHITE, float(VIEW_W))
	draw_texture_rect(img, menu_rect, false)                  # START GAME / LEVEL RECORDS / LEVEL SELECT
	var sel: int = clampi(menu_sel, 0, _menu_opts() - 1)
	var ry: float = menu_rect.position.y + float(MENU_FRACS[sel]) * menu_rect.size.y
	_file_box(Rect2(menu_rect.position.x + 4.0, ry - 15.0, menu_rect.size.x - 8.0, 30.0), C_PROMPT)


func _draw_levelsel() -> void:
	var w := float(VIEW_W)
	font.draw_text(self, Vector2(0, 22), "LEVEL SELECT", 2.0, C_PURPLE, w)
	if levelsel_back == "file":
		font.draw_text(self, Vector2(0, 8), "DEBUG", 1.0, Color(0.4, 1.0, 0.4), w)
	var best: Array = Main.save_best[Main.save_slot]
	for i in RECORD_LEVELS.size():
		var col := i / 4
		var row := i % 4
		var x := 20.0 + col * 78.0
		var y := 70.0 + row * 22.0
		var seld: bool = (i == levelsel_idx)
		if seld:
			_file_box(Rect2(x - 6.0, y - 12.0, 70.0, 20.0), C_PROMPT)
		var label := String(RECORD_LEVELS[i][0])
		var t: float = float(best[i]) if i < best.size() else 0.0
		font.draw_text(self, Vector2(x, y), label, 1.0, (C_PROMPT if seld else C_WHITE))
		font.draw_text(self, Vector2(x, y + 10.0), _fmt_time(t), 1.0, C_WHITE)
	font.draw_text(self, Vector2(0, float(VIEW_H) - 12), "ENTER PLAY   ESC BACK", 1.0, C_WHITE, w)


func _draw_records() -> void:
	var w := float(VIEW_W)
	font.draw_text(self, Vector2(0, 22), "LEVEL RECORDS", 2.0, C_PURPLE, w)
	var nm := String(Main.save_names[Main.save_slot])
	font.draw_text(self, Vector2(0, 40), nm, 1.0, C_PROMPT, w)
	var best: Array = Main.save_best[Main.save_slot]
	# three columns (one per world), four rows each
	for i in RECORD_LEVELS.size():
		var col := i / 4                                     # 0 = world 1, 1 = world 2, 2 = world 3
		var row := i % 4
		var x := 20.0 + col * 78.0
		var y := 70.0 + row * 22.0
		var label := String(RECORD_LEVELS[i][0])
		var t: float = float(best[i]) if i < best.size() else 0.0
		font.draw_text(self, Vector2(x, y), label, 1.0, C_WHITE)
		font.draw_text(self, Vector2(x, y + 10.0), _fmt_time(t), 1.0, C_PROMPT)
	font.draw_text(self, Vector2(0, float(VIEW_H) - 12), "PRESS ANY KEY TO GO BACK", 1.0, C_WHITE, w)


func _fmt_time(t: float) -> String:
	if t <= 0.0:
		return "---"
	var m := int(t) / 60
	if m > 0:
		return "%d:%05.2f" % [m, t - m * 60]
	return "%.2f" % t


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

	# blinking start prompt
	if t > 2.0 and fmod(t, 0.8) < 0.5:
		font.draw_text(self, Vector2(0, 198), "PRESS P OR START", 1.0, C_PROMPT, w)
