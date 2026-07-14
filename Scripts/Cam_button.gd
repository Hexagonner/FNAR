extends Button

@export var is_disconnected:bool = false
var normal = preload("res://Theme/Cam_normal_box.stylebox")
var hilight = preload("res://Theme/Cam_hilight_box.stylebox")
@warning_ignore("unused_signal")
signal cam_button_pressed(cam_node_name)
var is_hilight:bool = false
var self_pos:Vector2

func _ready() -> void:
	self_pos = self.global_position
	#print(name, " pos ", self_pos)
func _pressed() -> void:
	emit_signal("cam_button_pressed")
	
func button_blink() -> void:
	if is_hilight:
		self.add_theme_stylebox_override("focus", hilight)
		self.add_theme_stylebox_override("hover", hilight)
		self.add_theme_stylebox_override("pressed", hilight)
		self.add_theme_stylebox_override("normal", hilight)
		is_hilight = false
	else:
		self.add_theme_stylebox_override("focus", normal)
		self.add_theme_stylebox_override("hover", normal)
		self.add_theme_stylebox_override("pressed", normal)
		self.add_theme_stylebox_override("normal", normal)
		is_hilight = true
	
