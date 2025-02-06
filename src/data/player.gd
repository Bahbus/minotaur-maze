extends CharacterBody2D

class_name Player

@export var maze: Node2D  # Assign this in the editor or dynamically in code
@export var move_speed := 100
var move_direction := Vector2.ZERO

func _physics_process(_delta):
	move_direction = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	).normalized()
	velocity = move_direction * move_speed
	move_and_slide()
	check_exit_condition()

func check_exit_condition():
	if maze:  # Ensure we have a reference to the maze
		var tile_type = maze.get_cell(get_tile_position()).get("type", "")
#		print("Player is at: ", get_tile_position(), " | Tile type: ", tile_type)  # Debugging
		if tile_type == "exit_stairs":  # Direct comparison to ensure it's working
			handle_level_completion()

func get_tile_position() -> Vector2i:
	return Vector2i(floor(position.y / maze.CELL_SIZE), floor(position.x / maze.CELL_SIZE))  # Swap x and y

func handle_level_completion():
	print("Level Complete!")  # Temporary win state
#	get_tree().change_scene_to_file("res://scenes/win_screen.tscn")  # Placeholder win screen
