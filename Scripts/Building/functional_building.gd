class_name FunctionalBuilding
extends Node3D

@export var building_id: StringName
@export var cycle_time := 4.0
@export var input_costs: Dictionary = {}
@export var output_yields: Dictionary = {}
@export var harvest_resource_ids: Array[StringName] = []
@export var harvest_radius := 8.0
@export var harvest_amount := 2
@export var active_tint := Color(1.08, 1.08, 1.08, 1.0)
@export var idle_tint := Color(0.82, 0.82, 0.82, 1.0)
@export var show_range_indicator := true
@export var range_indicator_color := Color(1.0, 0.75, 0.25, 0.3)

@onready var gm = get_node_or_null("/root/Main/GameManager")
@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")
@onready var world_resources: Node3D = get_node_or_null("/root/Main/WorldResources")

const STATUS_IDLE := "\u5f85\u673a"
const STATUS_WORKING := "\u5de5\u4f5c\u4e2d"
const STATUS_DISCONNECTED := "\u672a\u8fde\u63a5"
const STATUS_RESOURCES_LAYER_MISSING := "\u672a\u8fde\u63a5\u8d44\u6e90\u5c42"
const STATUS_OUTPUT_NOT_CONFIGURED := "\u672a\u914d\u7f6e\u4ea7\u51fa"
const STATUS_NO_RESOURCE_IN_RANGE := "\u8303\u56f4\u5185\u65e0\u8d44\u6e90"
const STATUS_INPUTS_MISSING := "\u539f\u6599\u4e0d\u8db3"

var cycle_progress := 0.0
var base_material: Material
var base_albedo := Color(1, 1, 1, 1)
var range_material: StandardMaterial3D
var range_marker_material: StandardMaterial3D

var current_status_text := STATUS_IDLE
var current_status_color := Color(0.92, 0.92, 0.92, 1.0)
var current_activity_text := ""
var current_progress_ratio := 0.0


func _ready():
	set_meta("building_id", building_id)
	_cache_base_material()
	_setup_range_indicator()
	set_range_indicator_visible(false)
	_set_visual_active(false)
	_update_runtime_info(_get_activity_text(null), STATUS_IDLE, Color(0.92, 0.92, 0.92, 1.0), 0.0)


func _process(delta):
	if gm == null:
		_set_visual_active(false)
		_update_runtime_info(_get_activity_text(null), STATUS_DISCONNECTED, Color(1.0, 0.5, 0.5, 1.0), 0.0)
		return

	if _is_harvester() and world_resources == null:
		cycle_progress = 0.0
		_set_visual_active(false)
		_update_runtime_info(_get_activity_text(null), STATUS_RESOURCES_LAYER_MISSING, Color(1.0, 0.5, 0.5, 1.0), 0.0)
		return

	if not _is_harvester() and output_yields.is_empty():
		cycle_progress = 0.0
		_set_visual_active(false)
		_update_runtime_info(_get_activity_text(null), STATUS_OUTPUT_NOT_CONFIGURED, Color(1.0, 0.8, 0.4, 1.0), 0.0)
		return

	var active_resource_node: ResourceNode = null
	if _is_harvester():
		active_resource_node = _find_nearby_resource_node()
		if active_resource_node == null:
			cycle_progress = 0.0
			_set_visual_active(false)
			_update_runtime_info(_get_activity_text(null), STATUS_NO_RESOURCE_IN_RANGE, Color(1.0, 0.72, 0.4, 1.0), 0.0)
			return

	if not input_costs.is_empty() and not gm.has_resources(input_costs):
		cycle_progress = 0.0
		_set_visual_active(false)
		_update_runtime_info(_get_activity_text(active_resource_node), STATUS_INPUTS_MISSING, Color(1.0, 0.6, 0.4, 1.0), 0.0)
		return

	cycle_progress += delta
	_set_visual_active(true)
	_update_runtime_info(
		_get_activity_text(active_resource_node),
		STATUS_WORKING,
		Color(0.45, 1.0, 0.55, 1.0),
		clampf(cycle_progress / cycle_time, 0.0, 1.0)
	)
	if cycle_progress < cycle_time:
		return

	cycle_progress -= cycle_time
	if _try_run_cycle():
		_set_visual_active(true)
		_update_runtime_info(
			_get_activity_text(active_resource_node),
			STATUS_WORKING,
			Color(0.45, 1.0, 0.55, 1.0),
			clampf(cycle_progress / cycle_time, 0.0, 1.0)
		)
	else:
		cycle_progress = 0.0
		_set_visual_active(false)
		_update_runtime_info(_get_activity_text(active_resource_node), STATUS_IDLE, Color(0.92, 0.92, 0.92, 1.0), 0.0)


func _try_run_cycle() -> bool:
	if _is_harvester():
		return _try_harvest_cycle()

	if not input_costs.is_empty() and not gm.spend_resources(input_costs):
		return false

	for resource_id in output_yields.keys():
		gm.add_resource(StringName(resource_id), int(output_yields[resource_id]))
	return true


func _try_harvest_cycle() -> bool:
	var resource_node = _find_nearby_resource_node()
	if resource_node == null:
		return false

	var gathered = resource_node.gather(harvest_amount)
	if gathered <= 0:
		return false

	gm.add_resource(resource_node.resource_id, gathered)
	return true


func _cache_base_material():
	if mesh_instance == null:
		return

	base_material = mesh_instance.material_override
	if base_material == null and mesh_instance.mesh != null:
		base_material = mesh_instance.mesh.material
	if base_material != null:
		base_material = base_material.duplicate()
		mesh_instance.material_override = base_material
		if base_material is StandardMaterial3D:
			base_albedo = (base_material as StandardMaterial3D).albedo_color


func _set_visual_active(is_active: bool):
	if base_material == null:
		_update_range_indicator(is_active)
		return

	var tint = active_tint if is_active else idle_tint
	if base_material is StandardMaterial3D:
		var material := base_material as StandardMaterial3D
		material.albedo_color = base_albedo.lerp(tint, 0.08)
	_update_range_indicator(is_active)


func _is_harvester() -> bool:
	return not harvest_resource_ids.is_empty()


func _find_nearby_resource_node() -> ResourceNode:
	if world_resources == null:
		return null

	var best_node: ResourceNode
	var best_distance_sq := INF
	var max_distance_sq = harvest_radius * harvest_radius

	for child in world_resources.get_children():
		var resource_node = child as ResourceNode
		if resource_node == null:
			continue
		if resource_node.current_amount <= 0:
			continue
		if not harvest_resource_ids.has(resource_node.resource_id):
			continue

		var distance_sq = global_position.distance_squared_to(resource_node.global_position)
		if distance_sq > max_distance_sq:
			continue
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_node = resource_node

	return best_node


func _setup_range_indicator():
	if not _is_harvester() or not show_range_indicator:
		return

	var range_indicator := get_node_or_null("HarvestRangeIndicator") as MeshInstance3D
	if range_indicator == null:
		range_indicator = MeshInstance3D.new()
		range_indicator.name = "HarvestRangeIndicator"
		add_child(range_indicator)

	var disk := CylinderMesh.new()
	disk.top_radius = harvest_radius
	disk.bottom_radius = harvest_radius
	disk.height = 0.08
	disk.radial_segments = 64
	range_indicator.mesh = disk
	range_indicator.position = Vector3(0, 0.18, 0)
	range_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	range_material = StandardMaterial3D.new()
	range_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	range_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	range_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	range_material.emission_enabled = true
	range_material.emission = range_indicator_color
	range_material.albedo_color = range_indicator_color
	range_indicator.material_override = range_material

	_setup_range_markers()


func set_range_indicator_visible(is_visible: bool):
	var range_indicator := get_node_or_null("HarvestRangeIndicator")
	if range_indicator != null:
		range_indicator.visible = is_visible

	var marker_root := get_node_or_null("HarvestRangeMarkers")
	if marker_root != null:
		marker_root.visible = is_visible


func _update_range_indicator(is_active: bool):
	if range_material == null:
		return

	var target_color = range_indicator_color
	if is_active:
		target_color = range_indicator_color.lightened(0.18)
		target_color.a = min(range_indicator_color.a + 0.08, 0.42)
	range_material.albedo_color = target_color
	range_material.emission = target_color
	if range_marker_material != null:
		range_marker_material.albedo_color = target_color
		range_marker_material.emission = target_color


func _setup_range_markers():
	var marker_root := get_node_or_null("HarvestRangeMarkers") as Node3D
	if marker_root == null:
		marker_root = Node3D.new()
		marker_root.name = "HarvestRangeMarkers"
		add_child(marker_root)

	for child in marker_root.get_children():
		child.queue_free()

	range_marker_material = StandardMaterial3D.new()
	range_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	range_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	range_marker_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	range_marker_material.emission_enabled = true
	range_marker_material.emission = range_indicator_color
	range_marker_material.albedo_color = range_indicator_color

	var offsets := [
		Vector3(harvest_radius, 0.4, 0),
		Vector3(-harvest_radius, 0.4, 0),
		Vector3(0, 0.4, harvest_radius),
		Vector3(0, 0.4, -harvest_radius),
	]

	for offset in offsets:
		var marker := MeshInstance3D.new()
		marker.mesh = BoxMesh.new()
		marker.position = offset
		marker.scale = Vector3(0.18, 0.8, 0.18)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.material_override = range_marker_material
		marker_root.add_child(marker)


func _update_runtime_info(activity_text: String, status_text: String, status_color: Color, progress_ratio: float):
	current_activity_text = activity_text
	current_status_text = status_text
	current_status_color = status_color
	current_progress_ratio = progress_ratio


func get_activity_display() -> String:
	return current_activity_text


func get_status_display() -> String:
	return current_status_text


func get_status_color() -> Color:
	return current_status_color


func get_progress_ratio() -> float:
	return current_progress_ratio


func _get_activity_text(active_resource_node: ResourceNode) -> String:
	if _is_harvester():
		if active_resource_node != null:
			return "\u91c7\u96c6\uff1a%s" % _get_resource_label(active_resource_node.resource_id)
		if harvest_resource_ids.is_empty():
			return "\u91c7\u96c6\uff1a\u672a\u914d\u7f6e"
		if harvest_resource_ids.size() == 1:
			return "\u91c7\u96c6\uff1a%s" % _get_resource_label(harvest_resource_ids[0])
		return "\u91c7\u96c6\uff1a%s / %s" % [_get_resource_label(harvest_resource_ids[0]), _get_resource_label(harvest_resource_ids[1])]

	if not output_yields.is_empty():
		var first_output = output_yields.keys()[0]
		return "\u52a0\u5de5\uff1a%s" % _get_resource_label(StringName(first_output))

	return "\u529f\u80fd\uff1a\u672a\u914d\u7f6e"


func _get_resource_label(resource_id: StringName) -> String:
	if gm == null:
		return str(resource_id)
	return gm.get_resource_label(resource_id)
