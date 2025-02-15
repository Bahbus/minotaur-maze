extends Wall

class_name Door

# Door properties
@export var is_open: bool = false  # Tracks if the door is currently open
@export var auto_close_time: float = 30.0  # Time before the door auto-closes
@export var can_minotaur_open: bool = true  # If the Minotaur can open the door
@export var can_player_open: bool = true  # If the player can open the door
@export var door_type: String = "wood"

@onready var door_types = {
	 "wood": {true: preload("res://assets/wood_door_open.png"), false: preload("res://assets/wood_door_closed.png")},
	 "stone": {true: preload("res://assets/stone_door_open.png"), false: preload("res://assets/stone_door_closed.png")},
	 "reinforced": {true: preload("res://assets/reinforced_door_open.png"), false: preload("res://assets/reinforced_door_closed.png")}
	}  # Future expansion for door types

@onready var timer: Timer = $Timer

func _ready():
	# Ensure timer is set up correctly
	is_door = true
	timer.wait_time = auto_close_time
	timer.one_shot = true
	update_visual_state()
	
func set_door_type(type):
	if not door_types.has(type):
		return
	door_type = type
	update_visual_state()

func interact(entity):
	# Called when an entity (player or Minotaur) interacts with the door
	if entity is Player and can_player_open:
		toggle()
	elif entity is Minotaur and can_minotaur_open:
		toggle()

func toggle():
	# Toggles the door state between open and closed
	is_open = not is_open
	update_visual_state()

	if is_open:
		start_auto_close_timer()

func update_visual_state():
	# Updates the visual and collision state based on door status
	sprite.texture = door_types[door_type][is_open]
	collision_shape.disabled = is_open

func start_auto_close_timer():
	# Starts the timer to close the door automatically
	timer.start()

func _on_timer_timeout():
	# Automatically closes the door when the timer expires
	if is_open:
		toggle()
