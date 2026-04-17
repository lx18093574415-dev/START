class_name ResourceNode
extends Node3D

signal amount_changed(node_id: String, remaining_amount: int)
signal depleted(node_id: String)

const NODE_HEIGHT := 1.5
const SPAWN_SCALE := 0.22
const SPAWN_DURATION := 0.32

var node_id := ""
var resource_data: ResourceData
var resource_id: StringName
var gather_time := 2.0
var current_amount := 0
var visual_target_scale := Vector3.ONE


func configure(node_id_value: String, data: ResourceData, amount: int):
	node_id = node_id_value
	resource_data = data
	resource_id = data.resource_id
	gather_time = data.gather_time
	current_amount = amount
	_apply_visuals()


func gather(amount: int) -> int:
	if current_amount <= 0:
		return 0

	var gathered = min(amount, current_amount)
	current_amount -= gathered
	amount_changed.emit(node_id, current_amount)

	if current_amount <= 0:
		depleted.emit(node_id)
		queue_free()

	return gathered


func _apply_visuals():
	if resource_data == null:
		return

	var mesh_instance: MeshInstance3D = $MeshInstance3D
	var material = mesh_instance.material_override
	if material != null:
		material = material.duplicate()
		mesh_instance.material_override = material
	if material is StandardMaterial3D:
		material.albedo_color = resource_data.node_color

	visual_target_scale = Vector3(resource_data.node_size.x, NODE_HEIGHT, resource_data.node_size.y)
	mesh_instance.scale = visual_target_scale * SPAWN_SCALE
	mesh_instance.position = Vector3(0, NODE_HEIGHT * 0.2, 0)

	var collision_shape: CollisionShape3D = $StaticBody3D/CollisionShape3D
	collision_shape.position = Vector3(0, NODE_HEIGHT * 0.5, 0)
	var shape = collision_shape.shape
	if shape != null:
		shape = shape.duplicate()
		collision_shape.shape = shape
	if shape is BoxShape3D:
		shape.size = Vector3(resource_data.node_size.x, NODE_HEIGHT, resource_data.node_size.y)

	_play_spawn_intro(mesh_instance)


func _play_spawn_intro(mesh_instance: MeshInstance3D):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_instance, "scale", visual_target_scale, SPAWN_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh_instance, "position", Vector3(0, NODE_HEIGHT * 0.5, 0), SPAWN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
