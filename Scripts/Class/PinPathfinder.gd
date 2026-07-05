extends RefCounted
class_name PinPathfinder

## AStar3D 기반 핀 그래프 경로 탐색기.
## 모든 Movepoint 노드와 그 이웃 연결을 AStar3D 그래프로 구축한다.
##
## 사용법:
##   PinPathfinder.build_graph(movepoint_root)  # 1회 빌드
##   var path = PinPathfinder.find_pin_path(from, to)  # 경로 탐색
##   PinPathfinder.reset()  # 필요 시 재빌드

static var _astar: AStar3D = null
static var _pin_to_id: Dictionary = {}  # Movepoint -> int
static var _id_to_pin: Dictionary = {}  # int -> Movepoint
static var _built: bool = false


## Movepoint 루트 아래의 모든 핀을 수집하여 AStar3D 그래프를 구축한다.
static func build_graph(movepoint_root: Node3D, force: bool = false) -> void:
	if _built and not force:
		return
	if force:
		reset()
	_astar = AStar3D.new()
	_pin_to_id.clear()
	_id_to_pin.clear()

	var all_pins: Array[Movepoint] = []
	_collect_pins(movepoint_root, all_pins)

	# 모든 핀을 AStar 포인트로 추가
	for pin: Movepoint in all_pins:
		var id: int = _astar.get_available_point_id()
		_astar.add_point(id, pin.global_position)
		_pin_to_id[pin] = id
		_id_to_pin[id] = pin

	# 이웃 연결
	for pin: Movepoint in all_pins:
		var id: int = _pin_to_id[pin]
		for neighbor: Movepoint in pin.neighbors:
			if neighbor == null:
				continue
			var nid: int = _pin_to_id.get(neighbor, -1)
			if nid >= 0 and not _astar.are_points_connected(id, nid):
				_astar.connect_points(id, nid, true)

	_built = true


## AStar3D 그래프가 이미 구축되었는지 반환한다.
static func is_built() -> bool:
	return _built


## 두 핀 사이의 최단 경로를 [Movepoint] 배열로 반환한다.
## 경로를 찾을 수 없으면 빈 배열을 반환한다.
static func find_pin_path(from: Movepoint, to: Movepoint) -> Array[Movepoint]:
	if not _built or _astar == null:
		return []
	var from_id: int = _pin_to_id.get(from, -1)
	var to_id: int = _pin_to_id.get(to, -1)
	if from_id < 0 or to_id < 0:
		return []

	var id_path: PackedInt64Array = _astar.get_id_path(from_id, to_id)
	if id_path.is_empty():
		return []

	var path: Array[Movepoint] = []
	for id: int in id_path:
		var pin: Movepoint = _id_to_pin.get(int(id))
		if pin != null:
			path.append(pin)
	return path


## 두 Vector3 위치 사이의 맨하탄 (L자형) 경로를 생성한다.
## corner_first가 true면 먼저 X축을 따라 이동하고 Z축으로 이동한다.
## false면 먼저 Z축을 따라 이동한다.
static func make_manhattan_path(from: Vector3, to: Vector3, corner_first_x: bool = true) -> PackedVector3Array:
	var path := PackedVector3Array()
	path.append(from)

	var corner: Vector3
	if corner_first_x:
		corner = Vector3(to.x, from.y, from.z)
	else:
		corner = Vector3(from.x, from.y, to.z)

	path.append(corner)
	path.append(to)
	return path


## 두 맨하탄 세그먼트(직각 코너) 사이의 부드러운 원호 경로를 생성한다.
## corner는 코너 위치, approach는 코너에 접근하는 방향(단위 벡터),
## depart는 코너에서 떠나는 방향(단위 벡터), radius는 원호 반경, segments는 원호 분할 수.
## 반환: [approach_point, arc_point_1, ..., arc_point_n, depart_point] (n >= 1)
static func smooth_corner(
	corner: Vector3,
	approach_dir: Vector3,
	depart_dir: Vector3,
	radius: float,
	segments: int = 6
) -> PackedVector3Array:
	if radius <= 0.001 or segments < 1:
		return PackedVector3Array()

	var approach_vec: Vector3 = -approach_dir * radius
	var depart_vec: Vector3 = depart_dir * radius

	var approach_point: Vector3 = corner + approach_vec
	var depart_point: Vector3 = corner + depart_vec

	var result := PackedVector3Array()
	result.append(approach_point)

	for i in range(1, segments):
		var t: float = float(i) / float(segments)
		var angle: float = t * (PI / 2.0)
		var arc_point: Vector3 = corner + (-approach_dir * cos(angle) + depart_dir * sin(angle)) * radius
		result.append(arc_point)

	result.append(depart_point)
	return result


## 모든 Movepoint 노드를 재귀적으로 수집한다.
static func _collect_pins(node: Node3D, out: Array[Movepoint]) -> void:
	if node is Movepoint:
		out.append(node)
	for child in node.get_children():
		if child is Node3D:
			_collect_pins(child, out)


## 그래프를 리셋한다 (재빌드 필요 시).
static func reset() -> void:
	_astar = null
	_pin_to_id.clear()
	_id_to_pin.clear()
	_built = false
