extends MeshInstance3D


var is_turned_on:bool = false

func _ready() -> void:
	self.visible = true


func toggle() -> void:
	if is_turned_on:
		self.visible = true

	else:
		self.visible = false

	is_turned_on = !is_turned_on

func _on_light_button_right_light_button_press() -> void:
	toggle()


func _on_light_button_left_light_button_press() -> void:
	toggle()
