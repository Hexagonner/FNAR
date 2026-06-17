extends Control

@export var resolution_option:Node
@export var resolution_bar:Node
@export var FPS_node:Node
@export var FPS_checkbox:CheckBox
@export var low_spec_button:Node
#var is_mobile:bool =false

var resolution:Dictionary = {
	"전체화면":null,
	"3840×2160": Vector2i(3840,2160),
	"2560×1440": Vector2i(2560,1440),
	"1920×1080": Vector2i(1920,1080),
	"1280×720": Vector2i(1280,720),
	"854×480": Vector2i(854,480),
	"640×360": Vector2i(640,360),
}
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#설정값 로드하기.
	####Fps 체크박스 확인
	FPS_checkbox.button_pressed = GlobalSetting.is_show_fps
	#### 초기 해상도 설정
	var platform := OS.get_name()
	match platform:
		"Android","iOS":
			#low_spec_button.visible = false
			resolution_bar.visible = false
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"Windows", "Linux", "macOS":
			pass
	##################현재 해상도로 설정 세팅값을 바꾸기.
	var current_resoltion = get_window().size
	var resolution_select_index:int = 0
	for list in resolution:
		
		resolution_option.add_item(list)
		if resolution[list] == null:
			pass #전체화면 null 패스하기. 
		elif resolution[list].x >= current_resoltion.x and resolution[list].y >= current_resoltion.y:
			resolution_select_index +=1
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			resolution_option.selected = resolution_select_index #1920으로 설정.
	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			resolution_option.selected =0 # 전체화면으로 설정.
			
	####################		
	self.visible = false #설정 창 가리


# Called every frame. 'delta' is the elapsed time since the previous frame.

func _on_button_pressed() -> void:
	self.visible = false
	#설정 닫기 버튼 

@warning_ignore("unused_parameter")
func _input(event) -> void:
	#ALT ENTER 전체화면 바꾸기 키 (버그있음)
	if Input.is_action_just_pressed("toggle_fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			resolution_option.selected =0 # 전체화면으로 설정.
		elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			resolution_option.selected =3 #1920으로 설정.


func _on_Resolution_option_button_item_selected(index: int) -> void:
	if index == 0:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var window_size = resolution.get(resolution_option.get_item_text(index))
		#get_window().set_size(window_size)
		DisplayServer.window_set_size(window_size)
		
		#Debug
		print("size_change")
		print(get_window().size)
