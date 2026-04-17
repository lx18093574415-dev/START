class_name BuildMenu
extends PanelContainer

signal category_selected(category: StringName)
signal building_selected(building_data: BuildingData)
signal cancel_requested()

const CATEGORY_LABELS := {
	&"housing": "Housing",
	&"storage": "Storage",
	&"production": "Production",
}
const FALLBACK_ICON = preload("res://icon.svg")

@onready var housing_button: Button = $MarginContainer/Root/CategoryRow/HousingButton
@onready var storage_button: Button = $MarginContainer/Root/CategoryRow/StorageButton
@onready var production_button: Button = $MarginContainer/Root/CategoryRow/ProductionButton
@onready var building_list: VBoxContainer = $MarginContainer/Root/ContentScroll/BuildingList
@onready var empty_label: Label = $MarginContainer/Root/EmptyLabel
@onready var cancel_button: Button = $MarginContainer/Root/CancelButton

var current_category: StringName = &"housing"
var current_selected_id := StringName()
var available_buildings: Array[BuildingData] = []
var affordability := {}


func _ready():
	housing_button.pressed.connect(_on_category_button_pressed.bind(&"housing"))
	storage_button.pressed.connect(_on_category_button_pressed.bind(&"storage"))
	production_button.pressed.connect(_on_category_button_pressed.bind(&"production"))
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	hide_menu()


func update_state(category: StringName, buildings: Array[BuildingData], affordable_map: Dictionary, selected_id: StringName):
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
	_update_category_labels()
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
		button.custom_minimum_size = Vector2(260, 72)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = building.icon if building.icon != null else FALLBACK_ICON
		button.expand_icon = true
		button.toggle_mode = true
		button.button_pressed = building.building_id == current_selected_id
		button.text = _format_building_text(building)
		button.pressed.connect(_on_building_button_pressed.bind(building))
		building_list.add_child(button)


func _format_building_text(building: BuildingData) -> String:
	var lines = [
		building.display_name,
		"Wood: %d  Stone: %d" % [building.cost_wood, building.cost_stone],
	]

	if not affordability.get(building.building_id, false):
		lines.append("Insufficient resources")

	return "\n".join(lines)


func _update_category_labels():
	housing_button.text = _format_category_text(&"housing")
	storage_button.text = _format_category_text(&"storage")
	production_button.text = _format_category_text(&"production")


func _format_category_text(category: StringName) -> String:
	if category == current_category:
		return "> %s" % CATEGORY_LABELS[category]

	return CATEGORY_LABELS[category]


func _clear_building_list():
	for child in building_list.get_children():
		child.queue_free()


func _on_category_button_pressed(category: StringName):
	category_selected.emit(category)


func _on_building_button_pressed(building: BuildingData):
	building_selected.emit(building)


func _on_cancel_button_pressed():
	cancel_requested.emit()
