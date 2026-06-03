extends Control

func _ready() -> void:
	Global.play_music("res://assets/Cipher.mp3")

func _on_main_menu_button_pressed():
	Global.ui_change_requested.emit("res://scenes/main_menu.tscn", false)

func _on_text_block_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))
