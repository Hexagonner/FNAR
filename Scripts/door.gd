extends Node3D
var is_opened:bool  = true 
@onready var anim = $AnimationPlayer



func toggle() -> void:
	if is_opened:
		anim.play("Door_close")
		print("close")
	else:
		anim.play("Door_Open")
		print("open!")
	is_opened = !is_opened


func _on_door_button_left_door_button_press() -> void:
	toggle()


func _on_door_button_right_door_button_press() -> void:
	toggle()
