extends Node2D

var stroke_nodes: Dictionary = {}	# key: Line2D
var player_colors: Dictionary = {}
var color_index := 0

# TODO: limit max players, or add these programatically
var palette := [
	Color(1, 0.7, 0.7, 1),
	Color(0.7, 1, 0.7, 1),
	Color(0.7, 0.7, 1, 1),
	Color(1, 0.8, 0.6, 1),
]

func get_player_color(player_id: String) -> Color:
	if not player_colors.has(player_id):
		player_colors[player_id] = palette[color_index % palette.size()]
		color_index += 1
	return player_colors[player_id]

func add_remote_point(point: Vector2, sid: int, player_id: String):
	var key := str(player_id) + "_" + str(sid)
	if not stroke_nodes.has(key):
		var color := get_player_color(player_id)
		var line := _make_line(color)
		line.add_point(point)
		line.add_point(point + Vector2(0.01, 0))	# so that dots appear after clicking once
		add_child(line)
		stroke_nodes[key] = line
	else:
		stroke_nodes[key].add_point(point)

func clear_remote_strokes():
	for key in stroke_nodes:
		stroke_nodes[key].queue_free()
	stroke_nodes.clear()
	player_colors.clear()
	color_index = 0

# I use Line2D for the rounded end caps which draw_polyline() doesn't have
# TODO: consider draw calls
func _make_line(color: Color) -> Line2D:
	var l := Line2D.new()
	l.width = 40.0
	l.default_color = color
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.antialiased = true
	return l
