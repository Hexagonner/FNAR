extends SpotLight3D

@export var light_button:Node

var is_turned_on:bool = false
func _ready() -> void:
	print(self.name, "light")
	light_button.Light_button_press.connect(light_button_press)
func toggle() -> void:
	if is_turned_on:
		self.visible = false
		$AnimationPlayer.stop()
	else:
		self.visible = true
		$AnimationPlayer.play("blink")
	is_turned_on = !is_turned_on

@warning_ignore("unused_parameter")
func light_button_press(is_pressed) -> void:
	toggle()
