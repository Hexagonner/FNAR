extends Node

## 모바일 환경에 최적화된 소수(4개 이하) 에이전트용 다중 에이전트 경로 탐색(MAPF) 매니저입니다.
## 우선순위 기반 계획(Prioritized Planning) + 예약 테이블(Reservation Table) + 시간 확장 A*(Time-expanded A*) 알고리즘을 사용합니다.
class_name MapfPlanner

# 설정값들
const MAX_HORIZON := 48           # 경로 탐색 시 고려할 최대 시간 단계(너무 길어지면 성능 저하 방지)
const GOAL_HOLD_TICKS := MAX_HORIZON + 8 # 목적지에 도착한 후 해당 위치를 점유하고 있을 시간
const MAX_EXPANSIONS := 4096      # A* 탐색 시 확인할 최대 노드 수 (무한 루프 방지)
const YIELD_SEARCH_DEPTH := 10    # 길 양보를 위해 비어있는 공간을 찾을 때의 탐색 깊이
const YIELD_COOLDOWN_MS := 300    # 양보 요청 간의 대기 시간(연속된 양보 방지) - 단축: 1200ms → 300ms
const YIELD_MIN_CONFLICT_DISTANCE := 1 # 양보 시 충돌 지점으로부터 떨어져야 하는 최소 거리 (1칸으로 충분)
const FORBIDDEN_BUFFER_DEPTH := 1 # 양보 지점 선택 시 다른 경로 근처에 가지 않도록 하는 여유 공간
const BLOCKED_REPLAN_MAX_TIMES := 5 # 같은 충돌에 대한 최대 양보 요청 횟수 (무한 루프 방지)

var _agents: Dictionary = {}           # 등록된 에이전트들의 정보 (위치, 목표, 경로 등)
var _priority_order: Array[String] = [] # 에이전트들의 우선순위 순서
var _distance_cache: Dictionary = {}    # 노드 간 거리 계산 결과 저장 (속도 향상용)
var _yield_cooldown_until: Dictionary = {} # 에이전트별 다음 양보 가능 시간
var _yield_attempt_count: Dictionary = {} # 에이전트별 양보 시도 횟수 (충돌 위치별)
var _next_priority := 0                # 다음에 부여할 우선순위 번호

## 에이전트를 시스템에 등록합니다.
func register_agent(agent: Node, start_pin: Movepoint) -> void:
	var id := _agent_id(agent)
	if not _agents.has(id):
		_priority_order.append(id)
		_next_priority += 1
		_agents[id] = {
			"node": start_pin, # 현재 위치
			"goal": null,      # 목표 위치
			"must": null,      # 반드시 거쳐야 하는 경유지
			"path": [],        # 계산된 경로
			"path_index": 0,   # ⭐ NEW: 경로상 현재 위치 인덱스
			"valid": true,     # 경로 유효성 여부
			"priority": _next_priority, # 우선순위
		}
		return
	# 이미 등록된 경우 위치 정보 등을 업데이트
	_agents[id] = {
		"node": start_pin,
		"goal": null,
		"must": null,
		"path": [],
		"path_index": 0,      # ⭐ NEW: 경로상 현재 위치 인덱스
		"valid": true,
		"priority": _agents[id].get("priority", 999999),
	}
	# 새 경로 설정 시 해당 에이전트의 양보 시도 횟수 초기화
	_reset_yield_attempts_for_agent(id)

## 에이전트 등록을 해제합니다.
func unregister_agent(agent: Node) -> void:
	var id := _agent_id(agent)
	_agents.erase(id)
	_priority_order.erase(id)
	_reset_yield_attempts_for_agent(id)

## 특정 에이전트의 양보 시도 횟수를 초기화합니다.
func _reset_yield_attempts_for_agent(agent_id: String) -> void:
	for key in _yield_attempt_count.keys():
		if key.begins_with(agent_id):
			_yield_attempt_count.erase(key)

## 특정 에이전트의 경로를 요청합니다.
func request_path(agent: Node, start_pin: Movepoint, goal_pin: Movepoint, must_visit_pin: Movepoint = null) -> Array[Movepoint]:
	var id := _agent_id(agent)
	register_agent(agent, start_pin)
	_agents[id]["node"] = start_pin
	_agents[id]["goal"] = goal_pin
	_agents[id]["must"] = must_visit_pin
	_agents[id]["valid"] = true
	
	# 새로운 목표로 변경된 경우, 이전 충돌에 대한 양보 시도 횟수 초기화
	_reset_yield_attempts_for_agent(id)
	
	# 모든 에이전트의 경로를 다시 계산합니다 (우선순위 기반이므로 한 명만 바뀌어도 연쇄 영향)
	_replan_all()
	
	var result = _agents[id].get("path", [])
	if result is Array:
		return result
	return []

## 에이전트의 현재 위치를 업데이트합니다.
func update_agent_position(agent: Node, pin: Movepoint, path_index: int = -1) -> void:
	var id := _agent_id(agent)
	if _agents.has(id):
		_agents[id]["node"] = pin
		# ⭐ NEW: 경로상 현재 인덱스 동기화 (전달되지 않으면 현재 경로에서 pin의 위치 찾기)
		if path_index >= 0:
			_agents[id]["path_index"] = path_index
		else:
			var path: Array = _agents[id].get("path", [])
			for i in range(path.size()):
				if path[i] == pin:
					_agents[id]["path_index"] = i
					break

## 특정 노드(위치)에 들어갈 수 있는지 확인합니다. (다른 에이전트가 서 있는지 체크)
func can_enter_node(agent: Node, node: Movepoint) -> bool:
	if node == null:
		return false
	var requester_id := _agent_id(agent)
	for id in _agents.keys():
		if id == requester_id:
			continue
		var occupied: Movepoint = _agents[id].get("node")
		if occupied == node:
			return false
	return true

## 교착 상태(Deadlock)를 해결하려고 시도합니다.
## 두 에이전트가 서로 가려는 길을 막고 있을 때, 한 명이 비켜주는(Yield) 로직입니다.
func try_resolve_deadlock(blocked_agent: Node, blocked_from: Movepoint, blocked_to: Movepoint, requester_remaining: Array[Movepoint]) -> bool:
	if blocked_agent == null or blocked_to == null:
		return false
		
	# 가로막고 있는 에이전트(Blocker)를 찾습니다.
	var blocker := _find_agent_at_node(blocked_to, blocked_agent)
	if blocker == null:
		return false
		
	var blocked_id := _agent_id(blocked_agent)
	var blocker_id := _agent_id(blocker)
	var now_ms := Time.get_ticks_msec()
	
	# 우선순위 확인 (숫자가 작을수록 높음)
	var blocked_priority: int = int(_agents.get(blocked_id, {}).get("priority", 999999))
	var blocker_priority: int = int(_agents.get(blocker_id, {}).get("priority", 999999))

	# 낮은 우선순위의 에이전트가 먼저 양보하도록 설정합니다.
	var yielder: Node = blocker
	var yielder_id := blocker_id
	if blocked_priority > blocker_priority:
		yielder = blocked_agent
		yielder_id = blocked_id

	# 양보 쿨타임 확인
	var cooldown_until: int = _yield_cooldown_until.get(yielder_id, 0)
	if now_ms < cooldown_until:
		return false
	
	# 같은 충돌 지점에 대한 양보 시도 제한 (무한 루프 방지)
	var conflict_key := "%s|%s|%s" % [_agent_id(blocked_agent), _node_id(blocked_to), _agent_id(blocker)]
	var attempt_count: int = _yield_attempt_count.get(conflict_key, 0)
	if attempt_count >= BLOCKED_REPLAN_MAX_TIMES:
		print("[양보 불가] %s→%s 충돌: 최대 양보 횟수(%d) 초과, 계속 진행" % [
			blocked_agent.name, blocker.name, BLOCKED_REPLAN_MAX_TIMES
		])
		# 쿨타임을 더 길게 설정하여 안정화 유도
		_yield_cooldown_until[yielder_id] = now_ms + 2000
		return false
	_yield_attempt_count[conflict_key] = attempt_count + 1

	# 비켜줄 만한 적절한 위치(Target)를 찾습니다.
	var yield_target := _find_yield_target(yielder, blocked_from, blocked_to, requester_remaining)
	if yield_target == null:
		# 양보 위치를 찾을 수 없으면 현재 위치 인근으로 폴백
		yield_target = _find_yield_target_fallback(yielder, blocked_from, blocked_to, requester_remaining)
		if yield_target == null:
			print("[충돌] %s가 %s를 막고 있음 → %s가 양보할 위치를 찾을 수 없음 (폴백 실패)" % [
				blocker.name, 
				blocked_agent.name,
				yielder.name
			])
			return false
		print("[양보 폴백] 표준 양보 위치 선택 실패 → 인근 회피 경로 탐색")
		
	# 에이전트 노드에 'request_yield_to' 함수가 있다면 양보를 요청합니다.
	if not yielder.has_method("request_yield_to"):
		return false
	
	var yield_target_name: String = yield_target.name if yield_target != null else "Unknown"
	var accepted: bool = yielder.call("request_yield_to", yield_target)
	if accepted:
		# 양보를 수락했다면 쿨타임을 설정합니다.
		_yield_cooldown_until[yielder_id] = now_ms + YIELD_COOLDOWN_MS
		print("[양보 성공] %s → %s (양보자: %s, 목표: %s)" % [
			blocked_agent.name,
			blocker.name,
			yielder.name,
			yield_target_name
		])
	else:
		print("[양보 거부] %s가 양보를 거부함 (목표: %s)" % [yielder.name, yield_target_name])
	return accepted

## 특정 노드에 위치한 에이전트를 찾습니다.
func _find_agent_at_node(node: Movepoint, except_agent: Node = null) -> Node:
	for id in _agents.keys():
		var agent_node = instance_from_id(int(id))
		if not (agent_node is Node):
			continue
		if except_agent != null and agent_node == except_agent:
			continue
		var occupied: Movepoint = _agents[id].get("node")
		if occupied == node:
			return agent_node
	return null

## 양보할 위치를 찾을 수 없을 때의 폴백 전략: 양보자의 현재 위치 근처에서 가장 가까운 비어있는 노드
func _find_yield_target_fallback(blocker: Node, blocked_from: Movepoint, blocked_to: Movepoint, requester_remaining: Array[Movepoint]) -> Movepoint:
	var blocker_id := _agent_id(blocker)
	var blocker_node: Movepoint = _agents[blocker_id].get("node")
	if blocker_node == null:
		return null
	
	# 봉쇄된 구간 설정: 양보자가 진행하려던 전체 경로를 금지하여 다른 방향으로 양보하도록 유도
	var minimal_forbidden: Dictionary = {}
	minimal_forbidden[_node_id(blocked_to)] = true
	minimal_forbidden[_node_id(blocked_from)] = true
	
	# ⭐ 개선: requester_remaining (양보자가 진행하려던 경로) 전체를 금지
	# 이미 지나온 경로가 아닌, 앞으로 가려는 경로만 금지하여 뒤쪽 양보 가능
	for candidate_node in requester_remaining:
		if candidate_node != null:
			minimal_forbidden[_node_id(candidate_node)] = true
	
	# 양보자의 현재 위치에서 1-2칸 떨어진 곳 검색 (금지된 방향 제외)
	var candidates: Array[Movepoint] = blocker_node.neighbors.duplicate()
	for candidate in candidates:
		if candidate == null: continue
		var node_id := _node_id(candidate)
		if minimal_forbidden.has(node_id): continue
		if not can_enter_node(blocker, candidate): continue
		return candidate
	
	# 2칸 거리까지 확장
	var _secondary: Array[Movepoint] = []
	for first in blocker_node.neighbors:
		if first == null: continue
		for second in first.neighbors:
			if second == null: continue
			if second == blocker_node: continue
			var node_id := _node_id(second)
			if minimal_forbidden.has(node_id): continue
			if can_enter_node(blocker, second):
				return second
	
	return null

## 양보할 때 이동할 안전한 노드를 찾습니다.
func _find_yield_target(blocker: Node, blocked_from: Movepoint, blocked_to: Movepoint, requester_remaining: Array[Movepoint]) -> Movepoint:
	var blocker_id := _agent_id(blocker)
	if not _agents.has(blocker_id):
		return null
	var blocker_node: Movepoint = _agents[blocker_id].get("node")
	if blocker_node == null:
		return null

	# ⭐ 개선: 현재 위치에서의 대기가 항상 가능한지 먼저 확인
	# (현재 위치는 이미 안전한 곳이므로 충돌 거리 체크 불필요)
	if can_enter_node(blocker, blocker_node):
		return blocker_node  # 현재 위치에서 그냥 대기하면 됨!

	# 피해야 할 '금지 구역'을 설정합니다 (상대방의 이동 경로 등)
	var forbidden: Dictionary = _build_forbidden_nodes_for_yield(blocker_id, blocked_from, blocked_to, requester_remaining)
	
	# 각 지점으로부터의 거리를 계산하는 맵 생성
	var distance_from_blocker := _bfs_distance_map(blocker_node, YIELD_SEARCH_DEPTH)
	var distance_from_blocked_to := _bfs_distance_map(blocked_to, YIELD_SEARCH_DEPTH)
	var distance_from_blocked_from := _bfs_distance_map(blocked_from, YIELD_SEARCH_DEPTH)
	
	# blocker의 현재 경로를 이용해 blocker가 이미 가려던 경로 상의 노드들을 수집합니다
	var blocker_state: Dictionary = _agents[blocker_id]
	var blocker_path: Array = blocker_state.get("path", [])
	var path_node_ids: Dictionary = {} # 경로상의 노드들
	for node in blocker_path:
		if node is Movepoint:
			path_node_ids[_node_id(node)] = true
	
	var best_node: Movepoint = null
	var best_distance := 999999
	var best_is_on_path := false
	
	# 디버깅용 통계
	var candidates_checked := 0
	var candidates_filtered := 0
	var candidates_on_path := 0
	var candidates_valid := 0

	for node_id in distance_from_blocker.keys():
		var candidate: Movepoint = get_node_or_null(NodePath(node_id)) as Movepoint
		if candidate == null: continue
		
		candidates_checked += 1
		
		if forbidden.has(node_id):
			candidates_filtered += 1
			continue # 금지된 곳은 패스
		if not can_enter_node(blocker, candidate):
			candidates_filtered += 1
			continue # 이미 누가 있는 곳 패스
		
		var d_from_blocker: int = int(distance_from_blocker[node_id])
		if d_from_blocker < 0: continue  # 거리가 0인 경우(현재 위치)도 허용
		
		# 충돌 지점에서 충분히 떨어져 있는지 확인
		var d_from_blocked_to: int = int(distance_from_blocked_to.get(node_id, 999999))
		var d_from_blocked_from: int = int(distance_from_blocked_from.get(node_id, 999999))
		if d_from_blocked_to < YIELD_MIN_CONFLICT_DISTANCE:
			candidates_filtered += 1
			continue
		if d_from_blocked_from < YIELD_MIN_CONFLICT_DISTANCE:
			candidates_filtered += 1
			continue
		
		candidates_valid += 1
		
		# 경로 상에 있는지 확인합니다
		var is_on_path: bool = path_node_ids.has(node_id)
		if is_on_path:
			candidates_on_path += 1
		
		# 개선된 우선순위 로직:
		# Tier 1: 현재 위치에서 매우 가까운 곳 (거리 1-2)
		# Tier 2: 경로 상의 노드 중 가장 가까운 곳
		# Tier 3: 모든 노드 중 가장 가까운 곳
		
		var is_better := false
		var current_blocker_dist: int = int(distance_from_blocker.get(_node_id(blocker_node), 999999))
		
		if best_node == null:
			is_better = true
		elif d_from_blocker <= 2:
			# 아주 가까운 곳(1-2칸)은 항상 선호
			if current_blocker_dist > 2:
				is_better = true
			elif d_from_blocker < current_blocker_dist:
				is_better = true
		elif is_on_path and not best_is_on_path:
			# 경로상 노드를 처음 찾은 경우
			is_better = true
		elif is_on_path == best_is_on_path and d_from_blocker < best_distance:
			# 같은 카테고리 내에서는 거리가 가까운 것을 선택
			is_better = true
		
		if is_better:
			best_distance = d_from_blocker
			best_node = candidate
			best_is_on_path = is_on_path
	
	# 결과 출력
	if best_node != null:
		var target_info: String
		if best_distance <= 2:
			target_info = "근처"
		elif best_is_on_path:
			target_info = "경로상"
		else:
			target_info = "경로외"
		print("  [양보 대상 선택] %s ← %s (거리:%d, %s) | 검토:%d, 필터:%d, 유효:%d" % [
			best_node.name, blocker.name, best_distance, target_info,
			candidates_checked, candidates_filtered, candidates_valid
		])
	else:
		# 후보 부족 디버깅: 금지 구역이 너무 넓은 경우 완화 로직 필요
		print("  [양보 대상 선택 실패] 검토:%d개, 필터:%d개, 유효:%d개, 경로상:%d개" % [
			candidates_checked, candidates_filtered, candidates_valid, candidates_on_path
		])
		if candidates_valid == 0 and candidates_checked > 0:
			print("  → 금지 구역이 너무 넓을 가능성 높음. 차단 해제 검토 필요")
	
	return best_node

## 양보할 때 들어가면 안 되는 노드들의 목록을 만듭니다.
func _build_forbidden_nodes_for_yield(
	blocker_id: String,
	blocked_from: Movepoint,
	blocked_to: Movepoint,
	requester_remaining: Array[Movepoint]
) -> Dictionary:
	var forbidden: Dictionary = {}
	# 현재 충돌이 발생한 구간은 금지
	if blocked_from != null: forbidden[_node_id(blocked_from)] = true
	if blocked_to != null: forbidden[_node_id(blocked_to)] = true
	# 상대방이 앞으로 가려는 남은 경로도 금지
	for node in requester_remaining:
		if node != null: forbidden[_node_id(node)] = true

	# 다른 에이전트들의 위치와 계획된 경로도 금지
	for id in _agents.keys():
		if id == blocker_id: continue
		var current_node: Movepoint = _agents[id].get("node")
		if current_node != null: forbidden[_node_id(current_node)] = true
		var planned: Array = _agents[id].get("path", [])
		# ⭐ 개선: 경로상 현재 인덱스 기준으로 앞으로 가려는 경로만 금지
		# 이미 지나온 경로는 금지하지 않음 (양보 위치를 뒤쪽으로 더 확보)
		var path_index: int = _agents[id].get("path_index", 0)
		var start: int = max(path_index, 0)  # 현재 위치부터 시작
		var limit: int = mini(planned.size(), start + 3)  # 앞으로 3칸까지만 금지
		for i in range(start, limit):
			var planned_node: Variant = planned[i]
			if planned_node is Movepoint:
				forbidden[_node_id(planned_node as Movepoint)] = true
	
	# 양보자의 현재 경로도 금지 (양보 중에 원래 경로로 돌아가면 안됨)
	var blocker_path: Array = _agents[blocker_id].get("path", [])
	# ⭐ 개선: path_index를 사용하여 정확한 경로상 위치 파악
	var blocker_path_index: int = _agents[blocker_id].get("path_index", 0)
	if blocker_path.size() > 0:
		var start_idx: int = max(blocker_path_index + 1, 0)
		var limit_future: int = mini(blocker_path.size(), start_idx + 15)
		for i in range(start_idx, limit_future):
			var planned_node: Variant = blocker_path[i]
			if planned_node is Movepoint:
				forbidden[_node_id(planned_node as Movepoint)] = true
	
	# 주변 노드까지 금지 구역을 확장해서 여유 공간 확보
	_expand_forbidden_by_neighbors(forbidden, FORBIDDEN_BUFFER_DEPTH)
	return forbidden

## 금지 구역 주변을 추가로 금지 구역으로 설정합니다.
func _expand_forbidden_by_neighbors(forbidden: Dictionary, depth: int) -> void:
	if depth <= 0: return
	var frontier: Array[Movepoint] = []
	for node_id in forbidden.keys():
		var node := get_node_or_null(NodePath(String(node_id))) as Movepoint
		if node != null: frontier.append(node)
	
	for _step in range(depth):
		var next_frontier: Array[Movepoint] = []
		for node in frontier:
			for neighbor in node.neighbors:
				if neighbor == null: continue
				var n_id := _node_id(neighbor)
				if forbidden.has(n_id): continue
				forbidden[n_id] = true
				next_frontier.append(neighbor)
		frontier = next_frontier
		if frontier.is_empty(): return

## BFS(너비 우선 탐색)를 사용하여 시작 지점부터 주변 노드까지의 거리를 계산합니다.
func _bfs_distance_map(start: Movepoint, max_depth: int) -> Dictionary:
	var distance: Dictionary = {}
	if start == null: return distance
	var queue: Array[Movepoint] = [start]
	distance[_node_id(start)] = 0
	while not queue.is_empty():
		var current: Movepoint = queue.pop_front()
		var current_id := _node_id(current)
		var d: int = int(distance[current_id])
		if d >= max_depth: continue
		for next in current.neighbors:
			if next == null: continue
			var next_id := _node_id(next)
			if distance.has(next_id): continue
			distance[next_id] = d + 1
			queue.append(next)
	return distance

## 우선순위에 따라 모든 에이전트의 경로를 다시 계산합니다.
func _replan_all() -> void:
	var node_reservations: Dictionary = {} # 시간별 노드 예약 정보 {시간: {노드ID: 에이전트ID}}
	var edge_reservations: Dictionary = {} # 시간별 간선(이동경로) 예약 정보 {시간: {간선ID: 에이전트ID}}
	
	for id in _priority_order:
		if not _agents.has(id): continue
		var state: Dictionary = _agents[id]
		var start_pin: Movepoint = state.get("node")
		var goal_pin: Movepoint = state.get("goal")
		var must_pin: Movepoint = state.get("must")
		
		if start_pin == null:
			state["path"] = []
			state["valid"] = false
			_agents[id] = state
			continue

		var path: Array[Movepoint] = []
		if goal_pin == null:
			path = [start_pin]
		else:
			# 특정 에이전트의 경로를 탐색할 때, 이미 우선순위가 높은 에이전트들이 예약한 시간/위치를 피합니다.
			path = _plan_for_agent(id, start_pin, goal_pin, must_pin, node_reservations, edge_reservations)
			if path.is_empty():
				path = [start_pin]
				state["valid"] = false
			else:
				state["valid"] = true
		
		state["path"] = path
		_agents[id] = state
		# 계산된 경로를 예약 테이블에 등록하여 다음 순위 에이전트들이 피하게 합니다.
		_reserve_path(id, path, node_reservations, edge_reservations)

## 한 에이전트를 위해 경로를 생성합니다. (경유지 포함 가능)
func _plan_for_agent(
	agent_id: String,
	start_pin: Movepoint,
	goal_pin: Movepoint,
	must_pin: Movepoint,
	node_reservations: Dictionary,
	edge_reservations: Dictionary
) -> Array[Movepoint]:
	var waypoints: Array[Movepoint] = []
	if must_pin != null and must_pin != goal_pin:
		waypoints.append(must_pin)
	waypoints.append(goal_pin)

	var merged: Array[Movepoint] = [start_pin]
	var current := start_pin
	var start_t := 0
	for waypoint in waypoints:
		# 시간 확장 A*를 사용하여 충돌 없는 경로 탐색
		var segment := _time_a_star(agent_id, current, waypoint, start_t, node_reservations, edge_reservations)
		if segment.is_empty():
			return []
		segment.remove_at(0) # 시작 노드 중복 제거
		merged.append_array(segment)
		current = waypoint
		start_t = merged.size() - 1
	return merged

## 시간 요소를 고려한 A* 경로 탐색 알고리즘입니다.
## (위치, 시간)의 조합을 하나의 상태로 보고 탐색합니다.
func _time_a_star(
	agent_id: String,
	start_node: Movepoint,
	goal_node: Movepoint,
	start_t: int,
	node_reservations: Dictionary,
	edge_reservations: Dictionary
) -> Array[Movepoint]:
	if start_node == goal_node:
		return [start_node]

	var open: Array[Dictionary] = []   # 탐색할 후보 상태들
	var came_from: Dictionary = {}    # 경로 역추적용
	var g_score: Dictionary = {}      # 시작점부터의 실제 거리
	var closed: Dictionary = {}       # 이미 확인한 상태
	
	var start_key := _state_key(start_node, start_t)
	g_score[start_key] = 0
	open.append({
		"node": start_node,
		"t": start_t,
		"f": _heuristic(start_node, goal_node),
		"g": 0
	})

	var expansions := 0
	while not open.is_empty() and expansions < MAX_EXPANSIONS:
		expansions += 1
		# f점수(실제거리 + 예상남은거리)가 가장 낮은 상태를 먼저 확인
		var current_index := _pop_lowest_f_index(open)
		var current: Dictionary = open[current_index]
		open.remove_at(current_index)

		var node: Movepoint = current["node"]
		var t: int = current["t"]
		var state_key := _state_key(node, t)
		if closed.has(state_key): continue
		closed[state_key] = true

		# 목적지 도착 시 경로 재구성하여 반환
		if node == goal_node:
			return _reconstruct_path(came_from, state_key)
			
		# 최대 탐색 시간 범위를 넘어가면 포기
		if (t - start_t) >= MAX_HORIZON: continue

		# 이동 가능한 노드들 (주변 이웃들 + 제자리 대기)
		var candidates: Array[Movepoint] = node.neighbors.duplicate()
		candidates.append(node) # 제자리 대기(Wait) 액션 포함

		for next_node in candidates:
			if next_node == null: continue
			var next_t := t + 1
			
			# 해당 시간에 해당 위치가 이미 예약되어 있는지 확인 (Vertex Conflict)
			if _is_vertex_reserved(node_reservations, next_node, next_t, agent_id):
				continue
			# 두 에이전트가 서로 엇갈려 지나가는지 확인 (Edge Conflict)
			if _is_edge_conflict(edge_reservations, node, next_node, t, agent_id):
				continue

			var next_key := _state_key(next_node, next_t)
			var tentative_g: int = int(current["g"]) + 1
			if g_score.has(next_key) and tentative_g >= int(g_score[next_key]):
				continue
				
			g_score[next_key] = tentative_g
			came_from[next_key] = state_key
			open.append({
				"node": next_node,
				"t": next_t,
				"g": tentative_g,
				"f": tentative_g + _heuristic(next_node, goal_node) # A* 핵심 수식
			})
	return []

## 찾은 경로를 예약 테이블에 등록합니다.
func _reserve_path(agent_id: String, path: Array[Movepoint], node_reservations: Dictionary, edge_reservations: Dictionary) -> void:
	if path.is_empty(): return
	for t in range(path.size()):
		_reserve_vertex(node_reservations, path[t], t, agent_id)
		if t < path.size() - 1:
			_reserve_edge(edge_reservations, path[t], path[t + 1], t, agent_id)
	
	# 목적지에 도착한 이후에도 일정 시간 동안 그 자리를 점유하는 것으로 예약합니다.
	var goal_node: Movepoint = path[path.size() - 1]
	var goal_t := path.size() - 1
	for extra in range(1, GOAL_HOLD_TICKS + 1):
		_reserve_vertex(node_reservations, goal_node, goal_t + extra, agent_id)

# --- 예약 테이블 관리 유틸리티 ---

func _reserve_vertex(node_reservations: Dictionary, node: Movepoint, t: int, agent_id: String) -> void:
	if not node_reservations.has(t): node_reservations[t] = {}
	node_reservations[t][_node_id(node)] = agent_id

func _reserve_edge(edge_reservations: Dictionary, from_node: Movepoint, to_node: Movepoint, t: int, agent_id: String) -> void:
	if not edge_reservations.has(t): edge_reservations[t] = {}
	edge_reservations[t][_edge_id(from_node, to_node)] = agent_id

func _is_vertex_reserved(node_reservations: Dictionary, node: Movepoint, t: int, agent_id: String) -> bool:
	if not node_reservations.has(t): return false
	var at_time: Dictionary = node_reservations[t]
	var node_owner = at_time.get(_node_id(node))
	return node_owner != null and node_owner != agent_id

func _is_edge_conflict(edge_reservations: Dictionary, from_node: Movepoint, to_node: Movepoint, t: int, agent_id: String) -> bool:
	if not edge_reservations.has(t): return false
	var at_time: Dictionary = edge_reservations[t]
	var reverse_key := _edge_id(to_node, from_node)
	var same_key := _edge_id(from_node, to_node)
	
	# 반대 방향에서 오는 에이전트와 충돌하는지 체크
	var reverse_owner = at_time.get(reverse_key)
	if reverse_owner != null and reverse_owner != agent_id: return true
	# 같은 방향으로 가려는 에이전트가 있는지 체크
	var same_owner = at_time.get(same_key)
	return same_owner != null and same_owner != agent_id

## 탐색된 결과를 토대로 경로 배열을 다시 만듭니다.
func _reconstruct_path(came_from: Dictionary, end_key: String) -> Array[Movepoint]:
	var path: Array[Movepoint] = []
	var current_key := end_key
	while true:
		path.push_front(_key_to_node(current_key))
		if not came_from.has(current_key): break
		current_key = came_from[current_key]
	return path

## A* 알고리즘용 휴리스틱 (현재 위치에서 목표까지의 예상 거리)
func _heuristic(from_node: Movepoint, to_node: Movepoint) -> int:
	var key := "%s->%s" % [_node_id(from_node), _node_id(to_node)]
	if _distance_cache.has(key): return _distance_cache[key]
	var dist := _graph_distance(from_node, to_node)
	_distance_cache[key] = dist
	return dist

## 그래프에서 두 지점 사이의 최단 거리를 BFS로 계산합니다.
func _graph_distance(start: Movepoint, goal: Movepoint) -> int:
	if start == goal: return 0
	var queue: Array[Movepoint] = [start]
	var distance: Dictionary = {start: 0}
	while not queue.is_empty():
		var current: Movepoint = queue.pop_front()
		var d: int = distance[current]
		for next in current.neighbors:
			if next == null or distance.has(next): continue
			distance[next] = d + 1
			if next == goal: return d + 1
			queue.append(next)
	return 9999

## 후보들 중 가장 f점수가 낮은 인덱스를 찾습니다.
func _pop_lowest_f_index(open: Array[Dictionary]) -> int:
	var best_idx := 0
	var best_f := INF
	for i in range(open.size()):
		var f_val: float = float(open[i]["f"])
		if f_val < best_f:
			best_f = f_val
			best_idx = i
	return best_idx

# --- ID 및 키 생성 유틸리티 ---

func _agent_id(agent: Node) -> String:
	return str(agent.get_instance_id())



func _node_id(node: Movepoint) -> String:
	return str(node.get_path())

func _edge_id(from_node: Movepoint, to_node: Movepoint) -> String:
	return "%s->%s" % [_node_id(from_node), _node_id(to_node)]

func _state_key(node: Movepoint, t: int) -> String:
	return "%s|%d" % [_node_id(node), t]

func _key_to_node(state_key: String) -> Movepoint:
	var split := state_key.split("|")
	if split.is_empty(): return null
	var path := NodePath(split[0])
	return get_node_or_null(path) as Movepoint
