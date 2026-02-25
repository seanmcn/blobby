extends Area2D

@export var base_radius: float = 15.0

var size: float = 1.0
var blob_color: int = 0  # AbilityManager.BlobColor value

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Polygon2D = $Sprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	update_visual()


func initialize(blob_size: float, color: int) -> void:
	size = blob_size
	blob_color = color
	update_visual()


func update_visual() -> void:
	var scale_factor = sqrt(size)
	scale = Vector2(scale_factor, scale_factor)

	# Apply color
	modulate = AbilityManager.COLORS.get(blob_color, Color.WHITE)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var player = body as CharacterBody2D
		if player.has_method("can_absorb") and player.can_absorb(size):
			player.absorb(size, blob_color)
			play_absorb_animation(body)


func play_absorb_animation(target: Node2D) -> void:
	# Disable collision so blob can't be absorbed again
	set_deferred("monitoring", false)

	# Trigger membrane deformation on the player
	if target.has_method("play_absorb_deformation"):
		target.play_absorb_deformation(global_position)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", target.global_position, 0.2)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)
