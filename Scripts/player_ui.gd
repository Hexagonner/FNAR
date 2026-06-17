extends Control


@onready var battery_usage = 1
@onready var Left_door_using = false
@onready var Right_door_using = false
@onready var Left_light_using = false
@onready var Right_light_using = false
@onready var Cam_using = false

signal back_button_pressed
@warning_ignore("unused_signal")
signal cam_button_pressed
@warning_ignore("unused_signal")
signal battery_usage_change_signal(usage:int)
@warning_ignore("unused_signal")
signal battery_over
# Called when the node enters the scene tree for the first time.

	#Left_door_using = false
	#Right_door_using = false
	#Left_light_using = false
	#Right_light_using = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
@warning_ignore("unused_parameter")

func battery_usage_change(is_using) -> void:
	if is_using:
		battery_usage +=1
	else:
		battery_usage -=1
	emit_signal("battery_usage_change_signal", clamp(battery_usage, 1,4))
	
#region 버튼 배터리 사용 시그널 블럭 and Cam_on button signal

func _on_door_button_left_door_button_press() -> void:
	Left_door_using = !Left_door_using
	battery_usage_change(Left_door_using)


func _on_light_button_left_light_button_press() -> void:
	Left_light_using = !Left_light_using
	battery_usage_change(Left_light_using)


func _on_door_button_right_door_button_press() -> void:
	Right_door_using = !Right_door_using
	battery_usage_change(Right_door_using)


func _on_light_button_right_light_button_press() -> void:
	Right_light_using = !Right_light_using
	battery_usage_change(Right_light_using)
	

#endregion
func _on_texture_button_pressed() -> void:
	emit_signal("cam_button_pressed")


func _on_battery_battery_over() -> void:
	emit_signal("battery_over")
	$CanvasLayer/CamButton.visible= false
	$CanvasLayer/Battery.visible = false
	$CanvasLayer/Time.visible= false
func _on_texture_button_mouse_entered() -> void:
	emit_signal("cam_button_pressed")
	
	#일종의 시그널 허브 역할을 함. 
	#하위 노드들의 신호를 상위 노드로 받아서, 나중에 인스턴트화 할 때 유용하게 사용.


func _on_backbutton_pressed() -> void:
	emit_signal("back_button_pressed")
