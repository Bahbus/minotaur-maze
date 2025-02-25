class_name Charge extends ActionLeaf

func tick(actor: Node, blackboard: Blackboard) -> int:
	if blackboard.get_value("has_recovered"):
		blackboard.set_value("has_recovered", false)
		return SUCCESS
	if blackboard.get_value("charge_direction") == Vector2.ZERO:
		return FAILURE
	if blackboard.get_value("hit_wall", true):
		return RUNNING

	var direction = blackboard.get_value("charge_direction")
	if abs(wrapf(direction.angle() - actor.rotation, -PI, PI)) > actor.rotation_threshold:
		var theta = wrapf(atan2(direction.y, direction.x) - actor.rotation, -PI, PI)
		actor.rotation += clamp(actor.rot_speed * get_physics_process_delta_time(), 0, abs(theta)) * sign(theta)
		return RUNNING
	actor.look_at(actor.position + direction)
	actor.velocity = direction * actor.charge_speed
	actor.move_and_slide()

	if actor.get_last_slide_collision() != null:
		if actor.get_last_slide_collision().get_collider() is Wall:
			blackboard.set_value("hit_wall", true)

	return RUNNING

func interrupt(actor, blackboard) -> void:
	blackboard.set_value("charge_direction", Vector2.ZERO)
