extends HBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var savefile = SaveManager.loadData()
	#print(savefile["star"], " star")
	var i = 0
	for star in get_children():
		if star is TextureRect:
			star.visible = i < savefile["star"]
			i += 1
	
