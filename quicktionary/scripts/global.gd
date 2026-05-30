extends Node

var selected_category: String = "apple"

# network state
var server_url: String = "ws://localhost:8765"
var socket := WebSocketPeer.new()
var is_connected := false

func _ready() -> void:
	# connect to the server when the game boots up
	var err = socket.connect_to_url(server_url)
	if err != OK:
		print("Failed to connect globally: ", err)

func _process(_delta: float) -> void:
	socket.poll()
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected:
			is_connected = true
			print("Global connection established")
	elif state == WebSocketPeer.STATE_CLOSED or state == WebSocketPeer.STATE_CLOSING:
		is_connected = false
