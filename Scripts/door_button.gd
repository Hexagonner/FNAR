extends Area3D

@onready var Button_ani = $AnimationPlayer
@onready var Delay_timer = $Timer
signal Door_button_press()

@export var pressed:bool = false
@export var ignore_press:bool = false


@warning_ignore("unused_parameter")
func _input_event(camera: Camera3D, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if ignore_press:
			$AudioStreamPlayer3D.play()
			return
		if	!Button_ani.is_playing() and Delay_timer.is_stopped():
			Delay_timer.start()
			if pressed:
				Button_ani.play("Unpressed")
				Door_button_press.emit()
				
			else:
				Button_ani.play("Pressed")
				Door_button_press.emit()
				
func open_door() -> void:
	$OmniLight3D.visible =false
	if pressed:
				Button_ani.play("Unpressed")
				Door_button_press.emit()
