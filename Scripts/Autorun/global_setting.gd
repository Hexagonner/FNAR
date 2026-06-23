extends Node

var is_show_fps: bool = false
var is_motion_blur: bool = true
var low_spec_mode: bool = false

func _unhandled_input(event: InputEvent) -> void:
	# ALT+Enter (또는 F11) 전체화면/창모드 토글
	# InputMap 액션이 누락되어도 동작하도록 InputEventKey를 직접 검사한다
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event
		var is_alt: bool = key_event.alt_pressed
		var is_enter: bool = key_event.physical_keycode == KEY_ENTER or key_event.keycode == KEY_ENTER
		var is_f11: bool = key_event.physical_keycode == KEY_F11 or key_event.keycode == KEY_F11
		if (is_alt and is_enter) or is_f11:
			toggle_fullscreen()
			get_viewport().set_input_as_handled()

func toggle_fullscreen() -> void:
	var current_mode: int = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		# 창을 화면 중앙에 배치
		var screen_size: Vector2i = DisplayServer.screen_get_size()
		var window_size: Vector2i = DisplayServer.window_get_size()
		@warning_ignore("integer_division")
		var center_pos: Vector2i = (screen_size - window_size) / 2
		DisplayServer.window_set_position(center_pos)
		print("[GlobalSetting] switched to windowed mode: ", window_size)
