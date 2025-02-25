extends CharacterBody2D

class_name Minotaur

# Movement and state-related properties
@export var move_speed: int = 40  # Speed while wandering or searching
@export var charge_speed: int = 100  # Speed when charging at the player
@export var stun_duration: float = 1.5  # Duration of stun state in seconds
@export var maze: Node2D # Reference to the maze
@export var rot_speed: float = TAU

# Node references
@onready var vision:= $Vision  # Vision detection node
@onready var half_cell:= Vector2(maze.CELL_SIZE * 0.5, maze.CELL_SIZE * 0.5)
@onready var wall_offset:= Vector2(maze.WALL_THICKNESS * 0.5, maze.WALL_THICKNESS * 0.5)
@onready var player: Node2D = maze.player  # Reference to the player
@onready var wander_timer:= $Timer
@onready var bb := $Blackboard
@onready var tree := $BeehaveTree

# Minotaur state management
enum State { IDLE, SEARCHING, CHARGING, WANDERING, STUNNED, ROTATING }
var current_state: int = State.IDLE  # Default starting state
var previous_state: int = -1  # Stores the previous state before rotating

# Movement and rotation tracking
var charge_direction: Vector2 = Vector2.ZERO  # Direction when charging
#var direction: Vector2 = Vector2.RIGHT  # Default direction the Minotaur faces
var last_known_player_pos: Vector2 = Vector2(-1, -1)  # Last seen position of the player
var target_tile: Vector2i = Vector2i(-1, -1)  # Tile the Minotaur is moving towards
var last_tile: Vector2i = Vector2i(-1, -1)  # Stores last tile to avoid backtracking
var stun_timer: float = 0.0  # Timer for stun duration
var rotation_speed: float = 5.0
var rotation_threshold: float = 0.05  # Allowed deviation before snapping rotation
var center_threshold: float = 0.25 # Allowed distance before snapping
var target_rotation: float = 0.0  # Desired rotation angle

func _ready():
	if not vision:
		push_error("❌ ERROR: Vision node not found!")
		set_physics_process(false)  # Disable physics processing if vision is missing

	bb.set_value("maze", maze)
	bb.set_value("player", player)
	bb.set_value("vision", vision)


func _physics_process(delta):
	# Handle state-based behavior
	#match current_state:
		#State.IDLE:
			#check_for_player_entry()
			#return
		#State.SEARCHING:
			#search_for_player()
		#State.CHARGING:
			#charge_at_player()
		#State.WANDERING:
			#wander()
		#State.STUNNED:
			#handle_stun(delta)
		#State.ROTATING:
			#rotate_toward_target(delta)
			#return
#
	#move_and_slide()
	if current_state == State.CHARGING:
		check_collisions()

# Switches state to charging when player enters vision range
func _on_vision_body_entered(body: Node2D) -> void:
	if current_state in [State.IDLE, State.STUNNED, State.CHARGING]: #Ignore vision in these states
		return
	if body is Player:
		if last_known_player_pos != body.position:
			last_known_player_pos = body.position
		#set_state(State.CHARGING)

#func _on_wander_timer_timeout():
	#pick_new_wander_target()  # Pick a new target when timer expires

# Handles gradual rotation toward a target direction
func rotate_toward_target(delta):
	rotation = normalize_angle(lerp_angle(rotation, target_rotation, rotation_speed * delta))
	if is_facing_target():
		rotation = target_rotation  # Snap rotation once close
		set_state(previous_state if previous_state != -1 else State.SEARCHING)
		previous_state = -1

# Checks if the player enters the same room as the Minotaur
func check_for_player_entry():
	if maze.get_room_at(player.get_tile_position()) == maze.get_room_at(get_tile_position()):
		set_state(State.SEARCHING)

# Handles searching state when the Minotaur loses sight of the player
func search_for_player():
	set_state(State.WANDERING)

# Handles charging behavior towards last known player position
#func charge_at_player():
	#if charge_direction == Vector2.ZERO and last_known_player_pos != Vector2(-1, -1):
		#charge_direction = (last_known_player_pos - position).normalized()
		#update_direction(charge_direction)
		#return
#
	#if current_state == State.ROTATING:
		#return
#
	#if charge_direction == Vector2.ZERO:
		#reset_state()
		#set_state(State.WANDERING)
		#return
#
	#velocity = charge_direction * charge_speed

# Handles stun state, reducing timer until recovery
func handle_stun(delta):
	stun_timer -= delta
	if stun_timer <= 0 and is_at_target_tile(true):
		set_state(State.SEARCHING)

# Handles wandering behavior when searching for the player
func wander():
	if wander_timer.time_left >= 0 and not wander_timer.is_stopped():
		return  # Wait until the timer expires before picking a new direction
	wander_timer.start()

# Selects a new random valid tile to move towards
#func pick_new_wander_target():
	#var space_state = get_world_2d().direct_space_state
	##var directions = [direction, direction.rotated(PI / 2), direction.rotated(-PI / 2)]
	##directions.shuffle()
#
	##for dir in directions:
		#var ray_end = position + dir * (maze.CELL_SIZE * 0.6)
		#var query = PhysicsRayQueryParameters2D.create(position, ray_end)
		#query.exclude = [self]
		#var result = space_state.intersect_ray(query)
		#if result.get("collider") is Door:
			#result.get("collider").interact(self)
			#velocity = dir * move_speed
			#update_direction(dir)
			#return
		#if not result:
			#velocity = dir * move_speed
			#update_direction(dir)
			#return
#
	#velocity = Vector2.ZERO
	##update_direction([Vector2i(-direction.y, direction.x), Vector2i(direction.y, -direction.x)].pick_random())

# Updates direction and handles rotation state
#func update_direction(new_direction: Vector2):
	#if new_direction == Vector2.ZERO:
		#return
#
	#direction = new_direction.normalized()
	#target_rotation = normalize_angle(direction.angle())
#
	#if current_state == State.ROTATING:
		#return
#
	#if not is_facing_target():
		#previous_state = current_state if current_state != State.ROTATING else previous_state
		#set_state(State.ROTATING)
	#else:
		#rotation = target_rotation

# Checks for collisions while charging
func check_collisions():
	for i in range(get_slide_collision_count()):
		var coll = get_slide_collision(i)
		if coll:
			var collider = coll.get_collider()
			if collider is Player:
				print("~~~~~~Player caught~~~~~~")
				set_state(State.IDLE)
			else:
				reset_state()
				set_state(State.STUNNED)
				stun_timer = stun_duration

# Normalizes an angle to be within [0, TAU]
func normalize_angle(angle: float) -> float:
	angle = fmod(angle, TAU)
	return angle + TAU if angle < 0 else angle

# Gets the Minotaur's current tile position
func get_tile_position() -> Vector2i:
	return Vector2i(int(position.x / maze.CELL_SIZE), int(position.y / maze.CELL_SIZE))

# Resets all movement-related state variables
func reset_state():
	last_known_player_pos = Vector2i(-1, -1)
	target_tile = Vector2i(-1, -1)
	charge_direction = Vector2.ZERO
	velocity = Vector2.ZERO
	set_state(State.SEARCHING)

# Updates the Minotaur's state
func set_state(new_state: int):
	if current_state == State.ROTATING and new_state != State.ROTATING and not is_facing_target():
		previous_state = new_state if previous_state != new_state else previous_state
		return

	if current_state != new_state:
		current_state = new_state

# Ensures accurate angle wrapping
func rotation_difference(a: float, b: float) -> float:
	var diff = fmod(normalize_angle(b) - normalize_angle(a), TAU)  # Get the shortest distance
	if diff > PI:
		diff -= TAU  # Wrap negative if over half a turn
	elif diff < -PI:
		diff += TAU  # Wrap positive if over half a turn
	return diff

# Checks if the Minotaur is facing its target
func is_facing_target() -> bool:
	return abs(rotation_difference(rotation, target_rotation)) <= rotation_threshold

# Checks if the Minotaur is colliding with a wall
func is_colliding_with_wall(target: Vector2i) -> bool:
	return maze.has_wall_between(get_tile_position(), target)

# Checks if the Minotaur is at its target tile
func is_at_target_tile(recenter: bool = false) -> bool:
	var current_tile = get_tile_position()
	var target_center = (Vector2(target_tile if target_tile != Vector2i(-1, -1) else current_tile) * maze.CELL_SIZE) + half_cell + wall_offset
	if position.distance_to(target_center) <= center_threshold: # If already close enough, snap into place
		position = target_center
		return true

	if recenter: # Move toward the target center at a constant speed
		var step_size = min((move_speed * 0.5) * get_physics_process_delta_time(), position.distance_to(target_center))
		position = position.move_toward(target_center, step_size)
		#update_direction(direction.lerp(direction.sign(), step_size))

	return false
