extends Control

@export var classification_interval: float = 0.1
@export var win_threshold: float = 0.3

@onready var canvas := %Canvas
@onready var target_label: Label = %TargetLabel
@onready var predictions_label: RichTextLabel = %PredictionsLabel
@onready var timer_label: Label = %TimerLabel
@onready var winner_label: Label = %WinnerLabel  # add this to your scene

var countdown_timer: SceneTreeTimer = null
var game_started := false
var game_over := false
var time_elapsed := 0.0

func _ready() -> void:
	var tracks = [
		"res://assets/Adventure.mp3",
		"res://assets/Monkeys.mp3",
		"res://assets/QuirkyDog.mp3"
	]
	Global.play_music(tracks.pick_random())
	
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
	        window.__tts_done = true;
	        window.__tts_speak = function(text) {
	            window.speechSynthesis.cancel();
	            var u = new SpeechSynthesisUtterance(text);
	            u.rate = 1.4;
	            u.onend = function() { window.__tts_done = true; };
	            window.__tts_done = false;
	            window.speechSynthesis.speak(u);
	        }
		""")
	
	target_label.text = "Draw " + _article(Global.selected_category) + " " + Global.selected_category + "!"
	predictions_label.text = "Waiting..."
	winner_label.hide()
	canvas.set_process_input(false)  # locked until countdown
	canvas.stroke_started.connect(func():
		if not game_started:
			_begin_game()
	)
	_run_countdown_sequence()

func _run_countdown_sequence() -> void:
	countdown_timer = get_tree().create_timer(3.0)
	await countdown_timer.timeout
	_begin_game()

func _begin_game() -> void:
	if game_started:
		return
	game_started = true
	countdown_timer = null
	canvas.set_process_input(true)
	_start_classification_timer()

func _start_classification_timer() -> void:
	var t := Timer.new()
	t.wait_time = classification_interval
	t.autostart = true
	t.timeout.connect(func():
		if Global.is_connected and game_started and not game_over:
			_send_classify_request()
	)
	add_child(t)

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
	if stroke_data.is_empty():
		return
	var size = canvas.get_viewport().get_visible_rect().size
	Global.socket.send_text(JSON.stringify({
		"type": "classify",
		"strokes": stroke_data,
		"width": size.x,
		"height": size.y
	}))

func _handle_server_message(msg: Dictionary) -> void:
	match msg.get("type"):
		"draw":
			# peer stroke point arriving via broadcast relay
			var pos = Vector2(msg["x"], msg["y"])
			canvas.add_remote_point(pos, msg["sid"], msg["player_id"])
		"predictions":
			_handle_predictions(msg)
		"player_won":
			# another peer got it first
			if not game_over:
				_end_game(msg.get("player_id", "Someone"), msg.get("time", 0.0), false)

func _handle_predictions(msg: Dictionary) -> void:
	var results: Array = msg.get("results", []).slice(0, 3)
	var lines := []
	var won := false
	var win_confidence := 0.0
	var top_label: String = results[0]["label"] if results.size() > 0 else ""

	for r in results:
		var pct: float = r["score"] * 100.0
		var line: String = "%s: %.0f%%" % [r["label"], pct]
		if r["score"] >= win_threshold:
			line = "[color=green]%s[/color]" % line
			if r["label"].to_lower() == Global.selected_category.to_lower():
				won = true
				win_confidence = r["score"] * 100.0
		lines.append(line)

	predictions_label.text = "\n".join(lines)
	
	var is_done = JavaScriptBridge.eval("!!window.__tts_done")
	if is_done and top_label != "":
		_speak(top_label)

	if won:
		_speak(Global.selected_category)
		# tell peers before ending locally so they get the message
		Global.socket.send_text(JSON.stringify({
			"type": "broadcast",
			"data": {
				"type": "player_won",
				"player_id": Global.player_id,
				"time": time_elapsed
			}
		}))
		_end_game(Global.player_id, time_elapsed, true)

func _end_game(winner_id: String, win_time: float, is_local: bool) -> void:
	game_over = true
	canvas.set_process_input(false)
	timer_label.text = "%.1fs" % win_time
	winner_label.show()
	if is_local:
		winner_label.text = "You got it in %.1fs!" % win_time
		predictions_label.text = "[color=green]AI guessed '%s'![/color]" % Global.selected_category
	else:
		winner_label.text = "%s got it first in %.1fs!" % [winner_id, win_time]

func _article(word: String) -> String:
	return "an" if word.left(1).to_lower() in ["a","e","i","o","u"] else "a"

func _speak(text: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.__tts_speak(%s)" % JSON.stringify(text))
