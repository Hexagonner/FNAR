extends Node
class_name TemporaryPinDebugVisualizer

## 임시 핀들의 정보를 주기적으로 출력하는 디버그 스크립트

@export var print_interval: float = 0.5
var print_timer: float = 0.0
var agents: Array[animatronics] = []

func _ready() -> void:
	for child in get_tree().root.get_children():
		_find_agents_recursive(child)
	print("[DebugVisualizer] Found %d agents" % agents.size())

func _find_agents_recursive(node: Node) -> void:
	if node is animatronics:
		agents.append(node)
	for child in node.get_children():
		_find_agents_recursive(child)

func _process(delta: float) -> void:
	print_timer += delta
	if print_timer < print_interval:
		return
	print_timer = 0.0
	
	for agent: animatronics in agents:
		if agent._temporary_pin != null:
			var prev_name: String = agent._previous_pin.name if agent._previous_pin else "None"
			var next_name: String = agent._next_pin.name if agent._next_pin else "None"
			var temp_name: String = agent._temporary_pin.name
			print("[TempPin] %s - Pin: %s (Prev: %s, Next: %s) Path: %d/%d" % [
				agent.name, temp_name, prev_name, next_name,
				agent._path_index, agent._planned_path.size()
			])
