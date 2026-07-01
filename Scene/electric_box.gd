extends CSGBox3D

var index_arr: Array = []
var pin_arr: Array = []

func _ready() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	# "pins" 그룹의 OUT 핀 수집
	for pin: Node in tree.get_nodes_in_group("pins"):
		if pin.get("pin_type") == "OUT":
			index_arr.append(pin.global_position)
			pin_arr.append(pin)

	if index_arr.size() < 2:
		return

	print("[SHUFFLE] before: ", index_arr)
	index_arr.shuffle()
	print("[SHUFFLE] after: ", index_arr)

	# 핀 위치 셔플
	for i: int in range(pin_arr.size()):
		pin_arr[i].global_position = index_arr[i]

	# [추가] pin_num 기반 wire 재연결
	for pin: Marker3D in pin_arr:
		var my_pin_num: int = pin.get("pin_num")
		var my_parent_wire: Node3D = pin.get_parent()
		if my_parent_wire == null:
			continue
		for other_pin: Marker3D in pin_arr:
			if other_pin != pin and other_pin.get("pin_num") == my_pin_num:
				if my_parent_wire.has_method("force_connect_to_out_pin"):
					print("[SHUFFLE] reconnect: ", my_parent_wire.name, " -> ", other_pin.name)
					my_parent_wire.force_connect_to_out_pin(other_pin)
				break
