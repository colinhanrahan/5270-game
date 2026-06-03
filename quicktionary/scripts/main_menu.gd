extends Control

func _ready() -> void:
	Global.play_music("res://assets/WiiPlay.mp3")

func _on_singleplayer_button_pressed():
	Global.ui_change_requested.emit("res://scenes/singleplayer_lobby.tscn", false)

func _on_multiplayer_button_pressed():
	Global.ui_change_requested.emit("res://scenes/multiplayer_lobby.tscn", false)

func _on_how_to_play_button_pressed() -> void:
	Global.ui_change_requested.emit("res://scenes/how_to_play.tscn", false)

func _on_attributions_button_pressed() -> void:
	Global.ui_change_requested.emit("res://scenes/attributions.tscn", false)
