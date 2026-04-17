class_name ResourceData
extends Resource

@export var resource_id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var category: StringName
@export var sort_order := 0
@export var starter_zone_allowed := true
@export var danger_zone_only := false
@export var spawnable := false
@export var spawn_weight := 1.0
@export var node_color := Color(1, 1, 1, 1)
@export var node_size := Vector2(1.6, 1.6)
@export var gather_time := 2.0
@export var min_amount := 10
@export var max_amount := 20
