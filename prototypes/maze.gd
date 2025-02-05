extends Node2D

### 🏛 **Maze Configuration**
const ROWS = 28
const COLS = 28
const CELL_SIZE = 32
const WALL_THICKNESS = 2

### 🗄 **Data Structures**
var maze = []
var stack = []
var rooms = []

### 🚀 **Initialization & Setup**
func _ready():
	randomize()
	initialize_maze()
	place_rooms()
	generate_maze()
	place_exit_stairs()
	connect_room_exits()
	build_collision_shapes()

func initialize_maze():
	for i in range(ROWS):
		var row = []
		for j in range(COLS):
			row.append({ "visited": false, "walls": [true, true, true, true], "type": "path" })
		maze.append(row)

### 🏠 **Room Handling**
func place_rooms():
	var available_rooms = RoomDefinitions.get_rooms()
	available_rooms.shuffle()
	for room in available_rooms:
		var rotation_angle = [0, -90, 90, 180][randi() % 4]  # Random rotation angle
		var rotated_room = room.rotate(rotation_angle)  # Use Room's rotation method
		for attempt in range(20):
			var pos = Vector2i(randi() % (ROWS - 3) + 1, randi() % (COLS - 3) + 1)
			if can_place_room(rotated_room, pos):
				apply_room_to_grid(rotated_room, pos)
				rooms.append({ "room": rotated_room, "position": pos })
				break

func can_place_room(room, pos: Vector2i) -> bool:
	for cell in room.cells:
		var abs_pos = cell + pos
		if not is_within_bounds(abs_pos) or not is_type(abs_pos, "path") or has_adjacent_type(abs_pos, "room"):
			return false
	return true

func apply_room_to_grid(room, pos):
	for cell in room.cells:
		var abs_pos = cell + pos
		set_cell_type(abs_pos, "room")
		# Remove walls between adjacent cells of the same room
		for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var neighbor_pos = abs_pos + offset
			if is_within_bounds(neighbor_pos) and is_type(neighbor_pos, "room"):
				remove_wall_between(abs_pos, neighbor_pos)

func has_adjacent_type(pos: Vector2i, cell_type: String) -> bool:
	for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		if is_type(pos + offset, cell_type):
			return true
	return false

### 🔀 **Maze Generation**
func generate_maze():
	var current_cell = Vector2i(0, 0)
	visit(current_cell)
	stack.push_back(current_cell)
	while stack.size() > 0:
		current_cell = stack.back()
		var neighbors = []
		for dir in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var next_cell = current_cell + dir
			if is_within_bounds(next_cell) and not get_cell(next_cell).get("visited", false) and is_type(next_cell, "path"):
				neighbors.append(next_cell)
		if neighbors.size() > 0:
			var next_cell = neighbors[randi() % neighbors.size()]
			remove_wall_between(current_cell, next_cell)
			visit(next_cell)
			stack.push_back(next_cell)
		else:
			stack.pop_back()

### 🚪 **Exit Stairs Placement**
func place_exit_stairs():
	var valid_positions = []
	for i in range(ROWS):
		for j in range(COLS):
			var pos = Vector2i(j, i)  # Swap x/y here
			if get_cell(pos).get("visited", false):
				valid_positions.append(pos)

	if valid_positions.size() > 0:
		var exit_pos = valid_positions[randi() % valid_positions.size()]
		set_cell_type(exit_pos, "exit_stairs")
		print("Exit stairs placed at: ", exit_pos)  # Debugging

### 🔗 **Pathfinding & Connectivity**
func connect_room_exits():
	for room_data in rooms:
		var pos = room_data["position"]
		var room = room_data["room"]
		var perimeter = get_room_perimeter(room.cells, pos)
		var potential_exits = []
		for abs_pos in perimeter:
			for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				var neighbor_pos = abs_pos + offset
				if is_within_bounds(neighbor_pos) and not is_type(neighbor_pos, "room"):
					if is_type(neighbor_pos, "path") and has_valid_maze_connection(neighbor_pos):
						potential_exits.append({ "exit_pos": neighbor_pos, "room_pos": abs_pos })
		var exit_count = calculate_exit_count(room, pos)
		var valid_exits = potential_exits.filter(func(exit): return not is_type(exit["exit_pos"], "room"))
		valid_exits.shuffle()
		var selected_exits = select_non_adjacent_exits(valid_exits, exit_count)
		for exit_data in selected_exits:
			remove_wall_between(exit_data["room_pos"], exit_data["exit_pos"])

func has_valid_maze_connection(pos: Vector2i) -> bool:
	for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:  # Check if the neighboring paths actually lead somewhere in the main maze
		var neighbor_pos = pos + offset
		if is_within_bounds(neighbor_pos) and is_type(neighbor_pos, "path") and get_cell(neighbor_pos).get("visited", false):
			return true  # It's a valid connection to the maze
	return false

func calculate_exit_count(room, pos):
	var min_exits = 2
	var max_exits = max(2, len(get_room_perimeter(room.cells, pos)) / 2)
	var area = len(room.cells)
	return min(min_exits + floor((area - 15) / 10), max_exits) if area >= 15 else min_exits

func get_room_perimeter(room_cells: Array, pos: Vector2i) -> Array:
	var perimeter_cells = []
	var room_positions = room_cells.map(func(cell): return Vector2i(cell.y + pos.y, cell.x + pos.x))
	for cell in room_positions:
		for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var neighbor_pos = cell + offset
			if not room_positions.has(neighbor_pos):  # If the neighbor is outside the room, it's a perimeter cell
				perimeter_cells.append(cell)
				break  # No need to check further, it's already perimeter
	return perimeter_cells

func select_non_adjacent_exits(valid_exits, exit_count):
	valid_exits.shuffle()
	var selected_exits = []
	for exit_data in valid_exits:
		if selected_exits.is_empty() or not selected_exits.any(func(e): return abs(e["exit_pos"].x - exit_data["exit_pos"].x) <= 1 and abs(e["exit_pos"].y - exit_data["exit_pos"].y) <= 1):
			selected_exits.append(exit_data)
			if selected_exits.size() == exit_count:
				break
	return selected_exits

### 🚧 **Wall Handling**
func remove_wall_between(pos1: Vector2i, pos2: Vector2i):
	if not is_within_bounds(pos1) or not is_within_bounds(pos2): return
	var wall_map = {
		Vector2i(-1, 0): [0, 2],  # Top wall removed, bottom wall removed in neighbor
		Vector2i(1, 0): [2, 0],  # Bottom wall removed, top wall removed in neighbor
		Vector2i(0, -1): [3, 1],  # Left wall removed, right wall removed in neighbor
		Vector2i(0, 1): [1, 3]   # Right wall removed, left wall removed in neighbor
	}
	if wall_map.has(pos2 - pos1):
		set_wall_state(pos1, wall_map[pos2 - pos1][0], false)
		set_wall_state(pos2, wall_map[pos2 - pos1][1], false)

func set_wall_state(pos: Vector2i, wall_index: int, state: bool):
	if is_within_bounds(pos):
		maze[pos.y][pos.x]["walls"][wall_index] = state  # Swap x/y

### 🔨 **Collision Handling**
func build_collision_shapes():
	var collision_body = StaticBody2D.new()
	add_child(collision_body)
	for i in range(ROWS):
		for j in range(COLS):
			var cell_pos = Vector2i(i, j)
			if not is_within_bounds(cell_pos):
				continue
			var pos = Vector2(j * CELL_SIZE, i * CELL_SIZE)
			var walls = get_walls(cell_pos)
			var wall_definitions = [
				{ "wall": walls[0], "offset": Vector2(CELL_SIZE / 2, WALL_THICKNESS / 2), "extents": Vector2(CELL_SIZE / 2, WALL_THICKNESS / 2) },
				{ "wall": walls[1], "offset": Vector2(CELL_SIZE - WALL_THICKNESS / 2, CELL_SIZE / 2), "extents": Vector2(WALL_THICKNESS / 2, CELL_SIZE / 2) },
				{ "wall": walls[2], "offset": Vector2(CELL_SIZE / 2, CELL_SIZE - WALL_THICKNESS / 2), "extents": Vector2(CELL_SIZE / 2, WALL_THICKNESS / 2) },
				{ "wall": walls[3], "offset": Vector2(WALL_THICKNESS / 2, CELL_SIZE / 2), "extents": Vector2(WALL_THICKNESS / 2, CELL_SIZE / 2) }
			]
			for wall in wall_definitions:
				if wall["wall"]:
					add_wall_collision(collision_body, pos + wall["offset"], wall["extents"])

func add_wall_collision(parent: Node, pos: Vector2, extents: Vector2):
	var shape = RectangleShape2D.new()
	shape.extents = extents
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = shape
	collision_shape.position = pos
	parent.add_child(collision_shape)

### ✏️ **Drawing & Visualization**
func _draw():
	for i in range(ROWS):
		for j in range(COLS):
			var cell_pos = Vector2i(i, j)
			var pos = Vector2(j * CELL_SIZE, i * CELL_SIZE)
			if not is_within_bounds(cell_pos):
				continue
			if is_type(cell_pos, "room"):
				draw_rect(Rect2(pos, Vector2(CELL_SIZE, CELL_SIZE)), Color(0, 0, 1, 0.1), true)
			if is_type(cell_pos, "exit_stairs"):
				draw_rect(Rect2(pos, Vector2(CELL_SIZE, CELL_SIZE)), Color(0, 1, 0, 0.8), true)  # Green exit square
			var walls = get_cell(cell_pos).get("walls", [true, true, true, true])
			var wall_positions = [
				{ "start": pos, "end": pos + Vector2(CELL_SIZE, 0) },
				{ "start": pos + Vector2(CELL_SIZE, 0), "end": pos + Vector2(CELL_SIZE, CELL_SIZE) },
				{ "start": pos + Vector2(0, CELL_SIZE), "end": pos + Vector2(CELL_SIZE, CELL_SIZE) },
				{ "start": pos, "end": pos + Vector2(0, CELL_SIZE) }
			]
			for dir in range(4):
				if walls[dir]:
					draw_line(wall_positions[dir]["start"], wall_positions[dir]["end"], Color.WHITE, 2)

### 🛠 **Helper Functions**
func visit(pos: Vector2i):
	if is_within_bounds(pos):
		maze[pos.y][pos.x]["visited"] = true

func is_type(pos: Vector2i, cell_type: String) -> bool:
	return get_cell(pos).get("type", "") == cell_type

func is_within_bounds(pos: Vector2i) -> bool:
	return pos.y >= 0 and pos.y < ROWS and pos.x >= 0 and pos.x < COLS

func get_walls(pos: Vector2i) -> Array:
	if is_within_bounds(pos):
		return get_cell(pos).get("walls", [true, true, true, true])
	return [true, true, true, true]  # Default to all walls present if out of bounds

func get_cell(pos: Vector2i) -> Dictionary:
	return maze[pos.y][pos.x] if is_within_bounds(pos) else {}

func set_cell_type(pos: Vector2i, cell_type: String):
	if is_within_bounds(pos):
		maze[pos.y][pos.x]["type"] = cell_type
