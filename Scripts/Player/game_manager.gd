extends Node

var wood = 0
var stone = 0

var is_build_mode = false

func add_wood(amount):
	wood += amount

func add_stone(amount):
	stone += amount

func can_build():
	return wood >= 10

func consume_build_cost():
	wood -= 10

func _on_build_button_pressed():
	if can_build():
		is_build_mode = true
		print("建造模式:", is_build_mode)
