extends RefCounted

class_name Room

var cells: Array[Vector2i]  # Each cell is a relative position (x,y)
var room_type: String

func _init(_cells: Array[Vector2i], _room_type: String = "default"):
	cells = _cells.duplicate()
	room_type = _room_type

func rotate(angle: int) -> Room:
	var rotated_cells: Array[Vector2i] = []

	for cell in cells:
		match angle:
			-90: # rotate clockwise 90: (x, y) -> (y, -x)
				rotated_cells.append(Vector2i(cell.y, -cell.x))
			90:  # rotate counterclockwise 90: (x, y) -> (-y, x)
				rotated_cells.append(Vector2i(-cell.y, cell.x))
			180: # rotate 180: (x, y) -> (-x, -y)
				rotated_cells.append(Vector2i(-cell.x, -cell.y))
			_:
				# If angle = 0 or any unrecognized value, no rotation
				rotated_cells.append(cell)

	return Room.new(rotated_cells, room_type)
