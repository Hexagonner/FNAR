extends Node3D
class_name TemporaryPinPathVisualizer

## Agent의 임시 핀과 경로를 3D 공간에 시각화합니다

@export var show_temp_pins: bool = true
@export var show_path_connections: bool = true
@export var temp_pin_radius: float = 0.2
@export var previous_pin_radius: float = 0.15
@export var next_pin_radius: float = 0.15
@export var line_width: float = 0.05

var agents: Array[Node] = []
var meshes: Dictionary = {}

func _ready() -> void:
	_find_all_agents()
	print("[PathVisualizer] Found %d agents" % agents.size())

func _find_all_agents() -> void:
	for node in get_tree().get_nodes_in_group("animatronics"):
		if node is animatronics:
			agents.append(node)
	
	if agents.is_empty():
		for child in get_tree().root.get_children():
			_find_agents_recursive(child)

func _find_agents_recursive(node: Node) -> void:
	if node is animatronics:
		agents.append(node)
	for child in node.get_children():
		_find_agents_recursive(child)

func _process(_delta: float) -> void:
	if not show_temp_pins:
		return
	
	_clear_old_meshes()
	
	for agent: animatronics in agents:
		if agent._temporary_pin == null:
			continue
		
		_draw_temp_pin(agent)
		_draw_pin_connections(agent)

func _clear_old_meshes() -> void:
	for mesh: Node3D in meshes.values():
		if is_instance_valid(mesh):
			mesh.queue_free()
	meshes.clear()

func _draw_temp_pin(agent: animatronics) -> void:
	# 임시 핀 (노란색)
	if agent._temporary_pin != null:
		_create_sphere_mesh(
			agent._temporary_pin.global_position,
			temp_pin_radius,
			Color.YELLOW,
			"%s_temp" % agent.name
		)
	
	# 이전 핀 (초록색)
	if agent._previous_pin != null:
		_create_sphere_mesh(
			agent._previous_pin.global_position,
			previous_pin_radius,
			Color.GREEN,
			"%s_prev" % agent.name
		)
	
	# 다음 핀 (빨간색)
	if agent._next_pin != null:
		_create_sphere_mesh(
			agent._next_pin.global_position,
			next_pin_radius,
			Color.RED,
			"%s_next" % agent.name
		)

func _draw_pin_connections(agent: animatronics) -> void:
	if not show_path_connections:
		return
	
	if agent._previous_pin == null or agent._temporary_pin == null or agent._next_pin == null:
		return
	
	# 이전 핀 → 임시 핀
	_create_line_mesh(
		agent._previous_pin.global_position,
		agent._temporary_pin.global_position,
		Color.GREEN,
		"%s_line_prev_temp" % agent.name
	)
	
	# 임시 핀 → 다음 핀
	_create_line_mesh(
		agent._temporary_pin.global_position,
		agent._next_pin.global_position,
		Color.RED,
		"%s_line_temp_next" % agent.name
	)

func _create_sphere_mesh(pos: Vector3, radius: float, color: Color, key: String) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	mesh_instance.mesh = sphere_mesh
	
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission = color
	material.emission_energy_multiplier = 1.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.set_surface_override_material(0, material)
	
	mesh_instance.global_position = pos
	mesh_instance.name = key
	add_child(mesh_instance)
	meshes[key] = mesh_instance

func _create_line_mesh(from: Vector3, to: Vector3, color: Color, key: String) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	
	# 캡슐 메시를 선으로 사용
	var capsule_mesh: CapsuleMesh = CapsuleMesh.new()
	capsule_mesh.radius = line_width
	capsule_mesh.height = from.distance_to(to)
	mesh_instance.mesh = capsule_mesh
	
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission = color
	material.emission_energy_multiplier = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.set_surface_override_material(0, material)
	
	var midpoint: Vector3 = (from + to) / 2.0
	mesh_instance.global_position = midpoint
	
	var direction: Vector3 = (to - from).normalized()
	mesh_instance.look_at(to, Vector3.UP)
	
	mesh_instance.name = key
	add_child(mesh_instance)
	meshes[key] = mesh_instance
