extends Node3D

@export_enum("wood", "stone") var resource_type = "stone"
@export var total_amount = 50
@export var gather_time = 3.0

var current_amount = 50
