extends FunctionalBuilding


func _init():
	building_id = &"mining_station"
	cycle_time = 4.0
	harvest_resource_ids = [&"ferrite_ore", &"silicate_ore"]
	harvest_radius = 8.0
	harvest_amount = 2
	active_tint = Color(1.1, 1.05, 1.0, 1.0)
	idle_tint = Color(0.8, 0.8, 0.82, 1.0)
	range_indicator_color = Color(1.0, 0.72, 0.24, 0.12)
