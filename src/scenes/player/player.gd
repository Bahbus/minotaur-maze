extends CharacterBody2D

class_name Player

@export var maze: Node2D
@export var move_speed := 80

@onready var int_area: Area2D = $InteractArea

var move_direction := Vector2.ZERO
var center_threshold: float = 0.25 # Allowed distance before snapping
var last_tile_pos := Vector2i(-1, -1)  # Store last tile position
signal level_completed  # Define a signal

func _process(_delta):
	if Input.is_action_just_pressed("interact"):
		var door = get_nearby_door()
		if door:
			door.interact(self)

func _physics_process(_delta):
	move_direction = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	# Normalize only if there's movement
	if not move_direction.is_zero_approx():
		move_direction = move_direction.normalized()

	velocity = move_direction * move_speed
	move_and_slide()
	check_exit_condition()

func get_nearby_door() -> Door:
	for area in int_area.get_overlapping_bodies():
		if area is Door:
			return area
	return null
	
func check_exit_condition():
	if not maze:
		return
	
	var tile_pos = get_tile_position()
	if tile_pos == last_tile_pos:  
		# Ensure we still check in case tile type changed dynamically
		if maze.get_cell(tile_pos).get("type", "") != "exit_stairs":
			return
	
	last_tile_pos = tile_pos
	
	if not maze.is_within_bounds(tile_pos):
		return
	
	var tile_data = maze.get_cell(tile_pos)
	if tile_data.get("type", "") == "exit_stairs":
		handle_level_completion()

func get_tile_position() -> Vector2i:
	return Vector2i(int(position.x / maze.CELL_SIZE), int(position.y / maze.CELL_SIZE))
	
func recenter():
	var current_tile = get_tile_position()
	var target_center = (Vector2(current_tile) * maze.CELL_SIZE) + Vector2(maze.CELL_SIZE * 0.5, maze.CELL_SIZE * 0.5) + Vector2(maze.WALL_THICKNESS * 0.5, maze.WALL_THICKNESS * 0.5)
	var step_size = min(get_physics_process_delta_time(), position.distance_to(target_center))
	while position.distance_to(target_center) > center_threshold: # If already close enough, snap into place
		position = position.move_toward(target_center, step_size)
	position = target_center

func handle_level_completion():
	recenter()
	set_physics_process(false)
	level_completed.emit()  # Emit a signal instead
