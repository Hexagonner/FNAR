# Pin.gd (모든 핀 노드에 부착된 스크립트)
extends Marker3D
class_name WirePin

@export_enum("IN", "OUT") var pin_type: String = "IN"
@export_enum("a", "b", "c", "d") var pin_num: int = 0
# [추가] 이 핀에 연결된 와이어 객체를 저장 (null이면 빈 핀)
var connected_wire: Node3D = null
#static var index_arr:Array
#func _ready() -> void:
	#
	#if pin_type == "OUT":
		#self_pos = self.global_position
		#index_arr.append(self_pos)
		#index_arr.shuffle()
		#print(index_arr)
		#is_in_group("pins")
		#
