class_name FloatingOrigin
extends Node3D

signal origin_shifted(shift_delta: Vector3, new_origin_chunk: Vector2i)

const CHUNK_SIZE: float = WorldBlueprint.CHUNK_SIZE

@export var shift_threshold_m: float = 256.0

## Integer chunk index corresponding to local (0, 0, 0) so cumulative float drift is strictly zero.
var origin_chunk: Vector2i = Vector2i.ZERO
var total_shifts: int = 0


func get_origin_world_pos() -> Vector3:
	return Vector3(float(origin_chunk.x) * CHUNK_SIZE, 0.0, float(origin_chunk.y) * CHUNK_SIZE)


func local_to_world(local_pos: Vector3) -> Vector3:
	return local_pos + get_origin_world_pos()


func world_to_local(world_pos: Vector3) -> Vector3:
	return world_pos - get_origin_world_pos()


func world_to_chunk(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / CHUNK_SIZE)),
		int(floor(world_pos.z / CHUNK_SIZE))
	)


func chunk_to_local_origin(cx: int, cz: int) -> Vector3:
	return Vector3(
		float(cx - origin_chunk.x) * CHUNK_SIZE,
		0.0,
		float(cz - origin_chunk.y) * CHUNK_SIZE
	)


func set_origin_to_world_pos(world_pos: Vector3) -> void:
	origin_chunk = world_to_chunk(world_pos)


func check_and_shift(focus_local_pos: Vector3, tracked_nodes: Array = []) -> Vector3:
	if absf(focus_local_pos.x) <= shift_threshold_m and absf(focus_local_pos.z) <= shift_threshold_m:
		return Vector3.ZERO

	# Quantize shift strictly to CHUNK_SIZE (128m) increments so chunks keep exact integer transforms
	var dcx: int = int(round(focus_local_pos.x / CHUNK_SIZE))
	var dcz: int = int(round(focus_local_pos.z / CHUNK_SIZE))
	if dcx == 0 and dcz == 0:
		return Vector3.ZERO

	origin_chunk += Vector2i(dcx, dcz)
	total_shifts += 1
	var shift_vec := Vector3(float(dcx) * CHUNK_SIZE, 0.0, float(dcz) * CHUNK_SIZE)

	for item in tracked_nodes:
		if item == null or not is_instance_valid(item):
			continue
		if item.has_method("apply_origin_shift"):
			item.apply_origin_shift(shift_vec)
		elif item is Node3D:
			(item as Node3D).global_position -= shift_vec

	origin_shifted.emit(shift_vec, origin_chunk)
	return shift_vec
