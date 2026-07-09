extends Node

## apply_resolution 호출 시 mode/size 변경 직후 emit 된다.
## Option.gd 가 이 시그널을 받아 resolution_option.selected 를 갱신한다.
signal resolution_applied(index: int)

var is_show_fps: bool = false
var is_motion_blur: bool = true
var low_spec_mode: bool = false
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
func _unhandled_input(event: InputEvent) -> void:
	# ALT+Enter (또는 F11) 전체화면/창모드 토글
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()

func toggle_fullscreen() -> void:
	var current_mode: int = DisplayServer.window_get_mode()
	
	if current_mode == DisplayServer.WINDOW_MODE_WINDOWED or current_mode == DisplayServer.WINDOW_MODE_MAXIMIZED:
		apply_resolution(0)
	else:
		apply_resolution(2)

var _resolution_sizes: Array[Vector2i] = []
func apply_resolution(index: int) -> void:
	# 인덱스 0 == 전체화면, 그 외 == 창모드 + 해상도 적용
	if index <= 0:
		# 전체화면으로 전환. viewport.mode를 먼저 설정해야 OS 윈도우가
		# 그에 맞춰 reposition/resize 되고, 뒤따르는 size/position 설정이
		# 덮어쓰여지지 않는다.
		get_viewport().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		print("[Option] fullscreen mode 4", DisplayServer.window_get_mode())
		resolution_applied.emit(0)
		return


	# 인덱스 -> 크기 매핑
	var size_index: int = index
	if size_index < 0 or size_index >= _resolution_sizes.size():
		return
	var window_size: Vector2i = _resolution_sizes[size_index]
	if window_size == Vector2i.ZERO:
		return

	# 1) viewport(=root Window)의 mode를 먼저 WINDOWED로 변경.
	#    mode 변경 시 OS가 윈도우를 reposition/resize 하므로 size/position은
	#    그 *후*에 적용해야 한다.
	get_viewport().mode = Window.MODE_WINDOWED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# 2) 그 다음 size/position을 설정.
	DisplayServer.window_set_size(window_size)
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	# 창을 화면 중앙에 배치. 정수 나눗셈(소수점 버림)이 의도된 동작이다
	# (픽셀 정렬) → integer_division 경고를 무시한다.
	@warning_ignore("integer_division")
	var pos: Vector2i = Vector2i(
		(screen_size.x - window_size.x) / 2,
		(screen_size.y - window_size.y) / 2,
	)
	DisplayServer.window_set_position(pos)

	print("[Option] windowed: 0 ", window_size, DisplayServer.window_get_mode())
	resolution_applied.emit(index)
