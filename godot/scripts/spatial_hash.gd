class_name SpatialHash
extends RefCounted

# Spatial hash grid for O(n) collision detection instead of O(n²)
# Critical for performance when hundreds of enemies are on screen

var cell_size: float
var grid: Dictionary = {}  # Vector2i -> Array[Node2D]

func _init(p_cell_size: float = 64.0) -> void:
	cell_size = p_cell_size

func clear() -> void:
	grid.clear()

func _cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / cell_size), int(pos.y / cell_size))

func insert(node: Node2D) -> void:
	var key := _cell(node.position)
	if key not in grid:
		grid[key] = []
	grid[key].append(node)

func query_radius(pos: Vector2, radius: float) -> Array:
	var results: Array = []
	var min_cell := _cell(pos - Vector2(radius, radius))
	var max_cell := _cell(pos + Vector2(radius, radius))
	var r_sq := radius * radius
	
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var key := Vector2i(x, y)
			if key in grid:
				for node in grid[key]:
					if node.position.distance_squared_to(pos) <= r_sq:
						results.append(node)
	return results

func query_rect(rect: Rect2) -> Array:
	var results: Array = []
	var min_cell := _cell(rect.position)
	var max_cell := _cell(rect.end)
	
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var key := Vector2i(x, y)
			if key in grid:
				for node in grid[key]:
					if rect.has_point(node.position):
						results.append(node)
	return results
