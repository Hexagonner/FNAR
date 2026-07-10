extends Node

var normal = preload("res://Theme/Cam_normal_box.stylebox")
var hilight = preload("res://Theme/Cam_hilight_box.stylebox")


@export var cam_buttons_parent:Node
@export var Cam_ui:Node
@export var noise_ani :AnimationPlayer
@export var map_label:Node
@export var Warning_msg:Label
@export var blink_ani:AnimationPlayer
@export var white_noise:Node
@export var white_bg:ColorRect
@export_category("dont touch")
@export var map_light:Node # for optimize light
@export var selected_button:Button
@export var selected_cam: Camera3D

@export_category("Wire Bridge")
@export var wire1: Node
@export var wire2: Node
@export var wire3: Node
@export var wire4: Node

var map_name:Dictionary = {
	"cam1": "왼쪽 복도 구석",
	"cam2": "왼쪽 복도",
	"cam3": "오른쪽 복도 구석",
	"cam4": "오른쪽 복도",
	"cam5": "창고",
	"cam6": "단독 무대",
	"cam7": "뒷 무대",
	"cam8": "식사 구역",
	"cam9": "화장실",
	"cam0": "무대",
	"cam-": "주방",
	"cam+": "Debug",
}

var all_cams:Dictionary = {}
var all_lights:Dictionary = {}

var selected_light: Node3D

# ---- Wire-Camera Bridge ----
# wire 노드 → 해당 wire가 담당하는 cam 버튼 이름들 (lowercase)
var _wire_cam_map: Dictionary = {}
# cam 버튼 이름 (lowercase) → Button 레퍼런스
var _cam_button_dict: Dictionary = {}

# ---- Position Assignment System ----
# cam 버튼 이름 (lowercase) → 원래 위치 (시작 시 저장, 절대 변경 안 함)
var _button_original_positions: Dictionary = {}
# wire → [out-pin → wire] 매핑 캐시 (out-pin이 어느 wire 소속인지)
var _pin_to_wire_cache: Dictionary = {}


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	white_bg.visible =false
	Warning_msg.visible = false
	Cam_ui.visible = false
#여기서 나오는 c들은 for 문속 지역변수(임시)입니다. 또한 for in 구문은 파라미터 값을 검색?할때 쓰입니다.
#주의! 여기서 c는 자식(카메라)입니다. 카메라와 버튼의 이름을 일치시켜야 합니다.
	for c in get_children(): #get_children은 자기 자신의 직계 자식을 조사.
		if c is Camera3D:
			all_cams[c.name.to_lower()] = c
			c.current = false
			c.visible = false
	for c in map_light.get_children():
		if c is Node3D:
			all_lights[c.name.to_lower()] = c
			c.visible = false
	#at first cam on, basic cam is cam0
	map_label.text = map_name["cam0"]
	selected_cam = all_cams["cam0"]
	selected_light = all_lights["cam0"]
	#selected_button = $CamUi/CamButton/CAM0
	blink_ani.play("button_blink")
	map_light.get_child(0).visible = true #office 불켜
	#map_light.get_child(1).visible = true #office 불켜
#.bind를 사용해서 선택된 button 노드를 매개변수cam로 보냅니다.
# here cam is childern which is a cambutton,
	for cam in cam_buttons_parent.get_children():
		if cam is BaseButton:
			cam.connect("cam_button_pressed", set_current_cam.bind(cam))
			_cam_button_dict[cam.name.to_lower()] = cam

	# ---- Wire-Camera Bridge 초기화 ----
	_setup_wire_cam_bridge()


func set_current_cam(cam) -> void:
	if cam.is_disconnected:
		white_noise.rotation_degrees = 0
		white_bg.visible =true
		noise_ani.stop()
		noise_ani.play("disconnected")
	else:
		white_noise.rotation_degrees = randf_range(0.0, 12.0)
		noise_ani.stop()
		noise_ani.play("noise")
		white_bg.visible =false

	var prev_button = selected_button
	selected_cam.visible = false
	selected_light.visible = false
	selected_cam.current = false
	map_label.text = map_name[cam.name.to_lower()]
	selected_cam = all_cams[cam.name.to_lower()]
	selected_light = all_lights[cam.name.to_lower()]
	selected_button = cam
	selected_cam.visible = true
	selected_light.visible = true
	selected_cam.current = true

	# 이전 버튼만 normal로, 새로 선택한 버튼만 hilight로 (hover 시에도 블링크 유지)
	if prev_button != null and prev_button != cam:
		prev_button.add_theme_stylebox_override("focus", normal)
		prev_button.add_theme_stylebox_override("hover", normal)
		prev_button.add_theme_stylebox_override("normal", normal)
		prev_button.add_theme_stylebox_override("pressed", normal)
		if "is_hilight" in prev_button:
			prev_button.is_hilight = false
	selected_button.add_theme_stylebox_override("pressed", hilight)
	selected_button.add_theme_stylebox_override("normal", hilight)
	selected_button.add_theme_stylebox_override("focus", hilight)
	selected_button.add_theme_stylebox_override("hover", hilight)
	if "is_hilight" in selected_button:
		selected_button.is_hilight = true
	if cam.is_disconnected:
		Warning_msg.text = "-경고-\n연결 끊김"
		Warning_msg.visible = true
	elif cam.name.to_lower() == "cam-":
		Warning_msg.text = "-카메라 비활성화됨-\n사운드 전용"
		Warning_msg.visible = true
	else:
		Warning_msg.visible = false
		#for kitchen sound only alart

# ---- Wire-Camera Bridge Functions ----
func _setup_wire_cam_bridge() -> void:
	# wire → 담당 cam 목록 매핑 (기본 할당)
	_wire_cam_map = {
		wire1: ["cam1", "cam2", "cam5"],
		wire2: ["cam3", "cam4"],
		wire3: ["cam6", "cam7", "cam8"],
		wire4: ["cam0", "cam9", "cam-"],
	}
	
	# 모든 버튼의 원래 위치 저장
	for cam_name: String in _cam_button_dict.keys():
		var button: Button = _cam_button_dict[cam_name]
		_button_original_positions[cam_name] = button.position
	
	# pin → wire 매핑 캐시 구축
	_build_pin_to_wire_cache()
	
	for wire: Node in _wire_cam_map.keys():
		if wire == null:
			push_warning("[CameraManager] wire가 null입니다. Night_game.tscn에서 export 변수를 연결했는지 확인하세요.")
			continue
		if not wire.has_signal("connection_changed"):
			push_warning("[CameraManager] %s에 connection_changed 시그널이 없습니다." % wire.name)
			continue
		wire.connection_changed.connect(_on_wire_connection_changed.bind(wire))
	
	# 초기 상태 동기화: 모든 wire의 cam 위치를 연결 상태에 따라 재할당
	_reassign_all_cam_positions()

func _build_pin_to_wire_cache() -> void:
	_pin_to_wire_cache.clear()
	# "pins" 그룹의 OUT 핀을 순회 → 어떤 wire의 out_pins에 속하는지 검사
	var all_pins: Array = get_tree().get_nodes_in_group("pins")
	for pin: Node in all_pins:
		if pin.get("pin_type") == "OUT":
			for wire: Node in _wire_cam_map.keys():
				if wire == null:
					continue
				if wire.is_my_out_pin(pin):
					_pin_to_wire_cache[pin] = wire
					break

func _find_pins_recursive(node: Node, owner_wire: Node) -> void:
	if node is Marker3D:
		_pin_to_wire_cache[node] = owner_wire
	for child: Node in node.get_children():
		_find_pins_recursive(child, owner_wire)

## out-pin이 어느 wire에 속하는지 반환 (없으면 null)
func _get_wire_for_pin(pin: Node) -> Node:
	if pin in _pin_to_wire_cache:
		return _pin_to_wire_cache[pin]
	# 캐시 미스: 부모 계층 탐색
	var current: Node = pin
	while current != null:
		if current in _wire_cam_map:
			_pin_to_wire_cache[pin] = current
			return current
		current = current.get_parent()
	return null

## 모든 wire의 cam 버튼 위치를 현재 연결 상태에 따라 재할당
## 규칙:
##   1. 연결된 wire (pin1 → pin2) → pin2 주인의 cam 기본 위치 우선 할당
##   2. 연결 안 된 wire → 자신의 pin2가 비어있으면 자신, 없으면 다른 빈 pin2
##   3. cam 그룹 크기가 달라도 남는 cam들은 전역 남은 슬롯에 중복 없이 배정
##   4. 결과: 모든 cam이 서로 다른 pin2 위치에 배치 (겹침 없음)
func _reassign_all_cam_positions() -> void:
	var wires: Array = _wire_cam_map.keys()
	var target_map: Dictionary = {}  # wire → source_wire (이 wire의 기본 위치를 사용)
	var used_sources: Array = []

	# Phase 1: 연결된 wire → 대상 wire의 기본 위치로 (강제)
	# 주의: force_connect_to_out_pin으로 pin2를 빼앗긴 wire는
	# is_connected=true지만 current_out_pin의 connected_wire가 자신이 아님 → 제외
	for wire: Node in wires:
		if not wire.get("is_connected"):
			continue
		var out_pin: Node = wire.get("current_out_pin")
		if out_pin == null:
			continue
		# 이 wire가 실제로 이 out_pin의 legitimate 사용자인지 확인
		if out_pin.get("connected_wire") != wire:
			# pin2를 다른 wire에게 빼앗긴 상태 → 연결 끊긴 것으로 간주
			continue
		var target: Node = _get_wire_for_pin(out_pin)
		if target == null:
			continue
		target_map[wire] = target
		used_sources.append(target)

	# Phase 2: 연결 안 된 wire → 빈 pin2 위치 찾기 (자신 우선)
	for wire: Node in wires:
		if wire in target_map:
			continue
		if wire not in used_sources:
			target_map[wire] = wire
			used_sources.append(wire)
		else:
			for potential: Node in wires:
				if potential in used_sources:
					continue
				target_map[wire] = potential
				used_sources.append(potential)
				break

	# Phase 3: 전역 position pool 할당
	# 1차: 각 wire의 cam들 → target wire의 기본 위치(index matching, target 크기만큼)
	# 2차: 남은 cam들 → 남은 position slot에 중복 없이 배정
	var assigned_slots: Array = []  # 사용된 slot (cam_name 기준)
	var cam_positions: Dictionary = {}  # cam_name → Vector2

	# 1차: index-by-index 우선 할당 (slot이 이미 사용 중이면 skip)
	for wire: Node in wires:
		var own_cams: Array = _wire_cam_map.get(wire, [])
		var target: Node = target_map.get(wire, wire)
		var target_cams: Array = _wire_cam_map.get(target, [])
		for i: int in range(own_cams.size()):
			if i < target_cams.size():
				var slot: String = target_cams[i]
				if slot in assigned_slots:
					continue  # 이미 다른 wire가 이 slot 사용 중 → skip
				cam_positions[own_cams[i]] = _button_original_positions[slot]
				assigned_slots.append(slot)

	# 2차: 남은 cam들 → 남은 slot에 순차 배정
	var unassigned_cams: Array = []
	for wire: Node in wires:
		for cam_name: String in _wire_cam_map.get(wire, []):
			if cam_name not in cam_positions:
				unassigned_cams.append(cam_name)
	var available_slots: Array = []
	for slot: String in _button_original_positions.keys():
		if slot not in assigned_slots:
			available_slots.append(slot)
	for i: int in range(unassigned_cams.size()):
		if i < available_slots.size():
			cam_positions[unassigned_cams[i]] = _button_original_positions[available_slots[i]]

	# Phase 4: 모든 cam 버튼 위치 + disconnected 상태 적용
	for wire: Node in wires:
		var own_cams: Array = _wire_cam_map.get(wire, [])
		var wire_connected: bool = wire.get("is_connected")
		for cam_name: String in own_cams:
			var button: Button = _cam_button_dict.get(cam_name) as Button
			if button == null:
				continue
			if cam_name in cam_positions:
				button.position = cam_positions[cam_name]
			button.is_disconnected = not wire_connected
		_update_current_cam_state(own_cams)


@warning_ignore("shadowed_variable_base_class")
func _on_wire_connection_changed(_is_connected: bool, _wire: Node) -> void:
	_reassign_all_cam_positions()

func _update_current_cam_state(cam_names: Array) -> void:
	if selected_button != null and selected_button.name.to_lower() in cam_names:
		if selected_cam.current:
			if selected_button.is_disconnected:
				white_noise.rotation_degrees = 0
				white_bg.visible = true
				noise_ani.stop()
				noise_ani.play("disconnected")
				Warning_msg.text = "-경고-\n연결 끊김"
				Warning_msg.visible = true
			else:
				white_noise.rotation_degrees = randf_range(0.0, 12.0)
				white_bg.visible = false
				noise_ani.stop()
				noise_ani.play("noise")
				Warning_msg.visible = false

# (구 _undo_swap_for_wire, _restore_single_wire, _swap_positions_between_wires는
#  _reassign_all_cam_positions로 대체되어 제거됨)

func enable_camera_display() -> void:

	#if name.to_lower() == "cam-":
		#Warning_msg.text = "-카메라 비활성화됨-\n사운드 전용"
		#Warning_msg.visible = true
	
	if selected_button.is_disconnected:
		Warning_msg.text = "-경고-\n연결 끊김"
		Warning_msg.visible = true
		white_noise.rotation_degrees = 0
		white_bg.visible =true
		noise_ani.play("disconnected")
	elif selected_button.name.to_lower() == "cam-":
		Warning_msg.text = "-카메라 비활성화됨-\n사운드 전용"
		Warning_msg.visible = true
	else:
		white_noise.rotation_degrees = randf_range(0.0, 12.0)
		noise_ani.stop()
		noise_ani.play("noise")
		white_bg.visible =false
		Warning_msg.visible = false
		$cam_start_sound.play()
	selected_cam.visible = true
	selected_light.visible = true
	selected_cam.current = true
	selected_button.button_pressed = true
	Cam_ui.visible = true
	
func disable_camera_display() -> void:
	$cam_start_sound.stop()
	selected_cam.visible = false
	selected_light.visible = false
	selected_cam.current = false
	Cam_ui.visible = false

func blink_button() -> void:
	selected_button.button_blink()
	
	#function for animation 

func white_glitch_play() -> void:
	$CamUi/Noise_ani.play("noise_no_sound")


## low_spec_mode 토글. 풀스크린 셰이더(CRT_shader, Glitch, CRT_noise)의
## low_spec_mode 파라미터를 켜고, 값이 비싸지만 화면 전체에 깔리는
## colorrect 자체를 끄는 방식으로 비용을 크게 줄인다.
## night_game.gd에서 호출된다.
func apply_low_spec_mode(enabled: bool) -> void:
	# 카메라 매니저는 set_shader_parameter로 셰이더에 직접 접근한다.
	# 노드는 _ready 시점에 존재하므로 안전한 get_node_or_null 사용.
	var crt_shader_rect: CanvasItem = get_node_or_null("CanvasLayer/CamUi/CRT_shader") as CanvasItem
	var glitch_rect: CanvasItem = get_node_or_null("CanvasLayer/CamUi/Glitch") as CanvasItem
	var crt_noise_rect: CanvasItem = get_node_or_null("CanvasLayer/CamUi/CRT_noise") as CanvasItem
	var white_noise_rect: CanvasItem = get_node_or_null("CanvasLayer/CamUi/White_noise") as CanvasItem

	# low_spec이 켜져 있으면 가장 비싼 CRT_shader 풀스크린 셰이더는 완전히 끈다.
	# (이 ColorRect는 화면 전체에 한 번 더 풀스크린 셰이더를 적용한다.)
	if crt_shader_rect != null:
		crt_shader_rect.visible = not enabled
		if crt_shader_rect.material is ShaderMaterial:
			(crt_shader_rect.material as ShaderMaterial).set_shader_parameter("low_spec_mode", enabled)
	if glitch_rect != null:
		glitch_rect.visible = glitch_rect.visible and not enabled
		if glitch_rect.material is ShaderMaterial:
			(glitch_rect.material as ShaderMaterial).set_shader_parameter("low_spec_mode", enabled)
	if crt_noise_rect != null:
		crt_noise_rect.visible = not enabled
		if crt_noise_rect.material is ShaderMaterial:
			(crt_noise_rect.material as ShaderMaterial).set_shader_parameter("low_spec_mode", enabled)
	# White_noise는 살짝 비싼 CRT 효과만 적용되므로 끄지 않고 셰이더 cost만 줄임.
	if white_noise_rect != null and white_noise_rect.material is ShaderMaterial:
		(white_noise_rect.material as ShaderMaterial).set_shader_parameter("low_spec_mode", enabled)
