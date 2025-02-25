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
const DEFAULT_DOOR_PERCENT = 3  # Default % of walls to be replaced by doors
const MAX_DOOR_PERCENT = 10  # Maximum % allowed

var nav_poly: NavigationPolygon
var nav_source: NavigationMeshSourceGeometryData2D
var callback_parsing: Callable
var callback_baking: Callable

# Maze data structures
var maze = []
var stack = []
var rooms = []
var edge_map := {}
var wall_bodies = [] #includes doors
var player_selected_door_percent = DEFAULT_DOOR_PERCENT

@export var player: CharacterBody2D
@export var minotaur: CharacterBody2D

@onready var nav_region:=$NavRegion

func _ready():
	randomize()
	initialize_maze()
	place_rooms()
	generate_maze()
	connect_room_exits()
	place_exit_stairs()
	build_walls()
	place_doors()
	check_maze()
	await get_tree().process_frame
	rebake_navigation()
	spawn_player()
	spawn_minotaur()
	queue_redraw()
	stack.clear()

# Create the initial array of cells
func initialize_maze():
	maze.clear()
	rooms.clear()
	wall_bodies.clear()
	edge_map.clear()
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
				set_wall_state_between(abs_pos, neighbor_pos, false)

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
			set_wall_state_between(current_cell, next_cell, false)
			visit(next_cell)
			stack.push_back(next_cell)
		else:
			stack.pop_back()

# Connect rooms to the maze
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
			set_wall_state_between(exit_data["room_pos"], exit_data["exit_pos"], false)

# Random exit placement
func place_exit_stairs(stairs: Vector2i = Vector2i(-1, -1)):
	var valid_positions = []
	if stairs != Vector2i(-1, -1):
		valid_positions.append(stairs)
	else:
		for y in range(ROWS):
			for x in range(COLS):
				var pos = Vector2i(x, y)
				if get_cell(pos).get("visited", false):
					valid_positions.append(pos)
	if valid_positions.size() > 0:
		var exit_pos = valid_positions[randi() % valid_positions.size()]
		set_cell_type(exit_pos, "exit_stairs")
		print("Exit stairs placed at:", exit_pos)

# Place doors in strategic locations
func place_doors():
	var all_possible_doors = []
	var forced_doors = []
	var key
	var occupied_positions = {}

	# Identify all eligible wall positions
	for y in range(ROWS):
		for x in range(COLS):
			var cell_pos = Vector2i(x, y)
			if not is_within_bounds(cell_pos):
				continue

			var base_pos = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			var walls = get_walls(cell_pos)

			var wall_definitions = [
				{ "wall": walls[0], "pos": base_pos, "rot": 0 },  # Top
				{ "wall": walls[1], "pos": base_pos + Vector2(CELL_SIZE, 0), "rot": 90 },  # Right
				{ "wall": walls[2], "pos": base_pos + Vector2(0, CELL_SIZE), "rot": 0 },  # Bottom
				{ "wall": walls[3], "pos": base_pos, "rot": 90 }  # Left
			]
			
			for i in range(4):
				var neighbor_pos = cell_pos + [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][i]
				if is_type(neighbor_pos, "room"):
					continue
				if is_within_bounds(neighbor_pos): #and not is_colliding_with_wall(neighbor_pos):
					var door_entry = {
						"pos": wall_definitions[i]["pos"],
						"rot": wall_definitions[i]["rot"]
					}
					if walls[i]:
						if door_entry in all_possible_doors:
							continue
						if is_type(cell_pos, "room"):
							continue
						if has_sufficient_wall_support(cell_pos, i):
							all_possible_doors.append(door_entry)
					elif is_type(cell_pos, "room") and is_type(neighbor_pos, "path"):
						forced_doors.append(door_entry)
						key = "%s_%s_%s" % [door_entry["pos"].x, door_entry["pos"].y, door_entry["rot"]]
						occupied_positions[key] = true

	# Ensure no doors in forced_doors are ever removed
	# Remove adjacent doors in a straight line from all_possible_doors only
	var filtered_doors = []
	
	for door in all_possible_doors:
		key = "%s_%s_%s" % [door["pos"].x, door["pos"].y, door["rot"]]
		var neighbor_keys = [
			"%s_%s_%s" % [door["pos"].x - CELL_SIZE if door["rot"] == 0 else door["pos"].x, door["pos"].y if door["rot"] == 0 else door["pos"].y - CELL_SIZE, door["rot"]], 
			"%s_%s_%s" % [door["pos"].x + CELL_SIZE if door["rot"] == 0 else door["pos"].x, door["pos"].y if door["rot"] == 0 else door["pos"].y + CELL_SIZE, door["rot"]]
		]

		# If this door is from forced_doors somehow, always skip it
		if door in forced_doors:
			continue
		# Otherwise, prevent adjacency in straight lines
		if neighbor_keys[0] in occupied_positions or neighbor_keys[1] in occupied_positions:
			continue
		if not door in filtered_doors:
			filtered_doors.append(door)
			occupied_positions[key] = true

	# Shuffle all potential doors for random distribution
	filtered_doors.shuffle()

	# Determine the number of doors based on player-selected percentage
	var num_doors = min((wall_bodies.size() * player_selected_door_percent) * 0.01, (wall_bodies.size() * MAX_DOOR_PERCENT) * 0.01)
	var chosen_doors = filtered_doors.slice(0, num_doors)

	# Ensure room exits always get doors
	chosen_doors.append_array(forced_doors)

	# Prevent adjacent doors in a straight line
	var final_doors = []
	var used_positions = {}
	for door in chosen_doors:
		key = "%s_%s_%s" % [door["pos"].x, door["pos"].y, door["rot"]]
		if key in used_positions:
			continue
		final_doors.append(door)
		used_positions[key] = true

	# Place the selected doors
	for door in final_doors:
		place_door(door["pos"], door["rot"])
# Ensure a wall has at least 2 supporting adjacent walls before being considered for a door

func has_sufficient_wall_support(cell_pos: Vector2i, wall_index: int) -> bool:
	var required_walls 
	
	match wall_index:
		0:  # Top wall
			required_walls = [
				[[cell_pos + Vector2i(-1, -1), 1],  # Top-left neighbor's right wall
				[cell_pos + Vector2i(-1, 0), 0],  # Left cell's top wall
				[cell_pos + Vector2i(-1, 0), 1]],  # Left cell's right wall

				[[cell_pos + Vector2i(1, -1), 3],  # Top-right neighbor's left wall
				[cell_pos + Vector2i(1, 0), 0],  # Right neighbor's top wall
				[cell_pos + Vector2i(1, 0), 3]]    # Right cell's left wall
			]
		1:  # Right wall
			required_walls = [
				[[cell_pos + Vector2i(1, -1), 2],  # Top-right neighbor's bottom wall
				[cell_pos + Vector2i(0, -1), 1],  # Top neighbor's right wall
				[cell_pos + Vector2i(0, -1), 2]], # Top neighbor's bottom wall

				[[cell_pos + Vector2i(1, 1), 0],  # Bottom-right neighbor's top wall
				[cell_pos + Vector2i(0, 1), 1],  # Bottom neighbor's right wall
				[cell_pos + Vector2i(0, 1), 0]]   # Bottom neighbor's top wall
			]
		2:  # Bottom wall
			required_walls = [
				[[cell_pos + Vector2i(-1, 1), 1],  # Bottom-left neighbor's right wall
				[cell_pos + Vector2i(-1, 0), 2],  # Left neighbor's bottom wall
				[cell_pos + Vector2i(-1, 0), 1]],  # Left neighbor's right wall

				[[cell_pos + Vector2i(1, 1), 3],  # Bottom-right neighbor's left wall
				[cell_pos + Vector2i(1, 0), 2],  # Right neighbor's bottom wall
				[cell_pos + Vector2i(1, 0), 3]]    # Right neighbor's left wall
			]
		3:  # Left wall
			required_walls = [
				[[cell_pos + Vector2i(-1, -1), 2], # Top-left neighbor's bottom wall
				[cell_pos + Vector2i(0, -1), 3],  # Top neighbor's left wall
				[cell_pos + Vector2i(0, -1), 2]],  # Top neighbor's bottom wall

				[[cell_pos + Vector2i(-1, 1), 0],  # Bottom-left neighbor's top wall
				[cell_pos + Vector2i(0, 1), 3],  # Bottom neighbor left wall
				[cell_pos + Vector2i(0, 1), 0]]    # Bottom neighbor's top wall
			]

	var supporting_walls = [false, false]
	
	for i in required_walls.size():
		for pos_wall in required_walls[i]:
			var pos = pos_wall[0]
			var wall_idx = pos_wall[1]
			if get_walls(pos)[wall_idx]:
				supporting_walls[i] = true
				break # Don't need this side anymore if we find a supporting wall

	# ✅ Only allow a door if at least one structural wall exists on **each** side.
	return supporting_walls.all(func(e): return e)

# Convert a wall into a door at a given position and direction
func place_door(pos: Vector2, rot: int):
	# Replace the wall with a door
	var new_door = preload("res://src/scenes/wall/door/door.tscn").instantiate()
	new_door.position = pos
	new_door.rotation_degrees = rot
	new_door.maze = self
	new_door.add_to_group("doors")
	#destroy wall if one is here
	for wall in wall_bodies:
		if wall is Door:
			continue
		if wall.position == pos and wall.rotation_degrees == rot:
			wall.queue_free()
	wall_bodies.append(new_door)
	add_child(new_door, true)

func has_valid_maze_connection(pos: Vector2i) -> bool:
	for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var neighbor = pos + offset
		if is_within_bounds(neighbor):
			if is_type(neighbor, "path") and get_cell(neighbor).get("visited", false):
				return true
	return false

func calculate_exit_count(room, pos):
	var min_exits = 2
	var max_exits = max(min_exits, get_room_perimeter(room.cells, pos).size() * 0.5)
	var area = room.cells.size()
	var base_exits = max(min_exits, round((area / 9)+1))
	return clamp(base_exits, min_exits, max_exits)

func get_room_perimeter(room_cells: Array, pos: Vector2i) -> Array:
	var perimeter_cells = []
	var room_positions = []
	for c in room_cells:
		room_positions.append(Vector2i(pos.x + c.x, pos.y + c.y))
	for cell in room_positions:
		for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var neighbor_pos = cell + offset
			if not neighbor_pos in room_positions:
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
func set_wall_state_between(pos1: Vector2i, pos2: Vector2i, state: bool):
	if not is_within_bounds(pos1) or not is_within_bounds(pos2):
		return
	var delta = pos2 - pos1
	if delta in wall_map:
		var walls_to_set = wall_map[delta]
		set_wall_state(pos1, walls_to_set[0], state)
		set_wall_state(pos2, walls_to_set[1], state)

func set_wall_state(pos: Vector2i, wall_index: int, state: bool):
	if is_within_bounds(pos):
		maze[pos.y][pos.x]["walls"][wall_index] = state

# Build rectangular collision shapes for each active wall
# Optimize collision shape generation to prevent redundant colliders
func build_walls():
	for y in range(ROWS):
		for x in range(COLS):
			var cell_pos = Vector2i(x, y)
			if not is_within_bounds(cell_pos):
				continue
			var base_pos = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			var walls = get_walls(cell_pos)
			
			var wall_definitions = [
				{ "wall": walls[0], "pos": base_pos, "rot": 0 },  # Top
				{ "wall": walls[1], "pos": base_pos + Vector2(CELL_SIZE, 0), "rot": 90 },  # Right
				{ "wall": walls[2], "pos": base_pos + Vector2(0, CELL_SIZE), "rot": 0 },  # Bottom
				{ "wall": walls[3], "pos": base_pos, "rot": 90 }  # Left
			]
			
			for w in wall_definitions:
				if w["wall"]:
					add_wall(w["pos"], w["rot"])

func add_wall(pos: Vector2, rot: int):
	var wall_instance = preload("res://src/scenes/wall/wall.tscn").instantiate()
	for wall in wall_bodies:
		if wall.position == pos and wall.rotation_degrees == rot:
			return #wall already exists at this location

	wall_instance.position = pos
	wall_instance.rotation_degrees = rot
	wall_instance.maze = self
	wall_instance.add_to_group("walls")
	wall_bodies.append(wall_instance)
	add_child(wall_instance, true)

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

func rebake_navigation():
	if not nav_region:
		push_error("❌ Missing navigation regions!")
		return

	nav_region.navigation_polygon.clear()

	# ✅ Get or create NavigationPolygon
	nav_poly = nav_region.navigation_polygon if nav_region.navigation_polygon else NavigationPolygon.new()

	## ✅ Set parsing parameters
	nav_poly.agent_radius = 14.5
	nav_poly.cell_size = 1.0
	nav_poly.baking_rect = Rect2(0, 0, COLS * CELL_SIZE, ROWS * CELL_SIZE)
	nav_poly.parsed_collision_mask = 1  # Matches walls/doors collision layer
	nav_poly.parsed_geometry_type = NavigationPolygon.ParsedGeometryType.PARSED_GEOMETRY_STATIC_COLLIDERS

	# ✅ Ensure NavigationRegion2D is active and assigned to the same NavigationMap
	var rid = nav_region.get_rid()
	NavigationServer2D.region_set_enabled(rid, true)
	NavigationServer2D.region_set_map(rid, get_world_2d().get_navigation_map())  # ✅ Assign both to the same map

	# ✅ Initialize & parse source geometry
	nav_source = NavigationMeshSourceGeometryData2D.new()

	callback_parsing = on_parsing_done
	callback_baking = on_baking_done

	NavigationServer2D.parse_source_geometry_data(nav_poly, nav_source, self, callback_parsing)

func on_parsing_done() -> void:
	# ✅ Add rooms only to room navigation source
	
	nav_source.add_traversable_outline(PackedVector2Array([
		Vector2(0, 0),
		Vector2(COLS * CELL_SIZE, 0),
		Vector2(COLS * CELL_SIZE, ROWS * CELL_SIZE),
		Vector2(0, ROWS * CELL_SIZE)
	]))
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, nav_source, callback_baking)

func on_baking_done() -> void:
	NavigationServer2D.region_set_navigation_polygon(nav_region.get_rid(), nav_poly)
	nav_region.navigation_polygon = nav_poly

func spawn_player():
	var exit_pos = get_exit_stairs_position()
	var spawn_pos = find_valid_spawn_position(exit_pos)
	player = preload("res://src/scenes/player/player.tscn").instantiate()
	player.position = Vector2(
		(spawn_pos.x + 0.5) * CELL_SIZE,
		(spawn_pos.y + 0.5) * CELL_SIZE
	) + Vector2(WALL_THICKNESS * 0.5, WALL_THICKNESS * 0.5)  # Offset to avoid edge clipping
	player.maze = self
	player.connect("level_completed", _on_player_level_completed)
	add_child(player)
	print("Player spawned at: ", spawn_pos)

func spawn_minotaur():
	if rooms.is_empty():
		return
	minotaur = preload("res://src/scenes/minotaur/minotaur.tscn").instantiate()
	var room_data = rooms[randi() % rooms.size()]
	var room = room_data["room"]
	var room_pos = room_data["position"]
	var spawn_cell = room.cells[randi() % room.cells.size()]
	var abs_spawn = Vector2i(room_pos.x + spawn_cell.x, room_pos.y + spawn_cell.y)
	minotaur.position = Vector2(
		abs_spawn.x * CELL_SIZE + (CELL_SIZE * 0.5),
		abs_spawn.y * CELL_SIZE + (CELL_SIZE * 0.5)
	)
	minotaur.maze = self
	add_child(minotaur)
	print("Minotaur spawned at: ", abs_spawn,)

func _draw():
	for y in range(ROWS):
		for x in range(COLS):
			var cell_pos = Vector2i(x, y)
			if not is_within_bounds(cell_pos):
				continue
			var base_pos = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			
			if is_type(cell_pos, "room"):
				draw_rect(Rect2(base_pos, Vector2(CELL_SIZE, CELL_SIZE)), Color(0, 0, 1, 0.1), true)
			if is_type(cell_pos, "exit_stairs"):
				draw_rect(Rect2(base_pos, Vector2(CELL_SIZE, CELL_SIZE)), Color(0, 1, 0, 0.2), true)

func _on_player_level_completed():
	generate_new_maze()
	#print("Maze: player is on exit.")

func generate_new_maze():
	free_old_walls()
	randomize()
	initialize_maze()
	place_rooms()
	generate_maze()
	connect_room_exits()
	place_exit_stairs()
	build_walls()
	place_doors()
	check_maze()
	await get_tree().process_frame
	rebake_navigation()
	queue_redraw()
	#start a timer for minotaur to show up
	if player:
		player.set_physics_process(true)
	stack.clear()

func free_old_walls():
	for wall in wall_bodies:
		if not wall == null:
			wall.queue_free()

func visit(pos: Vector2i):
	if is_within_bounds(pos):
		maze[pos.y][pos.x]["visited"] = true

func check_maze():
	var visit_check = 0
	for y in range(ROWS):
		for x in range(COLS):
			if maze[y][x]["visited"]:
				visit_check += 1
	if visit_check < (ROWS * COLS) * 0.5:
		print("Bad maze generation - redoing")
		generate_new_maze()

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
