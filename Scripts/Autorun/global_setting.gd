extends Node



###########################################
var is_show_fps:bool = false
var is_motion_blur:bool = true
var low_spec_mode:bool = false

@warning_ignore("unused_parameter")
func _input(event) -> void:
	#ALT ENTER 전체화면 바꾸기 키 (버그있음)
	if Input.is_action_just_pressed("toggle_fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_size(Vector2(1920, 1080))
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
