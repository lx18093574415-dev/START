extends Node

const SAVE_PATH := "user://star_colony_save.json"

@onready var gm = get_node("../GameManager")
@onready var build_system = get_node("../BuildSystem")
@onready var map_resource_system = get_node("../MapResourceSystem")
@onready var buildings_root: Node3D = get_node("../Buildings")

var is_loading := false


func _ready():
	await get_tree().process_frame
	load_game()
	gm.resources_changed.connect(_on_state_changed)
	map_resource_system.state_changed.connect(_on_state_changed)
	build_system.building_placed.connect(_on_building_placed)


func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	is_loading = true

	var map_id = str(map_resource_system.get_current_map_id())
	var maps = parsed.get("maps", {})
	var map_state = maps.get(map_id, {})

	gm.apply_inventory(parsed.get("inventory", {}))
	map_resource_system.apply_saved_state(map_state)
	_restore_buildings(map_state.get("buildings", []))

	is_loading = false


func save_game():
	var map_id = str(map_resource_system.get_current_map_id())
	var map_state = map_resource_system.export_state()
	map_state["buildings"] = _export_buildings()
	var saved_maps := {}

	if FileAccess.file_exists(SAVE_PATH):
		var existing_file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if existing_file != null:
			var existing_payload = JSON.parse_string(existing_file.get_as_text())
			if typeof(existing_payload) == TYPE_DICTIONARY:
				saved_maps = existing_payload.get("maps", {}).duplicate(true)

	saved_maps[map_id] = map_state

	var payload = {
		"current_map_id": map_id,
		"inventory": gm.export_inventory(),
		"maps": saved_maps,
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))


func _export_buildings() -> Array:
	var result := []
	for child in buildings_root.get_children():
		if not child.has_meta("building_id"):
			continue

		var position = child.global_position
		result.append({
			"building_id": str(child.get_meta("building_id")),
			"position": [position.x, position.y, position.z],
			"rotation_y": child.rotation.y,
		})

	return result


func _restore_buildings(saved_buildings: Array):
	for child in buildings_root.get_children():
		child.free()

	for entry in saved_buildings:
		var building_id = StringName(entry.get("building_id", ""))
		var raw_position = entry.get("position", [0.0, 0.0, 0.0])
		var position = Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))
		var rotation_y = float(entry.get("rotation_y", 0.0))
		build_system.spawn_saved_building(building_id, position, rotation_y)


func _on_building_placed(_building_id: StringName, _position: Vector3, _rotation_y: float):
	_on_state_changed()


func _on_state_changed():
	if is_loading:
		return
	save_game()
