extends Control

@export var skip_warning = false
@export var BGM:AudioStreamPlayer
const start_menu_scene = "res://Scene/start_menu.tscn"

func _ready() -> void:
	RenderingServer.set_default_clear_color("black")
	ResourceLoader.load_threaded_request(start_menu_scene,"PackedScene",true)
	self.visible = true
	await get_tree().create_timer(5).timeout

	var tween = get_tree().create_tween()
	tween.tween_property($CenterContainer, "modulate", Color(1,1,1,0), 1)
	tween.tween_callback(self.Skip_warning_msg)
# Called every frame. 'delta' is the elapsed time since the previous frame.

func change_scene(scene) -> void:
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(scene))
func Skip_warning_msg() -> void:
	#BGM.start(0)
	change_scene(start_menu_scene)
	
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				Skip_warning_msg()


	
