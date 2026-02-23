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
			queue_free()
