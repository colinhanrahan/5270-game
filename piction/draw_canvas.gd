#extends Node2D
#
#var current_stroke: PackedVector2Array = []
#var all_strokes: Array = []
#var remote_strokes: Dictionary = {}
#var drawing := false
#var min_dist := 4.0
#
#func _input(event):
	#if event is InputEventMouseButton:
		#if event.button_index == MOUSE_BUTTON_LEFT:
			#if event.pressed:
				#drawing = true
				#current_stroke.clear()
				#current_stroke.append(event.position)
				#get_parent().on_stroke_start()
			#else:
				#drawing = false
				#if current_stroke.size() > 1:
					#all_strokes.append(current_stroke.duplicate())
				#current_stroke.clear()
				#queue_redraw()
#
	#if event is InputEventMouseMotion and drawing:
		#var last = current_stroke[-1] 
		#if event.position.distance_to(last) >= min_dist:
			#current_stroke.append(event.position)
			#get_parent().broadcast_point(event.position) # Only broadcast when a new point is saved
			#queue_redraw()
#
#func add_remote_point(point: Vector2, sid: int):
	#if not remote_strokes.has(sid):
		#remote_strokes[sid] = []
	#remote_strokes[sid].append(point)
	#queue_redraw()
#
#func _draw():
	## Draw finished strokes
	#for stroke in all_strokes:
		#if stroke.size() > 1:
			#draw_polyline(stroke, Color.BLACK, 3.0, true)
			#
	## Draw current active stroke
	#if current_stroke.size() > 1:
		#draw_polyline(current_stroke, Color.BLACK, 3.0, true)
		#
	## Draw remote strokes
	#for sid in remote_strokes:
		#var points = remote_strokes[sid]
		#if points.size() > 1:
			#draw_polyline(points, Color.RED, 3.0, true) # Maybe a different color for remote?
#
#func _draw_stroke(points: Array):
	#if points.size() > 1:
		## Convert Array to PackedVector2Array for performance
		#draw_polyline(PackedVector2Array(points), Color.BLACK, 3.0, true)
