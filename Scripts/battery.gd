extends Control

@warning_ignore("unused_signal")
signal battery_over
@export var left_power_label:Node #= $HBoxContainer/VBoxContainer/HBoxContainer2/Left_power
@export var battery_timer :Node
@export var USAGE_MULTIPLIER = 0.2
@export var left_power:float = 100
@export var battery_meter:Node
var Battery_usage:int = 1
var _battery_segment_nodes: Array[Node] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in range(1, 5):
		_battery_segment_nodes.append(battery_meter.get_child(i))
	for i in range(1, 4):
		_battery_segment_nodes[i].visible = false
	if !GameManager.inf_bat:
		battery_timer.start()


func _on_player_ui_battery_usage_change_signal(usage: int) -> void:
	Battery_usage = usage
	for i in range(4):
		_battery_segment_nodes[i].visible = (i < usage)


func _on_battery_timer_timeout() -> void:
	left_power -= Battery_usage/10.0
	#TODO add more usage 2 night -0.1 per 6sec ...
	
	left_power_label.text = str(int(left_power))
	if left_power <= 0:
		emit_signal("battery_over")
		battery_timer.stop()
		
