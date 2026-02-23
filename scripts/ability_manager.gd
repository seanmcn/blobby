extends Node
class_name AbilityManager

enum BlobColor { NONE, RED, BLUE, GREEN, YELLOW, PURPLE }

const COLORS = {
	BlobColor.NONE: Color.WHITE,
	BlobColor.RED: Color8(255, 120, 120),
	BlobColor.BLUE: Color8(120, 180, 255),
	BlobColor.GREEN: Color8(140, 220, 140),
	BlobColor.YELLOW: Color8(255, 240, 150),
	BlobColor.PURPLE: Color8(200, 150, 255),
}

var current_color: BlobColor = BlobColor.NONE
var player: CharacterBody2D

# Ability parameters
const BLUE_SPEED_BONUS: float = 1.15
const GREEN_GROWTH_RATE: float = 0.001
const YELLOW_ATTRACT_RADIUS: float = 200.0
const YELLOW_ATTRACT_FORCE: float = 50.0
const PURPLE_DAMAGE_RADIUS: float = 150.0
const PURPLE_DAMAGE_RATE: float = 0.5


func _ready() -> void:
	player = get_parent() as CharacterBody2D


func set_color(new_color: BlobColor) -> void:
	current_color = new_color
	if player:
		player.modulate = COLORS.get(new_color, Color.WHITE)


func set_color_from_int(color_int: int) -> void:
	set_color(color_int as BlobColor)


func get_color_int() -> int:
	return current_color as int


func get_visual_color() -> Color:
	return COLORS.get(current_color, Color.WHITE)


func get_speed_multiplier() -> float:
	if current_color == BlobColor.BLUE:
		return BLUE_SPEED_BONUS
	return 1.0


func get_mass_multiplier() -> float:
	if current_color == BlobColor.RED:
		return 1.25
	return 1.0


func apply_passive(delta: float) -> void:
	if not player:
		return

	match current_color:
		BlobColor.RED:
			pass  # Mass gain handled in absorption via get_mass_multiplier
		BlobColor.BLUE:
			pass  # Speed handled via get_speed_multiplier
		BlobColor.GREEN:
			# Very subtle passive growth
			player.grow(GREEN_GROWTH_RATE * delta)
		BlobColor.YELLOW:
			attract_nearby_blobs()
		BlobColor.PURPLE:
			damage_nearby_hunters(delta)


func attract_nearby_blobs() -> void:
	if not player:
		return

	var blobs_container = player.get_tree().get_first_node_in_group("blobs_container")
	if not blobs_container:
		return

	for blob in blobs_container.get_children():
		if not is_instance_valid(blob):
			continue
		var distance = player.global_position.distance_to(blob.global_position)
		if distance < YELLOW_ATTRACT_RADIUS and distance > 10.0:
			var direction = (player.global_position - blob.global_position).normalized()
			blob.global_position += direction * YELLOW_ATTRACT_FORCE * get_process_delta_time()


func damage_nearby_hunters(delta: float) -> void:
	if not player:
		return

	var hunters_container = player.get_tree().get_first_node_in_group("hunters_container")
	if not hunters_container:
		return

	for hunter in hunters_container.get_children():
		if not is_instance_valid(hunter):
			continue
		var distance = player.global_position.distance_to(hunter.global_position)
		if distance < PURPLE_DAMAGE_RADIUS:
			hunter.take_damage(PURPLE_DAMAGE_RATE * delta)


static func get_random_color(rng: RandomNumberGenerator) -> BlobColor:
	# 60% chance of no color, 40% chance of colored
	if rng.randf() < 0.6:
		return BlobColor.NONE
	return (rng.randi() % 5 + 1) as BlobColor
