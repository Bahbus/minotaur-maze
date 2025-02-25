extends ConditionLeaf

func tick(actor: Node, blackboard: Blackboard) -> int:
	return SUCCESS if blackboard.get_value("hit_wall") else FAILURE
