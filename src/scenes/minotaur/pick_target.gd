extends ActionLeaf

func tick(actor: Node, blackboard: Blackboard) -> int:
	var max_range := 6
	var maze = blackboard.get_value("maze")
	if not maze:
		return FAILURE

	# 1) Current tile from Minotaur
	var current_tile: Vector2i = actor.get_tile_position()

	# 2) Pick random offsets in [-max_range..+max_range]
	#    Repeat if both offsets are zero (we don't want (0,0) because that's our current tile)
	var offset_x = 0
	var offset_y = 0
	while true:
		offset_x = int(randi() % (max_range * 2) + 1) - max_range
		offset_y = int(randi() % (max_range * 2) + 1) - max_range
		if offset_x != 0 or offset_y != 0:
			break

	# 3) Compute target tile
	var target_tile = Vector2i(
		current_tile.x + offset_x,
		current_tile.y + offset_y
	)

	# 4) Clamp tile coordinates to Maze bounds
	target_tile.x = clamp(target_tile.x, 0, maze.COLS - 1)
	target_tile.y = clamp(target_tile.y, 0, maze.ROWS - 1)

	# 6) Convert tile -> world
	var target_pos = Vector2(target_tile.x * maze.CELL_SIZE + (maze.CELL_SIZE * 0.5), target_tile.y * maze.CELL_SIZE + (maze.CELL_SIZE * 0.5))
	blackboard.set_value("target_pos", target_pos)
	return SUCCESS
