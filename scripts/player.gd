extends CharacterBody2D

signal died
signal size_changed(new_size: float)

@export var base_speed: float = 200.0
@export var smoothing: float = 5.0
@export var drag_sensitivity: float = 1.5
@export var base_radius: float = 20.0

var target_velocity: Vector2 = Vector2.ZERO
var current_size: float = 1.0
var last_position: Vector2 = Vector2.ZERO

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Polygon2D = $Sprite2D
@onready var ability_manager: AbilityManager = $AbilityManager


func _ready() -> void:
	add_to_group("player")
	last_position = global_position
	update_visual_size()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		target_velocity = event.relative * drag_sensitivity * get_speed_modifier() * base_speed


func _physics_process(delta: float) -> void:
	# Smooth movement with inertia
	velocity = velocity.lerp(target_velocity, smoothing * delta)
	target_velocity = target_velocity.lerp(Vector2.ZERO, smoothing * delta)

	move_and_slide()

	# Apply passive ability effects
	if ability_manager:
		ability_manager.apply_passive(delta)


func get_speed_modifier() -> float:
	# Slightly slower when larger
	var size_penalty = 1.0 - (current_size * 0.005)
	var base_modifier = clamp(size_penalty, 0.5, 1.2)

	# Apply ability bonus
	if ability_manager:
		base_modifier *= ability_manager.get_speed_multiplier()

	return base_modifier


func get_distance_traveled() -> float:
	var distance = global_position.distance_to(last_position)
	last_position = global_position
	return distance


func get_radius() -> float:
	return base_radius * sqrt(current_size)


func can_absorb(other_size: float) -> bool:
	return current_size > other_size * 1.1


func absorb(blob_size: float, blob_color: int) -> void:
	var mass_gain = blob_size * 0.1
	if ability_manager:
		mass_gain *= ability_manager.get_mass_multiplier()

	grow(mass_gain)

	# Inherit color from absorbed blob
	if blob_color != AbilityManager.BlobColor.NONE:
		ability_manager.set_color_from_int(blob_color)


func grow(amount: float) -> void:
	current_size += amount
	update_visual_size()
	size_changed.emit(current_size)


func update_visual_size() -> void:
	var scale_factor = sqrt(current_size)
	scale = Vector2(scale_factor, scale_factor)

	# Update collision shape radius
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = base_radius


func die() -> void:
	died.emit()


func set_state(position: Vector2, size: float, color: int) -> void:
	global_position = position
	last_position = position
	current_size = size
	update_visual_size()
	if ability_manager:
		ability_manager.set_color_from_int(color)


func get_color_int() -> int:
	if ability_manager:
		return ability_manager.get_color_int()
	return 0
