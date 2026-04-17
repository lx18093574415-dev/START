class_name BuildMenu
extends PanelContainer

signal category_selected(category: StringName)
signal building_selected(building_data: BuildingData)
signal cancel_requested()

const FALLBACK_ICON = preload("res://icon.svg")

@onready var category_buttons: HBoxContainer = $MarginContainer/Root/CategoryButtons
@onready var building_list: VBoxContainer = $MarginContainer/Root/ContentScroll/BuildingList
@onready var empty_label: Label = $MarginContainer/Root/EmptyLabel
@onready var cancel_button: Button = $MarginContainer/Root/CancelButton

var category_order: Array[StringName] = []
var category_labels := {}
var resource_order: Array[StringName] = []
var resource_labels := {}
var current_category: StringName = &"residential"
var current_selected_id := StringName()
var available_buildings: Array[BuildingData] = []
var affordability := {}


func _ready():
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	hide_menu()


func update_state(categories: Array[StringName], labels: Dictionary, costs_order: Array[StringName], cost_labels: Dictionary, category: StringName, buildings: Array[BuildingData], affordable_map: Dictionary, selected_id: StringName):
	category_order = categories
	category_labels = labels
	resource_order = costs_order
	resource_labels = cost_labels
	current_category = category
	available_buildings = buildings
	affordability = affordable_map
	current_selected_id = selected_id
	_render()


func show_menu():
	visible = true


func hide_menu():
	visible = false


func _render():
	_render_categories()
	_clear_building_list()

	var buildings_in_category: Array[BuildingData] = []
	for building in available_buildings:
		if building.category == current_category:
			buildings_in_category.append(building)

	empty_label.visible = buildings_in_category.is_empty()
	if empty_label.visible:
		empty_label.text = "No buildings available."
		return

	for building in buildings_in_category:
		var button = Button.new()
		button.custom_minimum_size = Vector2(280, 86)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = building.icon if building.icon != null else FALLBACK_ICON
		button.expand_icon = true
		button.toggle_mode = true
		button.button_pressed = building.building_id == current_selected_id
		button.text = _format_building_text(building)
		button.pressed.connect(_on_building_button_pressed.bind(building))
		building_list.add_child(button)


func _render_categories():
	for child in category_buttons.get_children():
		child.queue_free()

	for category in category_order:
		var button = Button.new()
		button.text = _format_category_text(category)
		button.toggle_mode = true
		button.button_pressed = category == current_category
		button.pressed.connect(_on_category_button_pressed.bind(category))
		category_buttons.add_child(button)


func _format_building_text(building: BuildingData) -> String:
	var lines = [building.display_name]
	if building.description != "":
		lines.append(building.description)

	var cost_parts: Array[String] = []
	for resource_id in _sort_cost_keys(building.build_costs):
		var amount = int(building.build_costs[resource_id])
		var label = resource_labels.get(StringName(resource_id), str(resource_id))
		cost_parts.append("%s %d" % [label, amount])

	lines.append("Cost: %s" % ", ".join(cost_parts))

	if not affordability.get(building.building_id, false):
		lines.append("Insufficient resources")

	return "\n".join(lines)


func _sort_cost_keys(costs: Dictionary) -> Array:
	var ordered_keys: Array = []
	for resource_id in resource_order:
		if costs.has(resource_id):
			ordered_keys.append(resource_id)
		elif costs.has(str(resource_id)):
			ordered_keys.append(str(resource_id))

	for resource_id in costs.keys():
		if not ordered_keys.has(resource_id):
			ordered_keys.append(resource_id)

	return ordered_keys


func _format_category_text(category: StringName) -> String:
	var label = category_labels.get(category, str(category))
	if category == current_category:
		return "> %s" % label
	return label


func _clear_building_list():
	for child in building_list.get_children():
		child.queue_free()


func _on_category_button_pressed(category: StringName):
	category_selected.emit(category)


func _on_building_button_pressed(building: BuildingData):
	building_selected.emit(building)


func _on_cancel_button_pressed():
	cancel_requested.emit()
