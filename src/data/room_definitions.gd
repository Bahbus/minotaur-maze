extends Node

class_name RoomDefinitions  # Makes it easier to access

static func get_rooms() -> Array:
	return [
		# Large Square Room (5x5)
		Room.new(
			[
				Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4),
				Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4),
				Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4),
				Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4),
				Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4)
			],
			"large_treasure"
		),

		# Rectangular Room (6x3)
		Room.new(
			[
				Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2),
				Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2),
				Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2),
				Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2),
				Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2),
				Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2)
			],
			"long_hall"
		),

		# L-Shaped Room (4x4 with corner cut out)
		Room.new(
			[
				Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
				Vector2i(1, 0), Vector2i(1, 1),
				Vector2i(2, 0), Vector2i(2, 1),
				Vector2i(3, 0)
			],
			"l_shaped"
		),

		# Circular Room Approximation (Diameter: 5)
		Room.new(
			[
				Vector2i(0, 0), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2),
				Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
				Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)
			],
			"circular"
		),

		# Triangular/Pyramid Room
		Room.new(
			[
				Vector2i(0, 0),  
				Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
				Vector2i(-2, 2), Vector2i(-1, 2), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)
			],
			"pyramid"
		),

		Room.new(
			[
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
				Vector2i(2, 1), Vector2i(3, 1),
				Vector2i(1, 2), Vector2i(2, 2),
				Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)
			],
			"z_shaped"
		),

		# Large Open Chamber (7x7)
		Room.new(
			[
				Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 5), Vector2i(0, 6),
				Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4), Vector2i(1, 5), Vector2i(1, 6),
				Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5), Vector2i(2, 6),
				Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4), Vector2i(3, 5), Vector2i(3, 6),
				Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5), Vector2i(4, 6),
				Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4), Vector2i(5, 5), Vector2i(5, 6),
				Vector2i(6, 0), Vector2i(6, 1), Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4), Vector2i(6, 5), Vector2i(6, 6)
			],
			"grand_chamber"
		),

		# Odd Irregular Room (Random Shape)
		Room.new(
			[
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
				Vector2i(0, 1), Vector2i(2, 1),
				Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
				Vector2i(1, 3)
			],
			"irregular"
		),
		
		# Hollow Cross Room (5x5)
		Room.new(
			[
				Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
				Vector2i(1, 1), Vector2i(1, 3),
				Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4),
				Vector2i(3, 1), Vector2i(3, 3),
				Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3)
			],
			"arena"
		)
	]
