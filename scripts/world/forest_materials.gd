class_name ForestMaterials
extends RefCounted

const TEX_BASE: String = "res://assets/textures/"
const TREE_TEX_BASE: String = "res://assets/models/trees/Textures/"

static var _cache: Dictionary = {}


static func load_pbr_material(
	folder_name: String,
	uv_scale: Vector2 = Vector2.ONE,
	tint: Color = Color.WHITE,
	roughness_scale: float = 1.0,
	metallic_val: float = 0.0
) -> StandardMaterial3D:
	var key: String = "%s|%s|%s|%.2f|%.2f" % [folder_name, str(uv_scale), str(tint), roughness_scale, metallic_val]
	if _cache.has(key):
		return _cache[key]

	var dir_path: String = TEX_BASE + folder_name + "/"
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(dir_path + folder_name + "_Diffuse.png")
	mat.normal_enabled = true
	mat.normal_texture = load(dir_path + folder_name + "_nor_gl.png")
	mat.normal_scale = 1.15

	var rough_tex: Texture2D = load(dir_path + folder_name + "_Rough.png")
	if rough_tex != null:
		mat.roughness_texture = rough_tex
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	mat.roughness = roughness_scale

	var ao_tex: Texture2D = load(dir_path + folder_name + "_AO.png")
	if ao_tex != null:
		mat.ao_enabled = true
		mat.ao_texture = ao_tex
		mat.ao_light_affect = 0.65

	var arm_path: String = dir_path + folder_name + "_arm.png"
	if metallic_val > 0.0 and ResourceLoader.exists(arm_path):
		var arm_tex: Texture2D = load(arm_path)
		if arm_tex != null:
			mat.metallic_texture = arm_tex
			mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE

	mat.metallic = metallic_val
	mat.metallic_specular = 0.52
	mat.albedo_color = tint
	mat.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = mat
	return mat


static func build_tree_bark_material(kind: String) -> StandardMaterial3D:
	var key: String = "tree_bark_" + kind
	if _cache.has(key):
		return _cache[key]

	var prefix: String = "PineTree"
	var tint: Color = Color(0.76, 0.75, 0.74, 1.0)
	if kind == "normal" or kind == "dead":
		prefix = "NormalTree"
		tint = Color(0.74, 0.73, 0.72, 1.0) if kind == "normal" else Color(0.68, 0.66, 0.66, 1.0)
	elif kind == "birch":
		prefix = "BirchTree"
		tint = Color(0.84, 0.86, 0.88, 1.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(TREE_TEX_BASE + prefix + "_Bark.png")
	mat.normal_enabled = true
	mat.normal_texture = load(TREE_TEX_BASE + prefix + "_Bark_Normal.png")
	mat.normal_scale = 1.25
	mat.roughness = 0.90
	mat.albedo_color = tint
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = mat
	return mat


static func build_tree_leaves_material(kind: String) -> StandardMaterial3D:
	var key: String = "tree_leaves_" + kind
	if _cache.has(key):
		return _cache[key]

	var tex_name: String = "PineTree_Leaves.png"
	var tint: Color = Color(0.40, 0.50, 0.44, 1.0)
	if kind == "normal":
		tex_name = "NormalTree_Leaves_Dark.png"
		tint = Color(0.44, 0.50, 0.42, 1.0)
	elif kind == "birch":
		tex_name = "BirchTree_Leaves.png"
		tint = Color(0.48, 0.54, 0.44, 1.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(TREE_TEX_BASE + tex_name)
	mat.albedo_color = tint
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.36
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.88
	mat.backlight_enabled = true
	mat.backlight = Color(0.08, 0.14, 0.16, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = mat
	return mat


static func darken_material_for_night(src: Material, factor: float = 0.58, force_alpha_scissor: bool = false) -> Material:
	if src == null or not (src is BaseMaterial3D):
		return src
	var mat: BaseMaterial3D = src.duplicate() as BaseMaterial3D
	mat.albedo_color = Color(
		mat.albedo_color.r * factor,
		mat.albedo_color.g * factor,
		mat.albedo_color.b * factor,
		mat.albedo_color.a
	)
	if force_alpha_scissor and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.42
	mat.roughness = clampf(mat.roughness * 0.92, 0.45, 0.96)
	return mat


static func build_dark_metal_material(albedo: Color, rough: float = 0.55, metal: float = 0.85) -> StandardMaterial3D:
	var key: String = "pbr_metal|%s|%.2f|%.2f" % [str(albedo), rough, metal]
	if _cache.has(key):
		return _cache[key]

	# Map legacy flat metal/rubber/canvas specs onto downloaded 2K Poly Haven PBR materials
	var folder: String = "blue_metal_plate"
	var uv_sc := Vector2(2.0, 2.0)
	var lum: float = albedo.get_luminance()
	if metal < 0.15 and rough >= 0.82:
		folder = "rough_linen"
		uv_sc = Vector2(2.5, 2.5)
	elif rough < 0.25 and metal < 0.35:
		folder = "blue_metal_plate"
		uv_sc = Vector2(1.0, 1.0)
	elif lum < 0.08:
		folder = "asphalt_02" if metal < 0.55 else "rust_coarse_01"
		uv_sc = Vector2(2.5, 2.5)
	elif rough >= 0.68 or (albedo.r > albedo.b * 1.25 and albedo.r > albedo.g * 1.15):
		folder = "rust_coarse_01"
		uv_sc = Vector2(2.0, 2.0)

	# Preserve target hue while keeping 2K diffuse texture micro-detail visible under nocturnal lighting
	var tint: Color = albedo.lerp(Color(0.76, 0.78, 0.80, 1.0), 0.42)
	if lum < 0.08:
		tint = Color(clampf(albedo.r * 3.2 + 0.10, 0.08, 0.26), clampf(albedo.g * 3.2 + 0.10, 0.08, 0.26), clampf(albedo.b * 3.2 + 0.10, 0.08, 0.28), 1.0)
	elif folder == "rough_linen":
		tint = albedo.lerp(Color.WHITE, 0.32)

	var mat := load_pbr_material(folder, uv_sc, tint, clampf(rough, 0.06, 0.96), clampf(metal, 0.0, 0.95))
	# Ensure every variant gets a distinct cached instance when tweaking specular/clearcoat/triplanar
	mat = mat.duplicate()
	mat.uv1_triplanar = true
	mat.uv1_triplanar_sharpness = 3.0
	mat.uv1_scale = Vector3(uv_sc.x * 0.45, uv_sc.y * 0.45, uv_sc.x * 0.45)
	if rough < 0.25 and metal < 0.35:
		mat.metallic_specular = 0.95
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.85
		mat.clearcoat_roughness = 0.06
	elif metal >= 0.4 and rough <= 0.52:
		mat.metallic_specular = 0.72
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.35
		mat.clearcoat_roughness = 0.25
	_cache[key] = mat
	return mat


static func build_canvas_material(tint: Color = Color(0.28, 0.31, 0.22), uv_scale: Vector2 = Vector2(2.2, 2.2)) -> StandardMaterial3D:
	return load_pbr_material("rough_linen", uv_scale, tint.lerp(Color.WHITE, 0.28), 0.94, 0.0)


static func build_corrugated_iron_material(tint: Color = Color(0.66, 0.66, 0.68), uv_scale: Vector2 = Vector2(2.0, 2.0), rusty: bool = true) -> StandardMaterial3D:
	var folder: String = "rusty_corrugated_iron" if rusty else "corrugated_iron_02"
	return load_pbr_material(folder, uv_scale, tint, 0.68 if rusty else 0.52, 0.75)


static func build_emissive_material(color: Color, energy: float = 4.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.2
	return mat


static func build_creek_water_material() -> ShaderMaterial:
	var key: String = "shader_creek_water"
	if _cache.has(key):
		return _cache[key]
	var smat := ShaderMaterial.new()
	smat.shader = load("res://shaders/cascade_water.gdshader")
	smat.set_shader_parameter("wave_normal", load(TEX_BASE + "brown_mud_02/brown_mud_02_nor_gl.png"))
	smat.set_shader_parameter("rough_tex", load(TEX_BASE + "brown_mud_02/brown_mud_02_Rough.png"))
	smat.set_shader_parameter("shallow_color", Color(0.016, 0.030, 0.038, 1.0))
	smat.set_shader_parameter("deep_color", Color(0.006, 0.012, 0.018, 1.0))
	_cache[key] = smat
	return smat


static func build_cascade_river_material() -> ShaderMaterial:
	var key: String = "shader_cascade_river"
	if _cache.has(key):
		return _cache[key]
	var smat := ShaderMaterial.new()
	smat.shader = load("res://shaders/cascade_water.gdshader")
	smat.set_shader_parameter("wave_normal", load(TEX_BASE + "brown_mud_02/brown_mud_02_nor_gl.png"))
	smat.set_shader_parameter("rough_tex", load(TEX_BASE + "brown_mud_02/brown_mud_02_Rough.png"))
	smat.set_shader_parameter("shallow_color", Color(0.022, 0.048, 0.062, 1.0))
	smat.set_shader_parameter("deep_color", Color(0.008, 0.018, 0.026, 1.0))
	_cache[key] = smat
	return smat


## Re-centers XZ pivot and grounds bottom Y (-sink_y) after applying optional showcase node transform
static func normalize_mesh_pivot(
	src: Mesh,
	recenter_xz: bool = true,
	ground_y: bool = true,
	sink_y: float = 0.0,
	bake_xform: Transform3D = Transform3D.IDENTITY
) -> ArrayMesh:
	if src == null or src.get_surface_count() == 0:
		return null
	var min_p := Vector3(INF, INF, INF)
	var max_p := Vector3(-INF, -INF, -INF)
	var has_verts := false
	for si in range(src.get_surface_count()):
		var arrays: Array = src.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts:
			var tv: Vector3 = bake_xform * v
			min_p.x = minf(min_p.x, tv.x); min_p.y = minf(min_p.y, tv.y); min_p.z = minf(min_p.z, tv.z)
			max_p.x = maxf(max_p.x, tv.x); max_p.y = maxf(max_p.y, tv.y); max_p.z = maxf(max_p.z, tv.z)
			has_verts = true
	if not has_verts:
		return null
	var shift := Vector3.ZERO
	if recenter_xz:
		shift.x = -0.5 * (min_p.x + max_p.x)
		shift.z = -0.5 * (min_p.z + max_p.z)
	if ground_y:
		shift.y = -min_p.y - sink_y

	var n_basis: Basis = bake_xform.basis.inverse().transposed()
	var out := ArrayMesh.new()
	for si in range(src.get_surface_count()):
		var arrays: Array = src.surface_get_arrays(si).duplicate(true)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in range(verts.size()):
			verts[i] = (bake_xform * verts[i]) + shift
		arrays[Mesh.ARRAY_VERTEX] = verts
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var nrms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in range(nrms.size()):
				nrms[i] = (n_basis * nrms[i]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = nrms
		if arrays[Mesh.ARRAY_TANGENT] != null:
			var tans: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			var count: int = tans.size() / 4
			for i in range(count):
				var base_i: int = i * 4
				var tv := (bake_xform.basis * Vector3(tans[base_i], tans[base_i + 1], tans[base_i + 2])).normalized()
				tans[base_i] = tv.x; tans[base_i + 1] = tv.y; tans[base_i + 2] = tv.z
			arrays[Mesh.ARRAY_TANGENT] = tans
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var s_mat: Material = src.surface_get_material(si)
		if s_mat != null:
			out.surface_set_material(si, s_mat)
		out.surface_set_name(si, src.surface_get_name(si))
	return out


## Extracts named kit-of-parts nodes from a GLTF scene into a single material-grouped ArrayMesh centered near origin_offset
static func extract_gltf_kit_mesh(
	gltf_path: String,
	prefixes_or_names: Array,
	origin_offset: Vector3 = Vector3.ZERO,
	recenter_xz: bool = false,
	ground_y: bool = false,
	sink_y: float = 0.0
) -> ArrayMesh:
	var ps: PackedScene = load(gltf_path)
	if ps == null:
		return null
	var root: Node = ps.instantiate()
	var mat_groups: Dictionary = {} # Material key -> Array of {"mesh": Mesh, "xform": Transform3D, "mat": Material}
	var stack: Array = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for ch in cur.get_children():
			stack.append(ch)
		if cur is MeshInstance3D:
			var mi: MeshInstance3D = cur as MeshInstance3D
			var matched: bool = prefixes_or_names.is_empty()
			for pat in prefixes_or_names:
				var pstr := String(pat)
				if pstr.ends_with("*"):
					if mi.name.begins_with(pstr.substr(0, pstr.length() - 1)):
						matched = true; break
				elif mi.name == pstr:
					matched = true; break
			if not matched or mi.mesh == null:
				continue
			# Compute transform relative to scene root minus kit origin_offset
			var rel_xform: Transform3D = Transform3D.IDENTITY
			var n: Node = mi
			while n != null and n != root:
				if n is Node3D:
					rel_xform = (n as Node3D).transform * rel_xform
				n = n.get_parent()
			rel_xform.origin -= origin_offset
			for si in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.get_active_material(si)
				if mat == null:
					mat = mi.mesh.surface_get_material(si)
				if mat is BaseMaterial3D and str((mat as BaseMaterial3D).resource_name).contains("wire"):
					var bm := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
					bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					bm.alpha_scissor_threshold = 0.35
					bm.cull_mode = BaseMaterial3D.CULL_DISABLED
					mat = bm
				var mkey: String = str(mat.get_instance_id()) if mat != null else "null"
				if not mat_groups.has(mkey):
					mat_groups[mkey] = {"mat": mat, "parts": []}
				mat_groups[mkey]["parts"].append({"mesh": mi.mesh, "surf": si, "xform": rel_xform})
	root.free()
	if mat_groups.is_empty():
		return null

	var out := ArrayMesh.new()
	var surf_idx: int = 0
	for mkey in mat_groups:
		var grp: Dictionary = mat_groups[mkey]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in grp["parts"]:
			st.append_from(part["mesh"], part["surf"], part["xform"])
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
		if grp["mat"] != null:
			out.surface_set_material(surf_idx, grp["mat"])
		surf_idx += 1
	if recenter_xz or ground_y or absf(sink_y) > 0.0001:
		return normalize_mesh_pivot(out, recenter_xz, ground_y, sink_y, Transform3D.IDENTITY)
	return out
