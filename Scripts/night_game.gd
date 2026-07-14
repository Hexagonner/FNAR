extends Node
@export var pause_menu:Control
## 저사양 모드에서 비활성화할 풀스크린 셰이더 ColorRect들.
## 기본값 null이지만 Night_game.tscn에서 인스펙터로 연결한다.
@export var old_shader_rect: CanvasItem
@export var camera_manager: Node
@export var init_fadeout:ColorRect

func _ready() -> void:
	_apply_low_spec_mode(GlobalSetting.low_spec_mode)
	GlobalSetting.low_spec_changed.connect(_apply_low_spec_mode)

	# SceneTreeTween 생성
	var tween = create_tween()
	tween.tween_property(init_fadeout,"modulate:a",0.0,1.5).set_trans(Tween.TRANS_SINE)
	
	# 트윈 완료 시 ColorRect 삭제
	tween.finished.connect(_on_tween_finished)


func _on_tween_finished():
	if is_instance_valid(init_fadeout):
		init_fadeout.queue_free()  # ColorRect 삭제
## 저사양 모드일 때 비용이 큰 풀스크린 셰이더를 끄거나 low_spec_mode 파라미터를 켠다.
## (호출 시점: 게임 시작 시 1회 + 옵션 변경 시 1회)
func _apply_low_spec_mode(enabled: bool) -> void:
	# 1) night_game 자체의 old_shader (posterize + chromatic + grain 풀스크린)
	if old_shader_rect != null:
		old_shader_rect.visible = not enabled
	# 2) camera_manager 안의 CRT_shader / Glitch 풀스크린 셰이더
	if camera_manager != null and camera_manager.has_method("apply_low_spec_mode"):
		camera_manager.call("apply_low_spec_mode", enabled)
