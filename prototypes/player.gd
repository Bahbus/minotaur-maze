extends CharacterBody2D

@export var maze: Node2D  # Assign this in the editor or dynamically in code
@export var move_speed := 100
var cell_size := 32  # Default, in case maze isn't assigned
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
	if maze:
		if maze.get_cell(get_tile_position()).get("type", "") == "exit_stairs":
			handle_level_completion()

func get_tile_position() -> Vector2i:
	return Vector2i(position.y / cell_size, position.x / cell_size)  # Swap x and y

func handle_level_completion():
	print("Level Complete!")  # Temporary win state
#	get_tree().change_scene_to_file("res://scenes/win_screen.tscn")  # Placeholder win screen
