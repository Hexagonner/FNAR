extends Control

const start_menu_scene = "res://Scene/start_menu.tscn"
@export var ani:AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.visible = false
	$ColorRect/black_bar.visible = false
	#ResourceLoader.load_threaded_request(start_menu_scene,"PackedScene",true)
	
	
func game_win()  -> void:
	get_tree().paused = true

	#save data
	if GameManager.Selected_Night == 5 and SaveManager.get_value("star")==0:
		
		SaveManager.set_value("star",1)
	elif GameManager.Selected_Night == 6 and SaveManager.get_value("star")==1:
		SaveManager.set_value("star",2)
	elif GameManager.Selected_Night == 7 and 1 == 1 : #TODO 20/20/20/20 조건 추가 하기 
		SaveManager.set_value("star",3)
	if SaveManager.get_value("clear_night") < GameManager.Selected_Night:
		SaveManager.set_value("clear_night",GameManager.Selected_Night)

	GameManager.is_6am = true
	visible = true
	# ColorRect 초기 설정 (검은색, 완전히 불투명)
	self.modulate = Color(1, 1, 1, 0)  # R, G, B, A (A=1)

	# SceneTreeTween 생성
	var tween = create_tween()
	tween.tween_property(self,"modulate:a",1,1).set_trans(Tween.TRANS_SINE)
	tween.finished.connect(_on_tween_finished)


func _on_tween_finished() -> void:
	await get_tree().create_timer(0.1).timeout
	ani.play("game_win")


@warning_ignore("unused_parameter")
func _on_animation_player_animation_finished(anim_name:StringName) -> void:
	
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(start_menu_scene))
	
