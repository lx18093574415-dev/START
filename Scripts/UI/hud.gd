extends CanvasLayer

@onready var build_button: Button = $BuildButton
@onready var resource_list: VBoxContainer = $ResourceList
@onready var gm = get_node("../GameManager")


func _ready():
	build_button.text = "Build"
	gm.resources_changed.connect(_refresh_resources)
	_refresh_resources()


func _refresh_resources():
	for child in resource_list.get_children():
		child.queue_free()

	for resource_def in gm.get_visible_resources():
		var label = Label.new()
		label.text = "%s: %d" % [resource_def.display_name, gm.get_resource_amount(resource_def.resource_id)]
		resource_list.add_child(label)
