extends animatronics


@export var left_pupil:Node
@export var right_pupil:Node
@export var left_pupil_light:Node
@export var right_pupil_light:Node
@export var music_player:AudioStreamPlayer3D

#@export var ani_tree:AnimationTree
#@onready var playback = ani_tree.get("parameters/playback")



var left_pupil_mat 
var right_pupil_mat 


var is_black_out:bool = false
#region event_timing
var song_event =[
	0.1,
	0.5,
	0.7,
	0.8,
	1.0,
	1.3,
	1.7,
	2.0,
	2.3,
	2.6,
	2.9,
	3.3,
	3.5,
	3.6,
	3.9,
	4.0,
	4.2,
	4.4,
	5.1,
	5.4,
	5.5,
	5.8,
	6.0,
	6.1,
	6.4,
	6.5,
	6.9,
	7.0,
	7.7,
	8.0,
	8.3,
	8.6,
	8.9,
	9.1,
	9.3,
	9.4,
	9.6,
	9.9,
	10.0,
	10.1,
	10.2,
	11.1,
	11.3,
	11.5,
	12.1,
	12.4,
	12.7,
	12.8,
	13.0,
	13.1,
	13.4,
	13.6,
	13.7,
	14.0,
	14.1,
	14.3,
	14.5,
	15.2,
	15.5,
	15.6,
	15.9,
	16.1,
	16.2,
	16.5,
	16.7,
	17.0,
	17.1,
	17.8,
	18.0,
	18.1,
	18.4,
	18.6,
	18.7,
	19.0,
	19.3,
	19.4,
	19.7,
	20.0,
	20.1,
	20.3,
	20.6,
	20.9,
	21.0,
	21.2,
	21.5,
	21.6,
	21.8,
	21.9,
	22.1,
	22.2,
	22.4,
	22.5,
	22.7,
	22.8
]
#endregion
var event_index:=0


func _ready() -> void:
	super._ready()

	right_pupil_mat = right_pupil.get_active_material(0)
	left_pupil_mat = left_pupil.get_active_material(0)

	gui_node.battery_over.connect(black_out_song)
	set_next_goal(PinName.LEFT_DOOR)
#region pupil_light_toggle

func pupil_light_toggle()->void:
	right_pupil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	left_pupil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	left_pupil_light.visible = true
	right_pupil_light.visible = true
	await get_tree().create_timer(0.05).timeout
	right_pupil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	left_pupil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	left_pupil_light.visible = false
	right_pupil_light.visible = false
#endregion
	
func black_out_song() -> void:
	# TODO connect move to office door
	music_player.play(0.0)
	is_black_out = true  # this bool make eyes blink
	

@warning_ignore("unused_parameter")
func _process(delta: float) -> void: # FOR black out pupil only rando
	if is_black_out:
		@warning_ignore("unused_variable")
		var time := music_player.get_playback_position()
		if event_index >= song_event.size():
			pass
		elif time >= song_event[event_index]:
			event_index +=1
			pupil_light_toggle()
