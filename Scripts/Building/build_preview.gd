class_name BuildPreview
extends Node3D

var range_material: StandardMaterial3D
var range_marker_material: StandardMaterial3D


func configure_from_data(building_data: BuildingData):
	setup_build_area(building_data.size)
	_setup_range_indicator(building_data.preview_range_radius, building_data.preview_range_color)


func setup_build_area(footprint: Vector2):
	var shape_node = $BuildCheck/CollisionShape3D
	var shape = shape_node.shape

	shape.size = Vector3(footprint.x, 2.0, footprint.y)
	shape_node.position = Vector3(0, 1.0, 0)

	var highlight = get_node_or_null("Highlight")
	if highlight:
		var plane := highlight.mesh as PlaneMesh
		if plane:
			plane.size = footprint
		highlight.position = Vector3(0, 0.03, 0)


func set_buildable(is_buildable: bool):
	var highlight = get_node_or_null("Highlight")
	if highlight == null:
		return

	var mat = highlight.material_override
	if mat is StandardMaterial3D:
		mat.albedo_color = Color(0, 1, 0, 0.35) if is_buildable else Color(1, 0, 0, 0.35)


func is_area_free() -> bool:
	var area = get_node_or_null("BuildCheck")
	if area == null:
		return false

	var bodies = area.get_overlapping_bodies()
	for body in bodies:
		if body == self:
			continue
		if body.get_parent() == self:
			continue
		if body.collision_layer & 2:
			return false

	return true


func _setup_range_indicator(radius: float, indicator_color: Color):
	var range_indicator := get_node_or_null("HarvestRangeIndicator") as MeshInstance3D
	var marker_root := get_node_or_null("HarvestRangeMarkers")
	if radius <= 0.0:
		if range_indicator != null:
			range_indicator.queue_free()
		if marker_root != null:
			marker_root.queue_free()
		return

	if range_indicator == null:
		range_indicator = MeshInstance3D.new()
		range_indicator.name = "HarvestRangeIndicator"
		add_child(range_indicator)

	var disk := CylinderMesh.new()
	disk.top_radius = radius
	disk.bottom_radius = radius
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
	range_material.emission = indicator_color
	range_material.albedo_color = indicator_color
	range_indicator.material_override = range_material

	_setup_range_markers(radius, indicator_color)


func _setup_range_markers(radius: float, indicator_color: Color):
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
	range_marker_material.emission = indicator_color
	range_marker_material.albedo_color = indicator_color

	var offsets := [
		Vector3(radius, 0.4, 0),
		Vector3(-radius, 0.4, 0),
		Vector3(0, 0.4, radius),
		Vector3(0, 0.4, -radius),
	]

	for offset in offsets:
		var marker := MeshInstance3D.new()
		marker.mesh = BoxMesh.new()
		marker.position = offset
		marker.scale = Vector3(0.18, 0.8, 0.18)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.material_override = range_marker_material
		marker_root.add_child(marker)
