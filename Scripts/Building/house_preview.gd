extends Node3D

func _ready():
	await get_tree().process_frame   # ❗必须等一帧

	var shape_node = $BuildCheck/CollisionShape3D
	var shape = shape_node.shape

	var mesh = $jidipreview

	var aabb = mesh.get_aabb()
	var scale = mesh.global_transform.basis.get_scale()
	var size = aabb.size * scale   # 👉 世界尺寸

	var size_x = round(size.x)
	var size_z = round(size.z)

	print("Preview尺寸:", size)

	shape.size.x = size_x
	shape.size.z = size_z

	shape_node.position.x = 0
	shape_node.position.z = 0
