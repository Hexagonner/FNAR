extends Node3D
class_name animatronics

#@export var ani:Node
#region PINname
## Night_game/MovePoint 자식 노드 기반. 새 핀 추가 시 여기와 PIN_NODE_NAMES에 추가하세요.
enum PinName {
	NONE,
	LEFT_DOOR,
	LEFT_HALL_CORNER,
	LEFT_HALL_ENTRANCE,
	LEFT_HALL_MID_TOP,
	LEFT_HALL_MID_LOW,
	STORAGE_FRONT,
	STORAGE,
	STORAGE_DOOR,
	SOLO_STAGE_LEFT,
	SOLO_STAGE_FRONT,
	SOLO_STAGE,
	RIGHT_DOOR,
	RIGHT_HALL_CORNER,
	RIGHT_HALL_ENTRANCE,
	RIGHT_HALL_MIDDLE,
	RIGHT_HALL_MID_TOP,
	RIGHT_HALL_MID_LOW,
	FRONT_KITCHEN,
	KITCHEN,
	FRONT_TOILET,
	TOILET_CORNER,
	TOILET_MEN_FRONT,
	TOILET_MEN,
	TOILET_WOMEN_FRONT,
	TOILET_WOMEN,
	STAGE_RIGHT_CORNER,
	STAGE_CENTER,
	BACKSTAGE_FRONT,
	BACKSTAGE,
	MAIN_HALL_LEFT,
	MAIN_HALL_RIGHT,
	MAIN_HALL_MID_LEFT,
	MAIN_HALL_MID_RIGHT,
	MAIN_HALL_LOW_RIGHT,
	MAIN_HALL_LOW_LEFT,
	MAIN_HALL_MID_RIGHTEST,
	MAIN_HALL_MID_LEFTEST,
	STAGE_RD,
	STAGE_GMCH,
	STAGE_UM,
	STAGE_RDI,
}

## PinName enum 값 → 씬의 Movepoint 노드 이름 매핑
const PIN_NODE_NAMES: Dictionary = {
	PinName.NONE: "",
	PinName.LEFT_DOOR: "Left_door",
	PinName.LEFT_HALL_CORNER: "Left_hall_corner",
	PinName.LEFT_HALL_ENTRANCE: "Left_hall_entrance",
	PinName.LEFT_HALL_MID_LOW: "Right_hall_mid_low",
	PinName.LEFT_HALL_MID_TOP: "Right_hall_mid_top",
	PinName.STORAGE_FRONT: "Storage_front",
	PinName.STORAGE: "Storage",
	PinName.STORAGE_DOOR: "Storage_door",
	PinName.SOLO_STAGE_LEFT: "Solo_stage_left",
	PinName.SOLO_STAGE_FRONT: "Solo_stage_front",
	PinName.SOLO_STAGE: "Solo_stage",
	PinName.RIGHT_DOOR: "Right_door",
	PinName.RIGHT_HALL_CORNER: "Right_hall_corner",
	PinName.RIGHT_HALL_ENTRANCE: "Right_hall_entrance",
	PinName.RIGHT_HALL_MIDDLE: "Right_hall_middle",
	PinName.RIGHT_HALL_MID_TOP: "Right_hall_mid_top",
	PinName.RIGHT_HALL_MID_LOW: "Right_hall_mid_low",
	PinName.FRONT_KITCHEN: "Front_Kitchen",
	PinName.KITCHEN: "Kitchen",
	PinName.FRONT_TOILET: "Front_toilet",
	PinName.TOILET_CORNER: "toilet_corner",
	PinName.TOILET_MEN_FRONT: "toilet_men_front",
	PinName.TOILET_MEN: "toilet_men",
	PinName.TOILET_WOMEN_FRONT: "toilet_women_front",
	PinName.TOILET_WOMEN: "toilet_women",
	PinName.STAGE_RIGHT_CORNER: "stage_right_corner",
	PinName.STAGE_CENTER: "stage_center",
	PinName.BACKSTAGE_FRONT: "backstage_front",
	PinName.BACKSTAGE: "backstage",
	PinName.MAIN_HALL_LEFT: "main_hall_left",
	PinName.MAIN_HALL_RIGHT: "main_hall_right",
	PinName.MAIN_HALL_MID_LEFT: "main_hall_mid_left",
	PinName.MAIN_HALL_MID_RIGHT: "main_hall_mid_right",
	PinName.MAIN_HALL_LOW_RIGHT: "main_hall_low_right",
	PinName.MAIN_HALL_LOW_LEFT: "main_hall_low_left",
	PinName.MAIN_HALL_MID_RIGHTEST: "main_hall_mid_rightest",
	PinName.MAIN_HALL_MID_LEFTEST: "main_hall_mid_leftest",
	PinName.STAGE_RD: "stage_RD",
	PinName.STAGE_GMCH: "stage_GMCH",
	PinName.STAGE_UM: "stage_UM",
	PinName.STAGE_RDI: "stage_RDI",
}

## 기존 씬의 오탈자 노드명도 허용해 하위 호환 유지
const PIN_NODE_ALIASES: Dictionary = {
	PinName.LEFT_HALL_CORNER: ["Left_hall_coner"],
	PinName.RIGHT_HALL_CORNER: ["Right_hall_coner"],
	PinName.FRONT_TOILET: ["Front_toliet"],
	PinName.TOILET_CORNER: ["toliet_coner"],
	PinName.TOILET_MEN_FRONT: ["toliet_men_front"],
	PinName.TOILET_MEN: ["toliet_men"],
	PinName.TOILET_WOMEN_FRONT: ["toliet_women_front"],
	PinName.TOILET_WOMEN: ["toliet_women"],
	PinName.STAGE_RIGHT_CORNER: ["stage_Right_coner"],
}
#endregion 
static func get_pin_node_name(pin: PinName) -> String:
	return PIN_NODE_NAMES.get(pin, "")

func _find_pin_node(pin: PinName) -> Movepoint:
	if movepoint == null:
		return null
	var primary_name := get_pin_node_name(pin)
	if not primary_name.is_empty():
		var primary_node := movepoint.find_child(primary_name)
		if primary_node is Movepoint:
			return primary_node
	for alias in PIN_NODE_ALIASES.get(pin, []):
		var alias_node := movepoint.find_child(alias)
		if alias_node is Movepoint:
			return alias_node
	return null #핀노드 이름을 통해 핀 노드를 찾는 코드. 

func _get_closest_pin() -> Movepoint:
	if movepoint == null:
		return null
	var closest_pin: Movepoint = null
	var closest_distance := INF
	for pin in PinName.values():
		if pin == PinName.NONE:
			continue
		var node := _find_pin_node(pin) #노드를 하나하나 조사하면서, 최단거리 노드를 설정하는거.
		if node == null:
			continue
		var dist := node.global_position.distance_squared_to(global_position)
		if dist < closest_distance:
			closest_distance = dist
			closest_pin = node
	return closest_pin # 가장 가까운 핀을 찾는  코드  

func _get_mapf_manager() -> MapfPlanner:
	return get_node_or_null("/root/MapfManager") as MapfPlanner

@export var is_walking:bool = false
@export var gui_node:Node #only Rando?
#@export var is_turned:bool = false
@export var path_follow:PathFollow3D


@export var ani_tree:AnimationTree
#@export var is_turned:bool = false
@onready var playback = ani_tree.get("parameters/StateMachine/playback")


@export var move_speed:float = 1.0
@export var turn_speed:float = 8.0
@export var bake_interval_var:float = 2.5
## 꼭짓점을 부드럽게 연결하는 정도 (0=직선, 0.25~0.5 권장). 0이면 직각 경로 유지.
@export_range(0.0, 1.0) var path_smooth_factor:float = 0.25
@export var movepath:Path3D
@export var movepoint:Node3D
#var current_position
#@export var start_pos: PinName

const WAIT_STEP_SECONDS := 0.25
const NODE_REACH_EPSILON := 0.05
const BLOCKED_REPLAN_SECONDS := 0.9
const YIELD_REQUEST_COOLDOWN_SECONDS := 1.2
## 핀 사이 대기 시 can_enter가 잠깐 true가 되며 walking이 깜빡이는 것을 방지
const PATH_GATE_OPEN_HOLD_SECONDS := 0.15

var _planned_path: Array[Movepoint] = []
var _path_index := 0
var _wait_remaining := 0.0
var _path_gate_open_timer := 0.0
var _path_gate_was_blocked := false
var _current_pin: Movepoint = null
var _blocked_time := 0.0
var _yield_request_cooldown := 0.0
var _main_goal_pin: PinName = PinName.NONE
var _yield_resume_goal_pin: PinName = PinName.NONE
var _yield_wait_remaining := 0.0
var _is_yielding := false
var _current_anim_state: StringName = &"idle"
var _path_locomotion_moving := false

func _apply_animation_state(state: StringName) -> void:
	if state == _current_anim_state:
		return
	_current_anim_state = state
	if playback == null:
		return
	playback.travel(state)

func _set_walking_state(walking: bool) -> void:
	is_walking = walking
	if not walking:
		_enter_path_still()

func _enter_path_still() -> void:
	if _path_locomotion_moving:
		_path_locomotion_moving = false
		_apply_animation_state(&"idle")

func _enter_path_walk() -> void:
	if not _path_locomotion_moving:
		_path_locomotion_moving = true
		_apply_animation_state(&"walking_001")

func _reset_path_gate() -> void:
	_path_gate_open_timer = 0.0
	_path_gate_was_blocked = false

func _can_enter_next_node(mapf: MapfPlanner, next_node: Movepoint) -> bool:
	return mapf == null or mapf.can_enter_node(self, next_node)

func _segment_is_mapf_wait(index: int) -> bool:
	if index < 0 or index >= _planned_path.size() - 1:
		return false
	return _planned_path[index] == _planned_path[index + 1]

func _update_locomotion_for_current_segment(mapf: MapfPlanner) -> void:
	if _path_index >= _planned_path.size() - 1:
		_enter_path_still()
		return
	if _segment_is_mapf_wait(_path_index):
		_enter_path_still()
		return
	var next_node: Movepoint = _planned_path[_path_index + 1]
	if not _can_enter_next_node(mapf, next_node):
		_enter_path_still()
		return
	_enter_path_walk()

func _ready() -> void:
	_current_pin = _get_closest_pin() # 자신의 위치와 이름을 MAPF에 등록 
	var mapf := _get_mapf_manager()
	if mapf != null and _current_pin != null:
		mapf.register_agent(self, _current_pin)
	elif _current_pin == null:
		push_warning("animatronics: movepoint or closest pin is not ready yet.")


@warning_ignore("unused_parameter")
func _physics_process(delta)->void: #FOR turn animation 

	# 1. 반환 타입을 Quaternion으로 수정
	var rotation_delta: Quaternion = ani_tree.get_root_motion_rotation()
	# 2. 회전 값이 있을 때만 적용 (IDENTITY는 0,0,0,1임)
	if rotation_delta != Quaternion.IDENTITY:
		# 노드의 현재 quaternion에 변화량을 곱해 실제 회전 적용
		quaternion = (quaternion * rotation_delta).normalized()

		if playback.get_current_node() not in ["turn left", "turn right"]: #and is_turned:
		# Y축 회전값을 90도 단위로 반올림하여 고정
			var snapped_y = round(rotation.y / (PI/2)) * (PI/2)
			rotation.y = lerp_angle(rotation.y, snapped_y, 0.1)
			#is_turned = false
	
	
func _move_to_internal(goal: PinName, must_visit: PinName = PinName.NONE, update_main_goal: bool = true) -> void:
	if movepoint == null:
		printerr("movepoint가 할당되지 않아 경로 계산을 할 수 없습니다.")
		is_walking = false
		return
	var start_pin: Movepoint = _current_pin
	if start_pin == null:
		start_pin = _get_closest_pin()
	if start_pin == null:
		printerr("현재 위치 기준 시작 핀을 찾지 못했습니다.")
		return
	var goal_pin: Movepoint = _find_pin_node(goal)
	if goal_pin == null:
		printerr("잘못된 목표 핀 지정: ", goal)
		return
	if update_main_goal:
		_main_goal_pin = goal

	var must_visit_pin: Movepoint = null
	if must_visit != PinName.NONE:
		must_visit_pin = _find_pin_node(must_visit)
		if must_visit_pin == null:
			printerr("잘못된 경유지 지정: ", must_visit)
			return

	var move_path: Array[Movepoint] = []
	var mapf := _get_mapf_manager()
	if mapf != null:
		move_path = mapf.request_path(self, start_pin, goal_pin, must_visit_pin)
	else:
		move_path = find_path(start_pin, goal_pin, must_visit_pin)
	if move_path.is_empty():
		_set_walking_state(false)
		return

	_planned_path = move_path
	_path_index = 0
	_wait_remaining = 0.0
	_reset_path_gate()
	_blocked_time = 0.0
	_yield_request_cooldown = 0.0
	_path_locomotion_moving = false
	_set_walking_state(_planned_path.size() > 1)
	if _planned_path.size() > 1:
		_update_locomotion_for_current_segment(mapf)
	_current_pin = _planned_path[0]
	
	# 경로 출력 (가독성 개선)
	var path_names: Array[String] = []
	for node in move_path:
		if node is Movepoint:
			path_names.append(node.name)
	var path_str: String = " → ".join(path_names)
	print("[경로 계산] %s: %s (총 %d칸)" % [self.name, path_str, move_path.size()])
	#start_pos = goal

func move_to(goal: PinName, must_visit: PinName = PinName.NONE) -> void:
	_move_to_internal(goal, must_visit, true)

func request_yield_to(goal_pin: Movepoint) -> bool:
	if goal_pin == null:
		return false
	if _current_pin == null:
		_current_pin = _get_closest_pin()
	if _current_pin == null:
		return false
	if _current_pin == goal_pin:
		return true
	var wait_pin_name := _pin_name_from_node(goal_pin)
	if wait_pin_name == PinName.NONE:
		return false
	_yield_resume_goal_pin = _main_goal_pin
	_yield_wait_remaining = WAIT_STEP_SECONDS
	_is_yielding = true
	var goal_name: String = PIN_NODE_NAMES.get(_main_goal_pin, "Unknown")
	print("[양보 수락] %s가 %s에서 %s로 양보 (원래 목표: %s, 대기시간: %.1f초)" % [
		self.name, 
		_current_pin.name if _current_pin else "Unknown",
		goal_pin.name,
		goal_name,
		WAIT_STEP_SECONDS
	])
	_move_to_internal(wait_pin_name, PinName.NONE, false)
	return true

func _remaining_path_nodes(max_count: int = 10) -> Array[Movepoint]:
	var remaining: Array[Movepoint] = []
	var end: int = mini(_planned_path.size(), _path_index + max_count + 1)
	for i in range(_path_index, end):
		if _planned_path[i] != null:
			remaining.append(_planned_path[i])
	return remaining

func _pin_name_from_node(node: Movepoint) -> PinName:
	if node == null:
		return PinName.NONE
	for pin in PinName.values():
		if pin == PinName.NONE:
			continue
		if _find_pin_node(pin) == node:
			return pin
	return PinName.NONE

func _is_path_pin_to_pin(path: Array[Movepoint]) -> bool:
	if path.is_empty():
		return false
	for i in range(path.size() - 1):
		var a: Movepoint = path[i]
		var b: Movepoint = path[i + 1]
		if a == null or b == null:
			return false
		if a == b:
			continue
		if not a.neighbors.has(b):
			return false
	return true

func _repair_non_neighbor_step(current_node: Movepoint, next_node: Movepoint) -> bool:
	if current_node == null or next_node == null:
		return false
	if current_node == next_node:
		return true
	if current_node.neighbors.has(next_node):
		return true

	# Recover by expanding this jump into a valid pin-to-pin chain.
	var bridge: Array[Movepoint] = find_path(current_node, next_node, null)
	if bridge.size() < 2:
		return false

	var repaired: Array[Movepoint] = []
	for i in range(_path_index):
		repaired.append(_planned_path[i])
	repaired.append(current_node)
	for i in range(1, bridge.size()):
		repaired.append(bridge[i])
	for i in range(_path_index + 2, _planned_path.size()):
		repaired.append(_planned_path[i])

	if not _is_path_pin_to_pin(repaired):
		return false

	_planned_path = repaired
	return true

func advance_along_path(delta: float) -> void:
	if _is_yielding and (_planned_path.size() < 2 or _path_index >= _planned_path.size() - 1):
		_set_walking_state(false)
		_yield_wait_remaining -= delta
		if _yield_wait_remaining <= 0.0:
			var resume_goal := _yield_resume_goal_pin
			_is_yielding = false
			_yield_resume_goal_pin = PinName.NONE
			var resume_goal_name: String = PIN_NODE_NAMES.get(resume_goal, "Unknown")
			print("[양보 완료] %s가 원래 목표 %s로 복귀" % [
				self.name,
				resume_goal_name
			])
			if resume_goal != PinName.NONE:
				_move_to_internal(resume_goal, PinName.NONE, true)
		return

	if not is_walking:
		return
	if _planned_path.size() < 2:
		_set_walking_state(false)
		return
	if _path_index >= _planned_path.size() - 1:
		_set_walking_state(false)
		return

	var current_node: Movepoint = _planned_path[_path_index]
	var next_node: Movepoint = _planned_path[_path_index + 1]
	if current_node == null or next_node == null:
		_set_walking_state(false)
		return
	if not _repair_non_neighbor_step(current_node, next_node):
		printerr("Invalid non-neighbor step detected. Stopping movement to prevent wall clipping.")
		_set_walking_state(false)
		return
	# next step may have changed after repair.
	current_node = _planned_path[_path_index]
	next_node = _planned_path[_path_index + 1]

	if current_node == next_node:
		_blocked_time = 0.0
		_reset_path_gate()
		_enter_path_still()
		if _wait_remaining <= 0.0:
			_wait_remaining = WAIT_STEP_SECONDS
		_wait_remaining -= delta
		if _wait_remaining <= 0.0:
			_path_index += 1
			_reset_path_gate()
			if _path_index < _planned_path.size() - 1:
				_update_locomotion_for_current_segment(_get_mapf_manager())
		return

	var mapf := _get_mapf_manager()
	if not _can_enter_next_node(mapf, next_node):
		_path_gate_was_blocked = true
		_path_gate_open_timer = 0.0
		_blocked_time += delta
		_yield_request_cooldown = max(_yield_request_cooldown - delta, 0.0)
		_enter_path_still()
		
		# 처음 충돌이 감지된 순간 출력
		if _blocked_time - delta < BLOCKED_REPLAN_SECONDS and _blocked_time >= BLOCKED_REPLAN_SECONDS:
			var blocker: Node = null
			for agent_id in mapf._agents.keys():
				var agent_node = instance_from_id(int(agent_id))
				if agent_node is Node:
					var occupied: Movepoint = mapf._agents[agent_id].get("node")
					if occupied == next_node:
						blocker = agent_node
						break
			if blocker:
				print("[충돌 감지] %s이(가) %s로 가려하는데 %s이(가) %s에 있음" % [
					self.name, next_node.name, blocker.name, next_node.name
				])
		
		if mapf != null and _blocked_time >= BLOCKED_REPLAN_SECONDS and _yield_request_cooldown <= 0.0:
			var requested := mapf.try_resolve_deadlock(self, current_node, next_node, _remaining_path_nodes())
			if requested:
				_yield_request_cooldown = YIELD_REQUEST_COOLDOWN_SECONDS
				_blocked_time = 0.0
		return

	if _path_gate_was_blocked:
		if _path_gate_open_timer < PATH_GATE_OPEN_HOLD_SECONDS:
			_path_gate_open_timer += delta
			_enter_path_still()
			return
		_path_gate_was_blocked = false
		_path_gate_open_timer = 0.0

	_blocked_time = 0.0
	_yield_request_cooldown = max(_yield_request_cooldown - delta, 0.0)

	var next_pos := next_node.global_position
	var to_target := next_pos - global_position
	var distance := to_target.length()
	if distance <= NODE_REACH_EPSILON:
		global_position = next_pos
		_path_index += 1
		_reset_path_gate()
		_current_pin = next_node
		if mapf != null:
			mapf.update_agent_position(self, _current_pin)
		if _path_index >= _planned_path.size() - 1:
			_set_walking_state(false)
			return
		_update_locomotion_for_current_segment(mapf)
		return

	_enter_path_walk()
	var step := move_speed * delta
	global_position = global_position.move_toward(next_pos, step) #TODO 직선거리로 대기장소 가는걸 수정해야 합니다.

	# Smooth turning to avoid right-angle snap at corners.
	if distance > 0.001:
		var dir := to_target.normalized()
		var target_yaw := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clamp(turn_speed * delta, 0.0, 1.0))

func has_reached_path_end() -> bool:
	return not is_walking

func _exit_tree() -> void:
	var mapf := _get_mapf_manager()
	if mapf != null:
		mapf.unregister_agent(self)
	
	
func idle()->void:
	pass
	#TODO check self position pin and play animation
func attack_player()->void:
	pass
	#TODO check self position and try to kill.
	

func _find_path_segment(start:Movepoint, goal:Movepoint) -> Array[Movepoint]:
	var queue:Array[Movepoint] = [start] #큐에 초기 시작위치를 넣는다. #큐는 선입 선출. 
	var came_from :={} #어디 왔는지 확인할 딕션너리 
	came_from[start] = null
	
	var loop_counter = 0#TODO DELETME later
	
	while queue.size() > 0: #큐의 크기가 0 이상이면 계속 
		var current:Movepoint = queue.pop_front() #큐에 맨 앞자리의 값을 꺼낸다. (호출 후 값 삭제)
		#print(current, "조사한 노드?")
		#print(queue.size(), "큐사이즈")
		#print(queue, "큐")
		if current == goal:
			break #도착시 while 탈출 
		if current == null:
			if loop_counter >= 5:
				printerr("null 루프에 빠짐 경로없음!")
				break
			#current = queue.pop_front()
			loop_counter += 1
			printerr("null이 들어감 .")
			continue
		for next in current.neighbors: #큐에서 pop한 값들의 이웃들을 검사. 
			if not came_from.has(next): #만약 검사하는 이웃이 이미 조사했던것이 아니라면 
				came_from[next] = current #이웃이 어디서 왔는지를 작성 
				queue.append(next) #큐에 이웃 값들을 넣기.
		
	if not came_from.has(goal):
		printerr(start," to ", goal, " 이동 가능한 경로가 없음.")
		return [] #경로 없음
		
	
	var path:Array[Movepoint] = []
	var cur:Movepoint = goal
	while cur != null:
		path.push_front(cur)
		cur = came_from[cur]
		
	return path


func find_path(start:Movepoint, goal:Movepoint, must_visit:Movepoint = null) -> Array[Movepoint]:
	# 단순 경로
	if must_visit == null:
		return _find_path_segment(start, goal)
	
	# 반드시 거쳐야 하는 핀(must_visit)을 포함하는 경로:
	# start -> must_visit, must_visit -> goal 두 구간을 이어붙인다.
	var first_segment := _find_path_segment(start, must_visit)
	if first_segment.is_empty():
		return []
	
	var second_segment := _find_path_segment(must_visit, goal)
	if second_segment.is_empty():
		return []
	
	# must_visit이 중복되지 않도록 두 번째 구간의 첫 점은 제거해서 이어붙인다.
	second_segment.remove_at(0)
	first_segment.append_array(second_segment)
	return first_segment

func update_path3d(path:Array):
	var curve:Curve3D = Curve3D.new()
	movepath.curve = curve
	curve.bake_interval = bake_interval_var
	var points: PackedVector3Array = []
	for pin in path:
		if pin == null:
			continue
		
		points.append(pin.global_position)
	for i in points.size():
		curve.add_point(points[i])
	# 꼭짓점 사이를 부드럽게 연결 (베지어 인/아웃 핸들 설정)
	if path_smooth_factor > 0.0 and points.size() >= 2:
		for i in points.size():
			var n := points.size()
			var p_prev := points[i] if i == 0 else points[i - 1]
			var p_curr := points[i]
			var p_next := points[i] if i == n - 1 else points[i + 1]
			var out_offset := Vector3.ZERO
			var in_offset := Vector3.ZERO
			if i < n - 1:
				var to_next := (p_next - p_curr)
				out_offset = to_next * clampf(path_smooth_factor, 0.0, 0.5)
			if i > 0:
				var from_prev := (p_prev - p_curr)
				in_offset = from_prev * clampf(path_smooth_factor, 0.0, 0.5)
			curve.set_point_out(i, out_offset)
			curve.set_point_in(i, in_offset)
