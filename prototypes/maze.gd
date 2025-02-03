extends Node2D

# Maze parameters
const ROWS = 20
const COLS = 20
const CELL_SIZE = 32
const WALL_THICKNESS = 2

# The maze grid: a 2D array where each cell is a dictionary with visited flag and walls array
var maze = []
var stack = []

func _ready():
	randomize()  # Ensure different mazes each run
	generate_maze()
	build_collision_shapes()

func generate_maze():
	# Initialize the maze grid
	for i in range(ROWS):
		maze.append([])
		for j in range(COLS):
			maze[i].append({
				"visited": false,
				"walls": [true, true, true, true]  # Order: top, right, bottom, left
			})
	
	# Start at cell (0, 0)
	var current_cell = Vector2(0, 0)
	maze[0][0]["visited"] = true
	stack.push_back(current_cell)
	
	# Perform recursive backtracking
	while stack.size() > 0:
		current_cell = stack[stack.size() - 1]
		var i = int(current_cell.x)
		var j = int(current_cell.y)
		
		# Collect unvisited neighbors
		var neighbors = []
		if i > 0 and not maze[i - 1][j]["visited"]:
			neighbors.append(Vector2(i - 1, j))
		if i < ROWS - 1 and not maze[i + 1][j]["visited"]:
			neighbors.append(Vector2(i + 1, j))
		if j > 0 and not maze[i][j - 1]["visited"]:
			neighbors.append(Vector2(i, j - 1))
		if j < COLS - 1 and not maze[i][j + 1]["visited"]:
			neighbors.append(Vector2(i, j + 1))
		
		if neighbors.size() > 0:
			# Randomly choose one neighbor
			var next_cell = neighbors[randi() % neighbors.size()]
			remove_wall(current_cell, next_cell)
			maze[int(next_cell.x)][int(next_cell.y)]["visited"] = true
			stack.push_back(next_cell)
		else:
			stack.pop_back()

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
			# Calculate the top-left position of this cell
			var pos = Vector2(j * CELL_SIZE, i * CELL_SIZE)
			# Draw the top wall
			if cell["walls"][0]:
				draw_line(pos, pos + Vector2(CELL_SIZE, 0), Color.WHITE, WALL_THICKNESS)
			# Draw the right wall
			if cell["walls"][1]:
				draw_line(pos + Vector2(CELL_SIZE, 0), pos + Vector2(CELL_SIZE, CELL_SIZE), Color.WHITE, WALL_THICKNESS)
			# Draw the bottom wall
			if cell["walls"][2]:
				draw_line(pos + Vector2(CELL_SIZE, CELL_SIZE), pos + Vector2(0, CELL_SIZE), Color.WHITE, WALL_THICKNESS)
			# Draw the left wall
			if cell["walls"][3]:
				draw_line(pos + Vector2(0, CELL_SIZE), pos, Color.WHITE, WALL_THICKNESS)
