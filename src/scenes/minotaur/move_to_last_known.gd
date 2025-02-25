extends ActionLeaf

func tick(actor: Node, blackboard: Blackboard) -> int:
	var agent = actor.get_node_or_null("NavigationAgent2D")
	var int_area = actor.get_node_or_null("InteractArea")
	var hunt_target
	if blackboard.has_value("hunt_target"):
		hunt_target = blackboard.get_value("hunt_target")
	else:
		return FAILURE
	
	if agent.target_position != hunt_target:
		agent.target_position = hunt_target
	
	if agent.is_navigation_finished():
		return SUCCESS
	
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
	blackboard.erase_value("hunt_target")
