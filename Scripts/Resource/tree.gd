extends Node3D

@export_enum("wood", "stone") var resource_type = "wood"
@export var total_amount = 50
@export var gather_time = 2.0

var current_amount = 50
