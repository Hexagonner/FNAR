extends Control

@export var resolution_option: OptionButton
@export var resolution_bar: Node
@export var FPS_node: Node
@export var FPS_checkbox: CheckBox
@export var low_spec_button: Node

const WINDOWED_DEFAULT_SIZE: Vector2i = Vector2i(1920, 1080)

var resolution: Dictionary = {
	"전체화면": null,
	"경계선 없는 창모드": Vector2i(1920, 1080),
	"창모드": Vector2i(1280, 720),
}

# 사용 가능한 해상도(전체화면 인덱스 0을 제외한)의 Vector2i 목록
# Dictionary는 키 순서가 보장되지 않으므로 인덱스-크기 매핑을 별도로 유지한다


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

	# 해상도 옵션 채우기 (순서 보존을 위해 GlobalSetting._resolution_sizes에 인덱스 매핑)
	var current_resolution: Vector2i = get_window().size
	var resolution_select_index: int = 0
	GlobalSetting._resolution_sizes.clear()
	for key in resolution.keys():
		resolution_option.add_item(key)
		var value: Variant = resolution[key]
		if value == null:
			GlobalSetting._resolution_sizes.append(Vector2i.ZERO)  # 전체화면은 더미
		else:
			GlobalSetting._resolution_sizes.append(value as Vector2i)
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
	GlobalSetting.apply_resolution(index)
