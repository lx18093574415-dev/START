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
@export var cost_wood: int
@export var cost_stone: int
