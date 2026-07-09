extends Control

const start_menu_scene = "res://Scene/start_menu.tscn"
var tips:Array = [
	"모든 상호작용은 클릭으로 가능합니다.",
	"CCTV를 스페이스바로 켤 수 있습니다.",
	"Ctrl 키를 눌러 바로 뒤돌수 있습니다.",
	"Shift 키를 눌러 경비실의 불을 끌 수 있습니다.",
	"CCTV의 신호가 이상 할 시 뒤의 배전함을 고치시오.",
	"키패드로 빠르게 CCTV를 전환 할 수 있습니다.",
	"랜도프는 어두운 사무실을 좋아합니다.",
	"금천이는 밝은 사무실을 좋아합니다.",
	"전화기를 눌러 녹음 된 전화를 끊을 수 있습니다.",
	"주방은 항상 화면이 나오지 않고 소리만 들립니다.",
	"라디유는 바보입니다.",
]
var i:int =0
var count:int = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameManager.is_6am = false
	ResourceLoader.load_threaded_request(start_menu_scene,"PackedScene",true)
	self.visible = false
	tips.shuffle()
	$CenterContainer/Panel/Label2.text = "Tip: "+tips[0]
	process_mode = PROCESS_MODE_ALWAYS


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("exit_main_menu") and not GameManager.is_6am:
		if visible:
			self.visible = false
			get_tree().paused = false
			$unpause.play()
		else:
			self.visible = true
			get_tree().paused = true
			$"../pause".play()
	

	
		
func change_scene(scene) -> void:
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(scene))


func _on_back_button_pressed() -> void:
	if visible:
		@warning_ignore("standalone_expression")
		i=i+1
		count = count + 1
		if count == 20:
			tips.append("당신은 팁을 읽는것을 좋아하는군요!")
		if i >= tips.size():
			i=0
		self.visible = false
		$CenterContainer/Panel/Label2.text = "Tip: "+tips[i]
		if randi_range(0,1000) < 1:
			$CenterContainer/Panel/Label2.text ="It was YOU."
		get_tree().paused = false
		$unpause.play()

func _on_main_button_pressed() -> void:
	change_scene(start_menu_scene)
