extends CSGBox3D


@export var raycast: RayCast3D
@export var origin_marker: Marker3D
@export var rubber_mesh: MeshInstance3D 

var is_pulling: bool = false
var is_attached: bool = false
var attach_point: Vector3 = Vector3.ZERO

func _ready():
	rubber_mesh.visible = false

func _process(_delta):
	# 1. 입력 처리 (여기서는 마우스 왼쪽 클릭 예시)
	if Input.is_action_just_pressed("click"):
		is_pulling = true
		is_attached = false
		rubber_mesh.visible = true

	if Input.is_action_just_released("click"):
		is_pulling = false
		# 레이캐스트가 벽에 부착되어 있다면 고정, 아니면 탄성 수축
		if raycast.is_colliding():
			is_attached = true
			attach_point = raycast.get_collision_point()
			play_snap_effect() # 붙을 때 팅~ 하는 연출
		else:
			animate_release() # 아무데도 안 붙으면 스르륵 풀림

	# 2. 상태에 따른 고무줄 그리기
	if is_pulling:
		# 현재 조준하고 있는 곳(레이캐스트 끝점 또는 충돌 지점)까지 고무줄 연장
		var target_pos = raycast.get_collision_point() if raycast.is_colliding() else raycast.global_position + (-raycast.global_transform.basis.z * raycast.target_position.z)
		update_rubber_band(origin_marker.global_position, target_pos)
		
	elif is_attached:
		# 벽에 붙어있는 상태 유지
		update_rubber_band(origin_marker.global_position, attach_point)

# 두 지점 사이를 고무줄 메쉬로 연결하는 핵심 함수
func update_rubber_band(pos_a: Vector3, pos_b: Vector3):
	var dir = pos_b - pos_a
	var distance = dir.length()
	
	if distance < 0.01:
		rubber_mesh.visible = false
		return
		
	rubber_mesh.visible = true
	
	# 1. 위치를 두 지점의 중간으로 이동 (Cylinder의 중심점 기준 원리)
	rubber_mesh.global_position = pos_a + (dir * 0.5)
	
	# 2. 고무줄의 길이를 두 지점 사이의 거리로 조절 (기본 높이가 1.0이므로 scale.y 조정)
	rubber_mesh.scale.y = distance
	
	# 3. 고무줄이 target(pos_b)을 바라보도록 회전
	# look_at은 기본적으로 -Z축을 정렬하므로, Y축이 실린더인 경우 X축으로 90도 눕혀야 합니다.
	rubber_mesh.look_at(pos_b, Vector3.UP)
	rubber_mesh.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))

# 벽에 촥! 붙을 때의 가벼운 튕김 연출 (Tween 활용)
func play_snap_effect():
	var tween = create_tween()
	# 고무줄 두께(X, Z축)를 잠시 늘렸다가 줄여서 탄성 느낌 주기
	rubber_mesh.scale.x = 0.15
	rubber_mesh.scale.z = 0.15
	tween.tween_property(rubber_mesh, "scale:x", 0.05, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(rubber_mesh, "scale:z", 0.05, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# 허공에 놓았을 때 제자리로 팅! 돌아오는 연출
func animate_release():
	var tween = create_tween()
	# 0.1초 만에 크기를 0으로 줄여서 사라지게 만듦
	tween.tween_property(rubber_mesh, "scale:y", 0.0, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	rubber_mesh.visible = false
