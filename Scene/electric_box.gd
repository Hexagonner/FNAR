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

	index_arr.shuffle()

	# 핀 위치만 셔플 (wire 연결은 변경하지 않음)
	for i: int in range(pin_arr.size()):
		pin_arr[i].global_position = index_arr[i]
