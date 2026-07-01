extends CSGBox3D

var index_arr:Array
var pin_arr:Array

func _ready() -> void:
	for pin in get_tree().get_nodes_in_group("pins"):
		if pin.get("pin_type") == "OUT":
			index_arr.append(pin.global_position)
			pin_arr.append(pin)
		#is_in_group("pins")
	print(index_arr)
	index_arr.shuffle()
	print(index_arr)
	for i in range(pin_arr.size()):
		pin_arr[i].global_position = index_arr[i]
	
