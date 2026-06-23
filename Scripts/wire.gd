extends Node3D

@export var rubber_mesh: MeshInstance3D
var snap_threshold: float = 0.15
@onready var sound:AudioStreamPlayer3D = get_parent().get_node("wiresound")
@export_category("Materials")
@export var connected_material: Material
@export var disconnected_material: Material
@export var min_length = 0.05
@export_category("Auto Connection")
@export var auto_connect_on_start: bool = true
@export var fixed_in_index: int = 0 
@export var target_out_index: int = 0 

@onready var spark:GPUParticles3D = get_node("pin1/spark")
var spark_original_transform: Transform3D
static var current_dragging_wire: Node3D = null
static var top_sort_index: int = 10 
		
var in_pins: Array[Node] = []
var out_pins: Array[Node] = [] 

var fixed_in_pin: Marker3D = null
var current_out_pin: Marker3D = null

var is_dragging: bool = false
#@warning_ignore("shadowed_variable_base_class")
var is_connected: bool = false

var init_height: float = 0.0
var init_transform: Transform3D
var max_length: float = 0.0

var base_priority: int = 0
var local_conn_mat: Material
var local_disconn_mat: Material
var has_played_snap_sound: bool = false
var door_area: Area3D = null
var last_valid_mouse_pos: Vector3 = Vector3.ZERO
var electric_box: CSGBox3D = null

func _ready():
	rubber_mesh.visible = true
	if connected_material:
		local_conn_mat = connected_material.duplicate()
		if local_conn_mat is StandardMaterial3D:
			local_conn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			
	if disconnected_material:
		local_disconn_mat = disconnected_material.duplicate()
		if local_disconn_mat is StandardMaterial3D:
			local_disconn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	if rubber_mesh.mesh is CylinderMesh:
		init_height = rubber_mesh.mesh.height
			
	var my_index = get_index()
	base_priority = my_index
	if my_index >= top_sort_index:
		top_sort_index = my_index + 1
		
	var all_pins = get_tree().get_nodes_in_group("pins")
	for pin in all_pins:
		if pin.get("pin_type") == "IN":
			in_pins.append(pin)
		elif pin.get("pin_type") == "OUT":
			out_pins.append(pin)

	in_pins.sort_custom(func(a, b): return a.name < b.name)
	out_pins.sort_custom(func(a, b): return a.name < b.name)

	for p_in in in_pins:
		for p_out in out_pins:
			var dist = p_in.global_position.distance_to(p_out.global_position)
			if dist > max_length:
				max_length = dist
	#max_length += 2.0 
	
	init_transform = rubber_mesh.transform
	spark_original_transform = spark.transform
	update_material_and_priority(false, base_priority, float(base_priority)) 
	
	if fixed_in_index >= 0 and fixed_in_index < in_pins.size():
		fixed_in_pin = in_pins[fixed_in_index]
		fixed_in_pin.set("connected_wire", self)
	else:
		print("⚠️ [에러] ", name, ": 잘못된 fixed_in_index 입니다.")
	
	if auto_connect_on_start and fixed_in_pin:
		call_deferred("connect_to_out_index", target_out_index)
	else:
		call_deferred("reset_to_home")
	
	# door/Area3D 참조 가져오기 (같은 부모 아래에 있음)
	door_area = get_parent().get_node_or_null("door/Area3D") as Area3D
	
	# CSGBox3D 참조 및 초기 마우스 위치
	electric_box = get_parent() as CSGBox3D
	last_valid_mouse_pos = fixed_in_pin.global_position if fixed_in_pin else Vector3.ZERO

func _input(event):
	if not fixed_in_pin: return
	
	# 문이 닫혀 있으면 와이어 조작 불가
	if door_area and not door_area.is_door_open:
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		print_all_connections()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_3d = get_mouse_3d_position()
		
		if event.pressed:
			if current_dragging_wire != null: return
			
			var can_grab = false
			
			if is_connected and current_out_pin:
				if mouse_3d.distance_to(current_out_pin.global_position) < snap_threshold:
					can_grab = true
					
			elif not is_connected:
				if mouse_3d.distance_to(fixed_in_pin.global_position) < snap_threshold:
					can_grab = true
					
			if can_grab:
				current_dragging_wire = self 
				is_dragging = true
				
				if current_out_pin and current_out_pin.get("connected_wire") == self:
					current_out_pin.set("connected_wire", null)
				current_out_pin = null
					
				is_connected = false
				rubber_mesh.visible = true
				update_material_and_priority(false, 127, float(top_sort_index + 1000))
				spark.global_position = mouse_3d
				spark.emitting = true
				get_viewport().set_input_as_handled()
		
		else:
			if is_dragging and current_dragging_wire == self:
				is_dragging = false
				current_dragging_wire = null 
				
				top_sort_index += 1
				base_priority = top_sort_index
				
				var closest_out = get_closest_out_pin(mouse_3d)
				if closest_out:
					
					current_out_pin = closest_out
					current_out_pin.set("connected_wire", self)
					is_connected = true
					update_material_and_priority(true, base_priority, float(base_priority))
				else:
					reset_to_home() 
				
				get_viewport().set_input_as_handled()

func _process(_delta):
	if not fixed_in_pin: return
	
	if is_connected and current_out_pin:
		update_rubber_band(fixed_in_pin.global_position, current_out_pin.global_position)
		spark.emitting = false
	elif is_dragging and current_dragging_wire == self:
			var mouse_3d = get_mouse_3d_position()
			var closest = get_closest_out_pin(mouse_3d)
			var t_pos: Vector3 = mouse_3d
			if closest:
				t_pos = closest.global_position
				if !has_played_snap_sound and !sound.playing:
					sound.play()
					has_played_snap_sound = true
				update_material_and_priority(true, 127, float(top_sort_index + 1000))
			else:
				has_played_snap_sound = false
				update_material_and_priority(false, 127, float(top_sort_index + 1000))
			spark.global_position = mouse_3d
			spark.emitting = true
			update_rubber_band(fixed_in_pin.global_position, t_pos)
	elif !is_dragging and !is_connected and !spark.emitting:
		spark.transform = spark_original_transform
		await get_tree().create_timer(randf_range(1.0,4.0)).timeout
		spark.emitting = true
func connect_to_out_index(out_index: int):
	if out_index < 0 or out_index >= out_pins.size():
		print("⚠️ [에러] ", name, ": ", out_index, "번 OUT 핀이 없습니다.")
		return
		
	var p_out = out_pins[out_index]
	force_connect_to_out_pin(p_out)

func force_connect_to_out_pin(p_out: Marker3D):
	if current_out_pin and current_out_pin.get("connected_wire") == self:
		current_out_pin.set("connected_wire", null)
	
	current_out_pin = p_out
	if current_out_pin: 
		current_out_pin.set("connected_wire", self)
	
	is_connected = true
	rubber_mesh.visible = true
	
	update_material_and_priority(true, base_priority, float(base_priority))
	update_rubber_band(fixed_in_pin.global_position, current_out_pin.global_position)

func reset_to_home():
	if current_out_pin and current_out_pin.get("connected_wire") == self:
		current_out_pin.set("connected_wire", null)
		
	current_out_pin = null
	is_connected = false
	update_material_and_priority(false, base_priority, float(base_priority))
	
	# 초기 메쉬 상태로 명시적 복원 (update_rubber_band는 distance=0에서 return만 하므로 init 복원 생략됨)
	rubber_mesh.visible = true
	rubber_mesh.transform = init_transform
	if rubber_mesh.mesh is CylinderMesh:
		rubber_mesh.mesh.height = init_height
	
	# spark 원위치 복구
	spark.transform = spark_original_transform
	spark.emitting = false

func get_closest_out_pin(pos: Vector3) -> Marker3D:
	var closest: Marker3D = null
	var min_dist: float = snap_threshold
	
	for pin in out_pins:
		var connected_wire = pin.get("connected_wire")
		if connected_wire == null or connected_wire == self:
			var dist = pos.distance_to(pin.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = pin
			
	return closest

func update_material_and_priority(connected: bool, mat_priority: int, sort_offset: float):
	var target_mat: Material = local_disconn_mat
	if connected:
		target_mat = local_conn_mat
	if target_mat:
		rubber_mesh.material_override = target_mat
		var safe_priority = clamp(mat_priority, -128, 127)
		if "render_priority" in target_mat:
			target_mat.render_priority = safe_priority
			
	if "sorting_offset" in rubber_mesh:
		rubber_mesh.sorting_offset = sort_offset

# ==========================================
# ⚡ 수정됨: IN 핀이 완벽하게 고정되도록 계산식 변경
# ==========================================
func update_rubber_band(pos_a: Vector3, pos_b: Vector3): 
	var dir: Vector3 = pos_b - pos_a
	var current_dist = dir.length()
	var distance = clamp(current_dist, 0.0, max_length)
	
	if distance < min_length:
		rubber_mesh.visible = false 
		return
		
	# 방향 벡터를 정규화하고 실제 그려질 길이(distance)만큼만 적용하여 실제 그려질 벡터 생성
	var real_dir = dir.normalized() * distance
		
	rubber_mesh.visible = true
	# 선이 잘리지 않고 시작점(pos_a)에 완벽하게 닿도록 보정
	rubber_mesh.global_position = pos_a + (real_dir * 0.5)
	
	rubber_mesh.look_at(pos_a + real_dir, Vector3.UP)
	rubber_mesh.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
	
	if rubber_mesh.mesh is CylinderMesh:
		rubber_mesh.mesh.height = distance - 0.1
func get_mouse_3d_position() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	if not camera: return Vector3.ZERO
		
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_normal = camera.project_ray_normal(mouse_pos)
	
	var base_pos = fixed_in_pin.global_position if fixed_in_pin else Vector3.ZERO
	
	var plane_normal: Vector3 = fixed_in_pin.global_transform.basis.z
	
	var plane = Plane(plane_normal, base_pos)
	var intersection = plane.intersects_ray(ray_origin, ray_normal)
	
	var result: Vector3
	if intersection: 
		result = intersection
	else:
		result = ray_origin + ray_normal * 10
	
	# CSGBox3D 경계 검사: 박스 밖이면 마지막 유효 위치 반환
	if electric_box:
		var local_pos: Vector3 = electric_box.to_local(result)
		var half_size: Vector3 = electric_box.size * 0.5
		if abs(local_pos.x) <= half_size.x and abs(local_pos.y) <= half_size.y and abs(local_pos.z) <= half_size.z:
			last_valid_mouse_pos = result
			return result
		else:
			return last_valid_mouse_pos
	
	return result
# ==========================================
# ⚡ 수정됨: 배열 인덱스와 핀 종류를 명확히 출력
# ==========================================
func print_all_connections():
	print("\n=== 🔌 와이어 연결 현황 ===")
	var wire_nodes = []
	var root = get_tree().root
	_find_wire_nodes(root, wire_nodes)
	
	wire_nodes.sort_custom(func(a, b): return a.name < b.name)
	
	for wire in wire_nodes:
		# IN 핀 정보 구성 (인덱스 + 이름)
		var in_str = "알 수 없는 IN"
		if wire.fixed_in_pin:
			var in_idx = wire.in_pins.find(wire.fixed_in_pin)
			in_str = "IN %d번 (%s)" % [in_idx, wire.fixed_in_pin.name]
		
		# OUT 핀 정보 구성 (인덱스 + 이름)
		var out_str = "연결 안 됨 (허공)"
		if wire.is_connected and wire.current_out_pin:
			var out_idx = wire.out_pins.find(wire.current_out_pin)
			out_str = "OUT %d번 (%s)" % [out_idx, wire.current_out_pin.name]
		elif wire.is_dragging:
			out_str = "🖱️ 마우스로 드래그 중..."
			
		print("[%s] %s ──▶ %s" % [wire.name, in_str, out_str])
	print("================================\n")

func _find_wire_nodes(node: Node, array: Array):
	if node.has_method("print_all_connections") and not node.is_class("Window"):
		array.append(node)
	for child in node.get_children():
		_find_wire_nodes(child, array)
