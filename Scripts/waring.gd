extends Control
#@export var skip_tip: Label
@export var loading_label: Label
@export var fadeTime:= 3.0
const start_menu_scene := "res://Scene/start_menu.tscn"
const night_game_scene := "res://Scene/Night_game.tscn"
#const start_RD := "res://Scene/start_menu_Rd.tscn"
var _is_loaded: bool = false
var _menu_progress: Array = [0.0]
var _night_progress: Array = [0.0]
var _menu_loaded: bool = false
var _night_loaded: bool = false
var _fade_tween: Tween


func _ready() -> void:
	RenderingServer.set_default_clear_color("black")
	self.visible = true
	# 로딩 진행률 라벨 초기화 (검은 화면 방지를 위해 즉시 표시)
	if loading_label != null:
		loading_label.text = "로딩 중... 0%"
	# start_menu와 night_game을 동시에 비동기 로드.
	# 동기 load()를 쓰면 waring이 그려지기 전에 Night_game 로딩이 끝나야
	# 하므로 검은 화면이 오래 보임. 비동기로 띄워서 waring 화면이 즉시
	# 그려진 뒤 진행률이 증가하도록 한다.
	ResourceLoader.load_threaded_request(start_menu_scene, "PackedScene", true)
	ResourceLoader.load_threaded_request(night_game_scene, "PackedScene", true)
	#ResourceLoader.load_threaded_request(start_RD, "PackedScene", true)

func _process(_delta: float) -> void:
	# 매 프레임 로딩 진행률을 확인
	if _is_loaded:
		return
	# 각 씬의 진행률을 가져온다 (THREAD_LOAD_IN_PROGRESS, THREAD_LOAD_LOADED,
	# THREAD_LOAD_FAILED, THREAD_LOAD_INVALID_RESOURCE 중 하나와 진행률).
	# 진행률 인자는 길이 1짜리 Array에 0.0~1.0 값으로 채워진다.
	var menu_status: int = ResourceLoader.load_threaded_get_status(start_menu_scene, _menu_progress)
	var night_status: int = ResourceLoader.load_threaded_get_status(night_game_scene, _night_progress)

	# 에러 상태는 디버그 로그만 남기고 계속 진행 (한쪽 실패가 다른 쪽에 영향 X)
	if menu_status == ResourceLoader.THREAD_LOAD_FAILED or menu_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("[waring] start_menu 로딩 실패: %d" % menu_status)
	if night_status == ResourceLoader.THREAD_LOAD_FAILED or night_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("[waring] night_game 로딩 실패: %d" % night_status)

	# 두 진행률의 평균을 표시한다. 한쪽이 0이라도 다른 쪽이 진행 중이면
	# 0~50% 사이에서 움직이게 되며, 사용자가 로딩이 멈춘 것처럼 느끼지 않는다.
	var combined: float = (_menu_progress[0] + _night_progress[0]) * 0.5
	if loading_label != null:
		var percent: int = int(combined * 100.0)
		percent = clamp(percent, 0, 99)
		loading_label.text = "로딩 중... %d%%" % percent

	# 각 씬의 완료 여부를 추적 (실패해도 다음 단계로 갈 수 있도록 허용)
	_menu_loaded = menu_status == ResourceLoader.THREAD_LOAD_LOADED
	_night_loaded = night_status == ResourceLoader.THREAD_LOAD_LOADED
	if _menu_loaded and _night_loaded:
		_on_load_completed()


## 로딩이 완료되었을 때 호출된다.
## - 로딩 라벨을 "로딩 완료"로 잠시 표시
## - 잠시 후 전체 라벨들(CenterContainer, skip_tip, loading_label) fade out
## - fade out 완료 후 start_menu로 전환
func _on_load_completed() -> void:
	_is_loaded = true
	if loading_label != null:
		loading_label.text = "로딩 완료 100%"
	# "로딩 완료" 라벨이 잠시 보이도록 짧게 대기 후 페이드 아웃
	await get_tree().create_timer(0.5).timeout
	_fade_out_and_change()


## 라벨들을 포함한 전체 컨텐츠를 fade out 한 뒤 start_menu로 전환한다.
func _fade_out_and_change() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property($CenterContainer, "modulate", Color(1, 1, 1, 0), fadeTime)

	if loading_label != null:
		_fade_tween.tween_property(loading_label, "modulate", Color(1, 1, 1, 0), fadeTime)
	# tween이 모두 끝난 뒤에 start_menu로 전환 (set_parallel + callback은
	# tween 시작과 동시에 콜백이 실행될 수 있어 await finished로 안전하게 대기)
	await _fade_tween.finished
	_change_to_menu()


func _change_to_menu() -> void:
	# 안전하게 로드 완료된 리소스를 가져와 전환
	var loaded_scene: PackedScene = ResourceLoader.load_threaded_get(start_menu_scene) as PackedScene
	if loaded_scene != null:
		get_tree().change_scene_to_packed(loaded_scene)
