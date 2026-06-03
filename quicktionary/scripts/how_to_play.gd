extends Control

func _ready() -> void:
	Global.play_music("res://assets/Carefree.mp3")

func _on_main_menu_button_pressed():
	Global.ui_change_requested.emit("res://scenes/main_menu.tscn", false)
