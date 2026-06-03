extends Control

@onready var line_edit: LineEdit = %LineEdit
@onready var submit_button: Button = %SubmitButton
@onready var name_input_container: HBoxContainer = %NameInputContainer
@onready var list_container: VBoxContainer = %LeaderboardList
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var lobby_button: Button = %LobbyButton

var my_time: float = 0.0 # sent from singleplayer_game

func _ready() -> void:
	lobby_button.hide()
	scroll_container.hide()

func initialize_popup(player_time: float) -> void:
	my_time = player_time

func _on_submit_button_pressed() -> void:
	var player_name = line_edit.text.strip_edges()
	if player_name.is_empty():
		player_name = "Anonymous"

	submit_button.disabled = true
	line_edit.editable = false
	scroll_container.show()

	if Global.is_connected:
		var payload = {
			"type": "submit_score",
			"category": Global.selected_category,
			"name": player_name,
			"time": my_time
		}
		Global.socket.send_text(JSON.stringify(payload))

func _on_lobby_button_pressed() -> void:
	Global.ui_change_requested.emit("res://scenes/singleplayer_lobby.tscn", true)

func _on_replay_button_pressed() -> void:
	Global.ui_change_requested.emit("res://scenes/singleplayer_game.tscn", true)

func populate_leaderboard(player_time: float, highscores: Array, medals: Dictionary) -> void:
	name_input_container.hide()

	for child in list_container.get_children():
		child.free()

	var all_entries = []
	for entry in highscores:
		all_entries.append({
			"type": "player",
			"name": entry.get("name", "Unknown"),
			"time": float(entry.get("time", 999.0))
		})
	
	if medals.has("gold"): all_entries.append({"type": "medal", "tier": "🥇 Gold", "time": float(medals.gold)})
	if medals.has("silver"): all_entries.append({"type": "medal", "tier": "🥈 Silver", "time": float(medals.silver)})
	if medals.has("bronze"): all_entries.append({"type": "medal", "tier": "🥉 Bronze", "time": float(medals.bronze)})

	all_entries.sort_custom(func(a, b): return a["time"] < b["time"])

	var rank = 1
	for entry in all_entries:
		var lbl := Label.new()
		if entry["type"] == "player":
			var is_current_run = (entry["time"] == player_time) 
			lbl.text = "%d. %s - %.2fs" % [rank, entry["name"], entry["time"]]
			if is_current_run:
				lbl.text += " (YOU!)"
				lbl.modulate = Color.YELLOW # TODO: check if this is working?
			rank += 1
		else:
			lbl.text = "%s: %.2fs" % [entry["tier"], entry["time"]]
			lbl.modulate = Color.LIGHT_BLUE
			
		list_container.add_child(lbl)
	
	lobby_button.show()
