extends Control

@export var resolution_option: OptionButton
@export var resolution_bar: Node
@export var FPS_node: Node
@export var FPS_checkbox: CheckBox
@export var low_spec_button: Node

const WINDOWED_DEFAULT_SIZE: Vector2i = Vector2i(1920, 1080)

var resolution: Dictionary = {
	"전체화면": null,
	"3840×2160": Vector2i(3840, 2160),
	"2560×1440": Vector2i(2560, 1440),
	"1920×1080": Vector2i(1920, 1080),
	"1280×720": Vector2i(1280, 720),
	"854×480": Vector2i(854, 480),
	"640×360": Vector2i(640, 360),
}

# 사용 가능한 해상도(전체화면 인덱스 0을 제외한)의 Vector2i 목록
# Dictionary는 키 순서가 보장되지 않으므로 인덱스-크기 매핑을 별도로 유지한다
var _resolution_sizes: Array[Vector2i] = []

func _ready() -> void:
	# FPS 체크박스 초기화
	FPS_checkbox.button_pressed = GlobalSetting.is_show_fps

	# 모바일 플랫폼 처리
	var platform: String = OS.get_name()
	match platform:
		"Android", "iOS":
			resolution_bar.visible = false
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			pass

	# 해상도 옵션 채우기 (순서 보존을 위해 _resolution_sizes에 인덱스 매핑)
	var current_resolution: Vector2i = get_window().size
	var resolution_select_index: int = 0
	_resolution_sizes.clear()
	for key in resolution.keys():
		resolution_option.add_item(key)
		var value: Variant = resolution[key]
		if value == null:
			_resolution_sizes.append(Vector2i.ZERO)  # 전체화면은 더미
		else:
			_resolution_sizes.append(value as Vector2i)
			if (value as Vector2i).x >= current_resolution.x and (value as Vector2i).y >= current_resolution.y:
				resolution_select_index += 1

	# 현재 창 모드에 맞게 선택값 설정
	match DisplayServer.window_get_mode():
		DisplayServer.WINDOW_MODE_WINDOWED:
			resolution_option.selected = resolution_select_index
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, DisplayServer.WINDOW_MODE_FULLSCREEN:
			resolution_option.selected = 0
		_:
			resolution_option.selected = 0

	self.visible = false


func _on_button_pressed() -> void:
	self.visible = false


func _on_Resolution_option_button_item_selected(index: int) -> void:
	if index < 0 or index >= resolution_option.item_count:
		return
	apply_resolution(index)


func apply_resolution(index: int) -> void:
	# 인덱스 0 == 전체화면, 그 외 == 창모드 + 해상도 적용
	if index <= 0:
		# 전체화면으로 전환 (현재 모드가 이미 전체화면이어도 명시적으로 다시 설정)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		print("[Option] fullscreen mode")
		return

	# 창모드: 일단 WINDOWED로 명시적 전환 (이미 WINDOWED라도 안전)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# 인덱스 -> 크기 매핑 (인덱스 0은 전체화면이므로 1-based로 접근)
	var size_index: int = index - 1
	if size_index < 0 or size_index >= _resolution_sizes.size():
		return
	var window_size: Vector2i = _resolution_sizes[size_index]
	if window_size == Vector2i.ZERO:
		return

	DisplayServer.window_set_size(window_size)
	# 창을 화면 중앙에 배치
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var pos: Vector2i = (screen_size - window_size) / 2
	DisplayServer.window_set_position(pos)

	print("[Option] windowed: ", window_size)
