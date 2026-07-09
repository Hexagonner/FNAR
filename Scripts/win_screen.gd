extends Control

const start_menu_scene = "res://Scene/start_menu.tscn"
@export var ani:AnimationPlayer
var data = SaveManager.loadData()
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.visible = false
	$ColorRect/black_bar.visible = false
	ResourceLoader.load_threaded_request(start_menu_scene,"PackedScene",true)
	if GameManager.Selected_Night == 5 and data["star"]==0:
		data["star"] = 1
	elif GameManager.Selected_Night == 6 and data["star"]==1:
		data["star"] = 2
	elif GameManager.Selected_Night == 7 and 1 == 1 : #TODO 20/20/20/20 조건 추가 하기 
		data["star"] = 3
	if data["clear_night"] < GameManager.Selected_Night:
		data["clear_night"] = GameManager.Selected_Night
	
func game_win()  -> void:
	get_tree().paused = true
	SaveManager.saveData(data)
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
	
