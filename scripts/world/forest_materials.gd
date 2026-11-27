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

	mat.metallic = metallic_val
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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = rough
	mat.metallic = metal
	return mat


static func build_emissive_material(color: Color, energy: float = 4.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.2
	return mat


static func build_creek_water_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.014, 0.025, 0.032, 0.88)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	mat.metallic = 0.15
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	# Use normal map from forest water ripples or brown_mud nor_gl subtly
	mat.normal_enabled = true
	mat.normal_texture = load(TEX_BASE + "brown_mud_02/brown_mud_02_nor_gl.png")
	mat.normal_scale = 0.16
	mat.uv1_scale = Vector3(14.0, 4.0, 1.0)
	return mat
