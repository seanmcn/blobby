extends Node

const CHUNK_SIZE: int = 512

var spawn_radius: int = 3
var despawn_radius: int = 5

const BLOBS_PER_CHUNK: int = 8
const BASE_HUNTER_CHANCE: float = 0.1

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var active_chunks: Dictionary = {}  # Vector2i -> Array[Node]

var blob_scene: PackedScene
var hunter_scene: PackedScene

@onready var blobs_container: Node2D
@onready var hunters_container: Node2D


func _ready() -> void:
	blob_scene = load("res://scenes/blob.tscn")
	hunter_scene = load("res://scenes/hunter.tscn")


func initialize(blobs_node: Node2D, hunters_node: Node2D, seed_value: int) -> void:
	blobs_container = blobs_node
	hunters_container = hunters_node
	rng.seed = seed_value
	active_chunks.clear()
	update_spawn_radius()
	get_viewport().size_changed.connect(update_spawn_radius)


func update_spawn_radius() -> void:
	var visible_size = get_viewport().get_visible_rect().size
	var max_extent = max(visible_size.x, visible_size.y) / 2.0
	var needed_chunks = int(ceil(max_extent / CHUNK_SIZE)) + 1
	spawn_radius = max(3, needed_chunks)
	despawn_radius = spawn_radius + 2


func update_chunks(player_pos: Vector2, player_size: float, time: float) -> void:
	var player_chunk = world_to_chunk(player_pos)

	# Spawn new chunks in range
	for x in range(-spawn_radius, spawn_radius + 1):
		for y in range(-spawn_radius, spawn_radius + 1):
			var chunk = player_chunk + Vector2i(x, y)
			if not active_chunks.has(chunk):
				spawn_chunk(chunk, player_size, time)

	# Despawn distant chunks
	var chunks_to_remove: Array[Vector2i] = []
	for chunk in active_chunks.keys():
		var chunk_vec = chunk as Vector2i
		if chunk_distance(chunk_vec, player_chunk) > despawn_radius:
			chunks_to_remove.append(chunk_vec)

	for chunk in chunks_to_remove:
		despawn_chunk(chunk)


func world_to_chunk(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / CHUNK_SIZE)),
		int(floor(world_pos.y / CHUNK_SIZE))
	)


func chunk_to_world(chunk: Vector2i) -> Vector2:
	return Vector2(chunk.x * CHUNK_SIZE, chunk.y * CHUNK_SIZE)


func chunk_distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


func spawn_chunk(chunk: Vector2i, player_size: float, time: float) -> void:
	# Use chunk coordinates to create deterministic seed for this chunk
	var chunk_seed = rng.seed + chunk.x * 73856093 + chunk.y * 19349663
	var chunk_rng = RandomNumberGenerator.new()
	chunk_rng.seed = chunk_seed

	var spawned_nodes: Array[Node] = []
	var chunk_origin = chunk_to_world(chunk)

	# Spawn neutral blobs
	var blob_count = chunk_rng.randi_range(BLOBS_PER_CHUNK - 2, BLOBS_PER_CHUNK + 2)
	for i in range(blob_count):
		var blob = spawn_blob(chunk_origin, chunk_rng, player_size)
		if blob:
			spawned_nodes.append(blob)

	# Spawn hunters based on time and distance from origin
	var hunter_chance = BASE_HUNTER_CHANCE + (time * 0.001) + (chunk.length() * 0.01)
	hunter_chance = clamp(hunter_chance, 0.0, 0.5)

	if chunk_rng.randf() < hunter_chance:
		var hunter = spawn_hunter(chunk_origin, chunk_rng, player_size, time)
		if hunter:
			spawned_nodes.append(hunter)

	active_chunks[chunk] = spawned_nodes


func spawn_blob(chunk_origin: Vector2, chunk_rng: RandomNumberGenerator, player_size: float) -> Node:
	if not blob_scene or not blobs_container:
		return null

	var blob = blob_scene.instantiate()

	# Random position within chunk
	var pos = chunk_origin + Vector2(
		chunk_rng.randf() * CHUNK_SIZE,
		chunk_rng.randf() * CHUNK_SIZE
	)
	blob.global_position = pos

	# Size varies, generally smaller than player could be
	var blob_size = chunk_rng.randf_range(0.3, max(1.5, player_size * 0.8))

	# Random color
	var color = AbilityManager.get_random_color(chunk_rng)

	blob.initialize(blob_size, color)
	blobs_container.add_child(blob)

	return blob


func spawn_hunter(chunk_origin: Vector2, chunk_rng: RandomNumberGenerator, player_size: float, time: float) -> Node:
	if not hunter_scene or not hunters_container:
		return null

	var hunter = hunter_scene.instantiate()

	# Random position within chunk
	var pos = chunk_origin + Vector2(
		chunk_rng.randf() * CHUNK_SIZE,
		chunk_rng.randf() * CHUNK_SIZE
	)
	hunter.global_position = pos

	# Hunter size is always 2x-3x player size
	var hunter_size = chunk_rng.randf_range(player_size * 2.0, player_size * 3.0)

	hunter.initialize(hunter_size)
	hunters_container.add_child(hunter)

	return hunter


func despawn_chunk(chunk: Vector2i) -> void:
	if not active_chunks.has(chunk):
		return

	var nodes = active_chunks[chunk] as Array
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()

	active_chunks.erase(chunk)


func clear_all() -> void:
	for chunk in active_chunks.keys():
		despawn_chunk(chunk)
	active_chunks.clear()
