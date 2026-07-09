extends Control

@export var option_node:Node
@export var night_label:Label
@export var select_day_spinbox:SpinBox
@export var news:Sprite2D
@export var fadeout:ColorRect
@export var news_sound:AudioStreamPlayer
const night_scene = "res://Scene/Night_game.tscn"

var selected_day:int =1
var data: Dictionary = SaveManager.loadData()
var _can_skip: bool = false
var _skip_triggered: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().paused = false
	news.visible =false
	RenderingServer.set_default_clear_color("black")
	ResourceLoader.load_threaded_request(night_scene,"PackedScene",true)
	$Start_loading.visible =false

func _unhandled_input(event: InputEvent) -> void:
	if not _can_skip:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_skip_triggered = true

func change_scene(scene) -> void:
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(scene))
	#get_tree().change_scene_to_file(scene_path)
func _on_new_pressed() -> void:
	$bgm.stop()
	
	GameManager.Selected_Night = 1
	print(data.get("clear_night", 0), "night")
	
	#if data.get("clear_night", 0) >= 2:
	_can_skip = true
	_skip_triggered = false

	# 트윈 실행 중 모든 버튼 입력 차단
	for button: Button in $LEFT_button_containor.find_children("*", "Button"):
		button.disabled = true
	for button: Button in $VBoxContainer4.find_children("*", "Button"):
		button.disabled = true
	
	# 페이드아웃
	if not _skip_triggered:
		var fade_tween: Tween = create_tween()
		fade_tween.tween_property(fadeout, "color:a", 1.0, 1.0).from(0.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		await _wait_tween_or_skip(fade_tween)
	
	# 뉴스 등장 애니메이션 (병렬 실행)
	if not _skip_triggered:
		var tween1: Tween = create_tween()
		news_sound.play()
		tween1.stop()
		tween1.set_parallel(true)
		tween1.tween_property(news, "position:y", 500.0, 2.0).from(600.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween1.tween_property(news, "self_modulate:a", 1.0, 1.0).from(0.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween1.tween_property(news, "rotation_degrees", 5.0, 2.0).from(0.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween1.tween_property(news, "scale", Vector2(1.0, 1.0), 1.0).from(Vector2(0.9, 0.9)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween1.play()
		news.visible = true
		await _wait_tween_or_skip(tween1)
	if not _skip_triggered:
		await _wait_seconds_or_skip(7.0)
	# 뉴스 2차 애니메이션 (병렬 실행)
	if not _skip_triggered:
		var tween2: Tween = create_tween()
		tween2.stop()
		tween2.set_parallel(true)
		tween2.tween_property(news, "position:y", 400.0, 2.0).from(500.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween2.tween_property(news, "rotation_degrees", 7.5, 2.0).from(5.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween2.tween_property(news, "scale", Vector2(0.85, 0.85), 1.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween2.tween_property(news, "self_modulate:a", 0.0, 1).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween2.play()
		await _wait_tween_or_skip(tween2)
	
	if not _skip_triggered:
		await _wait_seconds_or_skip(0.5)
	
	_can_skip = false
	_skip_triggered = false
	news.visible = false
	show_loading_screen()


func _wait_tween_or_skip(tween: Tween) -> void:
	var was_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	while tween.is_running():
		if _skip_triggered:
			tween.kill()
			news_sound.stop()
			return
		var is_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if is_pressed and not was_pressed:
			_skip_triggered = true
			tween.kill()
			news_sound.stop()
			return
		was_pressed = is_pressed
		await get_tree().process_frame
	

func _wait_seconds_or_skip(seconds: float) -> void:
	var was_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var end_time: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end_time:
		if _skip_triggered:
			return
		var is_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if is_pressed and not was_pressed:
			_skip_triggered = true
			news_sound.stop()
			return
		was_pressed = is_pressed
		await get_tree().process_frame


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
