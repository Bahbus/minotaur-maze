extends ActionLeaf

func tick(actor: Node, blackboard: Blackboard) -> int:
	var maze = blackboard.get_value("maze")
	var player = blackboard.get_value("player")
	if maze.get_room_at(player.get_tile_position()) == maze.get_room_at(actor.get_tile_position()):
		blackboard.set_value("is_active", true)
		return SUCCESS
	return FAILURE
