extends Area3D

@export var ignore_press = false
@onready var Button_ani = $AnimationPlayer

signal Light_button_press(is_press:bool)
#@export var index:int =0
var isLightOn :bool = true



@warning_ignore("unused_parameter")
func _input_event(camera: Camera3D, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if ignore_press or Button_ani.is_playing():
			return
		if isLightOn:
			Button_ani.play("Pressed")
		else:
			Button_ani.play("Unpressed")
			
		isLightOn = !isLightOn
		Light_button_press.emit(isLightOn)

		
func force_turn_off_switch() -> void:
	await Button_ani.animation_finished
	Button_ani.play("Unpressed")
	isLightOn = false
	Light_button_press.emit(isLightOn)
