extends CharacterBody2D

class_name Minotaur

@onready var vision = $Vision
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
	if not vision:
		push_error("❌ ERROR: Vision node not found!")
		set_physics_process(false) # Disable physics if Vision is missing
		return
	vision.body_entered.connect(_on_vision_body_entered)


func _on_vision_body_entered(body):
	if current_state == State.IDLE:
		return
	if body is Player:
		#print("⚡ Minotaur sees the player!")
		last_known_player_pos = maze.player.get_tile_position()
		current_state = State.CHARGING

func _process(delta):
	if current_state in [State.IDLE, State.STUNNED]:
		return # Don't detect vision if idle or stunned
	var player = maze.player
	if check_vision_collision_with_player(player):
		last_known_player_pos = player.get_tile_position()
		current_state = State.CHARGING
	
	update_rotation()

func _physics_process(delta):
	match current_state:
		State.IDLE:
			check_for_player_entry()
			return
		State.SEARCHING:
			search_for_player()
		State.CHARGING:
			charge_at_player(delta)
		State.WANDERING:
			wander(delta)
		State.STUNNED:
			handle_stun(delta)
	
	# Always apply movement at the end
	move_and_slide()
	if current_state == State.CHARGING:
		for i in range(get_slide_collision_count()):
			var coll = get_slide_collision(i)
			if coll:
				var collider = coll.get_collider()
				if collider is Player:
					print("~~~~~~Player caught~~~~~~")
					# Handle player caught
				else:
					print("Minotaur stunned!")
					reset_state()
					current_state = State.STUNNED
					stun_timer = stun_duration

func check_vision_collision_with_player(player: Node2D) -> bool:
	return vision and vision.is_touching_player() and player

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
		if last_known_player_pos != Vector2i(-1, -1):
			print("Charging!")
			direction = (last_known_player_pos - get_tile_position()).sign()
	if direction == Vector2i.ZERO:
		print("❌ Failed to determine charge direction! Resetting...")
		reset_state()
		current_state = State.WANDERING
		return
	
	velocity = Vector2(direction).normalized() * charge_speed

func handle_stun(delta):
	stun_timer -= delta
	if stun_timer <= 0:
		if is_at_target_tile(true):
			reset_state()
			print("Minotaur recovered from stun!")
			pick_new_wander_target()
			current_state = State.WANDERING

func wander(delta):
	if target_tile != Vector2i(-1, -1):
		if not is_at_target_tile():
			return
		else:
			target_tile = Vector2i(-1, -1)

	pick_new_wander_target()

func pick_new_wander_target():
	var current_tile = get_tile_position()
	var move_directions = [
		direction,
		Vector2i(direction.y, -direction.x),  # rotate left
		Vector2i(-direction.y, direction.x)   # rotate right
	]
	move_directions.shuffle() # Randomizes directions

	for dir_vec in move_directions:
		var new_tile = current_tile + dir_vec
		if maze.is_within_bounds(new_tile) and not is_colliding_with_wall(new_tile) and new_tile != last_tile:
			target_tile = new_tile
			last_tile = current_tile
			break  # 🚀 Exit loop after finding a valid move

	# ✅ Ensure Minotaur always moves
	if target_tile != Vector2i(-1, -1):
		direction = (target_tile - current_tile).sign()
		velocity = Vector2(direction).normalized() * move_speed
	else:
		print("⚠ Minotaur stuck at ", current_tile, " - No valid moves found! Facing: ", direction, " | Rotating...")
		last_tile = current_tile
		direction = [Vector2i(-direction.y, direction.x), Vector2i(direction.y, -direction.x)].pick_random()


func get_tile_position() -> Vector2i:
	# x = column, y = row => tile.x = floor(position.x / CELL_SIZE), tile.y = floor(position.y / CELL_SIZE)
	var tile_x = int(floor(position.x / maze.CELL_SIZE))
	var tile_y = int(floor(position.y / maze.CELL_SIZE))
	return Vector2i(tile_x, tile_y)

func set_target_position(tile: Vector2i):
	direction = (tile - get_tile_position()).sign() if tile != Vector2i(-1, -1) else direction

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
	return false

func update_rotation():
	if direction != Vector2i.ZERO:
		rotation = Vector2(direction).angle()
