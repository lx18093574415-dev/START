class_name BuildPreview
extends Node3D


func configure_from_data(building_data: BuildingData):
	setup_build_area(building_data.size)


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
