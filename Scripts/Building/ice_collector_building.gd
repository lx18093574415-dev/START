extends FunctionalBuilding


func _init():
	building_id = &"ice_collector"
	cycle_time = 4.5
	harvest_resource_ids = [&"glacial_ice"]
	harvest_radius = 8.0
	harvest_amount = 2
	active_tint = Color(0.95, 1.08, 1.14, 1.0)
	idle_tint = Color(0.78, 0.86, 0.92, 1.0)
	range_indicator_color = Color(0.38, 0.78, 1.0, 0.12)
