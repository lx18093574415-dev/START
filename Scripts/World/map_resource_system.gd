class_name MapResourceSystem
extends Node3D

signal state_changed

const MAP_DEFINITION: MapDefinition = preload("res://Data/Maps/StarterBasin.tres")
const RESOURCE_NODE_SCENE: PackedScene = preload("res://Scenes/Resource/ResourceNode.tscn")
const PROVINCE_SIZE := 3

@onready var player: Node3D = get_node("../Player")
@onready var gm = get_node("../GameManager")
@onready var resource_root: Node3D = get_node("../WorldResources")

var explored_chunks := {}
var resource_states := {}
var active_nodes := {}
var current_chunk := Vector2i(999999, 999999)


func _ready():
	if player:
		current_chunk = world_to_chunk(player.global_position)
		_explore_visible_chunks(current_chunk)


func _process(_delta):
	if player == null:
		return

	var player_chunk = world_to_chunk(player.global_position)
	if player_chunk != current_chunk:
		current_chunk = player_chunk
		_explore_visible_chunks(current_chunk)


func get_current_map_id() -> StringName:
	return MAP_DEFINITION.map_id


func apply_saved_state(map_state: Dictionary):
	explored_chunks.clear()
	resource_states.clear()

	for child in resource_root.get_children():
		child.free()
	active_nodes.clear()

	for chunk_key in map_state.get("explored_chunks", []):
		explored_chunks[str(chunk_key)] = true

	var saved_resources = map_state.get("resource_nodes", {})
	for node_id in saved_resources.keys():
		resource_states[str(node_id)] = saved_resources[node_id].duplicate(true)

	for node_id in resource_states.keys():
		var state = resource_states[node_id]
		if state.get("depleted", false):
			continue
		_spawn_resource_node(node_id, state)


func export_state() -> Dictionary:
	return {
		"explored_chunks": explored_chunks.keys(),
		"resource_nodes": resource_states.duplicate(true),
	}


func world_to_chunk(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_position.x / float(MAP_DEFINITION.chunk_size)),
		floori(world_position.z / float(MAP_DEFINITION.chunk_size))
	)


func _explore_visible_chunks(center_chunk: Vector2i):
	for x in range(center_chunk.x - MAP_DEFINITION.visible_chunk_radius, center_chunk.x + MAP_DEFINITION.visible_chunk_radius + 1):
		for y in range(center_chunk.y - MAP_DEFINITION.visible_chunk_radius, center_chunk.y + MAP_DEFINITION.visible_chunk_radius + 1):
			var chunk = Vector2i(x, y)
			if not _is_chunk_in_bounds(chunk):
				continue
			_ensure_chunk_generated(chunk)


func _ensure_chunk_generated(chunk: Vector2i):
	var chunk_key = _chunk_key(chunk)
	if explored_chunks.has(chunk_key):
		return

	explored_chunks[chunk_key] = true
	_generate_chunk(chunk)
	state_changed.emit()


func _generate_chunk(chunk: Vector2i):
	var chunk_rng = RandomNumberGenerator.new()
	chunk_rng.seed = _chunk_seed(chunk)

	var context = _get_deposit_context(chunk)
	var resource_plan = _build_resource_plan(chunk, context, chunk_rng)

	for index in range(resource_plan.size()):
		var resource_def: ResourceData = resource_plan[index]
		var spawn_state = _generate_resource_state_for_chunk(chunk, index, resource_def, context, chunk_rng)
		if spawn_state.is_empty():
			continue

		var node_id = "%s:%d" % [_chunk_key(chunk), index]
		resource_states[node_id] = spawn_state
		_spawn_resource_node(node_id, spawn_state)


func _generate_resource_state_for_chunk(chunk: Vector2i, index: int, resource_def: ResourceData, context: Dictionary, chunk_rng: RandomNumberGenerator) -> Dictionary:
	var position = _pick_spawn_position(chunk, index, chunk_rng, context)
	if position == Vector3.INF:
		return {}

	var amount = chunk_rng.randi_range(resource_def.min_amount, resource_def.max_amount)
	return {
		"resource_id": str(resource_def.resource_id),
		"position": [position.x, position.y, position.z],
		"remaining_amount": amount,
		"depleted": false,
	}


func _build_resource_plan(chunk: Vector2i, context: Dictionary, chunk_rng: RandomNumberGenerator) -> Array[ResourceData]:
	var plan: Array[ResourceData] = []
	var richness = _get_chunk_richness(chunk, context, chunk_rng)
	var node_count = 0

	if richness >= 0.8:
		node_count = 3
	elif richness >= 0.48:
		node_count = 2
	elif richness >= 0.2:
		node_count = 1

	if node_count == 0:
		return plan

	var primary_id: StringName = context.get("primary_resource", &"ferrite_ore")
	var primary = gm.get_resource_def(primary_id)
	if primary == null:
		return plan

	plan.append(primary)

	for index in range(1, node_count):
		var companion = _pick_weighted_resource(context.get("companion_weights", {}), chunk_rng)
		if companion == null:
			companion = primary
		if companion.resource_id == primary.resource_id and index == node_count - 1:
			var fallback = _pick_weighted_resource(context.get("secondary_weights", {}), chunk_rng)
			if fallback != null:
				companion = fallback
		plan.append(companion)

	return plan


func _get_deposit_context(chunk: Vector2i) -> Dictionary:
	var province = Vector2i(
		floori(float(chunk.x) / PROVINCE_SIZE),
		floori(float(chunk.y) / PROVINCE_SIZE)
	)
	var province_rng = RandomNumberGenerator.new()
	province_rng.seed = _province_seed(province)

	var thermal = sin(float(province.x) * 0.53 + MAP_DEFINITION.map_seed * 0.00041) + cos(float(province.y) * 0.37 - MAP_DEFINITION.map_seed * 0.00017)
	var cryo = cos(float(province.x) * 0.29 - float(province.y) * 0.31 + MAP_DEFINITION.map_seed * 0.00063)
	var fracture = sin(float(province.x + province.y) * 0.21 + MAP_DEFINITION.map_seed * 0.00029)

	var deposit_type: StringName = &"regolith_belt"
	if abs(province.x) <= 1 and abs(province.y) <= 1:
		deposit_type = &"regolith_belt"
	elif cryo > 0.58 and cryo > thermal * 0.35:
		deposit_type = &"cryo_basin"
	elif thermal > 0.95:
		deposit_type = &"conductive_fault"
	elif fracture > 0.48:
		deposit_type = &"crater_rim"

	var province_world_size = float(PROVINCE_SIZE * MAP_DEFINITION.chunk_size)
	var province_origin = Vector2(
		float(province.x * PROVINCE_SIZE * MAP_DEFINITION.chunk_size),
		float(province.y * PROVINCE_SIZE * MAP_DEFINITION.chunk_size)
	)
	var anchor_world = province_origin + Vector2(
		province_rng.randf_range(1.5, province_world_size - 1.5),
		province_rng.randf_range(1.5, province_world_size - 1.5)
	)
	var anchor_chunk = world_to_chunk(Vector3(anchor_world.x, 0.0, anchor_world.y))

	match deposit_type:
		&"cryo_basin":
			return {
				"deposit_type": deposit_type,
				"anchor_world": anchor_world,
				"anchor_chunk": anchor_chunk,
				"primary_resource": &"glacial_ice",
				"companion_weights": {
					&"glacial_ice": 2.0,
					&"silicate_ore": 3.0,
					&"ferrite_ore": 1.0,
				},
				"secondary_weights": {
					&"silicate_ore": 3.0,
					&"ferrite_ore": 1.0,
				},
				"richness_bias": 0.08,
				"spread": 1.6,
			}
		&"conductive_fault":
			return {
				"deposit_type": deposit_type,
				"anchor_world": anchor_world,
				"anchor_chunk": anchor_chunk,
				"primary_resource": &"conductive_crystal",
				"companion_weights": {
					&"conductive_crystal": 2.0,
					&"rare_earth_nodule": 3.0,
					&"ferrite_ore": 2.0,
				},
				"secondary_weights": {
					&"rare_earth_nodule": 3.0,
					&"ferrite_ore": 2.0,
				},
				"richness_bias": 0.03,
				"spread": 1.2,
			}
		&"crater_rim":
			return {
				"deposit_type": deposit_type,
				"anchor_world": anchor_world,
				"anchor_chunk": anchor_chunk,
				"primary_resource": &"rare_earth_nodule",
				"companion_weights": {
					&"rare_earth_nodule": 2.0,
					&"ferrite_ore": 3.0,
					&"conductive_crystal": 2.0,
					&"silicate_ore": 2.0,
				},
				"secondary_weights": {
					&"ferrite_ore": 3.0,
					&"conductive_crystal": 2.0,
					&"silicate_ore": 2.0,
				},
				"richness_bias": -0.04,
				"spread": 1.1,
			}
		_:
			return {
				"deposit_type": &"regolith_belt",
				"anchor_world": anchor_world,
				"anchor_chunk": anchor_chunk,
				"primary_resource": &"ferrite_ore",
				"companion_weights": {
					&"ferrite_ore": 2.0,
					&"silicate_ore": 4.0,
					&"conductive_crystal": 0.7,
				},
				"secondary_weights": {
					&"silicate_ore": 4.0,
					&"conductive_crystal": 0.7,
				},
				"richness_bias": 0.12,
				"spread": 1.9,
			}


func _get_chunk_richness(chunk: Vector2i, context: Dictionary, chunk_rng: RandomNumberGenerator) -> float:
	var chunk_center = Vector2(
		(float(chunk.x) + 0.5) * MAP_DEFINITION.chunk_size,
		(float(chunk.y) + 0.5) * MAP_DEFINITION.chunk_size
	)
	var anchor_world: Vector2 = context.get("anchor_world", chunk_center)
	var spread = float(context.get("spread", 1.0))
	var influence_radius = float(MAP_DEFINITION.chunk_size) * (1.1 + spread)
	var distance_factor = clampf(1.0 - chunk_center.distance_to(anchor_world) / influence_radius, 0.0, 1.0)
	var geological_noise = 0.5 + 0.5 * sin(float(chunk.x) * 0.41 + float(chunk.y) * 0.19 + MAP_DEFINITION.map_seed * 0.00031)
	geological_noise *= 0.5 + 0.5 * cos(float(chunk.y) * 0.27 - float(chunk.x) * 0.13 + MAP_DEFINITION.map_seed * 0.00023)
	var local_variation = chunk_rng.randf_range(-0.08, 0.08)
	return clampf(distance_factor * 0.72 + geological_noise * 0.22 + float(context.get("richness_bias", 0.0)) + local_variation, 0.0, 1.0)


func _pick_weighted_resource(weight_map: Dictionary, chunk_rng: RandomNumberGenerator) -> ResourceData:
	var total_weight := 0.0
	for resource_id in weight_map.keys():
		total_weight += float(weight_map[resource_id])

	if total_weight <= 0.0:
		return null

	var pick = chunk_rng.randf() * total_weight
	var cursor := 0.0
	for resource_id in weight_map.keys():
		cursor += float(weight_map[resource_id])
		if pick <= cursor:
			return gm.get_resource_def(StringName(resource_id))

	return gm.get_resource_def(StringName(weight_map.keys()[0]))


func _pick_spawn_position(chunk: Vector2i, index: int, chunk_rng: RandomNumberGenerator, context: Dictionary) -> Vector3:
	var min_x = float(chunk.x * MAP_DEFINITION.chunk_size)
	var min_z = float(chunk.y * MAP_DEFINITION.chunk_size)
	var max_x = min_x + MAP_DEFINITION.chunk_size
	var max_z = min_z + MAP_DEFINITION.chunk_size
	var chunk_center = Vector2(
		min_x + MAP_DEFINITION.chunk_size * 0.5,
		min_z + MAP_DEFINITION.chunk_size * 0.5
	)
	var anchor_world: Vector2 = context.get("anchor_world", chunk_center)
	var flow = anchor_world - chunk_center
	var local_center = chunk_center

	if flow.length() > 0.01:
		local_center += flow.normalized() * min(flow.length(), MAP_DEFINITION.chunk_size * 0.3)

	var spiral_angle = (TAU / 3.0) * float(index) + chunk_rng.randf_range(-0.45, 0.45)
	var spiral_radius = MAP_DEFINITION.chunk_size * chunk_rng.randf_range(0.08, 0.22)

	for _attempt in range(10):
		var radial = Vector2(cos(spiral_angle), sin(spiral_angle)) * spiral_radius
		radial += Vector2(
			chunk_rng.randf_range(-1.15, 1.15),
			chunk_rng.randf_range(-1.15, 1.15)
		)
		var candidate = local_center + radial
		candidate.x = clampf(candidate.x, min_x + 1.5, max_x - 1.5)
		candidate.y = clampf(candidate.y, min_z + 1.5, max_z - 1.5)
		if candidate.length() < MAP_DEFINITION.starter_clear_radius:
			spiral_angle += 0.7
			spiral_radius += 0.35
			continue
		return Vector3(candidate.x, 0.0, candidate.y)

	return Vector3.INF


func _spawn_resource_node(node_id: String, state: Dictionary):
	var resource_def = gm.get_resource_def(StringName(state.get("resource_id", "")))
	if resource_def == null:
		return

	var instance = RESOURCE_NODE_SCENE.instantiate() as ResourceNode
	resource_root.add_child(instance)
	instance.global_position = _array_to_vector3(state.get("position", [0.0, 0.0, 0.0]))
	instance.configure(node_id, resource_def, int(state.get("remaining_amount", 0)))
	instance.amount_changed.connect(_on_resource_amount_changed)
	instance.depleted.connect(_on_resource_depleted)
	active_nodes[node_id] = instance


func _on_resource_amount_changed(node_id: String, remaining_amount: int):
	if resource_states.has(node_id):
		resource_states[node_id]["remaining_amount"] = remaining_amount
		state_changed.emit()


func _on_resource_depleted(node_id: String):
	if resource_states.has(node_id):
		resource_states[node_id]["remaining_amount"] = 0
		resource_states[node_id]["depleted"] = true
	active_nodes.erase(node_id)
	state_changed.emit()


func _chunk_key(chunk: Vector2i) -> String:
	return "%d,%d" % [chunk.x, chunk.y]


func _chunk_seed(chunk: Vector2i) -> int:
	return MAP_DEFINITION.map_seed + chunk.x * 92821 + chunk.y * 68917


func _province_seed(province: Vector2i) -> int:
	return MAP_DEFINITION.map_seed + province.x * 137913 + province.y * 97531


func _is_chunk_in_bounds(chunk: Vector2i) -> bool:
	var half_chunks_x = int(MAP_DEFINITION.world_size.x / MAP_DEFINITION.chunk_size / 2)
	var half_chunks_y = int(MAP_DEFINITION.world_size.y / MAP_DEFINITION.chunk_size / 2)
	return chunk.x >= -half_chunks_x and chunk.x < half_chunks_x and chunk.y >= -half_chunks_y and chunk.y < half_chunks_y


func _array_to_vector3(raw_position: Array) -> Vector3:
	if raw_position.size() < 3:
		return Vector3.ZERO
	return Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))
