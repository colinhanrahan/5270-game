extends Control

@export var classification_interval: float = 0.1 # in seconds
@export var win_threshold: float = 0.3 # in confidence 0-1
@onready var canvas := %Canvas
@onready var target_label: Label = %TargetLabel 
@onready var predictions_label: RichTextLabel = %PredictionsLabel
@onready var timer_label: Label = %TimerLabel
@export var leaderboard_popup_scene: PackedScene = preload("res://scenes/singleplayer_leaderboard.tscn")
var current_popup: Control = null
var countdown_timer: SceneTreeTimer = null
var game_started := false
var game_over := false
var time_elapsed := 0.0

func _ready() -> void:
	target_label.text = "Draw " + get_indefinite_article(Global.selected_category) + " " + Global.selected_category + "!"
	predictions_label.text = "Waiting..."
	canvas.set_process_input(true)
	# early start to prevent countdown from eating your first stroke
	canvas.stroke_started.connect(func():
		if not game_started:
			_begin_game()
	)
	_run_countdown_sequence()

# to decide "draw a x" vs. "draw an x"
func get_indefinite_article(word: String) -> String:
	var first_letter = word.left(1).to_lower()
	if first_letter in ["a", "e", "i", "o", "u"]:
		return "an"
	else:
		return "a"

func _run_countdown_sequence() -> void:
	countdown_timer = get_tree().create_timer(3.0)
	await countdown_timer.timeout
	_begin_game()

func _begin_game() -> void:
	if game_started: return
	game_started = true
	countdown_timer = null
	_start_classification_timer()

func _start_classification_timer() -> void:
	var classify_timer := Timer.new()
	classify_timer.wait_time = classification_interval
	classify_timer.autostart = true
	classify_timer.timeout.connect(func():
		if Global.is_connected and game_started and not game_over:
			_send_classify_request()
	)
	add_child(classify_timer)

func _process(delta: float) -> void:
	if countdown_timer:
		timer_label.text = str(ceili(countdown_timer.time_left))
	elif game_started and not game_over:
		time_elapsed += delta
		timer_label.text = "%.1fs" % time_elapsed

	if Global.is_connected:
		while Global.socket.get_available_packet_count() > 0:
			var raw = Global.socket.get_packet().get_string_from_utf8()
			var msg = JSON.parse_string(raw)
			if msg:
				_handle_server_message(msg)

func _send_classify_request() -> void:
	var stroke_data = canvas.get_stroke_data()
	if stroke_data.is_empty(): return
	var size = canvas.get_viewport().get_visible_rect().size
	var payload = {
		"type": "classify",
		"strokes": stroke_data,
		"width": size.x,
		"height": size.y
	}
	Global.socket.send_text(JSON.stringify(payload))

func _handle_server_message(msg: Dictionary) -> void:
	if msg.get("type") == "predictions":
		# server sends top 5, currently limiting to top 3 for readability
		var results: Array = msg.get("results", []).slice(0, 3)
		var lines := []
		var win_triggered := false
		var win_confidence := 0
		
		for r in results:
			# server scores as 0-1 confidence, score_percent is 0-100%
			var score_percent: float = r["score"] * 100
			var line: String = "%s: %.0f%%" % [r["label"], score_percent]
			if r["score"] >= win_threshold:
				# color a confident guess green even if incorrect
				line = "[color=green]%s[/color]" % line
				if r["label"].to_lower() == Global.selected_category.to_lower():
					win_triggered = true 
					win_confidence = r["score"] * 100
			lines.append(line)
		
		predictions_label.text = "\n".join(lines)
		if win_triggered:
			_trigger_win_condition(win_confidence)

	elif msg.get("type") == "leaderboard_data":
		if is_instance_valid(current_popup):
			current_popup.populate_leaderboard(time_elapsed, msg.get("highscores", []), msg.get("medals", {}))

func _trigger_win_condition(confidence: float) -> void:
	game_over = true
	canvas.set_process_input(false)
	timer_label.text = "Correct!"
	predictions_label.text = "[color=green]AI guessed '%s' at %.0f%%![/color]" % [Global.selected_category, confidence]

	if leaderboard_popup_scene:
		current_popup = leaderboard_popup_scene.instantiate()
		add_child(current_popup)
		current_popup.initialize_popup(time_elapsed)
