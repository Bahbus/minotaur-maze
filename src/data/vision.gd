extends Area2D

@onready var collision_polygon = $CollisionPolygon2D
@onready var polygon = $Polygon2D
@onready var minotaur = get_parent() as Minotaur

var max_radius = 6  # Vision range in tiles
var tile_size = 32  # Each tile is 32x32 pixels
var num_rays = 120  # Number of rays in the arc
var vision_angle = deg_to_rad(120)  # 120-degree vision cone
var last_position
var last_rotation

# Vision data
var visible_points = []  # Stores vision edges

func _ready():
	if polygon:
		polygon.color = Color(1, 0, 0, 0.15)
		polygon.antialiased = true
		collision_polygon.build_mode = 0

func _physics_process(_delta):
	if not minotaur or not minotaur.maze:
		return

	# ✅ Update vision only when Minotaur moves or rotates
	if minotaur.global_position != last_position or minotaur.rotation != last_rotation:
		last_position = minotaur.global_position
		last_rotation = minotaur.rotation
		update_vision()

func update_vision():
	visible_points.clear()

	# Generate vision polygon
	var poly = generate_vision_polygon()
	if poly.size() > 2:
		# ✅ Convert to local space before assigning!
		for i in range(poly.size()):
			poly[i] = to_local(poly[i]).snapped(Vector2(0.1, 0.1))
		polygon.polygon = poly
		collision_polygon.polygon = polygon.polygon

### **📌 Generate Vision Polygon Based on Minotaur Rotation**
func generate_vision_polygon() -> PackedVector2Array:
	compute_vision_rays()

	# Sort points counterclockwise without relying on a center
	var sorted_poly = sort_ccw_by_angle(visible_points)
	return clean_polygon(sorted_poly)

### **📌 Compute Vision Rays within 120-degree Arc**
func compute_vision_rays():
	var center = minotaur.global_position
	var max_distance = max_radius * tile_size
	var base_angle = normalize_angle(minotaur.rotation)
	var half_arc = vision_angle / 2.0

	var start_angle = normalize_angle(base_angle - half_arc)
	var end_angle = normalize_angle(base_angle + half_arc)

	# Ensure correct order when crossing 0°
	if start_angle > end_angle:
		end_angle += TAU  # Prevent wrapping issues

	for i in range(num_rays + 1):
		var fraction = float(i) / float(num_rays)
		var angle = normalize_angle(start_angle + fraction * (end_angle - start_angle))
		var direction = Vector2(cos(angle), sin(angle))
		var ray_end = cast_vision_ray(center, direction, max_distance)
		visible_points.append({"angle": angle, "pos": ray_end})

	# Ensure the Minotaur itself is part of the polygon
	visible_points.append({"angle": start_angle, "pos": center})

### **📌 Cast Vision Ray Until Collision or Max Distance**
func cast_vision_ray(start: Vector2, direction: Vector2, max_distance: float) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var end_pos = start + direction * max_distance
	var query = PhysicsRayQueryParameters2D.create(start, end_pos)
	query.exclude = [minotaur, minotaur.player]
	var result = space_state.intersect_ray(query)
	if result:
		var hit_pos = result.position
		var hit_dir = (hit_pos - start).normalized()
		return hit_pos - hit_dir * 1.0  # Offset by 1 pixel inward
	return end_pos

### **📌 Sort Points Counter-Clockwise By Angle**
func sort_ccw_by_angle(points: Array) -> PackedVector2Array:
	if points.size() < 3:
		return PackedVector2Array(points.map(func(p): return p["pos"]))

	# Sort based on angles directly, handling wrap-around cases
	points.sort_custom(func(a, b):
		return normalize_angle(a["angle"] - minotaur.rotation) < normalize_angle(b["angle"] - minotaur.rotation)
	)

	return PackedVector2Array(points.map(func(p): return p["pos"]))

### **📌 Remove Duplicate & Collinear Points**
func clean_polygon(poly: PackedVector2Array) -> PackedVector2Array:
	if poly.size() < 3:
		return poly

	var unique_poly = PackedVector2Array()
	var epsilon = 0.1  # Adjust for floating point precision

	# Step 1: Remove duplicate or near-identical points
	for p in poly:
		var is_duplicate = false
		for up in unique_poly:
			if p.distance_to(up) < epsilon:
				is_duplicate = true
				break
		if not is_duplicate:
			unique_poly.append(p)

	# Step 2: Remove collinear points
	var cleaned_poly = PackedVector2Array()
	cleaned_poly.append(unique_poly[0])  # Always keep first point

	for i in range(1, unique_poly.size() - 1):
		var prev = unique_poly[i - 1]
		var curr = unique_poly[i]
		var next = unique_poly[i + 1]

		if not is_collinear(prev, curr, next):
			cleaned_poly.append(curr)

	if not is_collinear(unique_poly[unique_poly.size() - 2], unique_poly[unique_poly.size() - 1], unique_poly[0]):
		cleaned_poly.append(unique_poly[unique_poly.size() - 1])

	return cleaned_poly

### **📌 Check if Three Points Are Collinear**
func is_collinear(a: Vector2, b: Vector2, c: Vector2) -> bool:
	return abs((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)) < 0.1

### **📌 Normalize Angle to 0 - TAU**
func normalize_angle(angle: float) -> float:
	return fmod(angle + TAU, TAU)
