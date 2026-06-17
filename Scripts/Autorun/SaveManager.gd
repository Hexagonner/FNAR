extends Node

const SAVE_PATH:String = "user://save.dat"
#var savefile:Dictionary = {
	#"star":0,
	#"clear_night":0,
	#
	#
#}
const reset_file:Dictionary = {
	"star":0,
	"clear_night":0,
}
#dictionary로 데이터 저장 하기 
func saveData(data:Dictionary) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var(data)
	file.close()
	
func loadData() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		print("NO SAVE")
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = file.get_var()
	file.close()
	return data
