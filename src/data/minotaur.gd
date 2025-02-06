extends CharacterBody2D

class_name Minotaur

@export var move_speed: int = 40
@export var charge_speed: int = 120
@export var stun_duration: float = 1.5
@export var maze: Node2D  # Assign dynamically in code

enum State { IDLE, SEARCHING, CHARGING, WANDERING, STUNNED }
var current_state = State.IDLE
var direction: Vector2i = Vector2i.ZERO
var last_known_player_pos: Vector2i = Vector2i(-1, -1)
var target_tile: Vector2i = Vector2i(-1, -1)  

var stun_timer = 0.0
var last_tile: Vector2i = Vector2i(-1, -1)  

func _ready():
	$VisionArea.connect("body_entered", Callable(self, "_on_vision_area_body_entered"))

func _on_vision_area_body_entered(body):
	if body is Player:
		if has_direct_line_of_sight(body.position):
			print("🔴 Player detected! CHARGE!")
			last_known_player_pos = maze.player.get_tile_position()
			current_state = State.CHARGING

func has_direct_line_of_sight(target_position: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(position, target_position, 1)
	var result = space_state.intersect_ray(query)
	if result:
		return result.collider is Player  # ✅ Only return true if it directly hits the player
	return false

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
	if not is_fully_inside_tile():
		print("Cannot charge, still aligning...")
		return  # Ensure Minotaur aligns with the grid before continuing

	if last_known_player_pos == Vector2i(-1, -1):
		print("Lost track of player, switching to wandering.")
		reset_state()
		current_state = State.WANDERING
		return

	var minotaur_tile = get_tile_position()
	var move_vector = last_known_player_pos - minotaur_tile
	var collision
	
	if move_vector.length() > 0:
		# Ensure movement is possible
		direction = move_vector.sign()  
		target_tile = minotaur_tile + direction

		# 🚀 **Allow charging even if diagonal**
		if not maze.is_within_bounds(target_tile):
			print("Charge target out of bounds! Switching to wandering.")
			reset_state()
			current_state = State.WANDERING
			return
		# ✅ **Set velocity here, not in `set_target_position()`**
		velocity = Vector2(direction.y, direction.x).normalized() * charge_speed
		collision = move_and_slide()
		if collision:
				if collision.get_collider() is Player: #Captured player
					print("~~~~~~Player caught~~~~~~")
				else: #probably a wall
					print("Minotaur stunned!")
					reset_state()
					current_state = State.STUNNED
					stun_timer = stun_duration
					velocity = Vector2.ZERO
	else:
		print("Charge move vector invalid! Switching to wandering.")
		reset_state()
		current_state = State.WANDERING  

	

### **🚧 Check for Wall Collisions**
func is_colliding_with_wall(target: Vector2i) -> bool:
	return maze.has_wall_between(get_tile_position(), target)

### **⏳ Handle Stun & Recovery**
func handle_stun(delta):
	stun_timer -= delta
	if stun_timer <= 0:
		print("Minotaur recovered from stun!")
		current_state = State.WANDERING

### **🚶‍♂️ Wandering Movement (Smooth Tile-Based Movement)**
func wander(delta):
	# 🚨 Safety check: Don't move to (-1, -1)
	if target_tile == Vector2i(-1, -1):
		#print("Invalid wander target, recalculating...")
		pick_new_wander_target()
		return  
	# ✅ **Ensure the Minotaur’s entire body is inside the tile before switching directions**
	if not is_fully_inside_tile():
		#print("Minotaur still aligning with tile.")
		move_and_slide()
		return
	search_for_player()
	# Pick a new move when the previous target is reached, if we are still wandering
	if current_state == State.WANDERING:
		pick_new_wander_target()

### **🎯 Pick a New Wander Target**
### **🎯 Pick a New Wander Target**
func pick_new_wander_target():
	var possible_moves = []
	var current_tile = get_tile_position()
	print("Minotaur at:", current_tile, " | Facing:", direction)

	# ✅ Try moving forward, left, or right first
	var move_directions = [
		direction,  # Forward
		Vector2i(-direction.y, direction.x),  # Left turn
		Vector2i(direction.y, -direction.x)   # Right turn
	]

	for move_dir in move_directions:
		var new_tile = current_tile + move_dir
		if maze.is_within_bounds(new_tile) and not is_colliding_with_wall(new_tile) and new_tile != last_tile:
			possible_moves.append(new_tile)

	# ✅ If possible moves exist, pick one
	if possible_moves.size() > 0:
		target_tile = possible_moves[randi() % possible_moves.size()]
		last_tile = current_tile

		# ✅ Update Minotaur's facing direction to match the move
		direction = (target_tile - current_tile).sign()

		#print("New wander target:", target_tile, " | Now facing:", direction)

		# ✅ Rotate Minotaur to face movement direction
		if direction != Vector2i.ZERO:
			rotation = Vector2(direction.x, direction.y).angle()
			$VisionArea.rotation = Vector2(direction.x, direction.y).angle()

		set_target_position(target_tile)
		velocity = Vector2(direction.y, direction.x) * move_speed
		move_and_slide()
		return  # ✅ Stop checking once a move is found

	# 🚨 **Stuck! Randomly rotate left or right**
	#print("Minotaur stuck! Rotating...")
	velocity = Vector2.ZERO  # Stop movement while rotating
	last_tile = current_tile
	var turn_options = [Vector2i(-direction.y, direction.x), Vector2i(direction.y, -direction.x)]
	direction = turn_options[randi() % turn_options.size()]

	# ✅ Ensure `direction` is always valid
	if direction == Vector2i.ZERO:
		direction = Vector2i(1, 0)  # Default facing right if lost

	# ✅ Rotate Minotaur to face new direction
	rotation = Vector2(direction.x, direction.y).angle()
	$VisionArea.rotation = Vector2(direction.x, direction.y).angle()
	#print("New facing direction after rotation:", direction)

### **📍 Convert Position to Grid Tile (Row, Col)**
func get_tile_position() -> Vector2i:
	# ✅ **Ensure row (y) maps correctly to rows, col (x) maps to columns**
	return Vector2i(floor(position.y / maze.CELL_SIZE), floor(position.x / maze.CELL_SIZE))

### **🛑 Check if Minotaur Reached the Target Tile**
func has_reached_target() -> bool:
	var current_tile = get_tile_position()
	#print("Minotaur at ", current_tile, ", trying to reach ", target_tile)
	return current_tile == target_tile

func set_target_position(tile: Vector2i):
	# 🚨 Safety check: Ensure we're not moving to (-1, -1)
	if tile == Vector2i(-1, -1):
		#print("Invalid target position detected, recalculating...")
		pick_new_wander_target()
		return
	
	# ✅ Ensure direction is updated properly
	direction = (tile - get_tile_position()).sign()
	
	# ✅ Rotate Minotaur to face movement direction
	if direction != Vector2i.ZERO:
		rotation = Vector2(direction.x, direction.y).angle()
	
	# ✅ Ensure correct target positioning
	var target_pos = Vector2(
		(tile.y * maze.CELL_SIZE) + (maze.CELL_SIZE / 2),  # Column → X
		(tile.x * maze.CELL_SIZE) + (maze.CELL_SIZE / 2)   # Row → Y
	)

func reset_state():
	target_tile = Vector2i(-1, -1)
	velocity = Vector2.ZERO

func is_fully_inside_tile() -> bool:
	var current_tile = get_tile_position()
	var cell_center = Vector2(
		(current_tile.y * maze.CELL_SIZE) + (maze.CELL_SIZE / 2),  
		(current_tile.x * maze.CELL_SIZE) + (maze.CELL_SIZE / 2)  
	)
	# ✅ Use `position` correctly for Minotaur’s center
	var minotaur_center = position
	# ✅ Allow for small floating point errors
	return minotaur_center.distance_to(cell_center) <= 1.0
