extends CharacterBody2D

@export var base_speed: float = 80.0
@export var steering_strength: float = 2.0
@export var base_radius: float = 25.0

var size: float = 1.5
var health: float = 1.0
var target: Node2D = null
var speed_ratio: float = 1.0

# State machine
enum State { WANDERING, PURSUING }
var state: State = State.WANDERING

# Wander behavior
var wander_speed: float = 40.0
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var detection_radius: float = 400.0

# Surround behavior
var approach_angle_offset: float = 0.0
var surround_offset_strength: float = 0.4

# Separation behavior
var separation_radius: float = 80.0
var separation_strength: float = 150.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Polygon2D = $Sprite2D


func _ready() -> void:
	add_to_group("hunters")
	update_visual()

	# Initialize wander state
	wander_direction = Vector2.from_angle(randf() * TAU)
	wander_timer = randf_range(2.0, 4.0)

	# Random approach angle offset for surround behavior (fixed for lifetime)
	approach_angle_offset = randf_range(-PI, PI)

	# Random speed ratio so hunters aren't perfectly uniform
	speed_ratio = randf_range(0.95, 1.05)

	# Find the player reference (but don't pursue yet)
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]


func initialize(hunter_size: float) -> void:
	size = hunter_size
	health = 1.0
	update_visual()


func update_visual() -> void:
	var scale_factor = sqrt(size)
	scale = Vector2(scale_factor, scale_factor)

	# Hunters have a reddish tint
	modulate = Color8(255, 100, 100)


func _physics_process(delta: float) -> void:
	match state:
		State.WANDERING:
			_process_wandering(delta)
		State.PURSUING:
			_process_pursuing(delta)

	move_and_slide()


func _process_wandering(delta: float) -> void:
	# Move slowly in wander direction
	var desired = wander_direction * wander_speed
	velocity = velocity.lerp(desired, steering_strength * delta)

	# Count down wander timer and re-roll direction
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_direction = Vector2.from_angle(randf() * TAU)
		wander_timer = randf_range(2.0, 4.0)

	# Check if player is within detection radius
	if target and is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist <= detection_radius:
			state = State.PURSUING


func _process_pursuing(delta: float) -> void:
	if target and is_instance_valid(target):
		var to_player = target.global_position - global_position
		var dist = to_player.length()
		var pursuit_dir = to_player.normalized()

		# Surround: offset the approach angle, stronger when closer
		var max_offset_dist = detection_radius
		var offset_weight = clampf(1.0 - (dist / max_offset_dist), 0.0, 1.0)
		var angle_offset = approach_angle_offset * surround_offset_strength * offset_weight
		pursuit_dir = pursuit_dir.rotated(angle_offset)

		var desired = pursuit_dir * get_speed()

		# Separation: push away from nearby hunters
		var separation_force = Vector2.ZERO
		var hunters = get_tree().get_nodes_in_group("hunters")
		for hunter in hunters:
			if hunter == self or not is_instance_valid(hunter):
				continue
			var diff = global_position - hunter.global_position
			var hunter_dist = diff.length()
			if hunter_dist > 0.0 and hunter_dist < separation_radius:
				# Stronger repulsion when closer
				var strength = (1.0 - hunter_dist / separation_radius) * separation_strength
				separation_force += diff.normalized() * strength

		desired += separation_force

		velocity = velocity.lerp(desired, steering_strength * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, delta * 0.5)

	# Check for collision with player
	check_player_collision()


func get_speed() -> float:
	if target and is_instance_valid(target):
		var player_speed = target.base_speed * target.get_speed_modifier()
		return player_speed * speed_ratio
	return base_speed


func get_radius() -> float:
	return base_radius * sqrt(size)


func check_player_collision() -> void:
	if not target or not is_instance_valid(target):
		return

	var distance = global_position.distance_to(target.global_position)
	var combined_radius = get_radius() + target.get_radius()

	if distance < combined_radius * 1.1:
		# Collision detected
		if target.has_method("can_absorb") and target.can_absorb(size):
			# Player absorbs hunter
			target.absorb(size, 0)
			play_absorb_animation(target)
		else:
			# Hunter kills player
			if target.has_method("die"):
				target.die()


func play_absorb_animation(absorber: Node2D) -> void:
	# Stop all hunter behavior
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	# Trigger membrane deformation on the player
	if absorber.has_method("play_absorb_deformation"):
		absorber.play_absorb_deformation(global_position)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", absorber.global_position, 0.2)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)


func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		queue_free()
