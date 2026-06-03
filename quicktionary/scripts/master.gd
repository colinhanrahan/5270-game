extends Node

@onready var ui_container = %UIContainer

var current_ui: Control = null
var current_ui_path: String = ""

const UI_POSITIONS = {
	"res://scenes/main_menu.tscn": Vector2.ZERO,
	"res://scenes/singleplayer_lobby.tscn": Vector2(-1, 0), # left
	"res://scenes/multiplayer_lobby.tscn": Vector2(1, 0),  # right
	"res://scenes/how_to_play.tscn": Vector2(0, -1),       # top
	"res://scenes/attributions.tscn": Vector2(0, 1)        # bottom
}

func _ready():
	Global.ui_change_requested.connect(_on_ui_change_requested)
	transition_to_ui.call_deferred("res://scenes/main_menu.tscn", true)

func _on_ui_change_requested(next_ui_path: String, instant: bool):
	transition_to_ui(next_ui_path, instant)

func transition_to_ui(next_ui_path: String, instant: bool = false):
	var next_ui_scene = load(next_ui_path)
	var next_ui = next_ui_scene.instantiate() as Control
	
	next_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# handle explicit instant clear flag
	if current_ui == null or instant:
		_execute_instant_swap(next_ui, next_ui_path)
		return

	# check fallback conditions
	var current_coord = UI_POSITIONS.get(current_ui_path, Vector2.ZERO)
	var next_coord = UI_POSITIONS.get(next_ui_path, null) # Returns null if missing

	if next_coord == null or current_coord == next_coord:
		_execute_instant_swap(next_ui, next_ui_path)
		return

	# proceed with sliding logic only if valid & coordinates are different
	ui_container.add_child(next_ui)
	next_ui.visible = false 

	var slide_direction = next_coord - current_coord

	if is_instance_valid(current_ui) and is_instance_valid(next_ui):
		next_ui.visible = true
		animate_slide(current_ui, next_ui, slide_direction)
		
		current_ui = next_ui
		current_ui_path = next_ui_path

func _execute_instant_swap(next_ui: Control, next_ui_path: String) -> void:
	ui_container.add_child(next_ui)
	next_ui.visible = true
	
	if current_ui != null: 
		current_ui.queue_free()
		
	current_ui = next_ui
	current_ui_path = next_ui_path

func animate_slide(old_ui: Control, new_ui: Control, direction: Vector2):
	var viewport_size = get_viewport().get_visible_rect().size
	var start_offset = direction * viewport_size
	new_ui.position = start_offset
	
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(old_ui, "position", -start_offset, 0.3)
	tween.tween_property(new_ui, "position", Vector2.ZERO, 0.3)
	
	tween.chain().tween_callback(old_ui.queue_free)
