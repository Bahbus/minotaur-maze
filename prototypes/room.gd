extends RefCounted  

class_name Room

var cells: Array[Vector2i]  # List of occupied cells relative to (0,0)
var room_type: String  # Room category (treasure, trap, boss, etc.)

func _init(_cells: Array[Vector2i], _room_type: String = "default"):
	cells = _cells
	room_type = _room_type
