# BuildingData.gd
class_name BuildingData
extends Resource

@export var building_id: StringName
@export var display_name: String
@export var category: StringName
@export var icon: Texture2D
@export var scene: PackedScene
@export var preview: PackedScene
@export var size: Vector2
@export var preview_range_radius := 0.0
@export var preview_range_color := Color(1.0, 0.75, 0.25, 0.3)
@export var build_costs: Dictionary = {}
@export_multiline var description := ""
@export var tier := 1
@export var unlocked_by: Array[StringName] = []
