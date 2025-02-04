extends RefCounted  

class_name Room

var cells: Array[Vector2i]  # List of occupied cells relative to (0,0)
var room_type: String  # Room category (treasure, trap, boss, etc.)

func _init(_cells: Array[Vector2i], _room_type: String = "default"):
	cells = _cells.duplicate()  # Ensure a copy is stored
	room_type = _room_type

# Method to rotate the room
func rotate(angle: int) -> Room:
	var rotated_cells: Array[Vector2i] = []  # Explicitly typed to prevent errors

	for cell in cells:
		match angle:
			-90:
				rotated_cells.append(Vector2i(-cell.y, cell.x))
			90:
				rotated_cells.append(Vector2i(cell.y, -cell.x))
			180:
				rotated_cells.append(Vector2i(-cell.x, -cell.y))
			_:
				rotated_cells.append(cell)  # No rotation if 0 degrees

	# Correct way to create a new Room instance
	return Room.new(rotated_cells, room_type)
