extends Node

signal resources_changed(wood: int, stone: int)

var wood = 0
var stone = 0


func _ready():
	resources_changed.emit(wood, stone)


func add_wood(amount):
	wood += amount
	resources_changed.emit(wood, stone)


func add_stone(amount):
	stone += amount
	resources_changed.emit(wood, stone)


func has_build_cost(building_data: BuildingData) -> bool:
	if building_data == null:
		return false

	return wood >= building_data.cost_wood and stone >= building_data.cost_stone


func spend_build_cost(building_data: BuildingData) -> bool:
	if not has_build_cost(building_data):
		return false

	wood -= building_data.cost_wood
	stone -= building_data.cost_stone
	resources_changed.emit(wood, stone)
	return true
