extends Node3D

@export var gui_node : Control
@export var cam_manager : Node
@export var Light_button_Left : Node
@export var Light_button_Right : Node
@export var Door_button_Left : Node
@export var Door_button_Right : Node
@export var map:Node
#@export var offlice_light:Node

@export var max_panning_speed : float = 70.0
@export var panning_curve : Curve
@export var right_rotation_limit = -50
@export var left_rotation_limit = 50

@onready var ambient_sound = $Ambient_sound
@onready var black_out_sound = $black_out_sound
@onready var cam = $playercam
@onready var monitor = $playercam/Monitor/AnimationPlayer
# Called when the node enters the scene tree for the first time.

var is_black_out:bool = false
var is_cam_on:bool = false
var is_looking_back:bool = false
var tween

func _ready() -> void:
	gui_node.cam_button_pressed.connect(swap_cam)
	gui_node.battery_over.connect(black_out)
	gui_node.back_button_pressed.connect(look_back)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#print(cam.rotation_degrees," 각도")
	if not is_cam_on:
		var vp = get_viewport()
		var mouse_pos = vp.get_mouse_position()
		var mouse_pos_x_normalized = mouse_pos.x / vp.get_visible_rect().size.x
		head_move(delta, mouse_pos_x_normalized)
func look_back() -> void:
	if is_cam_on and !is_black_out:
		return
	#print("backbutton ", cam.rotation_degrees)
	if tween:
		tween.kill()
	
	var cam_rot = cam.rotation_degrees.y
	var direction: float
	var target_y = 0.0

	if !is_looking_back:
		direction = 1.0 if cam_rot > 0 else -1.0
		is_looking_back = true
		target_y = 180.0 * direction
	else:
		is_looking_back = false
		target_y = 0.0
	tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees:y", target_y, 1.0)


func head_move(delta, mouse_pos_x_normalized) -> void:
	var distance_from_center = abs(mouse_pos_x_normalized - 0.5) * 2.0
	var panning_speed_multiplier = panning_curve.sample(distance_from_center)
	#print (distance_from_center,"  ",mouse_pos_x_normalized)
	#print(cam.rotation_degrees.y)
	# Inversing the value if the mouse is on the right side of the screen
	if mouse_pos_x_normalized > 0.5:
		panning_speed_multiplier *= -1
	
	# 카메라 회전
	cam.rotation_degrees.y += (delta * max_panning_speed * panning_speed_multiplier)
	# 머리 이동 각도 제한
	cam.rotation_degrees.y = clamp(cam.rotation_degrees.y, right_rotation_limit, left_rotation_limit)

@warning_ignore("unused_parameter")
func swap_cam() -> void:
	if !is_black_out:
		if not is_cam_on:
			is_black_out = true
			monitor.play("slam_into_face")
			is_cam_on = true
			await monitor.animation_finished
			gui_node.battery_usage_change(is_cam_on)
			cam_manager.enable_camera_display()
			Light_button_Left.turn_off_light()
			Light_button_Right.turn_off_light()
		else:
			is_black_out = true
			cam_manager.disable_camera_display()
			monitor.play("put_back_down")
			is_cam_on = false
			await monitor.animation_finished
			gui_node.battery_usage_change(is_cam_on)
		is_black_out = false
		
func black_out() -> void:
	
	#offlice_light.is_black_out = true
	ambient_sound.stop()
	black_out_sound.play()
	map.office_light_off()
	Light_button_Left.turn_off_light()
	Light_button_Left.ignore_press = true
	Light_button_Right.turn_off_light()
	Light_button_Right.turn_off_button_light()
	Light_button_Right.ignore_press = true
	Door_button_Left.open_door()
	Light_button_Left.turn_off_button_light()
	Door_button_Left.ignore_press = true
	Door_button_Right.open_door()
	Door_button_Right.ignore_press = true
	if monitor.is_playing():
		await monitor.animation_finished
	if is_cam_on:
		swap_cam()
		#await monitor.animation_finished
	if is_looking_back:
		look_back()
	#TODO ADD jump scare Scene
