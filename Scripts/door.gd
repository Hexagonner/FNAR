extends Node3D
var is_opened:bool  = true 
@onready var anim = $AnimationPlayer
@export var door_button:Node

func _ready() -> void:
	door_button.Door_button_press.connect(door_button_press)
func toggle() -> void:
	if is_opened:
		anim.play("Door_close")
		#print("close")
	else:
		anim.play("Door_Open")
		#print("open!")
	is_opened = !is_opened


@warning_ignore("unused_parameter")
func door_button_press(is_pressed) -> void:
	toggle()
	
