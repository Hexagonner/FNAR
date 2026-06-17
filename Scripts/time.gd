extends Control

@export var game_timer:Node
var current_time = 12
@onready var timer_label = $HBoxContainer/VBoxContainer/timer_label
@export var win_screen:Node
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_time_label()


func _update_time_label() -> void:
	timer_label.text = str(current_time) + " AM"
#TODO UPDATE night number

func _on_timer_timeout() -> void:
	if current_time == 12:
		current_time = 1
		_update_time_label()
		return
	if current_time == 5:
		#anitronics 정지 필요,
		print("win!")
		game_timer.stop()
		win_screen.game_win()
		return
	current_time += 1
	_update_time_label()
