class_name GameManager

extends Node

@onready var local_canvas := %LocalCanvas
@onready var remote_canvas := %RemoteCanvas
@onready var join_ui := %JoinUI
@onready var predictions_label := %PredictionsLabel
@onready var room_code_label := %RoomCodeLabel

var socket := WebSocketPeer.new()
var connected := false	# websocket connection is open
var in_room := false		# actually joined a room

var stroke_id := 0

func on_stroke_start():
	stroke_id += 1

func broadcast_point(point: Vector2):
	broadcast({"type": "draw", "x": point.x, "y": point.y, "sid": stroke_id})

func handle_message(msg: Dictionary):
	match msg.get("type", ""):
		"created":
			in_room = true
			room_code_label.text = "Room code: " + msg["code"]
		"joined":
			in_room = true
			room_code_label.text = "Room: " + msg["code"]
			join_ui.hide()
		"error":
			print("Error: ", msg["msg"])
		"draw":
			var point = Vector2(float(msg["x"]), float(msg["y"]))
			remote_canvas.add_remote_point(point, int(msg["sid"]), msg.get("player_id", "unknown"))
		"predictions":
			print("Got predictions: ", msg)
			var lines := []
			for r in msg["results"].slice(0, 5):
				lines.append("%s: %.0f%%" % [r["label"], r["score"] * 100])
			var result := "\n".join(lines)
			predictions_label.text = result

func send_classify():
	if not connected or not in_room:
		return
	var stroke_data = local_canvas.get_stroke_data()
	if stroke_data.is_empty():
		return
	var size = local_canvas.get_viewport().get_visible_rect().size
	socket.send_text(JSON.stringify({
		"type": "classify",
		"strokes": stroke_data,
		"width": size.x,
		"height": size.y
	}))

func _ready():
	var err = socket.connect_to_url("ws://localhost:8765")
	if err != OK:
		print("Failed to initiate connection: ", err)
	%JoinButton.pressed.connect(_on_join_pressed)
	
	local_canvas.stroke_started.connect(on_stroke_start)
	local_canvas.point_broadcasted.connect(broadcast_point)

	var classify_timer := Timer.new()
	classify_timer.wait_time = 1.5
	classify_timer.autostart = true
	classify_timer.timeout.connect(func():
		if connected and in_room:
			send_classify()
	)
	add_child(classify_timer)

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN and not connected:
		connected = true
		print("Connected to server")

	elif state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var raw = socket.get_packet().get_string_from_utf8()
			var msg = JSON.parse_string(raw)
			if msg:
				handle_message(msg)

func create_room():
	socket.send_text(JSON.stringify({"type": "create"}))

func join_room(code: String):
	socket.send_text(JSON.stringify({"type": "join", "code": code}))

func broadcast(data: Dictionary):
	socket.send_text(JSON.stringify({"type": "broadcast", "data": data}))

func _on_join_pressed():
	var code = %CodeInput.text.strip_edges().to_upper()
	if code.length() > 0:
		join_room(code)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_C:
			create_room()
		# TODO: add more hotkeys, like undo, and remove C to create
