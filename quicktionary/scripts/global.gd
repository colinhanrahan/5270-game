extends Node

signal ui_change_requested(next_ui_path: String, instant: bool)

var selected_category: String = "apple"
var current_track := ""
var music := AudioStreamPlayer.new()
var sfx := AudioStreamPlayer.new()

func play_music(path: String) -> void:
	if path == current_track:
		return
	current_track = path
	music.stream = load(path)
	music.play()

# network state
#var server_url: String = "ws://localhost:8765"
var server_url: String = "wss://web-production-1e454e.up.railway.app/"
var socket := WebSocketPeer.new()
var is_connected := false
var room_code: String = ""
var player_id: String = ""  # set to a random string on boot

func _ready() -> void:
	add_child(music)
	add_child(sfx)
	music.stream = preload("res://assets/WiiPlay.mp3")
	sfx.stream = preload("res://assets/WiiClick.mp3")
	music.volume_db = -5.0
	sfx.volume_db = -5.0
	get_tree().node_added.connect(_on_node_added)
	player_id = _random_id()
	# connect to the server when the game boots up
	var err = socket.connect_to_url(server_url)
	if err != OK:
		print("Failed to connect globally: ", err)

func _random_id() -> String:
	var chars = "abcdefghijklmnopqrstuvwxyz0123456789"
	var id = ""
	for i in 8:
		id += chars[randi() % chars.length()]
	return id

func _process(_delta: float) -> void:
	socket.poll()
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected:
			is_connected = true
			print("Global connection established")
	elif state == WebSocketPeer.STATE_CLOSED or state == WebSocketPeer.STATE_CLOSING:
		is_connected = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # escape
		sfx.stream = load("res://assets/WiiConfirm.mp3")
		sfx.play()
		room_code = ""
		player_id = _random_id()
		# reconnect the socket
		socket = WebSocketPeer.new()
		is_connected = false
		var err = socket.connect_to_url(server_url)
		if err != OK:
			print("Failed to reconnect: ", err)
		Global.ui_change_requested.emit("res://scenes/main_menu.tscn", true)

func play_button_sfx(button: Button) -> void:
	if button.is_in_group("home_button"):
		sfx.stream = load("res://assets/WiiConfirm.mp3")
	else:
		sfx.stream = load("res://assets/WiiClick.mp3")
	sfx.play()

func _on_node_added(node: Node) -> void:
	if node is Button:
		node.pressed.connect(func(): play_button_sfx(node))
