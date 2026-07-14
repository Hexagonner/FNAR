extends Area3D

@export var ignore_press = false
@export var Left_Light_button : Node
@export var Right_Light_button : Node
@onready var Button_ani = $AnimationPlayer

signal Light_button_press(is_press)

var pressed:bool = false



@warning_ignore("unused_parameter")
func _input_event(camera: Camera3D, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if ignore_press:
			$cancel_sound.play()
			return
		if pressed:
			Button_ani.play("Unpressed")
			Light_button_press.emit(0)
		else:
			if self == Left_Light_button and Right_Light_button.pressed: 
				Right_Light_button.turn_off_light()
			elif self == Right_Light_button and Left_Light_button.pressed: 
				Left_Light_button.turn_off_light()
			Button_ani.play("Pressed")
			Light_button_press.emit(1)
		pressed = !pressed
		
func turn_off_button_light() -> void:
	$OmniLight3D.visible =false
		
		
func turn_off_light() -> void:
	
	if pressed:
		Button_ani.play("Unpressed")
		Light_button_press.emit(0)
		pressed = !pressed
		
