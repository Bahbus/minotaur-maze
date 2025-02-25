class_name Search extends ActionLeaf

@export var min_rotation_deg := 30      # Minimum ± offset (degrees)
@export var max_rotation_deg := 160     # Maximum ± offset (degrees)

var target_angle_deg = 0.0
var is_turning = false
var interrupted = false

func tick(actor: Node, blackboard: Blackboard) -> int:
	if interrupted:
		interrupted = false
		return FAILURE
	if not is_turning:
		var offset = randf_range(min_rotation_deg, max_rotation_deg)
		if randi() % 2 == 0:
			offset = -offset
		target_angle_deg = fmod(actor.rotation_degrees + offset, 360.0)
		is_turning = true
	
	var diff = wrapf(target_angle_deg - actor.rotation_degrees, -180.0, 180.0)
	
	if abs(diff) <= actor.rotation_threshold:
		actor.rotation_degrees = target_angle_deg  # Snap final if you like
		is_turning = false
		return SUCCESS
	
	actor.rotation_degrees += clamp(rad_to_deg(actor.rot_speed) * get_physics_process_delta_time(), 0, abs(diff)) * sign(diff)
	return RUNNING

func interrupt(actor: Node, blackboard: Blackboard) -> void:
	interrupted = true
