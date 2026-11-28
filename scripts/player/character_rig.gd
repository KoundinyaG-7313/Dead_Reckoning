class_name CharacterRig
extends Node3D

const CHAR_BASE: String = "res://assets/characters/"
const LOOPING_CLIPS: Array[String] = [
	"idle", "idle_breathe", "idle_fidget", "idle_look",
	"walk", "walk_back", "run", "strafe_left", "strafe_right", "fall"
]

var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var chest_lamp_mount: BoneAttachment3D

var _current_clip: String = ""
var _idle_variation_timer: float = 0.0
var _use_look_idle: bool = false


func _ready() -> void:
	_assemble_character()


func _assemble_character() -> void:
	var body_ps: PackedScene = load(CHAR_BASE + "base_body_anim.glb")
	if body_ps == null:
		push_error("[CharacterRig] Missing base_body_anim.glb")
		return

	var body_inst: Node3D = body_ps.instantiate() as Node3D
	body_inst.name = "CharacterBase"
	# Face -Z (standard Godot forward) instead of +Z glTF rest facing
	body_inst.rotation.y = PI
	add_child(body_inst)

	skeleton = _find_node_by_class(body_inst, "Skeleton3D") as Skeleton3D
	anim_player = _find_node_by_class(body_inst, "AnimationPlayer") as AnimationPlayer
	if skeleton == null or anim_player == null:
		push_error("[CharacterRig] Missing Skeleton3D or AnimationPlayer in base_body_anim.glb")
		return

	# Attach modular wardrobe + hair onto the single animated Skeleton3D
	var outfit_parts: Array[String] = [
		"clothing_shirt.glb",
		"clothing_jeans.glb",
		"clothing_boots.glb",
		"clothing_jacket.glb",
		"hair_short04.glb"
	]
	for part_file in outfit_parts:
		var ps: PackedScene = load(CHAR_BASE + part_file)
		if ps == null:
			push_warning("[CharacterRig] Missing outfit asset: " + part_file)
			continue
		var inst: Node = ps.instantiate()
		for mi in _collect_meshes(inst):
			var dup: MeshInstance3D = mi.duplicate() as MeshInstance3D
			dup.skin = mi.skin
			dup.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			skeleton.add_child(dup)
			dup.skeleton = NodePath("..")
		inst.free()

	_apply_nocturnal_material_tuning(skeleton)
	_configure_animation_loops()
	_attach_chest_flashlight_socket()

	play_locomotion(0.0, true, false, false, 0.0)


func update_locomotion(
	delta: float,
	horiz_speed: float,
	is_grounded: bool,
	is_sprinting: bool,
	vel_y: float
) -> void:
	if anim_player == null:
		return

	if horiz_speed < 0.2 and is_grounded:
		_idle_variation_timer += delta
		if _idle_variation_timer > 6.5:
			_idle_variation_timer = 0.0
			_use_look_idle = not _use_look_idle
	else:
		_idle_variation_timer = 0.0
		_use_look_idle = false

	play_locomotion(horiz_speed, is_grounded, is_sprinting, _use_look_idle, vel_y)


func play_locomotion(
	horiz_speed: float,
	is_grounded: bool,
	is_sprinting: bool,
	look_around: bool,
	vel_y: float
) -> void:
	if anim_player == null:
		return

	var target: String = "idle"
	var speed_scale: float = 1.0
	var blend: float = 0.22

	if not is_grounded:
		if vel_y > 1.2 and _current_clip != "fall":
			target = "jump"
			blend = 0.10
		else:
			target = "fall"
			blend = 0.18
	elif horiz_speed > 3.25 or (is_sprinting and horiz_speed > 1.8):
		target = "run"
		# Reference run speed in clip timing is ~3.6 m/s
		speed_scale = clampf(horiz_speed / 3.65, 0.85, 1.45)
		blend = 0.18
	elif horiz_speed > 0.22:
		target = "walk"
		# Reference walk speed in clip timing is ~1.55 m/s
		speed_scale = clampf(horiz_speed / 1.55, 0.72, 1.45)
		blend = 0.20
	else:
		target = "idle_look" if look_around and anim_player.has_animation("idle_look") else "idle"
		blend = 0.35

	if not anim_player.has_animation(target):
		target = "idle"

	if _current_clip != target:
		anim_player.play(target, blend, speed_scale)
		_current_clip = target
	else:
		anim_player.speed_scale = speed_scale


func play_land_impact() -> void:
	if anim_player != null and anim_player.has_animation("land"):
		anim_player.play("land", 0.08, 1.35)
		_current_clip = "land"


func _configure_animation_loops() -> void:
	for anim_name in LOOPING_CLIPS:
		if anim_player.has_animation(anim_name):
			var anim: Animation = anim_player.get_animation(anim_name)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR


func _attach_chest_flashlight_socket() -> void:
	if skeleton == null:
		return
	var bone_idx: int = skeleton.find_bone("spine_03")
	if bone_idx < 0:
		return

	chest_lamp_mount = BoneAttachment3D.new()
	chest_lamp_mount.name = "ChestLampSocket"
	chest_lamp_mount.bone_name = "spine_03"
	skeleton.add_child(chest_lamp_mount)

	# Small physical weathered metal shoulder torch clipped onto left jacket lapel
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.022
	cyl.bottom_radius = 0.026
	cyl.height = 0.13
	body.mesh = cyl
	body.rotation.x = PI * 0.5
	body.position = Vector3(-0.11, 0.09, 0.14)
	body.material_override = ForestMaterials.build_dark_metal_material(Color(0.14, 0.15, 0.16), 0.55, 0.85)
	chest_lamp_mount.add_child(body)

	var lens := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.021
	disc.bottom_radius = 0.021
	disc.height = 0.012
	lens.mesh = disc
	lens.rotation.x = PI * 0.5
	lens.position = Vector3(-0.11, 0.09, 0.21)
	lens.material_override = ForestMaterials.build_emissive_material(Color(1.0, 0.94, 0.82), 5.0)
	chest_lamp_mount.add_child(lens)


func _apply_nocturnal_material_tuning(skel: Skeleton3D) -> void:
	# Rebalance garment tints for crisp weathered detail under night lanterns & flashlight
	var overrides: Dictionary = {
		"Cloth_jacket": {"tint": Color(0.46, 0.42, 0.32, 1.0), "rough": 0.86},
		"Cloth_shirt": {"tint": Color(0.38, 0.42, 0.46, 1.0), "rough": 0.90},
		"Cloth_jeans": {"tint": Color(0.28, 0.34, 0.45, 1.0), "rough": 0.88},
		"Cloth_boots": {"tint": Color(0.25, 0.19, 0.15, 1.0), "rough": 0.66},
		"Hair_short04": {"tint": Color(0.26, 0.19, 0.14, 1.0), "rough": 0.80}
	}
	for mi in _collect_meshes(skel):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var src: Material = mi.get_active_material(s)
			if not (src is StandardMaterial3D):
				continue
			var mat: StandardMaterial3D = src.duplicate() as StandardMaterial3D
			var mname: String = str(mi.name)
			if overrides.has(mname):
				var cfg: Dictionary = overrides[mname]
				mat.albedo_color = cfg["tint"]
				mat.roughness = float(cfg["rough"])
			elif str(mat.resource_name).begins_with("Skin"):
				mat.albedo_color = Color(0.92, 0.75, 0.65, 1.0)
				mat.roughness = 0.62
			mi.set_surface_override_material(s, mat)


func _find_node_by_class(n: Node, cls_name: String) -> Node:
	if n.get_class() == cls_name:
		return n
	for c in n.get_children():
		var f: Node = _find_node_by_class(c, cls_name)
		if f != null:
			return f
	return null


func _collect_meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_collect_meshes(c))
	return out
