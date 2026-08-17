extends SceneTree
func _init():
	var s = load("res://main.gd")
	var e = s.reload()
	print("reload err=", e)
	quit()
