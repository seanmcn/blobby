extends CharacterBody2D

@export var base_speed: float = 80.0
@export var steering_strength: float = 2.0
@export var base_radius: float = 25.0

var size: float = 1.5
var health: float = 1.0
var target: Node2D = null

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Polygon2D = $Sprite2D


func _ready() -> void:
	add_to_group("hunters")
	update_visual()
	# Find and always target the player
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
	if target and is_instance_valid(target):
		# Always pursue the player
		var desired = (target.global_position - global_position).normalized() * get_speed()
		velocity = velocity.lerp(desired, steering_strength * delta)
	else:
		# Drift slowly when no target
		velocity = velocity.lerp(Vector2.ZERO, delta * 0.5)

	move_and_slide()

	# Check for collision with player
	check_player_collision()


func get_speed() -> float:
	# Slightly faster when larger, but not too much
	return base_speed * (1.0 + size * 0.05)


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
			queue_free()
		else:
			# Hunter kills player
			if target.has_method("die"):
				target.die()


func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		queue_free()


