extends Node3D
class_name TemporaryPinSystemTest

## 임시 핀 시스템 테스트 스크립트
## 이 스크립트를 RD 시뮬레이션에서 실행하여 임시 핀 생성을 모니터링합니다.

@export var monitor_agent_name: String = "RD"
@export var check_interval: float = 0.5

var _last_check_time: float = 0.0
var _test_scene: Node = null

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("🧪 임시 핀 시스템 테스트 시작")
	print("=".repeat(60))
	print("모니터링 대상: %s" % monitor_agent_name)
	print("체크 간격: %.1f초" % check_interval)
	print("=".repeat(60) + "\n")

func _process(delta: float) -> void:
	_last_check_time += delta
	
	if _last_check_time < check_interval:
		return
	
	_last_check_time = 0.0
	_check_temporary_pin_system()

func _check_temporary_pin_system() -> void:
	# RD(Animatronics) 노드 찾기
	var agent = find_agent_by_name(monitor_agent_name)
	
	if agent == null:
		return
	
	# 임시 핀 정보 출력
	var temp_pin = agent.get_temporary_pin() if agent.has_method("get_temporary_pin") else null
	
	if temp_pin == null:
		return
	
	var prev_pin = agent.get_previous_pin() if agent.has_method("get_previous_pin") else null
	var next_pin = agent.get_next_pin() if agent.has_method("get_next_pin") else null
	var path_index = agent.get_path_index() if agent.has_method("get_path_index") else -1
	var current_path = agent.get_current_path() if agent.has_method("get_current_path") else null
	
	# 테스트 정보 출력
	print("📍 [TempPin Test]")
	print("  Agent: %s" % agent.name)
	print("  Temp Pin: %s" % temp_pin.name)
	print("  Position: %.2f, %.2f, %.2f" % [temp_pin.position.x, temp_pin.position.y, temp_pin.position.z])
	
	if prev_pin != null:
		print("  Previous Pin: %s" % prev_pin.name)
	
	if next_pin != null:
		print("  Next Pin: %s" % next_pin.name)
	
	if path_index >= 0 and current_path != null:
		print("  Path Index: %d / %d" % [path_index, current_path.size()])
	
	print("")
	
	# 검증
	var validation_results = _validate_temporary_pin_system(agent, temp_pin, prev_pin, next_pin)
	
	if not validation_results["all_passed"]:
		print("⚠️ 검증 실패:")
		for result_name in validation_results["results"].keys():
			if not validation_results["results"][result_name]:
				print("  ❌ %s" % result_name)

func find_agent_by_name(agent_name: String) -> Node:
	var agents = get_tree().get_nodes_in_group("agents")
	
	for agent in agents:
		if agent_name.is_empty() or agent.name.contains(agent_name):
			return agent
	
	# 직접 찾기
	return find_child(agent_name, true, false)

func _validate_temporary_pin_system(agent: Node, temp_pin: Node, prev_pin: Node, next_pin: Node) -> Dictionary:
	var results = {
		"temp_pin_not_null": temp_pin != null,
		"temp_pin_in_tree": temp_pin.is_inside_tree() if temp_pin != null else false,
		"prev_pin_not_null": prev_pin != null,
		"next_pin_not_null": next_pin != null,
		"neighbors_set": temp_pin.neighbors.size() == 2 if temp_pin != null and temp_pin.has_meta("neighbors") else false,
		"position_valid": temp_pin.position != Vector3.ZERO if temp_pin != null else false,
	}
	
	var all_passed = results.values().all(func(v): return v)
	
	return {
		"all_passed": all_passed,
		"results": results
	}
