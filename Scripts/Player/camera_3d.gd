extends Camera3D

@export var target: Node3D
@export var follow_smoothing := 7.5
@export var camera_pitch_degrees := 52.0
@export var camera_yaw_degrees := -45.0
@export var camera_distance := 22.0
@export var camera_height := 19.0
@export var look_ahead := 2.0


func _ready():
	top_level = true
	fov = 42.0
	_update_rotation()
	_snap_to_target()


func _process(delta):
	if target == null:
		return

	_update_rotation()

	var desired_position = _get_desired_position()
	global_position = global_position.lerp(desired_position, clampf(delta * follow_smoothing, 0.0, 1.0))


func _get_desired_position() -> Vector3:
	var yaw = deg_to_rad(camera_yaw_degrees)
	var target_anchor = target.global_position + Vector3(0.0, 0.0, -look_ahead)
	var planar_offset = Vector3(
		sin(yaw) * camera_distance,
		0.0,
		cos(yaw) * camera_distance
	)
	return target_anchor + planar_offset + Vector3(0.0, camera_height, 0.0)


func _update_rotation():
	rotation_degrees = Vector3(-camera_pitch_degrees, camera_yaw_degrees, 0.0)


func _snap_to_target():
	if target == null:
		return
	global_position = _get_desired_position()
