extends Control

signal stroke_started

@export var line_width: float = 20.0
@export var min_distance: float = 4.0
@export var line_color: Color = Color.BLACK

# local drawing state
var all_strokes: Array[PackedVector2Array] = []
var current_points: PackedVector2Array = PackedVector2Array()
var drawing := false
@onready var active_line: Line2D = _make_line(line_color)

# remote drawing state
var remote_stroke_nodes: Dictionary = {}  # "playerid_sid" -> Line2D
var remote_player_colors: Dictionary = {}
var color_index := 0
var palette := [
	Color(1, 0.7, 0.7, 1),
	Color(0.7, 1, 0.7, 1),
	Color(0.7, 0.7, 1, 1),
	Color(1, 0.8, 0.6, 1),
]

func _ready() -> void:
	add_child(active_line)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_stroke(get_local_mouse_position())
		else:
			_finish_stroke()
	elif event is InputEventMouseMotion and drawing:
		var local_pos = get_local_mouse_position()
		if local_pos.distance_to(current_points[-1]) >= min_distance:
			_add_point(local_pos)

func _start_stroke(pos: Vector2) -> void:
	stroke_started.emit()
	drawing = true
	current_points = PackedVector2Array([pos, pos + Vector2(0.01, 0)])
	active_line.points = current_points
	active_line.show()
	_broadcast_point(pos, 0, true)

func _add_point(pos: Vector2) -> void:
	current_points.append(pos)
	active_line.points = current_points
	var sid := all_strokes.size()  # current stroke index
	_broadcast_point(pos, sid, false)

func _finish_stroke() -> void:
	drawing = false
	if current_points.size() > 1:
		all_strokes.append(current_points.duplicate())
		var static_line := _make_line(line_color)
		static_line.points = current_points
		add_child(static_line)
	active_line.clear_points()
	active_line.hide()
	current_points = PackedVector2Array()

func _broadcast_point(pos: Vector2, sid: int, is_new_stroke: bool) -> void:
	if not Global.is_connected:
		return
	var payload = {
		"type": "broadcast",
		"data": {
			"type": "draw",
			"player_id": Global.player_id,
			"sid": sid,
			"x": pos.x,
			"y": pos.y,
			"new_stroke": is_new_stroke
		}
	}
	Global.socket.send_text(JSON.stringify(payload))

# called by multiplayer_game.gd when a draw message arrives from a peer
func add_remote_point(point: Vector2, sid: int, player_id: String) -> void:
	var key := player_id + "_" + str(sid)
	if not remote_stroke_nodes.has(key):
		var color := _get_player_color(player_id)
		var line := _make_line(color)
		line.add_point(point)
		line.add_point(point + Vector2(0.01, 0))
		# insert before active_line so remote strokes render underneath
		move_child(active_line, get_child_count() - 1)
		add_child(line)
		move_child(line, get_child_count() - 2)  # just under active_line
		remote_stroke_nodes[key] = line
	else:
		remote_stroke_nodes[key].add_point(point)

func get_stroke_data() -> Array:
	var stroke_data = []
	for stroke in all_strokes:
		var points = []
		for p in stroke:
			points.append([p.x, p.y])
		stroke_data.append(points)
	if current_points.size() > 1:
		var points = []
		for p in current_points:
			points.append([p.x, p.y])
		stroke_data.append(points)
	return stroke_data

func clear_canvas() -> void:
	all_strokes.clear()
	current_points.clear()
	active_line.clear_points()
	for key in remote_stroke_nodes:
		remote_stroke_nodes[key].queue_free()
	remote_stroke_nodes.clear()
	remote_player_colors.clear()
	color_index = 0
	for child in get_children():
		if child != active_line:
			child.queue_free()

func _get_player_color(player_id: String) -> Color:
	if not remote_player_colors.has(player_id):
		remote_player_colors[player_id] = palette[color_index % palette.size()]
		color_index += 1
	return remote_player_colors[player_id]

func _make_line(color: Color) -> Line2D:
	var l := Line2D.new()
	l.width = line_width
	l.default_color = color
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.antialiased = true
	return l
