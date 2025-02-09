extends Area2D

@onready var collision_polygon = $CollisionPolygon2D
@onready var polygon = $Polygon2D
@onready var minotaur = get_parent() as Minotaur

var fov = 120
var vision_angle = deg_to_rad(fov)  # Minotaur's field of view
var max_length = 6 * 32  # Vision range (6 tiles)
var num_rays = fov / 3  # Number of rays cast for accuracy
var last_position = Vector2.ZERO
var last_rotation = 0.0
var cached_player_polygon = PackedVector2Array()
var last_player_shape_id = 0

func _ready():
	if polygon:
		polygon.color = Color(1, 0, 0, 0.15)

func _process(delta):
	if not minotaur or not minotaur.maze:
		return
	# ✅ Only update vision if the Minotaur or Player moved
	if global_position != last_position or rotation != last_rotation or minotaur.maze.player.position != last_position:
		last_position = global_position
		last_rotation = rotation
		update_vision()

func update_vision():
	var edges = minotaur.maze.gather_maze_edges()
	var poly = build_vision_polygon(edges)
	
	if poly.size() > 2:
		if Geometry2D.is_polygon_clockwise(poly):
			poly.reverse()

		# ✅ Compute polygon area manually
		var area = get_polygon_area(poly)
		if area > 1.0:  # ✅ Ignore nearly-flat polygons
			collision_polygon.polygon = poly
			polygon.polygon = poly
		else:
			print("⚠ Skipping bad polygon with area:", area, "Points:", poly)

func get_polygon_area(poly: PackedVector2Array) -> float:
	if poly.size() < 3:
		return 0.0  # ✅ Invalid polygons have no area

	var area = 0.0
	for i in range(poly.size()):
		var p1 = poly[i]
		var p2 = poly[(i + 1) % poly.size()]  # ✅ Wrap around to first point
		area += (p1.x * p2.y) - (p2.x * p1.y)
	return abs(area) / 2.0  # ✅ Shoelace theorem

### **🎯 Build Properly Ordered Vision Polygon**
func build_vision_polygon(edges: Array) -> PackedVector2Array:
	var vantage = global_position
	var base_angle = minotaur.rotation
	var half_cone = vision_angle / 2.0

	var angle_points = []

	# **Step 1: Cast rays in the vision cone**
	for i in range(num_rays + 1):
		var fraction = float(i) / float(num_rays)
		var current_angle = base_angle - half_cone + (fraction * vision_angle)

		var hit_pos = cast_physics_ray(vantage, current_angle)
		angle_points.append({ "angle": current_angle, "pos": hit_pos })

	# **Step 2: Cast rays towards key wall points**
	for edge in edges:
		for point in [edge["p1"], edge["p2"]]:
			var angle = (point - vantage).angle()
			if abs(fmod(angle - base_angle + PI, TAU) - PI) <= half_cone:
				var hit_pos = cast_physics_ray(vantage, angle)
				angle_points.append({ "angle": angle, "pos": hit_pos })

	# **Step 3: Sort by angle**
	angle_points.sort_custom(_sort_by_angle)

	# **Step 4: Construct the polygon**
	var final_poly = PackedVector2Array()
	final_poly.append(Vector2.ZERO)  # Apex (Minotaur position)

	for data in angle_points:
		final_poly.append(to_local(data["pos"]))

	# **Step 5: Cleanup overlapping points**
	return clean_polygon(final_poly)

### **🛠 Helper Functions**
func _sort_by_angle(a, b) -> bool:
	return a["angle"] < b["angle"]

func cast_physics_ray(start_pos: Vector2, angle: float) -> Vector2:
	var ray_dir = Vector2(cos(angle), sin(angle))
	var end_pos = start_pos + ray_dir * max_length

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(start_pos, end_pos)
	query.exclude = [minotaur]

	var result = space_state.intersect_ray(query)
	if result:
		return result.position
	return end_pos

func clean_polygon(poly: PackedVector2Array) -> PackedVector2Array:
	if poly.size() < 3:
		return poly
	
	var seen = {}  # Hash table for quick lookup
	var cleaned_poly = PackedVector2Array()

	for p in poly:
		var key = p.snapped(Vector2(1, 1))  # ✅ More precise rounding
		if key not in seen:
			seen[key] = true
			cleaned_poly.append(p)

	return cleaned_poly

func is_touching_player() -> bool:
	if not minotaur or not minotaur.maze or not minotaur.maze.player:
		return false
	
	var player_polygon = get_player_collision_polygon()
	var vision_polygon = collision_polygon.polygon

	if player_polygon.is_empty() or vision_polygon.is_empty():
		return false

	# Convert to global positions
	var vision_global = []
	for point in vision_polygon:
		vision_global.append(to_global(point))

	var player_global = []
	for point in player_polygon:
		player_global.append(minotaur.maze.player.to_global(point))

	# 🔍 **Check if polygons are touching**
	var touching = Geometry2D.intersect_polygons(vision_global, player_global)
	var crossing = Geometry2D.intersect_polyline_with_polygon(player_global, vision_global)

	if touching.size() > 0 or crossing.size() > 0:
		return true

	return false

func get_player_collision_polygon() -> PackedVector2Array:
	var player = minotaur.maze.player
	if not player:
		return PackedVector2Array()

	var collision_shape = player.get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return PackedVector2Array()

	# ✅ Check if shape changed
	if collision_shape.shape.get_instance_id() == last_player_shape_id:
		return cached_player_polygon

	last_player_shape_id = collision_shape.shape.get_instance_id()
	var polygon = PackedVector2Array()

	if collision_shape.shape is ConvexPolygonShape2D:
		polygon.append_array(collision_shape.shape.points)

	elif collision_shape.shape is RectangleShape2D:
		var extents = collision_shape.shape.extents
		polygon.append(Vector2(-extents.x, -extents.y))
		polygon.append(Vector2(extents.x, -extents.y))
		polygon.append(Vector2(extents.x, extents.y))
		polygon.append(Vector2(-extents.x, extents.y))

	cached_player_polygon = polygon
	return polygon

func get_edges(polygon: PackedVector2Array, offset: Vector2) -> Array:
	var edges = []
	if polygon.size() < 2:
		return edges

	for i in range(polygon.size()):
		var p1 = offset + polygon[i]
		var p2 = offset + polygon[(i + 1) % polygon.size()]  # Wrap-around for last edge
		edges.append([p1, p2])

	return edges

func intersect_ray_segment(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	# Ray-line segment intersection formula
	var r = a2 - a1
	var s = b2 - b1
	var denominator = r.x * s.y - r.y * s.x

	if abs(denominator) < 0.00001:
		return false  # Parallel or collinear

	var u = ((b1.x - a1.x) * r.y - (b1.y - a1.y) * r.x) / denominator
	var t = ((b1.x - a1.x) * s.y - (b1.y - a1.y) * s.x) / denominator

	# Ensure the intersection occurs **on both segments**
	return 0.0 <= t and t <= 1.0 and 0.0 <= u and u <= 1.0
