extends Label

signal FPS_is_toggle

var _last_fps: float = -1.0

func _ready() -> void:
	self.visible = GlobalSetting.is_show_fps
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	connect("FPS_is_toggle",fps_show)

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	if visible:
		var current_fps := Engine.get_frames_per_second()
		if current_fps != _last_fps:
			_last_fps = current_fps
			self.text = str(current_fps)
	
@warning_ignore("unused_parameter")
func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("Show_fps"):
		FPS_is_toggle.emit()
		
func fps_show() -> void:
	GlobalSetting.is_show_fps = !GlobalSetting.is_show_fps
	self.visible = GlobalSetting.is_show_fps
	if visible:
		_last_fps = -1  # 다음 _process에서 즉시 갱신되도록
