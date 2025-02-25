extends ActionLeaf

func tick(actor: Node, blackboard: Blackboard) -> int:
	var maze = blackboard.get_value("maze")
	var agent = actor.get_node_or_null("NavigationAgent2D")
	var int_area = actor.get_node_or_null("InteractArea")
	if not agent:
		push_warning("Wander: No NavigationAgent2D on Minotaur!")
		return FAILURE

	# 1) Ensure target_pos exists
	if not blackboard.has_value("target_pos"):
		return FAILURE

	# 2) Assign the target_pos to the NavigationAgent if it isn't already
	if agent.target_position != blackboard.get_value("target_pos"):
		agent.target_position = blackboard.get_value("target_pos")

	# 3) Check if we reached the destination
	if agent.is_navigation_finished():
		blackboard.erase_value("target_pos")
		return SUCCESS

	# 4) Otherwise, still traveling
	var next_pos = agent.get_next_path_position()
	var direction = (next_pos - actor.position).normalized()
	if abs(wrapf((next_pos - actor.position).angle() - actor.rotation, -PI, PI)) > actor.rotation_threshold:
		var theta = wrapf(atan2(direction.y, direction.x) - actor.rotation, -PI, PI)
		actor.rotation += clamp(actor.rot_speed * get_physics_process_delta_time(), 0, abs(theta)) * sign(theta)
		return RUNNING
	actor.look_at(next_pos)
	agent.set_velocity(actor.position.direction_to(next_pos) * actor.move_speed)
	actor.velocity = agent.velocity
	actor.move_and_slide()
	var doors = int_area.get_overlapping_bodies()
	if doors.size() > 0:
		for area in int_area.get_overlapping_bodies():
			if area is Door:
				area.interact(actor)
				break
	
	return RUNNING

func interrupt(actor: Node, blackboard: Blackboard) -> void:
	blackboard.erase_value("target_pos")
