extends Node3D

var fan_spin:bool = true
@onready var fan = $spin/fan
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimationPlayer.play("spin")
	$spin/AnimationPlayer2.play("Swip")
	$AudioStreamPlayer3D.play()


func _on_audio_stream_player_3d_finished() -> void:
	$AudioStreamPlayer3D.play()

func stop_fan() -> void:
	fan_spin = false
	$spin/AnimationPlayer2.play("spin off")
	#$spin/AnimationPlayer2.pause()
	$AnimationPlayer.play("spin_off")
	$AudioStreamPlayer3D.stop()
	
