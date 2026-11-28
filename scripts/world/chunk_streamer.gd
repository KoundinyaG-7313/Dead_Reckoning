class_name ChunkStreamer
extends Node3D

signal chunk_loaded(coord: Vector2i, lod: int, metadata: Dictionary)
signal chunk_unloaded(coord: Vector2i)
signal initial_preload_finished()

const MIN_CHUNK: int = -125
const MAX_CHUNK: int = 124
const TEX_BASE: String = "res://assets/textures/"
const TERRAIN_SHADER_PATH: String = "res://shaders/cascade_terrain.gdshader"

@export var load_radius_chunks: int = 5
@export var lod0_radius_chunks: int = 1
@export var lod1_radius_chunks: int = 3
@export var physics_radius_chunks: int = 1
@export var max_in_flight_tasks: int = 8
@export var max_commits_per_frame: int = 2

var sampler: TerrainSampler
var floating_origin: FloatingOrigin
var asset_bank: CascadeAssetBank
var focus_world_pos: Vector3 = Vector3.ZERO

var _active_chunks: Dictionary = {} # Vector2i -> {node, lod, has_collision, meta}
var _pending_jobs: Dictionary = {}  # Vector2i -> ChunkBuildJob
var _ready_commits: Array[ChunkBuildJob] = []
var _active_landmarks: Dictionary = {} # site_id -> {id, coord, anchor_world, node, beacons, swaying, flickers}
var _sites_by_chunk: Dictionary = {}   # Vector2i -> Array[Dictionary]
var _landmarks_root: Node3D
var _variant_counts: Dictionary = {}
var _terrain_material: ShaderMaterial
var _water_material: Material
var _preloaded: bool = false
var _last_worker_ms_sum: int = 0
var _last_commit_ms_max: int = 0
var _total_commits: int = 0


class ChunkBuildJob extends RefCounted:
	var coord: Vector2i
	var lod: int
	var build_collision: bool
	var sampler_ref: TerrainSampler
	var variant_counts: Dictionary
	var task_id: int = -1
	var output: Dictionary = {}

	func _init(c: Vector2i, l: int, col: bool, smp: TerrainSampler, vc: Dictionary) -> void:
		coord = c
		lod = l
		build_collision = col
		sampler_ref = smp
		variant_counts = vc

	func run() -> void:
		output = ChunkMesher.build_chunk_data(sampler_ref, coord.x, coord.y, lod, build_collision, variant_counts)


func setup(p_sampler: TerrainSampler, p_origin: FloatingOrigin, initial_focus_world: Vector3) -> void:
	sampler = p_sampler
	floating_origin = p_origin
	focus_world_pos = initial_focus_world
	if not floating_origin.origin_shifted.is_connected(_on_origin_shifted):
		floating_origin.origin_shifted.connect(_on_origin_shifted)
	if asset_bank == null:
		asset_bank = CascadeAssetBank.new()
	asset_bank.ensure_loaded()
	_variant_counts = asset_bank.get_variant_counts()
	if _landmarks_root == null:
		_landmarks_root = Node3D.new()
		_landmarks_root.name = "CascadeLandmarksRoot"
		add_child(_landmarks_root)
	_index_landmarks_by_chunk()
	_ensure_shared_materials()


func preload_initial_chunks(center_world_pos: Vector3) -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	focus_world_pos = center_world_pos
	var center: Vector2i = floating_origin.world_to_chunk(center_world_pos)
	var batch: Array[ChunkBuildJob] = []

	for dz in range(-load_radius_chunks, load_radius_chunks + 1):
		for dx in range(-load_radius_chunks, load_radius_chunks + 1):
			var c := Vector2i(center.x + dx, center.y + dz)
			if not _is_chunk_in_bounds(c):
				continue
			var cheb: int = maxi(absi(dx), absi(dz))
			if cheb > load_radius_chunks:
				continue
			var desired_lod: int = _get_desired_lod(cheb)
			var want_col: bool = cheb <= physics_radius_chunks
			var job := ChunkBuildJob.new(c, desired_lod, want_col, sampler, _variant_counts)
			job.task_id = WorkerThreadPool.add_task(job.run, false, "CascadePreloadChunk")
			batch.append(job)

	# Sort near-to-far so center collision lands first
	batch.sort_custom(func(a: ChunkBuildJob, b: ChunkBuildJob) -> bool:
		return a.coord.distance_squared_to(center) < b.coord.distance_squared_to(center)
	)

	var worker_ms_sum: int = 0
	var max_commit_ms: int = 0
	for job in batch:
		WorkerThreadPool.wait_for_task_completion(job.task_id)
		var c0: int = Time.get_ticks_msec()
		_commit_chunk_job(job)
		max_commit_ms = maxi(max_commit_ms, Time.get_ticks_msec() - c0)
		worker_ms_sum += int(job.output.get("gen_ms", 0))

	_last_worker_ms_sum = worker_ms_sum
	_last_commit_ms_max = max_commit_ms
	_preloaded = true
	initial_preload_finished.emit()
	return {
		"chunks_loaded": _active_chunks.size(),
		"preload_wall_ms": Time.get_ticks_msec() - t0,
		"worker_cpu_ms_sum": worker_ms_sum,
		"max_single_commit_ms": max_commit_ms,
	}


func step_streaming(current_focus_world: Vector3) -> void:
	if sampler == null or floating_origin == null:
		return
	focus_world_pos = current_focus_world
	var center: Vector2i = floating_origin.world_to_chunk(focus_world_pos)

	# 1. Harvest finished worker tasks cleanly
	var done_coords: Array[Vector2i] = []
	for coord_key in _pending_jobs.keys():
		var job: ChunkBuildJob = _pending_jobs[coord_key]
		if WorkerThreadPool.is_task_completed(job.task_id):
			WorkerThreadPool.wait_for_task_completion(job.task_id)
			done_coords.append(coord_key)
			_ready_commits.append(job)
	for ck in done_coords:
		_pending_jobs.erase(ck)

	# 2. Commit closest ready chunks under per-frame spike budget
	if not _ready_commits.is_empty():
		_ready_commits.sort_custom(func(a: ChunkBuildJob, b: ChunkBuildJob) -> bool:
			return a.coord.distance_squared_to(center) < b.coord.distance_squared_to(center)
		)
		var committed: int = 0
		while not _ready_commits.is_empty() and committed < max_commits_per_frame:
			var job: ChunkBuildJob = _ready_commits.pop_front()
			var cheb: int = maxi(absi(job.coord.x - center.x), absi(job.coord.y - center.y))
			if cheb <= load_radius_chunks + 1:
				var c0: int = Time.get_ticks_msec()
				_commit_chunk_job(job)
				_last_commit_ms_max = maxi(_last_commit_ms_max, Time.get_ticks_msec() - c0)
				committed += 1

	# 3. Enqueue missing chunks or LOD upgrades by proximity priority
	var free_slots: int = maxi(0, max_in_flight_tasks - _pending_jobs.size())
	if free_slots > 0:
		var candidates: Array[Dictionary] = []
		for dz in range(-load_radius_chunks, load_radius_chunks + 1):
			for dx in range(-load_radius_chunks, load_radius_chunks + 1):
				var c := Vector2i(center.x + dx, center.y + dz)
				if not _is_chunk_in_bounds(c):
					continue
				if _pending_jobs.has(c):
					continue
				var cheb: int = maxi(absi(dx), absi(dz))
				var desired_lod: int = _get_desired_lod(cheb)
				var want_col: bool = cheb <= physics_radius_chunks

				var existing: Dictionary = _active_chunks.get(c, {})
				if not existing.is_empty():
					if int(existing["lod"]) == desired_lod and bool(existing["has_collision"]) == want_col:
						continue
				# Skip if already waiting in commit queue at matching target LOD
				var queued_match: bool = false
				for qj in _ready_commits:
					if qj.coord == c and qj.lod == desired_lod and qj.build_collision == want_col:
						queued_match = true
						break
				if queued_match:
					continue

				var prio: float = float(dx * dx + dz * dz)
				if want_col and (existing.is_empty() or not bool(existing["has_collision"])):
					# Tier 0: Never let outer visual LOD2 horizon chunks starve nearby terrain collision!
					prio += 0.0
				elif existing.is_empty():
					# Tier 1: Missing visible terrain
					prio += 200.0
				else:
					# Tier 2: Pure visual LOD refinement over already-visible terrain
					prio += 500.0
				candidates.append({"coord": c, "lod": desired_lod, "col": want_col, "prio": prio})

		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["prio"]) < float(b["prio"])
		)
		for i in range(mini(free_slots, candidates.size())):
			var item: Dictionary = candidates[i]
			var c: Vector2i = item["coord"]
			var job := ChunkBuildJob.new(c, int(item["lod"]), bool(item["col"]), sampler, _variant_counts)
			job.task_id = WorkerThreadPool.add_task(job.run, false, "CascadeStreamChunk")
			_pending_jobs[c] = job

	# 4. Unload chunks & landmarks outside hysteresis ring
	var to_unload: Array[Vector2i] = []
	var unload_cut: int = load_radius_chunks + 1
	for c_key in _active_chunks.keys():
		var c: Vector2i = c_key
		var cheb: int = maxi(absi(c.x - center.x), absi(c.y - center.y))
		if cheb > unload_cut:
			to_unload.append(c)
	for uc in to_unload:
		var entry: Dictionary = _active_chunks[uc]
		var node: Node3D = entry["node"]
		if is_instance_valid(node):
			node.queue_free()
		_active_chunks.erase(uc)
		_unload_chunk_landmarks(uc)
		chunk_unloaded.emit(uc)


func wait_for_all_pending_and_commit(center_world_pos: Vector3) -> void:
	focus_world_pos = center_world_pos
	var center: Vector2i = floating_origin.world_to_chunk(focus_world_pos)
	# Ensure immediate physics ring around focus is queued if not yet active/pending
	for dz in range(-physics_radius_chunks, physics_radius_chunks + 1):
		for dx in range(-physics_radius_chunks, physics_radius_chunks + 1):
			var c := Vector2i(center.x + dx, center.y + dz)
			if not _is_chunk_in_bounds(c) or _pending_jobs.has(c):
				continue
			var existing: Dictionary = _active_chunks.get(c, {})
			if existing.is_empty() or not bool(existing["has_collision"]):
				var job := ChunkBuildJob.new(c, 0, true, sampler, _variant_counts)
				job.task_id = WorkerThreadPool.add_task(job.run, false, "CascadeSyncColChunk")
				_pending_jobs[c] = job

	for ck in _pending_jobs.keys():
		var job: ChunkBuildJob = _pending_jobs[ck]
		WorkerThreadPool.wait_for_task_completion(job.task_id)
		_ready_commits.append(job)
	_pending_jobs.clear()
	while not _ready_commits.is_empty():
		_commit_chunk_job(_ready_commits.pop_front())


func get_active_chunk_count() -> int:
	return _active_chunks.size()


func get_active_landmark_count() -> int:
	return _active_landmarks.size()


func get_active_landmarks() -> Array:
	return _active_landmarks.values()


func get_total_foliage_instances() -> int:
	var sum: int = 0
	for entry in _active_chunks.values():
		sum += int(entry["meta"].get("foliage_instances", 0))
	return sum


func get_pending_task_count() -> int:
	return _pending_jobs.size()


func get_chunk_info(coord: Vector2i) -> Dictionary:
	return _active_chunks.get(coord, {})


func clear_all_chunks() -> void:
	_flush_pending_tasks()
	_ready_commits.clear()
	for entry in _active_chunks.values():
		var node: Node3D = entry["node"]
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_active_chunks.clear()
	for lm in _active_landmarks.values():
		var ln: Node3D = lm["node"]
		if is_instance_valid(ln):
			ln.queue_free()
	_active_landmarks.clear()


func _exit_tree() -> void:
	_flush_pending_tasks()


func _flush_pending_tasks() -> void:
	for ck in _pending_jobs.keys():
		var job: ChunkBuildJob = _pending_jobs[ck]
		if job.task_id >= 0:
			WorkerThreadPool.wait_for_task_completion(job.task_id)
	_pending_jobs.clear()


func _is_chunk_in_bounds(c: Vector2i) -> bool:
	return c.x >= MIN_CHUNK and c.x <= MAX_CHUNK and c.y >= MIN_CHUNK and c.y <= MAX_CHUNK


func _get_desired_lod(cheb_dist: int) -> int:
	if cheb_dist <= lod0_radius_chunks:
		return 0
	if cheb_dist <= lod1_radius_chunks:
		return 1
	return 2


func _commit_chunk_job(job: ChunkBuildJob) -> void:
	var data: Dictionary = job.output
	if data.is_empty():
		return
	var c: Vector2i = job.coord
	var chunk_node := Node3D.new()
	chunk_node.name = "Chunk_%d_%d_L%d" % [c.x, c.y, job.lod]
	chunk_node.position = floating_origin.chunk_to_local_origin(c.x, c.y)

	var arr_mesh := ArrayMesh.new()
	var custom_flags: int = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data["mesh_arrays"], [], {}, custom_flags)

	var mi := MeshInstance3D.new()
	mi.name = "TerrainSurface"
	mi.mesh = arr_mesh
	mi.material_override = _terrain_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	chunk_node.add_child(mi)

	var col_faces: PackedVector3Array = data["col_faces"]
	if job.build_collision and col_faces.size() >= 3:
		var sb := StaticBody3D.new()
		sb.name = "TerrainCollider"
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(col_faces)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		sb.add_child(cs)
		chunk_node.add_child(sb)

	var water_arrays: Array = data["water_arrays"]
	if not water_arrays.is_empty():
		var w_mesh := ArrayMesh.new()
		w_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, water_arrays)
		var w_mi := MeshInstance3D.new()
		w_mi.name = "RiverSurface"
		w_mi.mesh = w_mesh
		w_mi.material_override = _water_material
		w_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk_node.add_child(w_mi)

	# Commit MultiMesh foliage, corridors & flora colliders
	var scatter: Dictionary = data.get("scatter_data", {})
	var foliage_total: int = int(scatter.get("total_instances", 0))
	for batch in scatter.get("multimeshes", []):
		var mesh_res: Mesh = asset_bank.get_mesh(String(batch["bucket"]), int(batch["variant_idx"]))
		if mesh_res == null:
			continue
		var xforms: Array = batch["transforms"]
		if xforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = false
		mm.mesh = mesh_res
		mm.instance_count = xforms.size()
		for i in range(xforms.size()):
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MM_%s_%d" % [String(batch["bucket"]), int(batch["variant_idx"])]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(batch["cast_shadows"]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var vis_end: float = float(batch.get("vis_end", 0.0))
		if vis_end > 0.0:
			mmi.visibility_range_end = vis_end
			mmi.visibility_range_end_margin = 12.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		chunk_node.add_child(mmi)

	if job.build_collision:
		var trunks: PackedVector4Array = scatter.get("trunk_colliders", PackedVector4Array())
		var boulders: PackedVector4Array = scatter.get("boulder_colliders", PackedVector4Array())
		if trunks.size() > 0 or boulders.size() > 0:
			var flora_sb := StaticBody3D.new()
			flora_sb.name = "FloraColliders"
			for t in trunks:
				var cs := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				cyl.radius = 0.25 * t.w
				cyl.height = 3.6 * t.w
				cs.shape = cyl
				cs.position = Vector3(t.x, t.y + cyl.height * 0.5 - 0.16, t.z)
				flora_sb.add_child(cs)
			for b in boulders:
				var bs := CollisionShape3D.new()
				var sph := SphereShape3D.new()
				sph.radius = 0.78 * b.w
				bs.shape = sph
				bs.position = Vector3(b.x, b.y + 0.35 * b.w, b.z)
				flora_sb.add_child(bs)
			chunk_node.add_child(flora_sb)

	add_child(chunk_node)

	# Atomic swap: remove previous LOD only after replacement is live
	if _active_chunks.has(c):
		var old_node: Node3D = _active_chunks[c]["node"]
		if is_instance_valid(old_node):
			remove_child(old_node)
			old_node.queue_free()

	if job.lod <= 1:
		_ensure_chunk_landmarks(c)

	var meta: Dictionary = {
		"coord": c,
		"lod": job.lod,
		"has_collision": job.build_collision,
		"dominant_biome": data["dominant_biome"],
		"min_y": data["min_y"],
		"max_y": data["max_y"],
		"has_river": data["has_river"],
		"has_road": data["has_road"],
		"foliage_instances": foliage_total,
		"gen_ms": data["gen_ms"],
	}
	_active_chunks[c] = {
		"node": chunk_node,
		"lod": job.lod,
		"has_collision": job.build_collision,
		"meta": meta,
	}
	_total_commits += 1
	chunk_loaded.emit(c, job.lod, meta)


func _index_landmarks_by_chunk() -> void:
	_sites_by_chunk.clear()
	if sampler == null or sampler.blueprint == null or floating_origin == null:
		return
	for site in sampler.blueprint.structures:
		var owner_c: Vector2i = floating_origin.world_to_chunk(site["pos"])
		if not _sites_by_chunk.has(owner_c):
			_sites_by_chunk[owner_c] = [site]
		else:
			_sites_by_chunk[owner_c].append(site)


func _ensure_chunk_landmarks(c: Vector2i) -> void:
	if not _sites_by_chunk.has(c):
		return
	for site in _sites_by_chunk[c]:
		var sid: int = int(site["id"])
		if _active_landmarks.has(sid):
			continue
		var built: Dictionary = CascadeLandmarks.build_landmark(site, sampler, asset_bank)
		var lnode: Node3D = built["node"]
		var anchor_w: Vector3 = built["anchor_world"]
		lnode.position = floating_origin.world_to_local(anchor_w)
		_landmarks_root.add_child(lnode)
		built["coord"] = c
		_active_landmarks[sid] = built


func _unload_chunk_landmarks(c: Vector2i) -> void:
	if not _sites_by_chunk.has(c):
		return
	for site in _sites_by_chunk[c]:
		var sid: int = int(site["id"])
		if _active_landmarks.has(sid):
			var lm: Dictionary = _active_landmarks[sid]
			var ln: Node3D = lm["node"]
			if is_instance_valid(ln):
				ln.queue_free()
			_active_landmarks.erase(sid)


func _on_origin_shifted(_shift_delta: Vector3, _new_origin_chunk: Vector2i) -> void:
	for c_key in _active_chunks.keys():
		var c: Vector2i = c_key
		var node: Node3D = _active_chunks[c]["node"]
		if is_instance_valid(node):
			node.position = floating_origin.chunk_to_local_origin(c.x, c.y)
	for lm in _active_landmarks.values():
		var ln: Node3D = lm["node"]
		if is_instance_valid(ln):
			ln.position = floating_origin.world_to_local(lm["anchor_world"])


func _ensure_shared_materials() -> void:
	if _terrain_material == null:
		var smat := ShaderMaterial.new()
		smat.shader = load(TERRAIN_SHADER_PATH)
		_bind_pbr_set(smat, "floor", "forest_ground_04")
		_bind_pbr_set(smat, "leaf", "forest_leaves_04")
		_bind_pbr_set(smat, "mud", "brown_mud_02")
		_bind_pbr_set(smat, "rock", "mossy_rock")
		_bind_pbr_set(smat, "asphalt", "asphalt_02")
		_terrain_material = smat
	if _water_material == null:
		_water_material = ForestMaterials.build_cascade_river_material()


func _bind_pbr_set(smat: ShaderMaterial, prefix: String, folder: String) -> void:
	var base: String = TEX_BASE + folder + "/" + folder
	smat.set_shader_parameter(prefix + "_albedo", load(base + "_Diffuse.png"))
	smat.set_shader_parameter(prefix + "_normal", load(base + "_nor_gl.png"))
	smat.set_shader_parameter(prefix + "_arm", load(base + "_arm.png"))
