extends ActionLeaf

func tick(actor: Node, blackboard: Blackboard) -> int:
	var cell = blackboard.get_value("maze").CELL_SIZE
	var target_center = Vector2(actor.get_tile_position()) * Vector2(cell, cell) + Vector2(cell / 2, cell / 2)

	if actor.position.distance_to(target_center) <= actor.center_threshold: # If already close enough, snap into place
		actor.position = target_center
		blackboard.set_value("saw_player", false)
		blackboard.set_value("hit_wall", false)
		blackboard.set_value("has_recovered", true)
		blackboard.set_value("charge_direction", Vector2.ZERO)
		return SUCCESS

	var step_size = min((actor.move_speed * 0.5) * get_physics_process_delta_time(), actor.position.distance_to(target_center))
	actor.position = actor.position.move_toward(target_center, step_size)
	return RUNNING
