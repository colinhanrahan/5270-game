extends Control

func _ready() -> void:
	Global.play_music("res://assets/LocalForecast.mp3")
	set_process(true)

func _process(_delta: float) -> void:
	if not Global.is_connected:
		return
	while Global.socket.get_available_packet_count() > 0:
		var raw = Global.socket.get_packet().get_string_from_utf8()
		var msg = JSON.parse_string(raw)
		if not msg:
			continue
		if msg.get("type") == "created":
			%RoomInput.text = msg["code"]
		if msg.get("type") == "joined":
			Global.room_code = msg["code"]
			Global.ui_change_requested.emit("res://scenes/multiplayer_game.tscn", true)
		elif msg.get("type") == "error":
			# TODO: show error in UI
			print("Room error: ", msg.get("msg"))

func _on_join_button_pressed() -> void:
	var code = %RoomInput.text.strip_edges().to_upper()
	if code.length() == 0:
		return
	Global.socket.send_text(JSON.stringify({"type": "join", "code": code}))

func _on_create_button_pressed() -> void:
	Global.socket.send_text(JSON.stringify({"type": "create"}))

func _on_main_menu_button_pressed():
	Global.ui_change_requested.emit("res://scenes/main_menu.tscn", false)
