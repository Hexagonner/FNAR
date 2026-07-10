extends Node3D
class_name animatronics

#region PinName enum & maps
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

## 오탈자 노드명도 허용 (하위 호환)
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

#region Exports
@export var is_walking: bool = false
@export var gui_node: Node
@export var path_follow: PathFollow3D
@export var ani_tree: AnimationTree
#@export var move_speed: float = 1.0
@export var turn_speed: float = 8.0
var movepoint: Node3D
#endregion

#region NavigationAgent3D
@onready var navigation_agent: NavigationAgent3D = get_node("NavigationAgent3D")
@export var movement_speed: float = 4.0
#endregion

#region Animation
@onready var playback: AnimationNodeStateMachinePlayback = ani_tree.get("parameters/StateMachine/playback")

var _current_anim_state: StringName = &"idle"
@warning_ignore("unused_private_class_variable")
var _path_locomotion_moving: bool = false
#endregion

#region Navigation movement state
var _planned_path: Array[Movepoint] = []
var _path_index: int = 0
var _current_pin: Movepoint = null
var _main_goal_pin: PinName = PinName.NONE

## 디버그/시각화용: 현재 이동 중인 핀
var _temporary_pin: Movepoint = null
## 디버그/시각화용: 직전에 지나친 핀
var _previous_pin: Movepoint = null
## 디버그/시각화용: 다음으로 이동할 핀
var _next_pin: Movepoint = null
#endregion

var _physics_delta: float = 0.0
var _navigation_initialized: bool = false

## waypoint advance 쿨다운(초). 도착 직후 같은 프레임에 다음 waypoint가
## 즉시 도착 판정되는 것을 막아 도착-재계획 루프를 방지한다.
const _ADVANCE_COOLDOWN: float = 0.2
var _advance_cooldown_remaining: float = 0.0

## 최종 목표 핀에 도착했을 때 발생한다. 도착한 핀과 enum 정보를 함께 전달한다.
signal arrived_at_goal(pin: Movepoint, pin_name: PinName)
func _ready() -> void:
	add_to_group("animatronics")

	# PinPathfinder 그래프 빌드 (루트 MovePoint 노드 찾기)
	_build_pin_graph()


	# 첫 프레임 이후 네비게이션 맵 동기화 대기
	_initialize_navigation.call_deferred()
	navigation_agent.velocity_computed.connect(Callable(_on_velocity_computed))
	navigation_agent.target_reached.connect(_on_navigation_finished)

func _build_pin_graph() -> void:
	var movepoint_root: Node3D = _get_movepoint_root()
	if movepoint_root != null:
		PinPathfinder.build_graph(movepoint_root, true)
		# 현재 위치에서 가장 가까운 핀 찾기
		_current_pin = _find_nearest_pin(movepoint_root)
		if _current_pin != null:
			_previous_pin = _current_pin
			print("[%s] Initial pin: %s" % [name, _current_pin.name])
	else:
		push_warning("[%s] MovePoint root not found" % name)


func _initialize_navigation() -> void:
	await get_tree().physics_frame
	_navigation_initialized = true

	# NavAgent 설정
	# 인스펙터에서 radius / max_speed를 양수로 지정하면 그 값을 존중하고,
	# 비어있으면 기본값을 사용한다. RVO 회피는 활성화하여 RD1/RD2 같은
	# 여러 에이전트가 좁은 통로에서 서로 밀고 들어가는 충돌을 방지한다.
	if navigation_agent != null:
		navigation_agent.path_desired_distance = 0.05
		navigation_agent.target_desired_distance = 0.0
		if navigation_agent.max_speed <= 0.0:
			navigation_agent.max_speed = movement_speed
		if navigation_agent.radius <= 0.0:
			navigation_agent.radius = 0.5
		navigation_agent.neighbor_distance = 2.0
		navigation_agent.max_neighbors = 10
		navigation_agent.time_horizon_agents = 1.0
		navigation_agent.avoidance_enabled = true


## movepoint_root 아래에서 현재 위치에 가장 가까운 Movepoint 핀을 찾는다.
func _find_nearest_pin(movepoint_root: Node3D) -> Movepoint:
	var closest_pin: Movepoint = null
	var closest_dist: float = INF
	var all_pins: Array[Movepoint] = []
	PinPathfinder._collect_pins(movepoint_root, all_pins)

	var my_pos: Vector3 = global_position
	for pin: Movepoint in all_pins:
		var dist: float = my_pos.distance_squared_to(pin.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_pin = pin
	return closest_pin


## 목표 핀 이름(PinName enum)으로 경로를 설정하고 이동을 시작한다.
func set_goal_by_pin_name(target_pin_name: PinName) -> bool:
	if not PinPathfinder.is_built() or _current_pin == null:
		return false

	var target_pin: Movepoint = _resolve_pin(target_pin_name)
	if target_pin == null:
		return false

	_main_goal_pin = target_pin_name
	return _plan_and_start_path(target_pin)


## 목표 Movepoint 노드로 직접 경로를 설정하고 이동을 시작한다.
func set_goal_to_pin(target_pin: Movepoint) -> bool:
	if not PinPathfinder.is_built() or _current_pin == null:
		return false
	_main_goal_pin = PinName.NONE
	return _plan_and_start_path(target_pin)


func _plan_and_start_path(target_pin: Movepoint) -> bool:
	_planned_path = PinPathfinder.find_pin_path(_current_pin, target_pin)
	if _planned_path.is_empty():
		push_warning("[%s] No path from %s to %s" % [name, _current_pin.name, target_pin.name])
		return false

	print("[%s] Path planned: %s -> %s (hops: %d)" % [name, _current_pin.name, target_pin.name, _planned_path.size()])

	_path_index = 0
	if _planned_path[0] == _current_pin and _planned_path.size() > 1:
		_path_index = 1

	# 새 경로 시작 시 첫 waypoint에 대한 도착 판정을 잠시 보류하여
	# 도착-재계획-즉시도착 루프를 방지한다.
	_advance_cooldown_remaining = _ADVANCE_COOLDOWN
	_start_moving_to_next_pin()
	return true


## 경로의 다음 핀으로 NavigationAgent3D의 목표 위치를 설정한다.
func _start_moving_to_next_pin() -> void:
	if _path_index >= _planned_path.size():
		_arrived_at_goal()
		return

	if not _navigation_initialized or navigation_agent == null:
		return

	var target_pin: Movepoint = _planned_path[_path_index]
	if target_pin == null:
		_path_index += 1
		_start_moving_to_next_pin()
		return

	_temporary_pin = target_pin

	if _path_index + 1 < _planned_path.size():
		_next_pin = _planned_path[_path_index + 1]
	else:
		_next_pin = null

	is_walking = true
	_current_anim_state = &"walking_001"
	_play_anim(&"walking_001")

	navigation_agent.set_target_position(target_pin.global_position)
	print("[%s] Moving to pin %s" % [name, target_pin.name])


## 최종 목표 핀에 도착했을 때 호출된다.
## emit의 동기 콜백이 새 경로를 채울 수 있으므로, 도착 상태의 reset은 emit 이전에
## 끝내고 emit은 가장 마지막에 호출한다. 그래야 emit 콜백 안에서 채운 새 경로가
## 즉시 clear되어 무효화되는 일을 막을 수 있다.
func _arrived_at_goal() -> void:
	var arrived_pin: Movepoint = _current_pin
	var arrived_goal: PinName = _main_goal_pin
	is_walking = false
	_current_anim_state = &"idle"
	_play_anim(&"idle")
	_temporary_pin = null
	_next_pin = null
	_planned_path.clear()
	_main_goal_pin = PinName.NONE
	print("[%s] Arrived at goal" % name)
	# 콜백 안에서 set_next_goal이 새 경로를 채울 수 있다.
	arrived_at_goal.emit(arrived_pin, arrived_goal)


## NavigationAgent3D가 현재 목표 위치(하나의 핀)에 도착했을 때 호출된다.
## 우리는 _physics_process에서 직접 거리 기반으로 advance하므로 이 콜백은 사용하지 않는다.
func _on_navigation_finished() -> void:
	# 의도적으로 비워둠. advance는 _physics_process의 거리 체크로 처리.
	pass


## RVO 회피 속도가 계산되었을 때 호출된다. Node3D 방식으로 이동을 적용한다.
func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if _planned_path.is_empty() or _path_index >= _planned_path.size():
		# 도착 상태: 이동 없음, 정지
		_face_movement_direction(Vector3.ZERO)
		return
	var target_pin: Movepoint = _planned_path[_path_index]
	var target_pos: Vector3 = target_pin.global_position
	var dist_to_target: float = global_position.distance_to(target_pos)
	# 도착 직전 (0.3m 이내)에는 정확히 target에 맞춰 정지
	if dist_to_target <= 0.3:
		global_position = target_pos
		_previous_pin = _current_pin
		_current_pin = target_pin
		_face_movement_direction(Vector3.ZERO)
		return
	global_position = global_position.move_toward(
		global_position + safe_velocity,
		_physics_delta * movement_speed
	)
	_face_movement_direction(safe_velocity)


## 이동 방향으로 부드럽게 회전한다.
func _face_movement_direction(velocity: Vector3) -> void:
	if velocity.length_squared() > 0.001:
		var target_basis: Basis = Basis.looking_at(velocity.normalized(), Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(target_basis, _physics_delta * turn_speed)
		global_transform.basis = global_transform.basis.orthonormalized()



func _physics_process(delta):
	# Save the delta for use in _on_velocity_computed.
	_physics_delta = delta
	# Do not query when the map has never synchronized and is empty.
	if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) == 0:
		return
	if navigation_agent.is_navigation_finished():
		return
	if _planned_path.is_empty() or _path_index >= _planned_path.size():
		return

	# advance 쿨다운 중에는 도착 판정을 건너뛴다 (도착-재계획-즉시도착 루프 방지).
	if _advance_cooldown_remaining > 0.0:
		_advance_cooldown_remaining = max(0.0, _advance_cooldown_remaining - delta)
		return

	# 다음 waypoint 도달 판정 (NavigationAgent3D의 자동 advance를 신뢰하지 않고 직접 처리)
	var target_pin: Movepoint = _planned_path[_path_index]
	var target_pos: Vector3 = target_pin.global_position
	var dist_to_target: float = global_position.distance_to(target_pos)
	# target_desired_distance보다 가까우면 다음 waypoint로 advance
	if dist_to_target <= 0.3:
		# 도달한 핀을 _current_pin에 기록 → 다음 경로 계획의 시작점이 된다.
		_previous_pin = _current_pin
		_current_pin = target_pin
		# 다음 waypoint로 진행
		_path_index += 1
		_advance_cooldown_remaining = _ADVANCE_COOLDOWN
		if _path_index >= _planned_path.size():
			_arrived_at_goal()
			return
		_start_moving_to_next_pin()
		return

	# target까지 직접 이동 (NavigationAgent3D의 path 중간 waypoint를 무시)
	var next_path_position: Vector3 = target_pos
	var new_velocity: Vector3 = global_position.direction_to(next_path_position) * movement_speed
	if navigation_agent.avoidance_enabled:
		navigation_agent.set_velocity(new_velocity)
	else:
		_on_velocity_computed(new_velocity)



func _play_anim(anim_name: StringName) -> void:
	if playback != null:
		playback.travel(anim_name)


## PinName enum 값으로 실제 Movepoint 노드를 찾는다.
func _resolve_pin(pin_name: PinName) -> Movepoint:
	if pin_name == PinName.NONE:
		return null

	var movepoint_root: Node3D = _get_movepoint_root()
	if movepoint_root == null:
		return null

	# 정식 이름으로 먼저 시도
	var node_name: String = PIN_NODE_NAMES.get(pin_name, "")
	if node_name.is_empty():
		return null

	var pin_node: Node = movepoint_root.find_child(node_name, true, false)
	if pin_node != null and pin_node is Movepoint:
		return pin_node as Movepoint

	# 별칭으로 시도
	var aliases: Array = PIN_NODE_ALIASES.get(pin_name, [])
	for alias: String in aliases:
		pin_node = movepoint_root.find_child(alias, true, false)
		if pin_node != null and pin_node is Movepoint:
			return pin_node as Movepoint

	push_warning("[%s] Pin not found: %s (name: %s)" % [name, pin_name, node_name])
	return null


func set_movement_target(movement_target: Vector3):
	navigation_agent.set_target_position(movement_target)

## 목표 핀으로 이동을 시작한다. 이미 이동 중이면 즉시 새 경로로 재계획된다.
## on_arrived가 유효한 Callable이면 도착 시그널에 등록된다(다음 프레임에 등록됨).
## emit 진행 중 disconnect/connect로 인한 시그널 emit 깨짐(콜백 누락/중복)을
## 피하기 위해 핸들러 등록은 call_deferred로 다음 프레임에 실행한다.
func set_next_goal(target_pin_name: PinName, on_arrived: Callable = Callable()) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if on_arrived.is_valid():
		_defer_set_arrival_handler(on_arrived)
	var result: bool = set_goal_by_pin_name(target_pin_name)
	if not result:
		push_warning("[%s] Failed to set next goal to %s" % [name, target_pin_name])

## 도착 핸들러 등록을 다음 프레임으로 미룬다.
func _defer_set_arrival_handler(callable: Callable) -> void:
	call_deferred("_apply_deferred_arrival_handler", callable)

func _apply_deferred_arrival_handler(callable: Callable) -> void:
	set_arrival_handler(callable)

## 도착 시그널에 Callable 1개를 연결한다. 이미 연결된 핸들러가 있으면 교체한다.
## 또한 도달 시 추가로 다른 핸들러를 등록하고 싶다면 set_arrival_handler를 여러 번 호출하기보다
## arrived_at_goal.connect(...)를 직접 사용하면 된다.
func set_arrival_handler(callable: Callable) -> void:
	if not callable.is_valid():
		push_warning("[%s] set_arrival_handler called with invalid Callable" % name)
		return
	for c: Dictionary in arrived_at_goal.get_connections():
		var existing: Callable = c["callable"]
		arrived_at_goal.disconnect(existing)
	arrived_at_goal.connect(callable)

## 도착 시그널에 연결된 모든 핸들러를 해제한다.
func clear_arrival_handlers() -> void:
	for c: Dictionary in arrived_at_goal.get_connections():
		var existing: Callable = c["callable"]
		arrived_at_goal.disconnect(existing)

## 씬에서 MovePoint 루트 노드를 찾는다.
func _get_movepoint_root() -> Node3D:
	# 먼저 부모의 자식 중 "MovePoint" 이름을 가진 노드를 찾는다.
	var parent: Node = get_parent()
	if parent != null:
		for child in parent.get_children():
			if child is Node3D and child.name == "MovePoint":
				return child as Node3D
	# fallback: movepoint export에서 역으로 올라가 루트 탐색
	if movepoint != null:
		var node: Node = movepoint
		while node != null:
			if node.name == "MovePoint":
				return node as Node3D
			node = node.get_parent()
	return null
