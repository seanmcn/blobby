extends Node2D

const ZOOM_COMPENSATION: float = 0.25
const ZOOM_SPEED: float = 2.0

var time_survived: float = 0.0
var distance_traveled: float = 0.0
var is_game_active: bool = false
var target_zoom: float = 1.0

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var spawn_manager: Node = $SpawnManager
@onready var blobs_container: Node2D = $World/Blobs
@onready var hunters_container: Node2D = $World/Hunters
@onready var size_label: Label = $UI/SizeLabel


func _ready() -> void:
	# Set up group references for ability system
	blobs_container.add_to_group("blobs_container")
	hunters_container.add_to_group("hunters_container")

	# Connect player signals
	player.died.connect(_on_player_died)
	player.size_changed.connect(_on_player_size_changed)

	# Initialize spawn manager
	spawn_manager.initialize(blobs_container, hunters_container, SaveManager.get_seed())

	# Load saved state or start fresh
	if SaveManager.game_state.has_active_run:
		load_saved_state()
	else:
		SaveManager.start_new_run()

	is_game_active = true
	update_size_display()
	update_camera_zoom(player.current_size)
	camera.zoom = Vector2(target_zoom, target_zoom)


func _process(delta: float) -> void:
	if not is_game_active:
		return

	# Update time
	time_survived += delta

	# Track distance
	distance_traveled += player.get_distance_traveled()

	# Update camera to follow player (Camera2D has position_smoothing_enabled)
	camera.global_position = player.global_position

	# Smoothly interpolate camera zoom toward target
	camera.zoom = camera.zoom.lerp(Vector2(target_zoom, target_zoom), ZOOM_SPEED * delta)

	# Update spawn manager
	spawn_manager.update_chunks(player.global_position, player.current_size, time_survived)

	# Save state periodically (every ~5 seconds via frame count)
	if Engine.get_process_frames() % 300 == 0:
		save_current_state()


func load_saved_state() -> void:
	var state = SaveManager.game_state
	player.set_state(state.player_position, state.player_size, state.player_color)
	time_survived = state.time_survived
	distance_traveled = state.distance_traveled
	camera.global_position = player.global_position
	update_camera_zoom(player.current_size)
	camera.zoom = Vector2(target_zoom, target_zoom)


func save_current_state() -> void:
	SaveManager.update_run(
		player.global_position,
		player.current_size,
		player.get_color_int(),
		time_survived,
		distance_traveled
	)


func update_size_display() -> void:
	size_label.text = "%.1f" % player.current_size


func update_camera_zoom(size: float) -> void:
	if size <= 5.0:
		target_zoom = 1.0
		return
	target_zoom = 1.0 / pow(size / 5.0, ZOOM_COMPENSATION)
	target_zoom = maxf(target_zoom, 0.1)


func _on_player_size_changed(new_size: float) -> void:
	update_size_display()
	update_camera_zoom(new_size)


func _on_player_died() -> void:
	is_game_active = false

	# Prepare final stats
	var final_stats = {
		"time_survived": time_survived,
		"max_size": SaveManager.game_state.max_size,
		"distance_traveled": distance_traveled
	}

	# Clear save since run is over
	SaveManager.clear_state()

	# Transition to game over
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

	# Store stats for game over screen (using a simple approach)
	Engine.set_meta("last_run_stats", final_stats)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android back button - save and quit to menu
		save_current_state()
		get_tree().change_scene_to_file("res://scenes/main.tscn")
