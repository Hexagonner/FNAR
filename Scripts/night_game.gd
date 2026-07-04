extends Node
@export var pause_menu:Control
func _input(event) -> void:
	if Input.is_action_just_pressed("exit_main_menu"):
		pause_menu.visible =true
		get_tree().paused = true
		$CanvasLayer/pause.play()
