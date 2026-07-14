extends Node

const SAVE_PATH: String = "user://save.dat"



# 기본값 (파일이 없거나 리셋할 때 사용)
const RESET_DATA: Dictionary = {
	##게임 진행상황 
	"star": 0,
	"clear_night": 0,
	##설정 파일 저장
	"low_spec_mode": 0,
	#"version": 0,
	
}

# [핵심] 현재 메모리에 로드된 세이브 데이터를 가리키는 변수
var current_data: Dictionary = {}

func _ready() -> void:
	# 게임이 시작될 때 자동으로 세이브 파일을 로드합니다.
	load_data_to_memory()
	
## 1. 메모리에 데이터를 로드하고 파일이 없으면 초기화하는 내부 함수
func load_data_to_memory() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveManager] 세이브 파일이 없어 초기화합니다.")
		current_data = RESET_DATA.duplicate() # 얕은 복사로 기본값 세팅
		save_current_data()
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var loaded = file.get_var()
	file.close()
	
	if loaded is Dictionary:
		current_data = loaded
		# [팁] 혹시 업데이트로 세이브 항목이 늘어났을 때를 대비해 누락된 키를 채워줍니다.
		_verify_data_keys()
	else:
		current_data = RESET_DATA.duplicate()

## 2. [해결책] 특정 키의 값 하나만 바꾸고 즉시 저장하는 함수
func set_value(key: String, value: Variant) -> void:
	# 딕셔너리의 전체를 바꾸지 않고 해당 키의 값만 수정합니다.
	current_data[key] = value
	save_current_data() # 변경 즉시 파일에 저장

## 3. 특정 키의 값을 안전하게 가져오는 함수
func get_value(key: String, default_value: Variant = null) -> Variant:
	if current_data.has(key):
		return current_data[key]
	return default_value

## 4. 현재 메모리의 데이터를 파일에 통째로 쓰는 내부 함수
func save_current_data() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var(current_data)
	file.close()
	print("[SaveManager] 데이터가 안전하게 저장되었습니다: ", current_data)

# 새 키가 추가되었을 때 기존 세이브파일과의 호환성을 위한 헬퍼 함수
func _verify_data_keys() -> void:
	for key in RESET_DATA.keys():
		if not current_data.has(key):
			current_data[key] = RESET_DATA[key]
