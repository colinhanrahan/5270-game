extends Control

func _on_singleplayer_button_pressed():
	get_tree().change_scene_to_file("res://scenes/singleplayer_lobby.tscn")

func _on_multiplayer_button_pressed():
	get_tree().change_scene_to_file("res://scenes/multiplayer_lobby.tscn")
