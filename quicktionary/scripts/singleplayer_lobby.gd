extends Control

# TODO: not sure if I need separate scene anymore, it's just one button
const BOX_TEMPLATE = preload("res://scenes/category_box.tscn")
@onready var grid_container = %CategoryGrid

func _ready() -> void:
	load_and_build_grid()

func load_and_build_grid() -> void:
	var file_path = "res://data/labels.txt"
	var file = FileAccess.open(file_path, FileAccess.READ)
	var categories: Array[String] = []
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line != "":
			categories.append(line)
	
	file.close()
	
	# sort lowercase e.g. The Great Wall of China -> t's
	categories.sort_custom(func(a, b): return a.to_lower() < b.to_lower())
	for category_name in categories:
		var box_instance = BOX_TEMPLATE.instantiate() as Button
		box_instance.text = category_name
		box_instance.pressed.connect(func(): _on_category_selected(category_name))
		grid_container.add_child(box_instance)

func _on_category_selected(category_name: String) -> void:
	# store category globally so that singleplayer_game can read it
	Global.selected_category = category_name
	get_tree().change_scene_to_file("res://scenes/singleplayer_game.tscn")

func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
