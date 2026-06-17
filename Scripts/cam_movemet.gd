extends Camera3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var ran_num:int = int(randf_range(0,1)*10)
	await get_tree().create_timer(ran_num).timeout
	$AnimationPlayer.play("Cam_move")
