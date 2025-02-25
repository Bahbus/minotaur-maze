extends StaticBody2D
class_name Wall

@export var is_door: bool = false
@export var maze: Node2D

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
