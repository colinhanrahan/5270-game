extends Node2D

# TODO: move line_width to be shared by local and remote?
@export var line_width: float = 40.0
@export var min_distance: float = 4.0
@export var line_color: Color = Color.BLACK

signal stroke_started
signal point_broadcasted(pos: Vector2)

var all_strokes: Array[PackedVector2Array] = []
var current_points: PackedVector2Array = PackedVector2Array()
var drawing := false

@onready var active_line: Line2D = _make_line(line_color)

func _ready():
	add_child(active_line)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_stroke(event.position)
		else:
			_finish_stroke()
	elif event is InputEventMouseMotion and drawing:
		# don't spam points on top of each other when holding
		if event.position.distance_to(current_points[-1]) >= min_distance:
			_add_point(event.position)

func _start_stroke(pos: Vector2):
	drawing = true
	current_points = PackedVector2Array([pos, pos + Vector2(0.01, 0)])
	active_line.points = current_points
	active_line.show()
	stroke_started.emit()
	point_broadcasted.emit(pos)

func _add_point(pos: Vector2):
	current_points.append(pos)
	active_line.points = current_points
	point_broadcasted.emit(pos)

func _finish_stroke():
	drawing = false
	if current_points.size() > 1:
		all_strokes.append(current_points.duplicate())
		var static_line := _make_line(line_color)
		static_line.points = current_points
		add_child(static_line)
	active_line.clear_points()
	active_line.hide()
	current_points = PackedVector2Array()

# TODO: share this with remote script?
func _make_line(color: Color) -> Line2D:
	var l := Line2D.new()
	l.width = line_width
	l.default_color = color
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.antialiased = true
	return l

# TODO: finish this functionality
func undo():
	# Children: index 0 = active_line, rest = finished strokes
	if get_child_count() > 1:
		get_child(get_child_count() - 1).queue_free()
		all_strokes.pop_back()

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
