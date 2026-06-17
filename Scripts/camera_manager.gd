extends Node

var normal = preload("res://Theme/Cam_normal_box.stylebox")
var hilight = preload("res://Theme/Cam_hilight_box.stylebox")

@export var map_light:Node # for optimize light

@export var cam_buttons_parent:Node
@export var Cam_ui:Node
@export var noise_ani :Node
@export var map_label:Node
@export var Warning_msg:Node
@export var blink_ani:Node
@export var white_noise:Node

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
@export var selected_cam: Camera3D
var selected_light: Node3D
@export var selected_button:Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
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


func set_current_cam(cam) -> void:
	white_noise.rotation_degrees = randf_range(0.0, 12.0)
	#print($CamUi/White_noise.rotation_degrees)
	noise_ani.stop()
	noise_ani.play("noise")

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

	if cam.name.to_lower() == "cam-":
		Warning_msg.visible = true
	else:
		Warning_msg.visible = false
		#for kitchen sound only alart
func enable_camera_display() -> void:
	selected_cam.visible = true
	selected_light.visible = true
	selected_cam.current = true
	selected_button.button_pressed = true
	Cam_ui.visible = true
	noise_ani.play("noise")
	$cam_start_sound.play()
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
	
