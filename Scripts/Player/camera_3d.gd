extends Camera3D

@export var target: Node3D

func _process(delta):
	if target:
		global_position.x = target.global_position.x + 10
		global_position.z = target.global_position.z + 10
