class_name SawPlayer extends ConditionLeaf

## Checks if the Player is overalapping with Minotaur's vision.

func tick(actor: Node, blackboard: Blackboard) -> int:
	if blackboard.get_value("saw_player"):
		actor.tree.interrupt()
		return SUCCESS
	var bodies = actor.vision.get_overlapping_bodies()
	for body in bodies:
		if body is Player:
			blackboard.set_value("saw_player", true)
			blackboard.set_value("charge_direction", (body.global_position - actor.position).normalized())
			return SUCCESS
	return FAILURE
