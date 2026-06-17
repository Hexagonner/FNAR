extends Node

const start_menu_scene = "res://Scene/start_menu.tscn"
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ResourceLoader.load_threaded_request(start_menu_scene,"PackedScene",true)



@warning_ignore("unused_parameter")
func _input(event) -> void:
	if Input.is_action_just_pressed("exit_main_menu"):
		change_scene(start_menu_scene)
		
func change_scene(scene) -> void:
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(scene))
