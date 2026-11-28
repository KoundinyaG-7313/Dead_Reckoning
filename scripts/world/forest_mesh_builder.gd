class_name ForestMeshBuilder
extends RefCounted

const TEX_BASE: String = "res://assets/textures/"
const TERRAIN_SHADER_PATH: String = "res://shaders/forest_terrain.gdshader"


static func build_terrain(terrain: ForestTerrainData, parent: Node3D) -> void:
	const GRID: int = 216
	const SIZE: float = ForestTerrainData.WORLD_SIZE
	const HALF: float = ForestTerrainData.HALF_WORLD
	var step: float = SIZE / float(GRID)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var stride: int = GRID + 1
	verts.resize(stride * stride)
	normals.resize(stride * stride)
	uvs.resize(stride * stride)
	colors.resize(stride * stride)

	for gz in range(stride):
		var z: float = -HALF + float(gz) * step
		var v_coord: float = float(gz) / float(GRID)
		for gx in range(stride):
			var x: float = -HALF + float(gx) * step
			var u_coord: float = float(gx) / float(GRID)
			var idx: int = gz * stride + gx
			var h: float = terrain.get_height(x, z)
			verts[idx] = Vector3(x, h, z)
			normals[idx] = terrain.get_normal(x, z)
			uvs[idx] = Vector2(u_coord, v_coord)
			colors[idx] = terrain.get_terrain_weights(x, z)

	indices.resize(GRID * GRID * 6)
	var k: int = 0
	for gz in range(GRID):
		for gx in range(GRID):
			var i0: int = gz * stride + gx
			var i1: int = i0 + 1
			var i2: int = i0 + stride
			var i3: int = i2 + 1
			indices[k] = i0
			indices[k + 1] = i1
			indices[k + 2] = i2
			indices[k + 3] = i1
			indices[k + 4] = i3
			indices[k + 5] = i2
			k += 6

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var smat := ShaderMaterial.new()
	smat.shader = load(TERRAIN_SHADER_PATH)
	_bind_layer(smat, "floor", "forest_ground_04")
	_bind_layer(smat, "mud", "brown_mud_02")
	_bind_layer(smat, "leaf", "forest_leaves_04")
	smat.set_shader_parameter("uv_scale", 38.0)
	smat.set_shader_parameter("detail_uv_scale", 12.0)

	var mi := MeshInstance3D.new()
	mi.name = "ForestTerrainMesh"
	mi.mesh = arr_mesh
	mi.material_override = smat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	mi.create_trimesh_collision()

	_build_creek_water_ribbon(terrain, parent)


static func _bind_layer(smat: ShaderMaterial, prefix: String, folder: String) -> void:
	var base: String = TEX_BASE + folder + "/" + folder
	smat.set_shader_parameter(prefix + "_albedo", load(base + "_Diffuse.png"))
	smat.set_shader_parameter(prefix + "_normal", load(base + "_nor_gl.png"))
	smat.set_shader_parameter(prefix + "_arm", load(base + "_arm.png"))


static func _build_creek_water_ribbon(terrain: ForestTerrainData, parent: Node3D) -> void:
	const X_STEPS: int = 120
	const HALF_WIDTH: float = 3.2
	const HALF_LEN: float = ForestTerrainData.HALF_WORLD - 4.0
	var water_y: float = terrain.get_creek_water_level()

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for i in range(X_STEPS + 1):
		var t: float = float(i) / float(X_STEPS)
		var x: float = lerpf(-HALF_LEN, HALF_LEN, t)
		var cz: float = terrain.get_creek_center_z(x)
		var dz_dx: float = (terrain.get_creek_center_z(x + 0.5) - cz) / 0.5
		var perp: Vector3 = Vector3(-dz_dx, 0.0, 1.0).normalized()

		var bed_y: float = terrain.get_height(x, cz)
		var local_y: float = maxf(water_y, bed_y + 0.42)
		# Dampen extremes so it settles inside the cut channel
		local_y = lerpf(water_y, bed_y + 0.34, 0.55)

		var p_l: Vector3 = Vector3(x, local_y, cz) - perp * HALF_WIDTH
		var p_r: Vector3 = Vector3(x, local_y, cz) + perp * HALF_WIDTH
		verts.append(p_l)
		verts.append(p_r)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(t * 28.0, 0.0))
		uvs.append(Vector2(t * 28.0, 1.0))

	for i in range(X_STEPS):
		var b: int = i * 2
		indices.append(b)
		indices.append(b + 1)
		indices.append(b + 2)
		indices.append(b + 1)
		indices.append(b + 3)
		indices.append(b + 2)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var water_mesh := ArrayMesh.new()
	water_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var water_mi := MeshInstance3D.new()
	water_mi.name = "WoodlandCreekWater"
	water_mi.mesh = water_mesh
	water_mi.material_override = ForestMaterials.build_creek_water_material()
	water_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(water_mi)
