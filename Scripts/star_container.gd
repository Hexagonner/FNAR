extends HBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	var i = 0
	for star in get_children():
		if star is TextureRect:
			star.visible = i < SaveManager.get_value("star")
			i += 1
	
