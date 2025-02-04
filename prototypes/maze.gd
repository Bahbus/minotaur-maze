extends Node2D

# Maze parameters
const ROWS = 28
const COLS = 28
const CELL_SIZE = 32
const WALL_THICKNESS = 2

# The maze grid: a 2D array where each cell is a dictionary with visited flag and walls array
var maze = []
var stack = []
var rooms = []  # List of placed rooms

func _ready():
	randomize()  # Ensure different mazes each run
	initialize_maze()
	place_rooms()
	generate_maze()
	connect_room_exits()
	queue_redraw()
	build_collision_shapes()

func initialize_maze():
	# Initialize the maze grid
	for i in range(ROWS):
		maze.append([])
		for j in range(COLS):
			maze[i].append({
				"visited": false,
				"walls": [true, true, true, true],  # Order: top, right, bottom, left
				"type": "path"  # Default to a normal maze path
			})

func place_rooms():
	var available_rooms = RoomDefinitions.get_rooms()
	available_rooms.shuffle()  # Shuffle rooms for random placement order

	for room in available_rooms:
		var placed = false
		for attempt in range(20):  # Try 20 random placements
			var pos = Vector2i(randi() % (ROWS - 3) + 1, randi() % (COLS - 3) + 1)  # Ensure a 1-cell buffer
			if can_place_room(room, pos):
				apply_room_to_grid(room, pos)
				rooms.append({"room": room, "position": pos})
				placed = true
				break
		if not placed:
			print("Failed to place room")

func can_place_room(room, pos):
	# Ensure all cells fit inside the grid and don’t overlap
	for cell in room.cells:
		var abs_pos = cell + pos

		# Check if the room extends beyond the maze bounds
		if abs_pos.x < 1 or abs_pos.x >= ROWS - 1 or abs_pos.y < 1 or abs_pos.y >= COLS - 1:
			return false

		# Check if this position is already occupied
		if maze[abs_pos.x][abs_pos.y]["type"] != "path":
			return false

		# Ensure 1-cell buffer around the room
		var neighbors = [
			Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)
		]
		for offset in neighbors:
			var neighbor_pos = abs_pos + offset
			if neighbor_pos.x >= 0 and neighbor_pos.x < ROWS and neighbor_pos.y >= 0 and neighbor_pos.y < COLS:
				if maze[neighbor_pos.x][neighbor_pos.y]["type"] == "room":
					return false  # Prevent direct adjacency to other rooms

	return true

func apply_room_to_grid(room, pos):
	for cell in room.cells:
		var abs_pos = cell + pos
		maze[abs_pos.x][abs_pos.y]["type"] = "room"

func generate_maze():
	# Perform recursive backtracking
	var current_cell = Vector2(0, 0)
	maze[0][0]["visited"] = true
	stack.push_back(current_cell)
	
	while stack.size() > 0:
		current_cell = stack[stack.size() - 1]
		var i = int(current_cell.x)
		var j = int(current_cell.y)
		
		# Collect unvisited neighbors
		var neighbors = []
		if i > 0 and not maze[i - 1][j]["visited"] and maze[i - 1][j]["type"] == "path":
			neighbors.append(Vector2(i - 1, j))
		if i < ROWS - 1 and not maze[i + 1][j]["visited"] and maze[i + 1][j]["type"] == "path":
			neighbors.append(Vector2(i + 1, j))
		if j > 0 and not maze[i][j - 1]["visited"] and maze[i][j - 1]["type"] == "path":
			neighbors.append(Vector2(i, j - 1))
		if j < COLS - 1 and not maze[i][j + 1]["visited"] and maze[i][j + 1]["type"] == "path":
			neighbors.append(Vector2(i, j + 1))
		
		if neighbors.size() > 0:
			var next_cell = neighbors[randi() % neighbors.size()]
			remove_wall(current_cell, next_cell)
			maze[int(next_cell.x)][int(next_cell.y)]["visited"] = true
			stack.push_back(next_cell)
		else:
			stack.pop_back()

func connect_room_exits():
	# Dynamically create exits by ensuring rooms have paths leading out
	for room_data in rooms:
		var room = room_data["room"]
		var pos = room_data["position"]
		var potential_exits = []

		# Remove only internal walls within each distinct room
		for cell in room.cells:
			var abs_pos = cell + pos

			# Define neighbor positions and corresponding wall indices
			var neighbors = [
				{ "pos": abs_pos + Vector2i(0, -1), "wall_index": 0 },  # Top
				{ "pos": abs_pos + Vector2i(1, 0),  "wall_index": 1 },  # Right
				{ "pos": abs_pos + Vector2i(0, 1),  "wall_index": 2 },  # Bottom
				{ "pos": abs_pos + Vector2i(-1, 0), "wall_index": 3 }   # Left
			]

			for neighbor in neighbors:
				var neighbor_pos = neighbor["pos"]
				var wall_index = neighbor["wall_index"]

				# Ensure the neighbor position is within the maze bounds
				if neighbor_pos.x >= 0 and neighbor_pos.x < ROWS and neighbor_pos.y >= 0 and neighbor_pos.y < COLS:
					var neighbor_cell = maze[neighbor_pos.x][neighbor_pos.y]

					# Only remove walls if both cells belong to the SAME room
					var is_same_room = false
					if neighbor_cell["type"] == "room":
						for other_room in rooms:
							if other_room["room"] == room and neighbor_pos - pos in other_room["room"].cells:
								is_same_room = true
								break

					if is_same_room:
						remove_wall(abs_pos, neighbor_pos)  # Use remove_wall for consistency
						continue  # Skip exit logic for internal room walls

					# If adjacent to a hallway, mark as a potential exit
					if neighbor_cell["type"] == "path":
						potential_exits.append({ "exit_pos": neighbor_pos, "wall_index": wall_index, "room_pos": abs_pos })

		# Ensure at least 2 exits into the maze
		var valid_exits = []
		for exit_data in potential_exits:
			var exit_pos = exit_data["exit_pos"]
			var wall_index = exit_data["wall_index"]

			# Ensure exits don't lead directly into another room unless necessary
			if maze[exit_pos.x][exit_pos.y]["type"] == "room":
				continue  # Skip exits into other rooms unless no other options exist
			valid_exits.append(exit_data)

		# Randomize exit selection to avoid clustering
		valid_exits.shuffle()

		# Enforce exactly 2 exits that are not adjacent
		if valid_exits.size() >= 2:
			var selected_exits = []
			for exit_data in valid_exits:
				if selected_exits.size() == 0 or abs(selected_exits[0]["exit_pos"].x - exit_data["exit_pos"].x) > 1 or abs(selected_exits[0]["exit_pos"].y - exit_data["exit_pos"].y) > 1:
					selected_exits.append(exit_data)
				if selected_exits.size() == 2:
					break

			for exit_data in selected_exits:
				var exit_pos = exit_data["exit_pos"]
				var wall_index = exit_data["wall_index"]
				var room_pos = exit_data["room_pos"]

				# Mark exit in the maze grid
				maze[exit_pos.x][exit_pos.y]["type"] = "exit"

				# Remove the wall between room and exit using remove_wall function
				remove_wall(room_pos, exit_pos)

# Removes the wall between two adjacent cells based on their relative positions
func remove_wall(current, next):
	var dx = int(next.x) - int(current.x)
	var dy = int(next.y) - int(current.y)
	
	if dx == -1:
		# Next is above current
		maze[int(current.x)][int(current.y)]["walls"][0] = false  # Remove top wall of current
		maze[int(next.x)][int(next.y)]["walls"][2] = false          # Remove bottom wall of neighbor
	elif dx == 1:
		# Next is below current
		maze[int(current.x)][int(current.y)]["walls"][2] = false  # Remove bottom wall of current
		maze[int(next.x)][int(next.y)]["walls"][0] = false          # Remove top wall of neighbor
	elif dy == -1:
		# Next is left of current
		maze[int(current.x)][int(current.y)]["walls"][3] = false  # Remove left wall of current
		maze[int(next.x)][int(next.y)]["walls"][1] = false          # Remove right wall of neighbor
	elif dy == 1:
		# Next is right of current
		maze[int(current.x)][int(current.y)]["walls"][1] = false  # Remove right wall of current
		maze[int(next.x)][int(next.y)]["walls"][3] = false          # Remove left wall of neighbor

func build_collision_shapes():
	var collision_body = StaticBody2D.new()
	add_child(collision_body)
	
	for i in range(ROWS):
		for j in range(COLS):
			var cell = maze[i][j]
			# Calculate the top-left position of the current cell.
			# Note: In our _draw() function, we used (j * CELL_SIZE, i * CELL_SIZE)
			var pos = Vector2(j * CELL_SIZE, i * CELL_SIZE)
			
			# Top wall
			if cell["walls"][0]:
				var shape_top = RectangleShape2D.new()
				shape_top.extents = Vector2(CELL_SIZE / 2, WALL_THICKNESS / 2)
				var cs_top = CollisionShape2D.new()
				cs_top.shape = shape_top
				# Center of the top wall: half cell width, half thickness from the top
				cs_top.position = pos + Vector2(CELL_SIZE / 2, WALL_THICKNESS / 2)
				collision_body.add_child(cs_top)
			
			# Right wall
			if cell["walls"][1]:
				var shape_right = RectangleShape2D.new()
				shape_right.extents = Vector2(WALL_THICKNESS / 2, CELL_SIZE / 2)
				var cs_right = CollisionShape2D.new()
				cs_right.shape = shape_right
				# Center of the right wall: near the right edge and half cell height
				cs_right.position = pos + Vector2(CELL_SIZE - WALL_THICKNESS / 2, CELL_SIZE / 2)
				collision_body.add_child(cs_right)
			
			# Bottom wall
			if cell["walls"][2]:
				var shape_bottom = RectangleShape2D.new()
				shape_bottom.extents = Vector2(CELL_SIZE / 2, WALL_THICKNESS / 2)
				var cs_bottom = CollisionShape2D.new()
				cs_bottom.shape = shape_bottom
				# Center of the bottom wall: half cell width, near the bottom edge
				cs_bottom.position = pos + Vector2(CELL_SIZE / 2, CELL_SIZE - WALL_THICKNESS / 2)
				collision_body.add_child(cs_bottom)
			
			# Left wall
			if cell["walls"][3]:
				var shape_left = RectangleShape2D.new()
				shape_left.extents = Vector2(WALL_THICKNESS / 2, CELL_SIZE / 2)
				var cs_left = CollisionShape2D.new()
				cs_left.shape = shape_left
				 # Center of the left wall: near the left edge and half cell height
				cs_left.position = pos + Vector2(WALL_THICKNESS / 2, CELL_SIZE / 2)
				collision_body.add_child(cs_left)

# Draw the maze: Each cell's remaining walls are drawn as lines.
func _draw():
	for i in range(ROWS):
		for j in range(COLS):
			var cell = maze[i][j]
			var pos = Vector2(j * CELL_SIZE, i * CELL_SIZE)
			
			# Fill rooms with a semi-transparent blue background
			if cell["type"] == "room":
				draw_rect(Rect2(pos, Vector2(CELL_SIZE, CELL_SIZE)), Color(0, 0, 1, 0.1), true)
			
			# Draw walls with the appropriate color
			var wall_color = Color.WHITE
			for dir in range(4):
				if cell["walls"][dir]:
					var start_pos = pos
					var end_pos = pos
					if dir == 0:
						end_pos += Vector2(CELL_SIZE, 0)  # Top
					elif dir == 1:
						start_pos += Vector2(CELL_SIZE, 0)
						end_pos = start_pos + Vector2(0, CELL_SIZE)  # Right
					elif dir == 2:
						start_pos += Vector2(0, CELL_SIZE)
						end_pos = start_pos + Vector2(CELL_SIZE, 0)  # Bottom
					elif dir == 3:
						end_pos = start_pos + Vector2(0, CELL_SIZE)  # Left
					draw_line(start_pos, end_pos, wall_color, 2)
