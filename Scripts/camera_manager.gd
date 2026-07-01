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

# ---- Position Swap System ----
# cam 버튼 이름 (lowercase) → 원래 위치 (시작 시 저장, 절대 변경 안 함)
var _button_original_positions: Dictionary = {}
# wire → 현재 할당된 cam 버튼 이름 배열 (swap 시 변경됨)
var _wire_cam_assignment: Dictionary = {}
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
	
	# 각 wire의 현재 카메라 할당을 기본값으로 초기화
	for wire: Node in _wire_cam_map.keys():
		_wire_cam_assignment[wire] = _wire_cam_map[wire].duplicate()
	
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
		# 초기 상태 동기화 (wire가 이미 연결/비연결 상태일 수 있음)
		@warning_ignore("shadowed_variable_base_class")
		var is_connected: bool = wire.get("is_connected")
		_apply_wire_state(wire, is_connected)

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

@warning_ignore("shadowed_variable_base_class")
func _on_wire_connection_changed(is_connected: bool, wire: Node) -> void:
	_apply_wire_state(wire, is_connected)
	# wire가 해제될 때, 다른 wire가 이 wire의 out-pin을 사용 중이었다면
	# 그 wire도 disconnected + swap 해제되어야 함
	if not is_connected:
		for other: Node in _wire_cam_map.keys():
			if other == null or other == wire:
				continue
			var other_out_pin: Marker3D = other.get("current_out_pin") as Marker3D
			if other_out_pin == null:
				continue
			if _get_wire_for_pin(other_out_pin) == wire:
				# other가 wire의 out-pin을 쓰고 있었음 → other도 disconnected & swap 해제
				for cam_name: String in _wire_cam_map.get(other, []):
					var button: Node = _cam_button_dict.get(cam_name)
					if button != null:
						button.is_disconnected = true
				_undo_swap_for_wire(other)

				# [핵심 수정] other가 여전히 연결 상태인지 확인
				# force_connect_to_out_pin에 의해 previous wire가 해제된 경우, is_connected가 이미 true
				# 일 수 있으므로 즉시 복구
				var other_still_connected: bool = other.get("is_connected")
				if other_still_connected:
					print("[DEBUG] 잘못 disconnected → 복구: ", other.name)
					for cam_name: String in _wire_cam_map.get(other, []):
						var button: Node = _cam_button_dict.get(cam_name)
						if button != null:
							button.is_disconnected = false
					# swap 다시 실행 (other가 wire의 out-pin에 연결된 상태 유지)
					_swap_positions_between_wires(other, wire)
				_update_current_cam_state(_wire_cam_map.get(other, []))
func _apply_wire_state(wire: Node, is_connected: bool) -> void:
	# wire 자신의 원래 카메라들 (in-pin 기준)
	var own_cams: Array = _wire_cam_map.get(wire, [])

	if not is_connected:
		# 연결 해제: 자신의 카메라들 disconnected + swap 복원
		for cam_name: String in own_cams:
			var button: Node = _cam_button_dict.get(cam_name)
			if button != null:
				button.is_disconnected = true
		_undo_swap_for_wire(wire)
		_update_current_cam_state(own_cams)
		return

	# 연결됨: out-pin의 소유 wire 찾기
	var out_pin: Marker3D = wire.get("current_out_pin") as Marker3D
	var out_wire: Node = null
	if out_pin != null:
		out_wire = _get_wire_for_pin(out_pin)

	# in-pin은 연결됐으므로 disconnected 해제
	for cam_name: String in own_cams:
		var button: Node = _cam_button_dict.get(cam_name)
		if button != null:
			button.is_disconnected = false

	if out_wire == null or out_wire == wire:
		# 자기 own out-pin에 연결 (또는 owner 식별 불가) → swap 없음
		_undo_swap_for_wire(wire)
	else:
		# 교차 연결 (다른 wire의 own out-pin) → 신호 섞임
		_undo_swap_for_wire(wire)
		_undo_swap_for_wire(out_wire)
		_swap_positions_between_wires(wire, out_wire)

	_update_current_cam_state(own_cams)

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

## wire의 swap 상대를 찾아서 양쪽 모두 원래 위치 + 할당 복원
func _undo_swap_for_wire(wire: Node) -> void:
	# 이미 기본 할당 상태면 할 일 없음
	if _wire_cam_assignment.get(wire, []) == _wire_cam_map.get(wire, []):
		return
	
	# swap 상대 찾기: 누가 wire의 원래 카메라들을 현재 할당받고 있는가
	var wire_origin: Array = _wire_cam_map.get(wire, [])
	var swap_partner: Node = null
	for other: Node in _wire_cam_map.keys():
		if other == wire:
			continue
		if _wire_cam_assignment.get(other, []) == wire_origin:
			swap_partner = other
			break
	
	if swap_partner == null:
		# 상대를 못 찾았으면 자신만 복원
		_restore_single_wire(wire)
		return
	
	# 양쪽 모두 복원
	_restore_single_wire(wire)
	_restore_single_wire(swap_partner)

## wire 하나만 원래 위치 + 할당 복원
func _restore_single_wire(wire: Node) -> void:
	var cam_names: Array = _wire_cam_map.get(wire, [])
	for cam_name: String in cam_names:
		var button: Button = _cam_button_dict.get(cam_name) as Button
		if button == null:
			continue
		var original_pos: Vector2 = _button_original_positions.get(cam_name, button.position)
		button.position = original_pos
	_wire_cam_assignment[wire] = _wire_cam_map[wire].duplicate()

## wire_a(in)와 wire_b(out) 사이의 버튼 위치 교환 (교차 연결)
## 모든 위치를 한 풀에 모아서 중복 없이 분배 → 남는 버튼도 위치가 섞임
func _swap_positions_between_wires(wire_a: Node, wire_b: Node) -> void:
	if wire_a == wire_b:
		return
	
	# 각 wire에 원래 할당된 cam 버튼들
	var origin_a: Array = _wire_cam_map.get(wire_a, [])
	var origin_b: Array = _wire_cam_map.get(wire_b, [])
	
	if origin_a.is_empty() or origin_b.is_empty():
		return
	
	# wire_b → wire_a 순서로 현재 위치를 하나의 풀로 합침
	# (wire_a 버튼들이 wire_b 위치부터 차례대로 가져가도록)
	var position_pool: Array[Vector2] = []
	for cam_name: String in origin_b:
		var btn: Button = _cam_button_dict.get(cam_name) as Button
		if btn != null:
			position_pool.append(btn.position)
	for cam_name: String in origin_a:
		var btn: Button = _cam_button_dict.get(cam_name) as Button
		if btn != null:
			position_pool.append(btn.position)
	
	# wire_a 버튼들 → 풀 앞부분 (wire_b 위치 우선)
	for i: int in range(origin_a.size()):
		var cam_name: String = origin_a[i]
		var button: Button = _cam_button_dict.get(cam_name) as Button
		if button == null:
			continue
		button.position = position_pool[i]
	
	# wire_b 버튼들 → 풀 뒷부분 (wire_a 위치 우선 + 남는 것)
	var offset: int = origin_a.size()
	for i: int in range(origin_b.size()):
		var cam_name: String = origin_b[i]
		var button: Button = _cam_button_dict.get(cam_name) as Button
		if button == null:
			continue
		button.position = position_pool[offset + i]
	
	# 할당 배열도 swap (논리적 소유권 교환)
	_wire_cam_assignment[wire_a] = origin_b.duplicate()
	_wire_cam_assignment[wire_b] = origin_a.duplicate()

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
	
