extends Control

@onready var time_label: Label = $VBoxContainer/TimeLabel
@onready var size_label: Label = $VBoxContainer/SizeLabel
@onready var distance_label: Label = $VBoxContainer/DistanceLabel
@onready var restart_button: Button = $VBoxContainer/RestartButton


func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	display_stats()


func display_stats() -> void:
	var stats = {}
	if Engine.has_meta("last_run_stats"):
		stats = Engine.get_meta("last_run_stats")
		Engine.remove_meta("last_run_stats")

	var time = stats.get("time_survived", 0.0)
	var size = stats.get("max_size", 1.0)
	var distance = stats.get("distance_traveled", 0.0)

	time_label.text = "Time: %s" % format_time(time)
	size_label.text = "Max Size: %.1f" % size
	distance_label.text = "Distance: %.0f" % distance


func format_time(seconds: float) -> String:
	var minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%d:%02d" % [minutes, secs]


func _on_restart_pressed() -> void:
	SaveManager.clear_state()
	get_tree().change_scene_to_file("res://scenes/game.tscn")
