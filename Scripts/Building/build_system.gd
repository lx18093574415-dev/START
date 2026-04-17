class_name BuildSystem
extends Node

signal building_placed(building_id: StringName, position: Vector3, rotation_y: float)

const CATEGORY_ORDER: Array[StringName] = [&"residential", &"logistics", &"industrial", &"military"]
const CATEGORY_LABELS := {
	&"residential": "Residential",
	&"logistics": "Logistics",
	&"industrial": "Industrial",
	&"military": "Military",
}

@export var grid_size := 1.0
@export var buildings: Array[BuildingData]

@onready var camera: Camera3D = get_viewport().get_camera_3d()
@onready var gm = get_node("../GameManager")
@onready var grid: MeshInstance3D = get_node("../Ground/GridOverlay")
@onready var build_menu: BuildMenu = get_node("../UI/BuildMenu")
@onready var buildings_root: Node3D = get_node("../Buildings")

var is_build_mode := false
var current_category: StringName = CATEGORY_ORDER[0]
var current_building: BuildingData
var current_preview: BuildPreview
var build_rotation := 0.0
var current_build_transform := {}


func _ready():
	_setup_grid()
	build_menu.hide_menu()
	build_menu.category_selected.connect(_on_category_selected)
	build_menu.building_selected.connect(_on_building_selected)
	build_menu.cancel_requested.connect(_on_cancel_requested)
	gm.resources_changed.connect(_on_resources_changed)
	_refresh_build_menu()


func _process(_delta):
	if not is_build_mode or current_building == null or current_preview == null:
		return

	var result = get_mouse_result()
	if result.is_empty():
		current_preview.visible = false
		current_build_transform.clear()
		return

	current_build_transform = get_snapped_build_transform(current_building, result.position, build_rotation)
	_apply_preview_transform(current_build_transform)
	var placement_state = _get_placement_state(current_building, current_build_transform)
	current_preview.set_buildable(placement_state.can_place)


func _input(event):
	if not is_build_mode:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		if current_building != null:
			build_rotation = wrapf(build_rotation + deg_to_rad(90), 0.0, TAU)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			exit_build_mode()
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if get_viewport().gui_get_hovered_control() == null:
				_try_place_current_building()
				get_viewport().set_input_as_handled()


func is_build_mode_active() -> bool:
	return is_build_mode


func _on_build_button_pressed():
	if is_build_mode:
		exit_build_mode()
		return

	enter_build_mode()


func enter_build_mode():
	is_build_mode = true
	current_category = CATEGORY_ORDER[0]
	current_building = null
	build_rotation = 0.0
	current_build_transform.clear()
	grid.visible = true
	build_menu.show_menu()
	_clear_preview()
	_refresh_build_menu()


func exit_build_mode():
	is_build_mode = false
	current_category = CATEGORY_ORDER[0]
	current_building = null
	build_rotation = 0.0
	current_build_transform.clear()
	grid.visible = false
	_clear_preview()
	build_menu.hide_menu()
	_refresh_build_menu()


func get_snapped_build_transform(building_data: BuildingData, hit_position: Vector3, rotation_y: float) -> Dictionary:
	var local_footprint = building_data.size
	var world_footprint = _get_world_footprint(local_footprint, rotation_y)
	var snapped_x = _snap_axis_to_grid(hit_position.x, world_footprint.x)
	var snapped_z = _snap_axis_to_grid(hit_position.z, world_footprint.y)
	var snapped_position = Vector3(snapped_x, 0.0, snapped_z)

	return {
		"position": snapped_position,
		"rotation_y": rotation_y,
		"local_footprint": local_footprint,
		"world_footprint": world_footprint,
	}


func request_place_building(building_data: BuildingData, build_transform: Dictionary) -> bool:
	var placement_state = _get_placement_state(building_data, build_transform)
	if not placement_state.can_place:
		return false

	if not gm.spend_resources(building_data.build_costs):
		return false

	var building = _instantiate_building(building_data, build_transform.position, build_transform.rotation_y)
	if building == null:
		return false

	building_placed.emit(building_data.building_id, build_transform.position, build_transform.rotation_y)
	exit_build_mode()
	return true


func spawn_saved_building(building_id: StringName, position: Vector3, rotation_y: float):
	var building_data = get_building_by_id(building_id)
	if building_data == null:
		return

	_instantiate_building(building_data, position, rotation_y)


func get_building_by_id(building_id: StringName) -> BuildingData:
	for building in buildings:
		if building.building_id == building_id:
			return building
	return null


func get_mouse_result() -> Dictionary:
	if camera == null:
		return {}

	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_dir * 1000.0

	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 1
	return space_state.intersect_ray(query)


func _setup_grid():
	var mat = grid.material_override
	if mat == null:
		push_error("Grid material is missing.")
		return

	mat = mat.duplicate()
	grid.material_override = mat
	mat.set("shader_parameter/grid_size", grid_size)
	grid.visible = false


func _refresh_build_menu():
	var affordable_map := {}
	for building in buildings:
		affordable_map[building.building_id] = gm.has_resources(building.build_costs)

	var selected_id := StringName()
	if current_building != null:
		selected_id = current_building.building_id

	build_menu.update_state(
		CATEGORY_ORDER,
		CATEGORY_LABELS,
		gm.get_resource_order(),
		gm.get_resource_labels(),
		current_category,
		buildings,
		affordable_map,
		selected_id
	)


func _on_category_selected(category: StringName):
	current_category = category
	current_building = null
	build_rotation = 0.0
	current_build_transform.clear()
	_clear_preview()
	_refresh_build_menu()


func _on_building_selected(building_data: BuildingData):
	current_building = building_data
	build_rotation = 0.0
	current_build_transform.clear()
	_create_preview(building_data)
	_refresh_build_menu()


func _on_cancel_requested():
	exit_build_mode()


func _on_resources_changed():
	_refresh_build_menu()


func _try_place_current_building():
	if current_building == null or current_build_transform.is_empty():
		return

	request_place_building(current_building, current_build_transform)


func _create_preview(building_data: BuildingData):
	_clear_preview()

	var preview_instance = building_data.preview.instantiate()
	if preview_instance == null:
		push_error("Failed to instantiate build preview.")
		return

	add_child(preview_instance)
	current_preview = preview_instance as BuildPreview
	if current_preview == null:
		push_error("Preview scene must use BuildPreview.")
		preview_instance.queue_free()
		return

	current_preview.configure_from_data(building_data)


func _clear_preview():
	if current_preview:
		current_preview.queue_free()
		current_preview = null


func _apply_preview_transform(build_transform: Dictionary):
	if current_preview == null:
		return

	current_preview.visible = true
	current_preview.global_position = build_transform.position
	current_preview.rotation.y = build_transform.rotation_y


func _get_placement_state(building_data: BuildingData, build_transform: Dictionary) -> Dictionary:
	if current_preview == null:
		return {
			"has_enough_resources": false,
			"is_area_free": false,
			"can_place": false,
		}

	_apply_preview_transform(build_transform)
	var has_enough_resources = gm.has_resources(building_data.build_costs)
	var is_area_free = current_preview.is_area_free()

	return {
		"has_enough_resources": has_enough_resources,
		"is_area_free": is_area_free,
		"can_place": has_enough_resources and is_area_free,
	}


func _instantiate_building(building_data: BuildingData, position: Vector3, rotation_y: float) -> Node3D:
	var building = building_data.scene.instantiate()
	if building == null:
		return null

	building.set_meta("building_id", building_data.building_id)
	buildings_root.add_child(building)
	building.global_position = position
	building.rotation.y = rotation_y
	return building


func _get_world_footprint(size: Vector2, rotation_y: float) -> Vector2:
	if int(round(rotation_y / deg_to_rad(90))) % 2 == 1:
		return Vector2(size.y, size.x)

	return size


func _snap_axis_to_grid(value: float, axis_size: float) -> float:
	if int(round(axis_size)) % 2 == 1:
		return round(value / grid_size) * grid_size

	return floor(value / grid_size) * grid_size + grid_size * 0.5
