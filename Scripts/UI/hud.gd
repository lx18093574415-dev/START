extends CanvasLayer

@onready var build_button: Button = $BuildButton
@onready var resource_list: VBoxContainer = $ResourceList
@onready var gm = get_node("../GameManager")
@onready var player: CharacterBody3D = get_node("../Player")
@onready var build_system = get_node("../BuildSystem")

var building_info_panel: PanelContainer
var building_name_label: Label
var building_status_label: Label
var building_activity_label: Label
var building_progress_bar: ProgressBar
var selected_building: FunctionalBuilding


func _ready():
	build_button.text = "\u5efa\u9020"
	gm.resources_changed.connect(_refresh_resources)
	if player != null and player.has_signal("selected_building_changed"):
		player.selected_building_changed.connect(_on_selected_building_changed)
	_build_building_info_panel()
	_refresh_resources()
	_refresh_building_info()


func _process(_delta):
	if selected_building == null or not is_instance_valid(selected_building):
		if building_info_panel != null:
			building_info_panel.visible = false
		return

	_refresh_building_info()


func _refresh_resources():
	for child in resource_list.get_children():
		child.queue_free()

	for resource_def in gm.get_visible_resources():
		var label = Label.new()
		label.text = "%s: %d" % [resource_def.display_name, gm.get_resource_amount(resource_def.resource_id)]
		label.add_theme_font_size_override("font_size", 18)
		resource_list.add_child(label)


func _build_building_info_panel():
	building_info_panel = PanelContainer.new()
	building_info_panel.name = "BuildingInfoPanel"
	building_info_panel.offset_left = 16
	building_info_panel.offset_top = 300
	building_info_panel.offset_right = 270
	building_info_panel.offset_bottom = 430
	building_info_panel.visible = false
	add_child(building_info_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.1, 0.84)
	panel_style.border_color = Color(0.34, 0.48, 0.42, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	building_info_panel.add_theme_stylebox_override("panel", panel_style)

	var content := MarginContainer.new()
	content.add_theme_constant_override("margin_left", 14)
	content.add_theme_constant_override("margin_top", 12)
	content.add_theme_constant_override("margin_right", 14)
	content.add_theme_constant_override("margin_bottom", 12)
	building_info_panel.add_child(content)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	content.add_child(layout)

	building_name_label = Label.new()
	building_name_label.add_theme_font_size_override("font_size", 24)
	layout.add_child(building_name_label)

	building_status_label = Label.new()
	building_status_label.add_theme_font_size_override("font_size", 20)
	layout.add_child(building_status_label)

	building_activity_label = Label.new()
	building_activity_label.add_theme_font_size_override("font_size", 20)
	building_activity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(building_activity_label)

	building_progress_bar = ProgressBar.new()
	building_progress_bar.min_value = 0
	building_progress_bar.max_value = 100
	building_progress_bar.show_percentage = false
	building_progress_bar.custom_minimum_size = Vector2(0, 14)
	layout.add_child(building_progress_bar)


func _on_selected_building_changed(building: FunctionalBuilding):
	selected_building = building
	_refresh_building_info()


func _refresh_building_info():
	if building_info_panel == null:
		return

	if selected_building == null or not is_instance_valid(selected_building):
		building_info_panel.visible = false
		return

	var building_data = build_system.get_building_by_id(selected_building.building_id)
	var building_name = selected_building.building_id
	if building_data != null and building_data.display_name != "":
		building_name = building_data.display_name

	building_info_panel.visible = true
	building_name_label.text = str(building_name)
	building_status_label.text = "\u72b6\u6001\uff1a%s" % selected_building.get_status_display()
	building_status_label.modulate = selected_building.get_status_color()
	building_activity_label.text = selected_building.get_activity_display()
	building_progress_bar.value = selected_building.get_progress_ratio() * 100.0
