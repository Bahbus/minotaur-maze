extends Node

class_name RoomDefinitions  # Makes it easier to access

static func get_rooms() -> Array:
	return [
		# Large Square Room (4x4)
		Room.new(
			[
				Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
				Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3),
				Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3),
				Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3)
			],
			"treasure"
		),
		
		# Larger L-Shaped Room (4x3)
		Room.new(
			[
				Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2),
				Vector2i(1, 0), Vector2i(1, 1), 
				Vector2i(2, 0), Vector2i(2, 1)
			],
			"trap"
		),

		# Expanded Circular Room Approximation
		Room.new(
			[
				Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
				Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
			],
			"boss"
		)
	]
