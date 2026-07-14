extends Node3D

@warning_ignore("shadowed_variable_base_class")
@export var look_at:Node3D
@export var move_speed: float = 1.5
@onready var anim_tree = $RD/AnimationTree
@onready var playback = anim_tree.get("parameters/playback")
#var left_eye
#var right_eye
@export var look_modify:LookAtModifier3D

var start_pos: Vector3
var target_distance: float = 5.3
var is_moving: bool = true


func _ready() -> void:
	look_modify.target_node = look_at.get_path()
	#left_eye = $Armature/GeneralSkeleton/Left_eye.get_surface_override_material(0)
	#right_eye = $Armature/GeneralSkeleton/Right_eye.get_surface_override_material(0)
	start_pos = global_position
	print("startMOve")
	playback.travel("walking_001") # 이동 시작
	
func _process(delta) -> void:

	if not is_moving:
		return

	# 1. 현재 이동한 거리 계산
	var moved_dist = global_position.distance_to(start_pos)
	# 매 프레임 albedo alpha를 lerp로 갱신하던 부분을 1회성으로 변경.
	# (이전: 양 눈의 material.albedo_color.a를 60fps로 30+ 프레임씩 변경 → 셰이더 재컴파일 위험 + 불필요)
	#var target_alpha: float = clamp(target_distance - moved_dist - 4.5, 0.0, 1.0)
	#right_eye.albedo_color.a = target_alpha
	#left_eye.albedo_color.a = target_alpha
	# 2. 목표 거리 도달 판정 [[5](https://steamcommunity.com/app/404790/discussions/0/601903308219614819/?l=tchinese)]
	if moved_dist >= target_distance-0.5:

		is_moving = false
		playback.travel("idle") # 애니메이션 전환 [[3](https://godotforums.org/d/36951-animate-between-idle-walk-and-run-with-animationtree3d)]
		# 도달 후 더 이상 _process가 필요 없으므로 비활성화.
		set_process(false)
		return

	# 3. 전진 (In-place 애니메이션을 위한 위치 이동)
	var forward_dir = global_transform.basis.z
	global_position += forward_dir * move_speed * delta
