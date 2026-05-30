extends Control

signal stroke_started # to inform singleplayer_game that player started early 

@export var line_width: float = 20.0
@export var min_distance: float = 4.0
@export var line_color: Color = Color.BLACK

var all_strokes: Array[PackedVector2Array] = []
var current_points: PackedVector2Array = PackedVector2Array()
var drawing := false

@onready var active_line: Line2D = _make_line(line_color)

func _ready() -> void:
	add_child(active_line)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# so coordinates are relative to this canvas panel
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

func _add_point(pos: Vector2) -> void:
	current_points.append(pos)
	active_line.points = current_points

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

func _make_line(color: Color) -> Line2D:
	var l := Line2D.new()
	l.width = line_width
	l.default_color = color
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.antialiased = true
	return l

# fetches drawing data to be sent to the server
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
	for child in get_children():
		if child != active_line:
			child.queue_free()
