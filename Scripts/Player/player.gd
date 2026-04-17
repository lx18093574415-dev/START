extends CharacterBody3D

@export var speed = 6.0
@export var gather_rate = 2

@onready var camera = get_viewport().get_camera_3d()
@onready var build_system = get_node("/root/Main/BuildSystem")
@onready var gm = get_node("/root/Main/GameManager")

var target_position: Vector3
var has_target = false
var target_resource = null
var gather_timer = 0.0


func safe_value(value, default):
	if value == null:
		return default
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return value
	return default


func _input(event):
	if build_system and build_system.is_build_mode_active():
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var result = get_mouse_result()

		if result:
			var collider = result.collider
			var parent = collider.get_parent()

			if parent != null and "current_amount" in parent:
				target_resource = parent
				target_position = parent.global_transform.origin
				has_target = true
			else:
				target_resource = null
				target_position = result.position
				has_target = true


func _physics_process(delta):
	if has_target:
		var direction = target_position - global_transform.origin
		direction.y = 0

		if direction.length() > 1.5:
			direction = direction.normalized()
			var real_speed = safe_value(speed, 6.0)
			velocity.x = direction.x * real_speed
			velocity.z = direction.z * real_speed
		else:
			velocity = Vector3.ZERO

			if target_resource != null and is_instance_valid(target_resource):
				gather_timer += delta

				if gather_timer >= target_resource.gather_time:
					gather_timer = 0.0
					var gathered = target_resource.gather(gather_rate)
					if gathered > 0:
						gm.add_resource(target_resource.resource_id, gathered)

					if target_resource.current_amount <= 0:
						target_resource = null
						has_target = false

	move_and_slide()


func get_mouse_result():
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_dir * 1000

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	return space_state.intersect_ray(query)
