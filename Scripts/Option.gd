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

	# 저사양 모드 체크박스 초기화
	#if low_spec_button is CheckBox:
		#(low_spec_button as CheckBox).button_pressed = SaveManager.get_value("low_spec_mode") #GlobalSetting.low_spec_mode

	# GlobalSetting.apply_resolution (예: Alt+Enter / F11 토글) 으로
	# mode/size 가 바뀐 경우 OptionButton.selected 도 같이 맞춰준다.
	# 패널이 닫혀 있어도 signal 만 연결해 두면, 다음에 열렸을 때 dropdown 의
	# 텍스트가 현재 mode 와 일치한다.
	GlobalSetting.resolution_applied.connect(_on_global_resolution_applied)
	# low_spec_mode가 시작 메뉴에서 토글된 경우, 이미 로드된 night_game에
	# 알려 셰이더 비용을 즉시 낮출 수 있도록 한다. (low_spec_button 자체
	# 스크립트가 GlobalSetting을 업데이트하므로 여기서 신호만 연결한다.)
	GlobalSetting.low_spec_changed.connect(_on_low_spec_changed)
	_initialize_resolution_options()


func _on_low_spec_changed(_enabled: bool) -> void:
	# 옵션 패널이 열려 있는 동안 사용자 토글이 가능. low_spec_button 체크박스
	# 상태는 자기 자신의 스크립트가 처리하므로 여기서는 별도 작업 없음.
	# (필요 시 현재 씬의 알려진 셰이더 노드들의 visible/material 토글)
	pass


func _initialize_resolution_options() -> void:
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
	@warning_ignore("unused_variable")
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
		DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_MAXIMIZED:
			resolution_option.selected = 2
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


# GlobalSetting.apply_resolution (예: Alt+Enter / F11 토글) 으로 mode 가 바뀐 뒤
# 호출된다. OptionButton.selected 만 갱신하면 되며, 다시 apply_resolution 을
# 호출하지 않도록 GlobalSetting 에 시그널을 그대로 흘려보내지 않는다 (이 핸들러는
# resolution_applied 의 *수신자* 일 뿐).
func _on_global_resolution_applied(index: int) -> void:
	if index < 0 or index >= resolution_option.item_count:
		return
	resolution_option.selected = index
