extends CharacterBody2D

class_name Player

@export var maze: Node2D
@export var move_speed := 100
var move_direction := Vector2.ZERO

func _physics_process(delta):
	move_direction = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	).normalized()
	velocity = move_direction * move_speed
	move_and_slide()
	check_exit_condition()

func check_exit_condition():
	if maze:
		var tile_data = maze.get_cell(get_tile_position())
		var tile_type = tile_data.get("type", "")
		if tile_type == "exit_stairs":
			handle_level_completion()

func get_tile_position() -> Vector2i:
	# tile.x = floor(position.x / CELL_SIZE) => the column
	# tile.y = floor(position.y / CELL_SIZE) => the row
	var tile_x = int(floor(position.x / maze.CELL_SIZE))
	var tile_y = int(floor(position.y / maze.CELL_SIZE))
	return Vector2i(tile_x, tile_y)

func handle_level_completion():
	print("Level Complete!")
	# get_tree().change_scene_to_file("res://scenes/win_screen.tscn")
