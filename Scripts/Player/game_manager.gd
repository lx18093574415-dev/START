extends Node

signal resources_changed

const RESOURCE_DIR := "res://Data/Resources"

var resource_catalog: Array[ResourceData] = []
var resource_defs_by_id := {}
var inventory := {}


func _ready():
	_load_resource_catalog()
	_ensure_inventory_defaults()
	resources_changed.emit()


func add_resource(resource_id: StringName, amount: int):
	var key = str(resource_id)
	inventory[key] = get_resource_amount(resource_id) + amount
	resources_changed.emit()


func get_resource_amount(resource_id: StringName) -> int:
	return int(inventory.get(str(resource_id), 0))


func has_resources(costs: Dictionary) -> bool:
	for resource_id in costs.keys():
		if get_resource_amount(StringName(resource_id)) < int(costs[resource_id]):
			return false

	return true


func spend_resources(costs: Dictionary) -> bool:
	if not has_resources(costs):
		return false

	for resource_id in costs.keys():
		var key = str(resource_id)
		inventory[key] = get_resource_amount(StringName(resource_id)) - int(costs[resource_id])

	resources_changed.emit()
	return true


func apply_inventory(saved_inventory: Dictionary):
	inventory.clear()
	_ensure_inventory_defaults()

	for resource_id in saved_inventory.keys():
		inventory[str(resource_id)] = int(saved_inventory[resource_id])

	resources_changed.emit()


func export_inventory() -> Dictionary:
	return inventory.duplicate(true)


func get_resource_catalog() -> Array[ResourceData]:
	return resource_catalog.duplicate()


func get_resource_def(resource_id: StringName) -> ResourceData:
	return resource_defs_by_id.get(resource_id)


func get_resource_label(resource_id: StringName) -> String:
	var resource_def = get_resource_def(resource_id)
	if resource_def == null:
		return str(resource_id)
	return resource_def.display_name


func get_resource_labels() -> Dictionary:
	var labels := {}
	for resource_def in resource_catalog:
		labels[resource_def.resource_id] = resource_def.display_name
	return labels


func get_resource_order() -> Array[StringName]:
	var order: Array[StringName] = []
	for resource_def in resource_catalog:
		order.append(resource_def.resource_id)
	return order


func get_visible_resources() -> Array[ResourceData]:
	var visible_resources: Array[ResourceData] = []
	for resource_def in resource_catalog:
		if resource_def.spawnable or get_resource_amount(resource_def.resource_id) > 0:
			visible_resources.append(resource_def)
	return visible_resources


func _load_resource_catalog():
	resource_catalog.clear()
	resource_defs_by_id.clear()

	var files = DirAccess.get_files_at(RESOURCE_DIR)
	files.sort()

	for file_name in files:
		if file_name.get_extension() != "tres":
			continue

		var loaded = load(RESOURCE_DIR.path_join(file_name))
		if loaded is ResourceData:
			resource_catalog.append(loaded)
			resource_defs_by_id[loaded.resource_id] = loaded

	resource_catalog.sort_custom(func(a: ResourceData, b: ResourceData): return a.sort_order < b.sort_order)


func _ensure_inventory_defaults():
	for resource_def in resource_catalog:
		var key = str(resource_def.resource_id)
		if not inventory.has(key):
			inventory[key] = 0
