extends CharacterBody3D

signal selected_building_changed(building: FunctionalBuilding)

@export var speed = 6.0
@export var gather_rate = 20
@export var gather_time_multiplier = 0.1

@onready var camera: Camera3D = get_viewport().get_camera_3d()
@onready var build_system = get_node("/root/Main/BuildSystem")
@onready var gm = get_node("/root/Main/GameManager")
@onready var terrain: TerrainSystem = get_node("/root/Main/TerrainSystem")

var target_resource = null
var gather_timer = 0.0
var current_path: Array[Vector3] = []
var path_index := 0
var has_target := false
var ground_offset := 0.0
var selected_building: FunctionalBuilding


func _ready():
	if terrain != null:
		var start_cell = terrain.world_to_cell(global_position)
		ground_offset = global_position.y - terrain.get_surface_height(global_position)


func safe_value(value, default):
	if value == null:
		return default
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return value
	return default


func _input(event):
	if build_system and build_system.is_build_mode_active():
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click()


func _physics_process(delta):
	if terrain == null:
		move_and_slide()
		return

	if has_target and path_index < current_path.size():
		var real_speed = safe_value(speed, 6.0)
		var has_waypoint := false
		while path_index < current_path.size():
			var waypoint = current_path[path_index]
			var direction = waypoint - global_position
			direction.y = 0
			if direction.length() <= 0.16:
				path_index += 1
				continue

			direction = direction.normalized()
			velocity.x = direction.x * real_speed
			velocity.z = direction.z * real_speed
			has_waypoint = true
			break

		if not has_waypoint:
			velocity = Vector3.ZERO
			_try_gather(delta)
	else:
		velocity = Vector3.ZERO
		_try_gather(delta)

	move_and_slide()
	_update_height_from_terrain()


func _handle_right_click():
	var result = get_mouse_result()
	if result.is_empty():
		return

	var current_cell = terrain.world_to_cell(global_position)
	var target_cell = result.get("cell", terrain.world_to_cell(result.position))
	if not terrain.is_tile_walkable(target_cell):
		target_cell = terrain.find_nearest_walkable_cell_towards(current_cell, target_cell)

	var path_cells: Array[Vector2i] = []
	if terrain.has_direct_path(current_cell, target_cell):
		path_cells = [current_cell, target_cell]
	else:
		path_cells = terrain.find_path(current_cell, target_cell)
	if path_cells.is_empty():
		target_resource = null
		has_target = false
		current_path.clear()
		path_index = 0
		return

	current_path.clear()
	var simplified_path = terrain.smooth_path(path_cells)
	for index in range(1, simplified_path.size()):
		var cell = simplified_path[index]
		var world_point = terrain.cell_to_world_top(cell)
		world_point.y += ground_offset
		current_path.append(world_point)

	target_resource = result.get("resource_node")
	gather_timer = 0.0
	path_index = 0
	has_target = not current_path.is_empty() or target_resource != null


func _handle_left_click():
	_set_selected_building(_get_clicked_building())


func _try_gather(delta):
	if target_resource == null or not is_instance_valid(target_resource):
		target_resource = null
		has_target = false
		return

	var target_cell = terrain.world_to_cell(target_resource.global_position)
	var current_cell = terrain.world_to_cell(global_position)
	if current_cell != target_cell:
		has_target = true
		return

	gather_timer += delta
	var gather_interval = max(target_resource.gather_time * gather_time_multiplier, 0.05)
	if gather_timer < gather_interval:
		return

	gather_timer = 0.0
	var gathered = target_resource.gather(gather_rate)
	if gathered > 0:
		gm.add_resource(target_resource.resource_id, gathered)

	if target_resource.current_amount <= 0:
		target_resource = null
		has_target = false


func _update_height_from_terrain():
	var current_cell = terrain.world_to_cell(global_position)
	if not terrain.is_cell_in_bounds(current_cell):
		return
	var target_y = terrain.get_surface_height(global_position) + ground_offset
	global_position.y = target_y


func _get_clicked_building() -> FunctionalBuilding:
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_dir * 500.0
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 2
	var hit = space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var collider = hit.collider
	if collider == null:
		return null

	var building = collider.get_parent() as FunctionalBuilding
	return building


func _set_selected_building(building: FunctionalBuilding):
	if selected_building != null and is_instance_valid(selected_building):
		selected_building.set_range_indicator_visible(false)

	selected_building = building

	if selected_building != null and is_instance_valid(selected_building):
		selected_building.set_range_indicator_visible(true)

	selected_building_changed.emit(selected_building)


func get_selected_building() -> FunctionalBuilding:
	if selected_building != null and is_instance_valid(selected_building):
		return selected_building
	return null


func get_mouse_result() -> Dictionary:
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_dir * 500.0

	var resource_hit := {}
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 2
	resource_hit = space_state.intersect_ray(query)

	if not resource_hit.is_empty():
		var collider = resource_hit.collider
		if collider != null:
			var resource_node = collider.get_parent()
			if resource_node != null and "current_amount" in resource_node:
				return {
					"cell": terrain.world_to_cell(resource_node.global_position),
					"position": resource_node.global_position,
					"resource_node": resource_node,
				}

	return terrain.raycast_from_camera(camera, mouse_pos)
