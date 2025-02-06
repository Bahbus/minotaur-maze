extends CharacterBody2D

class_name Minotaur

@export var move_speed: int = 40
@export var charge_speed: int = 120
@export var stun_duration: float = 1.5
@export var maze: Node2D  # Assign dynamically in code

enum State { IDLE, SEARCHING, CHARGING, WANDERING, STUNNED }
var current_state = State.IDLE
var direction: Vector2i = Vector2i(-1,0)
var last_known_player_pos: Vector2i = Vector2i(-1, -1)
var target_tile: Vector2i = Vector2i(-1, -1)  

var stun_timer = 0.0
var last_tile: Vector2i = Vector2i(-1, -1)  

func _ready():
	$VisionArea.body_entered.connect(_on_VisionArea_body_entered)

func _on_VisionArea_body_entered(body):
	if body is Player:
		print("Player in area...")
		if has_direct_line_of_sight(body.position):
			print("🔴 Player detected! CHARGE!")
			last_known_player_pos = maze.player.get_tile_position()
			current_state = State.CHARGING

func has_direct_line_of_sight(target_position: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(position, target_position)
	query.collide_with_areas = true  # Ensure it can hit areas (e.g., VisionArea)
	query.collide_with_bodies = true  # Ensure it can hit bodies (e.g., Player)
	query.exclude = [self]  # Exclude the Minotaur itself
	var result = space_state.intersect_ray(query)
	# Debugging Output
	if result:
		print("Ray hit something:", result.collider)
		return result.collider is Player  # ✅ Only return true if it directly hits the player
	else:
		print("Ray missed!")
		return false

func _process(delta):
	update_vision()

func _physics_process(delta):
	match current_state:
		State.IDLE:
			check_for_player_entry()
		State.SEARCHING:
			search_for_player()
		State.CHARGING:
			charge_at_player(delta)
		State.WANDERING:
			wander(delta)
		State.STUNNED:
			handle_stun(delta)
			

### **🏛 Activate Minotaur When Player Enters Room**
func check_for_player_entry():
	var player_tile = maze.player.get_tile_position()
	var player_room = maze.get_room_at(player_tile)
	var minotaur_room = maze.get_room_at(get_tile_position())

	if player_room != null and player_room == minotaur_room:
		print("Minotaur Activated!")
		last_known_player_pos = player_tile
		current_state = State.SEARCHING

### **🔍 Search for Player (Use Raycasting)**
func search_for_player():
	if false: #eventually convert this if to handle sound based searching
		print("Shouldn't see this...")#do nothing for now
	else:
		print("No sight, wandering instead.")
		current_state = State.WANDERING

### **⚡ Charge at Player (Smooth Tile-Based Movement)**
func charge_at_player(delta):
	# Ensure Minotaur keeps charging in the same direction
	if direction == Vector2i.ZERO:
		print("Charge direction was zero, something went wrong!")
		reset_state()
		current_state = State.WANDERING
		return

	# Maintain charge velocity in the same direction
	velocity = Vector2(direction.y, direction.x).normalized() * charge_speed
	move_and_slide()

	# ✅ **Check for collisions**
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision:
			var collider = collision.get_collider()
			if collider is Player:
				print("~~~~~~Player caught~~~~~~")
				# TODO: Handle game over or player hit logic
			else:
				print("Minotaur stunned!")
				reset_state()
				current_state = State.STUNNED
				stun_timer = stun_duration
				return  # Stop further checks after collision

### **🚧 Check for Wall Collisions**
func is_colliding_with_wall(target: Vector2i) -> bool:
	return maze.has_wall_between(get_tile_position(), target)

### **⏳ Handle Stun & Recovery**
func handle_stun(delta):
	stun_timer -= delta
	if stun_timer <= 0:
		print("Minotaur recovered from stun! Recentering...")

		# ✅ Smoothly recenter before resuming movement
		if is_at_target_tile(true):
			reset_state()
			pick_new_wander_target()
			current_state = State.WANDERING

### **🚶‍♂️ Wandering Movement (Smooth Tile-Based Movement)**
func wander(delta):
	# ✅ If the Minotaur already has a target tile, move toward it
	if target_tile != Vector2i(-1, -1):
		if not is_at_target_tile():
			move_and_slide()
			return  # ✅ Keep moving, don't pick a new target
		else:
			# ✅ If the Minotaur reached the target, reset it
			target_tile = Vector2i(-1, -1)

	# ✅ If no valid target exists, pick a new wander destination
	pick_new_wander_target()

### **🎯 Pick a New Wander Target**
func pick_new_wander_target():
	var possible_moves = []
	var current_tile = get_tile_position()

	print("Minotaur at:", current_tile, " | Facing:", direction)

	# ✅ Strictly consider only forward, left, and right
	var move_directions = [
		direction,  # Forward
		Vector2i(direction.y, -direction.x),  # Left turn (-90°)
		Vector2i(-direction.y, direction.x)   # Right turn (+90°)
	]

	for move_dir in move_directions:
		var new_tile = current_tile + move_dir
		if maze.is_within_bounds(new_tile) and not is_colliding_with_wall(new_tile) and new_tile != last_tile:
			possible_moves.append(new_tile)

	# ✅ If valid moves exist, pick one at random
	if possible_moves.size() > 0:
		print("Possible moves ", possible_moves)
		target_tile = possible_moves[randi() % possible_moves.size()]
		last_tile = current_tile

		# ✅ Update Minotaur's facing direction to match the move
		direction = (target_tile - current_tile).sign()
		print("New wander target:", target_tile, " | Now facing:", direction)

		set_target_position(target_tile)
		velocity = Vector2(direction.y, direction.x) * move_speed
		move_and_slide()
		return  # ✅ Stop checking once a move is found

	# 🚨 **If stuck, rotate 90 degrees left or right**
	print("Minotaur stuck! Rotating...")

	velocity = Vector2.ZERO  # Stop movement before rotating
	last_tile = current_tile

	# ✅ Choose a random 90-degree turn (left or right)
	var turn_options = [Vector2i(-direction.y, direction.x), Vector2i(direction.y, -direction.x)]
	direction = turn_options[randi() % turn_options.size()]

### **📍 Convert Position to Grid Tile (Row, Col)**
func get_tile_position() -> Vector2i:
	# ✅ **Ensure row (y) maps correctly to rows, col (x) maps to columns**
	return Vector2i(floor(position.y / maze.CELL_SIZE), floor(position.x / maze.CELL_SIZE))

func set_target_position(tile: Vector2i):
	# 🚨 Safety check: Ensure we're not moving to (-1, -1)
	if tile == Vector2i(-1, -1):
		#print("Invalid target position detected, recalculating...")
		pick_new_wander_target()
		return
	
	# ✅ Ensure direction is updated properly
	direction = (tile - get_tile_position()).sign()
	
	# ✅ Ensure correct target positioning
	var target_pos = Vector2(
		(tile.y * maze.CELL_SIZE) + (maze.CELL_SIZE / 2),  # Column → X
		(tile.x * maze.CELL_SIZE) + (maze.CELL_SIZE / 2)   # Row → Y
	)

func reset_state():
	target_tile = Vector2i(-1, -1)
	velocity = Vector2.ZERO

func is_at_target_tile(recenter: bool = false) -> bool:
	var current_tile = get_tile_position()
	var target_position = Vector2(
		(current_tile.y * maze.CELL_SIZE) + (maze.CELL_SIZE / 2),
		(current_tile.x * maze.CELL_SIZE) + (maze.CELL_SIZE / 2)
	)

	# ✅ If close enough to the tile center, consider it "inside"
	if position.distance_to(target_position) <= 0.2:
		position = target_position  # Final snap if close enough
		velocity = Vector2.ZERO
		return true  # ✅ Successfully centered

	# 🚀 If recentering is enabled, smoothly adjust position
	if recenter:
		var move_vector = (target_position - position).normalized()
		var recenter_speed = move_speed / 2  # Adjust speed if needed
		velocity = move_vector * recenter_speed
		move_and_slide()

	return false  # ❌ Still aligning

func update_vision():
	if direction != Vector2i.ZERO:
		rotation = Vector2(-direction.x, direction.y).angle()
