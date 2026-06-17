extends Control

@export var option_node:Node
@export var night_label:Label
@export var select_day_spinbox:SpinBox
const night_scene = "res://Scene/Night_game.tscn"
var selected_day:int =1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().paused = false
	
	RenderingServer.set_default_clear_color("black")
	ResourceLoader.load_threaded_request(night_scene,"PackedScene",true)
	$Start_loading.visible =false
# Called every frame. 'delta' is the elapsed time since the previous frame.

func change_scene(scene) -> void:
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(scene))
	#get_tree().change_scene_to_file(scene_path)
func _on_new_pressed() -> void:
	GameManager.Selected_Night = 1
	show_loading_screen()
	

func _on_option_button_pressed() -> void:
	option_node.visible = true

@warning_ignore("unused_parameter")
func show_loading_screen() -> void:
	get_viewport().gui_get_focus_owner().release_focus()
	if GameManager.Selected_Night == 1:
		night_label.text = "1st Night"
	elif GameManager.Selected_Night == 2:
		night_label.text = "2nd Night"
	elif GameManager.Selected_Night == 3:
		night_label.text = "3rd Night"
	else:
		night_label.text = str(GameManager.Selected_Night) + "th Night"
	$Noise_ani.play("noise")
	$Start_loading.visible = true
	$start_sound.play()
	$bgm.stop()
	await get_tree().create_timer(2.5).timeout
	change_scene(night_scene)


func _on_continue_pressed() -> void:
	@warning_ignore("narrowing_conversion")
	GameManager.Selected_Night = select_day_spinbox.value
	show_loading_screen()
	
func _on_night_6_pressed() -> void:
	GameManager.Selected_Night = 6
	show_loading_screen()
