extends CharacterBody2D

class_name Minotaur

@onready var vision_collision = $Vision/CollisionPolygon2D

@export var move_speed: int = 40
@export var charge_speed: int = 120
@export var stun_duration: float = 1.5
@export var maze: Node2D

enum State { IDLE, SEARCHING, CHARGING, WANDERING, STUNNED }
var current_state = State.IDLE

# direction.x < 0 => left, direction.x > 0 => right
# direction.y < 0 => up,   direction.y > 0 => down
var direction: Vector2i = Vector2i(1, 0)

var last_known_player_pos: Vector2i = Vector2i(-1, -1)
var target_tile: Vector2i = Vector2i(-1, -1)
var stun_timer = 0.0
var last_tile: Vector2i = Vector2i(-1, -1)

func _ready():
	var vision = $Vision
	if vision:
		vision.body_entered.connect(_on_vision_body_entered)
	else:
		print("❌ ERROR: Vision node not found!")

func _on_vision_body_entered(body):
	if current_state == State.IDLE:
		return
	if body is Player:
		#print("⚡ Minotaur sees the player!")
		last_known_player_pos = maze.player.get_tile_position()
		current_state = State.CHARGING

func _process(delta):
	var player = maze.player
	if not player:
		return

	# 🔍 Hybrid check: Does the Player's collision bounds touch Vision's collision bounds?
	if check_vision_collision_with_player(player):
		last_known_player_pos = maze.player.get_tile_position()
		current_state = State.CHARGING
	update_rotation()

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

func check_vision_collision_with_player(player: Node2D) -> bool:
	if not player or not $Vision:
		return false
	if current_state == State.IDLE:
		return false
	# Direct overlap check
	if $Vision.is_touching_player():
		return true

	return false

func check_for_player_entry():
	var p_tile = maze.player.get_tile_position()
	var player_room = maze.get_room_at(p_tile)
	var mino_room = maze.get_room_at(get_tile_position())
	if player_room != null and player_room == mino_room:
		print("Minotaur Activated!")
		last_known_player_pos = p_tile
		current_state = State.SEARCHING

func search_for_player():
	print("No sight, switching to wander.")
	current_state = State.WANDERING

func charge_at_player(delta):
	if direction == Vector2i.ZERO:
		print("Charge direction zero, something went wrong!")
		reset_state()
		current_state = State.WANDERING
		return

	# Move in 'direction' at charge_speed
	velocity = Vector2(direction).normalized() * charge_speed
	move_and_slide()

	# Check collisions
	for i in range(get_slide_collision_count()):
		var coll = get_slide_collision(i)
		if coll:
			var collider = coll.get_collider()
			if collider is Player:
				print("~~~~~~Player caught~~~~~~")
			else:
				print("Minotaur stunned!")
				reset_state()
				current_state = State.STUNNED
				stun_timer = stun_duration
				return

func handle_stun(delta):
	stun_timer -= delta
	if stun_timer <= 0:
		print("Minotaur recovered from stun!")
		if is_at_target_tile(true):
			reset_state()
			pick_new_wander_target()
			current_state = State.WANDERING

func wander(delta):
	if target_tile != Vector2i(-1, -1):
		if not is_at_target_tile():
			move_and_slide()
			return
		else:
			target_tile = Vector2i(-1, -1)

	pick_new_wander_target()

func pick_new_wander_target():
	var current_tile = get_tile_position()
	var possible_moves = []

	# forward, left, right relative to direction
	var move_directions = [
		direction,
		Vector2i(direction.y, -direction.x),  # rotate left
		Vector2i(-direction.y, direction.x)   # rotate right
	]

	for dir_vec in move_directions:
		var new_tile = current_tile + dir_vec
		if maze.is_within_bounds(new_tile):
			if not is_colliding_with_wall(new_tile) and new_tile != last_tile:
				possible_moves.append(new_tile)

	if possible_moves.size() > 0:
		target_tile = possible_moves[randi() % possible_moves.size()]
		last_tile = current_tile
		direction = (target_tile - current_tile).sign()

		set_target_position(target_tile)
		velocity = Vector2(direction).normalized() * move_speed
		move_and_slide()
		return

	print("Minotaur stuck! Rotating...")
	velocity = Vector2.ZERO
	last_tile = current_tile

	var turn_options = [
		Vector2i(-direction.y, direction.x),
		Vector2i(direction.y, -direction.x)
	]
	direction = turn_options[randi() % turn_options.size()]

func get_tile_position() -> Vector2i:
	# x = column, y = row => tile.x = floor(position.x / CELL_SIZE), tile.y = floor(position.y / CELL_SIZE)
	var tile_x = int(floor(position.x / maze.CELL_SIZE))
	var tile_y = int(floor(position.y / maze.CELL_SIZE))
	return Vector2i(tile_x, tile_y)

func set_target_position(tile: Vector2i):
	if tile == Vector2i(-1, -1):
		pick_new_wander_target()
		return
	direction = (tile - get_tile_position()).sign()

func reset_state():
	target_tile = Vector2i(-1, -1)
	velocity = Vector2.ZERO

func is_colliding_with_wall(target: Vector2i) -> bool:
	return maze.has_wall_between(get_tile_position(), target)

func is_at_target_tile(recenter: bool = false) -> bool:
	var current_tile = get_tile_position()
	var target_center = Vector2(
		(current_tile.x + 0.5) * maze.CELL_SIZE,
		(current_tile.y + 0.5) * maze.CELL_SIZE
	)
	if position.distance_to(target_center) <= 0.5:
		position = target_center
		velocity = Vector2.ZERO
		return true
	if recenter:
		var move_vec = (target_center - position).normalized()
		var recenter_speed = move_speed / 2
		velocity = move_vec * recenter_speed
		move_and_slide()
	return false

func update_rotation():
	# If your sprite is drawn to face right at angle=0,
	# then direction.x>0 (right) => rotation=0, direction.x<0 => rotation=PI, etc.
	# Adjust as needed for your art.

	if direction == Vector2i(1, 0):
		# right
		rotation = 0
	elif direction == Vector2i(-1, 0):
		# left
		rotation = PI
	elif direction == Vector2i(0, -1):
		# up
		rotation = -PI/2
	elif direction == Vector2i(0, 1):
		# down
		rotation = PI/2
	else:
		rotation = 0
