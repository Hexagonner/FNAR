extends CheckBox

@export var FPS_Node:Node
func _ready() -> void:
	FPS_Node.connect("FPS_is_toggle", box_show)
# Called when the node enters the scene tree for the first tim
@warning_ignore("unused_parameter")

	
func box_show()->void:
	self.button_pressed = FPS_Node.visible


func _on_button_up() -> void:
	FPS_Node.emit_signal("FPS_is_toggle")
