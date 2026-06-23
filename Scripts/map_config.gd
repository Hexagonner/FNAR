extends Node3D

@export var furniture:Node
@export var office_light:Node #= $Celling/Lights/OfficeLight
#@export var light_off:Material
@export var back_light: OmniLight3D
func office_light_off() -> void:
	#office_light.set_surface_override_material(0,light_off)
	office_light.get_node("Lightblub_pos/Lightblub/Node3D/MiddleLight").visible = false
	back_light.visible = false
	office_light.get_node("Lightblub_pos/Lightblub/Node3D/light_blub_model/Sketchfab_model/root/GLTF_SceneRootNode/lightbulb_01_0/Area3D").is_black_out = true
	office_light.get_node("jumpscare_light").visible = false
	office_light.get_node("ambience_light").visible = true
	office_light.get_node("ambience_light").omni_range = 8
	furniture.get_node("Fan").stop_fan()
	
