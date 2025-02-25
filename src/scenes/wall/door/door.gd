extends Wall

class_name Door

# Door properties
@export var is_open: bool = false  # Tracks if the door is currently open
@export var auto_close_time: float = 5.0  # Time before the door auto-closes
@export var can_minotaur_open: bool = true  # If the Minotaur can open the door
@export var can_player_open: bool = true  # If the player can open the door
@export var door_type: String = "wood"

@onready var door_types = {
	 "wood": {true: "res://assets/wood_door_open.png", false: "res://assets/wood_door_closed.png"},
	 "stone": {true: "res://assets/stone_door_open.png", false: "res://assets/stone_door_closed.png"},
	 "reinforced": {true: "res://assets/reinforced_door_open.png", false: "res://assets/reinforced_door_closed.png"}
	}  # Future expansion for door types

@onready var timer: Timer = $Timer
var waiting_to_close: bool = false  # Tracks if the door is waiting for an obstruction to clear

func _ready():
	# Ensure timer is set up correctly
	timer.wait_time = auto_close_time
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	update_visual_state()

func _process(_delta):
	# If the door is waiting to close, check if it is still obstructed
	if waiting_to_close and not is_obstructed():
		toggle()
		waiting_to_close = false

func set_door_type(type):
	if not type in door_types:
		return
	door_type = type
	update_visual_state()

func interact(entity):
	# Called when an entity (player or Minotaur) interacts with the door
	if entity is Player and can_player_open:
		toggle()
	elif entity is Minotaur:
		toggle()

func toggle():
	# Toggles the door state between open and closed
	is_open = not is_open
	update_visual_state()

	if is_open:
		start_auto_close_timer()

func update_visual_state():
	sprite.texture = load(door_types[door_type][is_open])
	sprite.self_modulate.a = 0.3 if is_open else 1.0
	collision_shape.disabled = is_open
	queue_redraw()

func start_auto_close_timer():
	# Starts the timer to close the door automatically
	timer.start()

func _on_timer_timeout():
	# Tries to close the door when the timer expires
	if is_open:
		if is_obstructed():
			print("Door is obstructed, waiting to close...")
			waiting_to_close = true  # Mark door as waiting
		else:
			toggle()

func is_obstructed() -> bool:
	# Checks if something is blocking the door from closing
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.collision_mask = 16+32
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.exclude = [self]

	var result = space_state.intersect_shape(query)
	return result.size() > 0  # If there's any collision, the door is obstructed
