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

var _base_polygon: PackedVector2Array
var _deformations: Array = []

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Polygon2D = $Sprite2D
@onready var ability_manager: AbilityManager = $AbilityManager


func _ready() -> void:
	add_to_group("player")
	last_position = global_position
	_base_polygon = sprite.polygon.duplicate()
	update_visual_size()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		target_velocity = event.relative * drag_sensitivity * get_speed_modifier() * base_speed


func _process(_delta: float) -> void:
	if _deformations.size() > 0:
		_update_polygon()


func _physics_process(delta: float) -> void:
	# Check for keyboard input
	var keyboard_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if keyboard_input != Vector2.ZERO:
		target_velocity = keyboard_input * base_speed * get_speed_modifier()

	# Smooth movement with inertia
	velocity = velocity.lerp(target_velocity, smoothing * delta)
	target_velocity = target_velocity.lerp(Vector2.ZERO, smoothing * delta)

	move_and_slide()

	# Apply passive ability effects
	if ability_manager:
		ability_manager.apply_passive(delta)


func get_speed_modifier() -> float:
	# Boost world-space speed to offset camera zoom making movement look sluggish
	var zoom_compensation = 1.0
	if current_size > 5.0:
		zoom_compensation = pow(current_size / 5.0, 0.12)
	var size_drag = 1.0 / (1.0 + current_size * 0.002)
	var base_modifier = max(zoom_compensation * size_drag, 0.75)

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


func play_absorb_deformation(absorb_global_pos: Vector2) -> void:
	var local_dir = (absorb_global_pos - global_position).normalized()
	var contact_angle = local_dir.angle()

	var deformation = {angle = contact_angle, strength = 0.0}
	_deformations.append(deformation)

	var tween = create_tween()
	# Indent inward
	tween.tween_method(func(val): deformation.strength = val, 0.0, 1.0, 0.08) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Spring back with overshoot (bulge outward)
	tween.tween_method(func(val): deformation.strength = val, 1.0, -0.15, 0.1) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Settle to rest
	tween.tween_method(func(val): deformation.strength = val, -0.15, 0.0, 0.08) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	# Cleanup
	tween.tween_callback(func():
		_deformations.erase(deformation)
		if _deformations.size() == 0:
			sprite.polygon = _base_polygon
	)


func _update_polygon() -> void:
	var new_polygon = _base_polygon.duplicate()
	var indent_depth = base_radius * 0.35
	var indent_width = PI / 2.5

	for i in range(new_polygon.size()):
		var vertex = new_polygon[i]
		var vertex_dir = Vector2(vertex.x, vertex.y)
		var vertex_angle = vertex_dir.angle()
		var offset = Vector2.ZERO

		for def in _deformations:
			var angle_diff = wrapf(vertex_angle - def.angle, -PI, PI)
			if abs(angle_diff) < indent_width:
				var factor = cos(angle_diff / indent_width * PI / 2.0)
				offset -= vertex_dir.normalized() * indent_depth * def.strength * factor

		new_polygon[i] = vertex + offset

	sprite.polygon = new_polygon
