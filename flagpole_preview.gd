@tool
extends Node2D
## Editor-only preview of the flagpole + castle so the end of the level is visible
## while editing Level2.tscn. Draws NOTHING at runtime — the game draws the real
## (animated) flagpole/castle itself (tile_renderer). Keep flag_x/castle_x in sync
## with main.gd's per-level values.

const TILE := 16
const FLOOR := 13
@export var flag_x: int = 192
@export var castle_x: int = 195


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return   # runtime draws the real flagpole/castle; this is editor-only
	var pole_cx := flag_x * TILE + 8
	var pole_top := (FLOOR - 11) * TILE
	var base_top := (FLOOR - 1) * TILE
	# pole
	draw_rect(Rect2(pole_cx - 1, pole_top, 2, base_top - pole_top), Color(0, 1, 0))
	# base block
	var base: Texture2D = load("res://sprites/flagpole_base.png")
	if base:
		draw_texture(base, Vector2(flag_x * TILE, base_top))
	# ball
	var ball: Texture2D = load("res://sprites/flagpole_ball.png")
	if ball:
		draw_texture(ball, Vector2(pole_cx - ball.get_width() / 2.0, pole_top - ball.get_height() + 2))
	# flag at its start position
	var flag: Texture2D = load("res://sprites/flagpole_flag.png")
	if flag:
		draw_texture(flag, Vector2(pole_cx - flag.get_width(), (FLOOR - 11) * TILE + 3))
	# castle
	var castle: Texture2D = load("res://sprites/castle.png")
	if castle:
		draw_texture(castle, Vector2(castle_x * TILE, (FLOOR - 5) * TILE))
