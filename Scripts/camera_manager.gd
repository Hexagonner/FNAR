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
	# wire → 담당 cam 목록 매핑
	_wire_cam_map = {
		wire1: ["cam1", "cam2", "cam5"],
		wire2: ["cam3", "cam4"],
		wire3: ["cam6", "cam7", "cam8"],
		wire4: ["cam0", "cam9"],
	}
	
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

@warning_ignore("shadowed_variable_base_class")
func _on_wire_connection_changed(is_connected: bool, wire: Node) -> void:
	_apply_wire_state(wire, is_connected)

@warning_ignore("shadowed_variable_base_class")
func _apply_wire_state(wire: Node, is_connected: bool) -> void:
	var cam_names: Array = _wire_cam_map.get(wire, [])
	for cam_name: String in cam_names:
		var button: Node = _cam_button_dict.get(cam_name)
		if button != null:
			button.is_disconnected = not is_connected
	
	# 현재 선택된 카메라의 연결 상태가 변경되었으면 실시간 업데이트
	if selected_button != null and selected_button.name.to_lower() in cam_names:
		# 카메라가 켜져있으면 상태 업데이트
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

func enable_camera_display() -> void:
	if selected_button.is_disconnected:
		white_noise.rotation_degrees = 0
		white_bg.visible =true
		noise_ani.play("disconnected")
	else:
		white_noise.rotation_degrees = randf_range(0.0, 12.0)
		noise_ani.stop()
		noise_ani.play("noise")
		white_bg.visible =false
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
	
