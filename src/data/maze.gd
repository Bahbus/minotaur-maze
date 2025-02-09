extends Node2D

# Walls: [top, right, bottom, left]
# Directions: 
#   (-1, 0) = left, (1, 0) = right, (0, -1) = up, (0, 1) = down

# For removing walls:
var wall_map = {
	Vector2i(-1, 0): [3, 1],  # pos1's left, pos2's right
	Vector2i(1, 0): [1, 3],   # pos1's right, pos2's left
	Vector2i(0, -1): [0, 2],  # pos1's top, pos2's bottom
	Vector2i(0, 1): [2, 0]    # pos1's bottom, pos2's top
}

# Maze dimensions and cell metrics
const ROWS = 28
const COLS = 28
const CELL_SIZE = 32
const WALL_THICKNESS = 2

# Maze data structures
var maze = []
var stack = []
var rooms = []
var edge_map := {}

var drawn_walls = []
var cached_edges = []

@export var player: CharacterBody2D
@export var minotaur: CharacterBody2D

func _ready():
	randomize()
	initialize_maze()
	place_rooms()
	generate_maze()
	place_exit_stairs()
	connect_room_exits()
	build_collision_shapes()
	spawn_player()
	spawn_minotaur()
	stack.clear()

# Create the initial array of cells
func initialize_maze():
	maze.clear()
	rooms.clear()
	for y in range(ROWS):
		var row_data = []
		for x in range(COLS):
			row_data.append({
				"visited": false,
				"walls": [true, true, true, true], # [top, right, bottom, left]
				"type": "path"
			})
		maze.append(row_data)

# Randomly place pre-defined rooms
func place_rooms():
	var available_rooms = RoomDefinitions.get_rooms()
	available_rooms.shuffle()
	var available_positions = []
	
	# Build a list of all valid positions
	for y in range(1, ROWS - 3):
		for x in range(1, COLS - 3):
			available_positions.append(Vector2i(x, y))

	available_positions.shuffle()

	for room in available_rooms:
		var rotation_angle = [0, -90, 90, 180][randi() % 4]
		var rotated_room = room.rotate(rotation_angle)

		# Try placing the room in available positions
		for pos in available_positions:
			if can_place_room(rotated_room, pos):
				apply_room_to_grid(rotated_room, pos)
				rooms.append({ "room": rotated_room, "position": pos })
				available_positions.erase(pos)  # Remove used position
				break

func can_place_room(room, pos: Vector2i) -> bool:
	for cell in room.cells:
		var abs_pos = cell + pos
		if not is_within_bounds(abs_pos):
			return false
		if not is_type(abs_pos, "path"):
			return false
		if has_adjacent_type(abs_pos, "room"):
			return false
	return true

func apply_room_to_grid(room, pos: Vector2i):
	for cell in room.cells:
		var abs_pos = cell + pos
		set_cell_type(abs_pos, "room")
		# Remove walls between adjacent cells within the same room
		for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var neighbor_pos = abs_pos + offset
			if is_within_bounds(neighbor_pos) and is_type(neighbor_pos, "room"):
				remove_wall_between(abs_pos, neighbor_pos)

func has_adjacent_type(pos: Vector2i, cell_type: String) -> bool:
	for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		if is_type(pos + offset, cell_type):
			return true
	return false

# Standard DFS maze generation
func generate_maze():
	var current_cell = Vector2i(randi() % COLS, randi() % ROWS)
	while not is_type(current_cell, "path"):
		current_cell = Vector2i(randi() % COLS, randi() % ROWS)
	
	visit(current_cell)
	stack.push_back(current_cell)
	while stack.size() > 0:
		current_cell = stack.back()
		var neighbors = []
		for dir in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var next_cell = current_cell + dir
			if is_within_bounds(next_cell):
				if not get_cell(next_cell).get("visited", false):
					if is_type(next_cell, "path"):
						neighbors.append(next_cell)
		if neighbors.size() > 0:
			var next_cell = neighbors[randi() % neighbors.size()]
			remove_wall_between(current_cell, next_cell)
			visit(next_cell)
			stack.push_back(next_cell)
		else:
			stack.pop_back()

# Random exit placement
func place_exit_stairs():
	var valid_positions = []
	for y in range(ROWS):
		for x in range(COLS):
			var pos = Vector2i(x, y)
			if get_cell(pos).get("visited", false):
				valid_positions.append(pos)
	if valid_positions.size() > 0:
		var exit_pos = valid_positions[randi() % valid_positions.size()]
		set_cell_type(exit_pos, "exit_stairs")
		print("Exit stairs placed at:", exit_pos)

# Connect rooms to the maze
# Optimize `connect_room_exits()` by reducing redundant calls
func connect_room_exits():
	for room_data in rooms:
		var pos = room_data["position"]
		var room = room_data["room"]
		var perimeter = get_room_perimeter(room.cells, pos)
		var potential_exits = []

		for abs_pos in perimeter:
			for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				var neighbor_pos = abs_pos + offset
				if is_within_bounds(neighbor_pos) and is_type(neighbor_pos, "path"):
					potential_exits.append({ "exit_pos": neighbor_pos, "room_pos": abs_pos })

		var exit_count = calculate_exit_count(room, pos)
		var valid_exits = potential_exits.filter(func(e): return not is_type(e["exit_pos"], "room"))
		valid_exits.shuffle()
		var chosen = select_non_adjacent_exits(valid_exits, exit_count)

		for exit_data in chosen:
			remove_wall_between(exit_data["room_pos"], exit_data["exit_pos"])

func has_valid_maze_connection(pos: Vector2i) -> bool:
	for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var neighbor = pos + offset
		if is_within_bounds(neighbor):
			if is_type(neighbor, "path") and get_cell(neighbor).get("visited", false):
				return true
	return false

func calculate_exit_count(room, pos):
	var min_exits = 2
	var max_exits = max(2, get_room_perimeter(room.cells, pos).size() / 2)
	var area = room.cells.size()
	var base_exits = max(2, round((area / 9)+1))
	return clamp(base_exits, 2, max_exits)

func get_room_perimeter(room_cells: Array, pos: Vector2i) -> Array:
	var perimeter_cells = []
	var room_positions = []
	for c in room_cells:
		room_positions.append(Vector2i(pos.x + c.x, pos.y + c.y))
	for cell in room_positions:
		for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var neighbor_pos = cell + offset
			if not room_positions.has(neighbor_pos):
				perimeter_cells.append(cell)
				break
	return perimeter_cells

func select_non_adjacent_exits(valid_exits, exit_count):
	valid_exits.shuffle()
	var selected = []
	var occupied_positions := []

	for exit_data in valid_exits:
		var no_conflict = true
		for e in selected:
			if abs(e["exit_pos"].x - exit_data["exit_pos"].x) <= 2 and abs(e["exit_pos"].y - exit_data["exit_pos"].y) <= 2:
				no_conflict = false
				break
		if no_conflict:
			selected.append(exit_data)
			occupied_positions.append(exit_data["exit_pos"])
			if selected.size() == exit_count:
				break

	# Ensure exits are distributed
	if selected.size() < exit_count and valid_exits.size() > exit_count:
		for exit_data in valid_exits:
			if exit_data["exit_pos"] not in occupied_positions:
				selected.append(exit_data)
				if selected.size() == exit_count:
					break

	return selected

# Remove walls between cells
func remove_wall_between(pos1: Vector2i, pos2: Vector2i):
	if not is_within_bounds(pos1) or not is_within_bounds(pos2):
		return
	var delta = pos2 - pos1
	if wall_map.has(delta):
		var walls_to_remove = wall_map[delta]
		# walls_to_remove[0] = which wall index to remove for pos1
		# walls_to_remove[1] = which wall index to remove for pos2
		set_wall_state(pos1, walls_to_remove[0], false)
		set_wall_state(pos2, walls_to_remove[1], false)

func set_wall_state(pos: Vector2i, wall_index: int, state: bool):
	if is_within_bounds(pos):
		maze[pos.y][pos.x]["walls"][wall_index] = state

# Build rectangular collision shapes for each active wall
# Optimize collision shape generation to prevent redundant colliders
func build_collision_shapes():
	var collision_body = StaticBody2D.new()
	collision_body.set_collision_layer_value(1, true)
	collision_body.set_collision_mask_value(1, false)
	add_child(collision_body)
	for y in range(ROWS):
		for x in range(COLS):
			var cell_pos = Vector2i(x, y)
			if not is_within_bounds(cell_pos):
				continue
			var base_pos = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			var walls = get_walls(cell_pos)
			var wall_definitions = [
				{ "wall": walls[0], "p1": base_pos, "p2": base_pos + Vector2(CELL_SIZE, 0) },
				{ "wall": walls[1], "p1": base_pos + Vector2(CELL_SIZE, 0), "p2": base_pos + Vector2(CELL_SIZE, CELL_SIZE) },
				{ "wall": walls[2], "p1": base_pos + Vector2(0, CELL_SIZE), "p2": base_pos + Vector2(CELL_SIZE, CELL_SIZE) },
				{ "wall": walls[3], "p1": base_pos, "p2": base_pos + Vector2(0, CELL_SIZE) }
			]
			for w in wall_definitions:
				if w["wall"]:
					var key = "%s_%s_%s_%s" % [str(w["p1"].x), str(w["p1"].y), str(w["p2"].x), str(w["p2"].y)]
					if not edge_map.has(key):
						edge_map[key] = true
						add_wall_collision(collision_body, (w["p1"] + w["p2"]) / 2, abs(w["p2"] - w["p1"]) / 2)

func add_wall_collision(parent: Node, pos: Vector2, extents: Vector2):
	var shape = RectangleShape2D.new()
	shape.extents = Vector2(extents.x + WALL_THICKNESS / 2, extents.y + WALL_THICKNESS / 2)  # Adjusted for thickness
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = shape
	collision_shape.position = pos
	parent.add_child(collision_shape)

# Optimize `find_valid_spawn_position()` using a flood-fill approach
func find_valid_spawn_position(exit_pos: Vector2i) -> Vector2i:
	var step_down = [0.75, 0.6, 0.5, 0.35]
	for scaler in step_down:
		var distance_threshold = int(scaler * max(ROWS, COLS))
		var valid_positions = []
		for y in range(ROWS):
			for x in range(COLS):
				var pos = Vector2i(x, y)
				if is_type(pos, "path"):
					if pos.distance_to(exit_pos) >= distance_threshold and get_cell(pos).get("visited", false):
						valid_positions.append(pos)
		if valid_positions.size() > 0:
			return valid_positions[randi() % valid_positions.size()]

	# Fallback if none found
	print("Spawning fallback")
	return Vector2i(0, 0)

func spawn_player():
	var exit_pos = get_exit_stairs_position()
	var spawn_pos = find_valid_spawn_position(exit_pos)
	player = preload("res://src/scenes/player.tscn").instantiate()
	player.position = Vector2(
		(spawn_pos.x + 0.5) * CELL_SIZE,
		(spawn_pos.y + 0.5) * CELL_SIZE
	) + Vector2(WALL_THICKNESS / 2, WALL_THICKNESS / 2)  # Offset to avoid edge clipping
	player.maze = self
	add_child(player)
	print("Player spawned at: ", spawn_pos)

func spawn_minotaur():
	if rooms.is_empty():
		return
	minotaur = preload("res://src/scenes/minotaur.tscn").instantiate()
	var room_data = rooms[randi() % rooms.size()]
	var room = room_data["room"]
	var room_pos = room_data["position"]
	var spawn_cell = room.cells[randi() % room.cells.size()]
	var abs_spawn = Vector2i(room_pos.x + spawn_cell.x, room_pos.y + spawn_cell.y)
	minotaur.position = Vector2(
		(abs_spawn.x + 0.5) * CELL_SIZE,
		(abs_spawn.y + 0.5) * CELL_SIZE
	) + Vector2(WALL_THICKNESS / 2, WALL_THICKNESS / 2)  # Offset for collision accuracy
	minotaur.maze = self
	add_child(minotaur)
	print("Minotaur spawned at: ", abs_spawn,)

func _draw():
	if drawn_walls.size() > 0:
		for wall in drawn_walls:
			draw_line(wall["start"], wall["end"], Color.WHITE, 2)
		return

	for y in range(ROWS):
		for x in range(COLS):
			var cell_pos = Vector2i(x, y)
			if not is_within_bounds(cell_pos):
				continue
			var base_pos = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			if is_type(cell_pos, "room"):
				draw_rect(Rect2(base_pos, Vector2(CELL_SIZE, CELL_SIZE)), Color(0, 0, 1, 0.1), true)
			if is_type(cell_pos, "exit_stairs"):
				draw_rect(Rect2(base_pos, Vector2(CELL_SIZE, CELL_SIZE)), Color(0, 1, 0, 0.8), true)

			var walls = get_cell(cell_pos).get("walls", [true, true, true, true])
			var wall_positions = [
				{ "start": base_pos, "end": base_pos + Vector2(CELL_SIZE, 0) },
				{ "start": base_pos + Vector2(CELL_SIZE, 0), "end": base_pos + Vector2(CELL_SIZE, CELL_SIZE) },
				{ "start": base_pos + Vector2(0, CELL_SIZE), "end": base_pos + Vector2(CELL_SIZE, CELL_SIZE) },
				{ "start": base_pos, "end": base_pos + Vector2(0, CELL_SIZE) }
			]

			for dir in range(4):
				if walls[dir]:
					drawn_walls.append(wall_positions[dir])
					draw_line(wall_positions[dir]["start"], wall_positions[dir]["end"], Color.WHITE, 2)

func visit(pos: Vector2i):
	if is_within_bounds(pos):
		maze[pos.y][pos.x]["visited"] = true

func is_type(pos: Vector2i, cell_type: String) -> bool:
	return get_cell(pos).get("type", "") == cell_type

func is_within_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < COLS and pos.y >= 0 and pos.y < ROWS

func get_walls(pos: Vector2i) -> Array:
	if is_within_bounds(pos):
		return get_cell(pos).get("walls", [true, true, true, true])
	return [true, true, true, true]

func get_cell(pos: Vector2i) -> Dictionary:
	if is_within_bounds(pos):
		return maze[pos.y][pos.x]
	return {}

func set_cell_type(pos: Vector2i, cell_type: String):
	if is_within_bounds(pos):
		maze[pos.y][pos.x]["type"] = cell_type

func get_exit_stairs_position() -> Vector2i:
	for y in range(ROWS):
		for x in range(COLS):
			var pos = Vector2i(x, y)
			if is_type(pos, "exit_stairs"):
				return pos
	return Vector2i(0, 0)

func get_room_at(pos: Vector2i):
	for rd in rooms:
		var room = rd["room"]
		var room_pos = rd["position"]
		if (pos - room_pos) in room.cells:
			return room
	return null

func has_wall_between(pos1: Vector2i, pos2: Vector2i) -> bool:
	if not is_within_bounds(pos1) or not is_within_bounds(pos2):
		return true
	var delta = pos2 - pos1
	match delta:
		Vector2i(-1, 0):
			# pos1's left or pos2's right
			return maze[pos1.y][pos1.x]["walls"][3] or maze[pos2.y][pos2.x]["walls"][1]
		Vector2i(1, 0):
			# pos1's right or pos2's left
			return maze[pos1.y][pos1.x]["walls"][1] or maze[pos2.y][pos2.x]["walls"][3]
		Vector2i(0, -1):
			# pos1's top or pos2's bottom
			return maze[pos1.y][pos1.x]["walls"][0] or maze[pos2.y][pos2.x]["walls"][2]
		Vector2i(0, 1):
			# pos1's bottom or pos2's top
			return maze[pos1.y][pos1.x]["walls"][2] or maze[pos2.y][pos2.x]["walls"][0]
		_:
			return true



func gather_maze_edges() -> Array:
	if cached_edges.size() > 0:
		return cached_edges  # Use precomputed edges
	
	var edge_map := {}
	for y in range(ROWS):
		for x in range(COLS):
			var cell_pos = Vector2i(x, y)
			if not is_within_bounds(cell_pos):
				continue
			var cell_top_left = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			var walls = get_walls(cell_pos)

			if walls[0]: add_edge(edge_map, cell_top_left, cell_top_left + Vector2(CELL_SIZE, 0))
			if walls[1]: add_edge(edge_map, cell_top_left + Vector2(CELL_SIZE, 0), cell_top_left + Vector2(CELL_SIZE, CELL_SIZE))
			if walls[2]: add_edge(edge_map, cell_top_left + Vector2(0, CELL_SIZE), cell_top_left + Vector2(CELL_SIZE, CELL_SIZE))
			if walls[3]: add_edge(edge_map, cell_top_left, cell_top_left + Vector2(0, CELL_SIZE))

	cached_edges = edge_map.values()
	return cached_edges

func add_edge(edge_map: Dictionary, p1: Vector2, p2: Vector2) -> void:
	# Expand the wall by thickness
	var direction = (p2 - p1).normalized()  # Get direction of wall
	var perpendicular = Vector2(-direction.y, direction.x) * (WALL_THICKNESS / 2)

	# Offset edges slightly outward to match actual wall thickness
	var thick_p1 = p1 - perpendicular
	var thick_p2 = p2 + perpendicular

	if thick_p2 < thick_p1:
		var temp = thick_p1
		thick_p1 = thick_p2
		thick_p2 = temp

	var key = "%s_%s_%s_%s" % [str(thick_p1.x), str(thick_p1.y), str(thick_p2.x), str(thick_p2.y)]
	if not edge_map.has(key):
		edge_map[key] = { "p1": thick_p1, "p2": thick_p2 }
