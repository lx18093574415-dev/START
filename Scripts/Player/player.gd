extends CharacterBody3D

@export var grid_size = 1
@export var speed = 6.0
@export var gather_rate = 2
@export var buildings: Array[BuildingData]

var build_scene
var current_building = "house"
var current_building_data: BuildingData

@onready var camera = get_viewport().get_camera_3d()
@onready var grid = get_node("/root/Main/Ground/GridOverlay")
@onready var wood_label = get_node("/root/Main/UI/Label")
@onready var stone_label = get_node("/root/Main/UI/Label2")
@onready var gm = get_node("/root/Main/GameManager")

var preview_house = null
var can_build = false
var build_rotation = 0.0

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


func _ready():
	current_building_data = buildings[0]
	build_scene = current_building_data.scene
	switch_preview(current_building_data.preview)

	var mat = grid.material_override
	if mat == null:
		push_error("❌ Grid 没材质")
		return

	mat = mat.duplicate()
	grid.material_override = mat

	mat.set("shader_parameter/highlight_pos", Vector3.ZERO)
	mat.set("shader_parameter/highlight_area", Vector2.ONE)
	mat.set("shader_parameter/grid_size", grid_size)


func _process(delta):
	var mat = grid.material_override
	if mat == null or not mat is ShaderMaterial:
		return
	if mat.shader == null:
		return

	grid.visible = gm.is_build_mode

	if gm.is_build_mode:
		if preview_house and preview_house.is_inside_tree():
			var result = get_mouse_result()

			if result:
				var pos = result.position

				# ✅ 核心：中心对齐（唯一方案）
				var snapped_x = floor(pos.x / grid_size) * grid_size
				var snapped_z = floor(pos.z / grid_size) * grid_size

				preview_house.visible = true

				var mesh = preview_house.get_node("jidipreview")
				var aabb = mesh.get_aabb()
				var scale = mesh.global_transform.basis.get_scale()
				var size = aabb.size * scale

				var current_size_x = round(size.x)
				var current_size_z = round(size.z)
				print("真实尺寸:", size)

				# 👉 旋转修正尺寸
				if int(build_rotation / deg_to_rad(90)) % 2 == 1:
					var temp = current_size_x
					current_size_x = current_size_z
					current_size_z = temp

				# ✅ 高亮（中心）
				var highlight_pos = Vector3(
					snapped_x,
					0,
					snapped_z
				)
				mat.set("shader_parameter/highlight_pos", highlight_pos)
				mat.set("shader_parameter/highlight_area",
					Vector2(current_size_x, current_size_z)
				)

				# ✅ 蓝图位置（中心）
				var snapped_pos = Vector3(snapped_x, pos.y, snapped_z)
				preview_house.global_position = snapped_pos
				preview_house.rotation.y = build_rotation

				# ✅ 建造检测
				can_build = true
				var area = preview_house.get_node("BuildCheck")
				var bodies = area.get_overlapping_bodies()

				for body in bodies:
					if body == preview_house:
						continue
					if body.get_parent() == preview_house:
						continue
					if body.collision_layer & 2:
						can_build = false
						break

				if can_build:
					mat.set("shader_parameter/highlight_color", Color(0,1,0,0.3))
				else:
					mat.set("shader_parameter/highlight_color", Color(1,0,0,0.3))
	else:
		if preview_house:
			preview_house.visible = false


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			build_rotation += deg_to_rad(90)

		if event.keycode == KEY_1:
			current_building_data = buildings[0]
			build_scene = current_building_data.scene
			switch_preview(current_building_data.preview)

		if event.keycode == KEY_2:
			current_building_data = buildings[1]
			build_scene = current_building_data.scene
			switch_preview(current_building_data.preview)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if gm.is_build_mode:
			var result = get_mouse_result()

			if result and can_build:
				var pos = result.position

				var snapped_x = floor(pos.x / grid_size) * grid_size
				var snapped_z = floor(pos.z / grid_size) * grid_size

				var snapped_pos = Vector3(snapped_x, pos.y, snapped_z)

				var building = build_scene.instantiate()
				get_node("/root/Main").add_child(building)

				building.global_position = snapped_pos
				building.rotation.y = build_rotation

				gm.consume_build_cost()
				wood_label.text = "木头：" + str(gm.wood)

				gm.is_build_mode = false
				preview_house.visible = false


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

					var amount = min(gather_rate, target_resource.current_amount)
					target_resource.current_amount -= amount

					if target_resource.resource_type == "wood":
						gm.add_wood(amount)
						wood_label.text = "木头：" + str(gm.wood)

					elif target_resource.resource_type == "stone":
						gm.add_stone(amount)
						stone_label.text = "石头：" + str(gm.stone)

					if target_resource.current_amount <= 0:
						target_resource.queue_free()
						target_resource = null
						has_target = false

	move_and_slide()


func switch_preview(scene: PackedScene):
	if scene == null:
		push_error("❌ preview scene 是空的")
		return

	if preview_house:
		preview_house.queue_free()

	var new_preview = scene.instantiate()
	if new_preview == null:
		push_error("❌ preview 实例化失败")
		return

	add_child(new_preview)
	preview_house = new_preview


func get_mouse_result():
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_dir * 1000

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	return space_state.intersect_ray(query)
