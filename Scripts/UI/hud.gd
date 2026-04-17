extends CanvasLayer

@onready var wood_label: Label = $Label
@onready var stone_label: Label = $Label2
@onready var build_button: Button = $BuildButton
@onready var gm = get_node("../GameManager")


func _ready():
	build_button.text = "Build"
	gm.resources_changed.connect(_on_resources_changed)
	_on_resources_changed(gm.wood, gm.stone)


func _on_resources_changed(wood: int, stone: int):
	wood_label.text = "Wood: %d" % wood
	stone_label.text = "Stone: %d" % stone
