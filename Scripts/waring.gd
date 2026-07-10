extends Control
#@export var skip_tip: Label
@export var loading_label: Label
@export var fadeTime:= 3.0
const start_menu_scene := "res://Scene/start_menu.tscn"
#const start_RD := "res://Scene/start_menu_Rd.tscn"
var _is_loaded: bool = false
var _load_progress: Array = [0.0]
var _fade_tween: Tween


func _ready() -> void:
	RenderingServer.set_default_clear_color("black")
	self.visible = true
	# 로딩 진행률 라벨 초기화
	if loading_label != null:
		loading_label.text = "로딩 중... 0%"
	
	# 백그라운드 로딩 시작
	ResourceLoader.load_threaded_request(start_menu_scene, "PackedScene", true)
	#ResourceLoader.load_threaded_request(start_RD, "PackedScene", true)

func _process(_delta: float) -> void:
	# 매 프레임 로딩 진행률을 확인
	if _is_loaded:
		return
	var status: int = ResourceLoader.load_threaded_get_status(start_menu_scene, _load_progress)
	if loading_label != null:
		# 진행률 표시 (0~99%까지만 표시 후 완료시 별도 메시지)
		var percent: int = int(_load_progress[0] * 100.0)
		percent = clamp(percent, 0, 99)
		loading_label.text = "로딩 중... %d%%" % percent
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_on_load_completed()
	elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		# 에러 등의 비정상 상태
		push_error("[waring] 로딩 비정상 상태: %d" % status)


## 로딩이 완료되었을 때 호출된다.
## - 로딩 라벨을 "로딩 완료"로 잠시 표시
## - 잠시 후 전체 라벨들(CenterContainer, skip_tip, loading_label) fade out
## - fade out 완료 후 start_menu로 전환
func _on_load_completed() -> void:
	_is_loaded = true
	if loading_label != null:
		loading_label.text = "로딩 완료"
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
