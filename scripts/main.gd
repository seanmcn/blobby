extends Control

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var resume_button: Button = $VBoxContainer/ResumeButton
@onready var title_label: Label = $VBoxContainer/TitleLabel


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	resume_button.pressed.connect(_on_resume_pressed)

	# Show/hide resume button based on saved state
	resume_button.visible = SaveManager.game_state.has_active_run

	if SaveManager.game_state.has_active_run:
		play_button.text = "New Game"
	else:
		play_button.text = "Play"


func _on_play_pressed() -> void:
	SaveManager.clear_state()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_resume_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
