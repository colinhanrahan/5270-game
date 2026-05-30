extends Control

func _on_create_button_pressed():
	get_tree().change_scene_to_file("res://scenes/pvp.tscn")

func _on_join_button_pressed():
	get_tree().change_scene_to_file("res://scenes/pve.tscn")

func _on_main_menu_button_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
