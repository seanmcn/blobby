extends Node

const SAVE_PATH = "user://blobby_save.tres"
const GameStateScript = preload("res://resources/game_state.gd")

var game_state: Resource


func _ready() -> void:
	game_state = load_state()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_state()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		save_state()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_state()


func save_state() -> void:
	if game_state.has_active_run:
		ResourceSaver.save(game_state, SAVE_PATH)


func load_state() -> Resource:
	if ResourceLoader.exists(SAVE_PATH):
		var loaded = ResourceLoader.load(SAVE_PATH)
		if loaded:
			return loaded
	return GameStateScript.new()


func clear_state() -> void:
	game_state = GameStateScript.new()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func get_seed() -> int:
	if game_state.world_seed == 0:
		game_state.world_seed = randi()
	return game_state.world_seed


func start_new_run() -> void:
	game_state = GameStateScript.new()
	game_state.has_active_run = true
	game_state.world_seed = randi()


func update_run(position: Vector2, size: float, color: int, time: float, distance: float) -> void:
	game_state.player_position = position
	game_state.player_size = size
	game_state.player_color = color
	game_state.time_survived = time
	game_state.distance_traveled = distance
	game_state.max_size = max(game_state.max_size, size)
