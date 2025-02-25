extends ActionLeaf

func tick(actor: Node, blackboard: Blackboard) -> int:
	if blackboard.get_value("hunt_cooldown_on_start"):
		blackboard.set_value("hunt_cooldown_on_start", false)
		return FAILURE
	blackboard.set_value("hunt_target", blackboard.get_value("maze").player.position)
	return SUCCESS
