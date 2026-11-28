class_name ThirdPersonPlayer
extends CharacterBody3D

@export var walk_speed: float = 2.05
@export var sprint_speed: float = 4.65
@export var jump_velocity: float = 4.5
@export var turn_speed: float = 11.5
@export var mouse_sensitivity: float = 0.0024
@export var capture_mouse_on_ready: bool = true

const CAMERA_MODES: Array = [
	{"name": "OverShoulder", "offset": Vector3(0.48, 0.10, 0.0), "length": 2.85, "fov": 62.0},
	{"name": "MediumChase", "offset": Vector3(0.26, 0.22, 0.0), "length": 3.55, "fov": 65.0},
	{"name": "WideForest", "offset": Vector3(0.0, 0.42, 0.0), "length": 4.75, "fov": 68.0}
]

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _cam_mode_idx: int = 0
var _yaw: float = 0.0
var _pitch: float = -0.10
var _was_on_floor: bool = true
var _bob_phase: float = 0.0
var _mouse_warp_skip: int = 0

var rig: CharacterRig
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var flashlight: SpotLight3D
var flashlight_enabled: bool = true


func _ready() -> void:
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.35

	rig = get_node_or_null("CharacterRig") as CharacterRig
	camera_pivot = get_node_or_null("CameraPivot") as Node3D
	spring_arm = get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D
	camera = get_node_or_null("CameraPivot/SpringArm3D/ThirdPersonCamera") as Camera3D
	flashlight = get_node_or_null("FlashlightMount/ExplorerFlashlight") as SpotLight3D

	_yaw = rotation.y
	if camera_pivot != null:
		camera_pivot.top_level = true
		camera_pivot.global_position = global_position + Vector3(0.0, 1.32, 0.0)
		camera_pivot.rotation = Vector3(_pitch, _yaw, 0.0)

	_apply_camera_mode()
	if flashlight != null:
		flashlight.visible = flashlight_enabled

	if capture_mouse_on_ready and not DisplayServer.get_name().contains("headless") and not OS.has_environment("NO_MOUSE_CAPTURE"):
		_mouse_warp_skip = 4
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_initial_heading(yaw_rad: float) -> void:
	rotation.y = yaw_rad
	_yaw = yaw_rad
	if camera_pivot != null:
		camera_pivot.global_position = global_position + Vector3(0.0, 1.32, 0.0)
		camera_pivot.rotation = Vector3(_pitch, _yaw, 0.0)


func apply_origin_shift(shift_vec: Vector3) -> void:
	global_position -= shift_vec
	if camera_pivot != null:
		camera_pivot.global_position -= shift_vec
	if flashlight != null:
		var mount: Node3D = flashlight.get_parent() as Node3D
		if mount != null and mount.top_level:
			mount.global_position -= shift_vec


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _mouse_warp_skip > 0:
			return
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		# Reject compositor pointer-warp spikes on focus/capture transitions
		if mm.relative.length() > 140.0:
			return
		_yaw -= mm.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - mm.relative.y * mouse_sensitivity, deg_to_rad(-58.0), deg_to_rad(52.0))

	if event is InputEventKey:
		var ek: InputEventKey = event as InputEventKey
		if ek.pressed and not ek.echo and ek.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				_mouse_warp_skip = 3
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if not DisplayServer.get_name().contains("headless") and not OS.has_environment("NO_MOUSE_CAPTURE"):
			_mouse_warp_skip = 3
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("toggle_flashlight"):
		flashlight_enabled = not flashlight_enabled
		if flashlight != null:
			flashlight.visible = flashlight_enabled

	if event.is_action_pressed("toggle_camera_mode"):
		_cam_mode_idx = (_cam_mode_idx + 1) % CAMERA_MODES.size()
		_apply_camera_mode()


func _physics_process(delta: float) -> void:
	if _mouse_warp_skip > 0:
		_mouse_warp_skip -= 1
	var on_floor_now: bool = is_on_floor()

	if not on_floor_now:
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		on_floor_now = false

	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := Basis(Vector3.UP, _yaw)
	var move_dir: Vector3 = (cam_basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()

	var is_sprinting: bool = Input.is_action_pressed("sprint") and move_dir.length_squared() > 0.01
	var target_speed: float = sprint_speed if is_sprinting else walk_speed
	var accel: float = 12.0 if on_floor_now else 4.5

	if move_dir.length_squared() > 0.001:
		velocity.x = move_toward(velocity.x, move_dir.x * target_speed, accel * delta * 3.0)
		velocity.z = move_toward(velocity.z, move_dir.z * target_speed, accel * delta * 3.0)
		var target_yaw: float = atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, turn_speed * delta))
	else:
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)

	move_and_slide()

	if not _was_on_floor and is_on_floor() and rig != null:
		rig.play_land_impact()
	_was_on_floor = is_on_floor()

	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	if rig != null:
		rig.update_locomotion(delta, horiz_speed, is_on_floor(), is_sprinting, velocity.y)

	_update_camera_and_flashlight(delta, horiz_speed, is_sprinting)


func _update_camera_and_flashlight(delta: float, horiz_speed: float, is_sprinting: bool) -> void:
	if camera_pivot != null:
		var pivot_target: Vector3 = global_position + Vector3(0.0, 1.32, 0.0)
		camera_pivot.global_position = camera_pivot.global_position.lerp(pivot_target, minf(1.0, 16.0 * delta))
		camera_pivot.rotation = Vector3(_pitch, _yaw, 0.0)

	if camera != null:
		var cfg: Dictionary = CAMERA_MODES[_cam_mode_idx]
		var target_fov: float = float(cfg["fov"]) + (4.5 if is_sprinting and horiz_speed > 2.5 else 0.0)
		camera.fov = lerpf(camera.fov, target_fov, minf(1.0, 6.0 * delta))

	if flashlight != null:
		# Offset emitter ahead of chest and clamp beam yaw inside forward torso cone so orbiting camera never blows out own shoulder
		var mount: Node3D = flashlight.get_parent() as Node3D
		if mount != null:
			if horiz_speed > 0.3:
				_bob_phase += delta * (11.5 if is_sprinting else 7.2)
			var sway_x: float = sin(_bob_phase * 0.5) * (0.014 if horiz_speed > 0.3 else 0.004)
			var sway_y: float = absf(cos(_bob_phase)) * (0.020 if horiz_speed > 0.3 else 0.005)
			var rel_yaw: float = clampf(wrapf(_yaw - rotation.y, -PI, PI), -deg_to_rad(52.0), deg_to_rad(52.0))
			var beam_yaw: float = rotation.y + rel_yaw
			var aim_rot := Basis.from_euler(Vector3(_pitch + sway_x * 0.7, beam_yaw, 0.0))
			var chest_pos: Vector3 = global_position + (Basis(Vector3.UP, rotation.y) * Vector3(-0.14 + sway_x, 1.40 + sway_y, -0.26))
			mount.global_position = chest_pos + (-aim_rot.z * 0.24)
			mount.global_transform.basis = mount.global_transform.basis.slerp(aim_rot, minf(1.0, 10.0 * delta))


func _apply_camera_mode() -> void:
	if spring_arm == null or camera == null:
		return
	var cfg: Dictionary = CAMERA_MODES[_cam_mode_idx]
	spring_arm.position = cfg["offset"]
	spring_arm.spring_length = float(cfg["length"])
	camera.fov = float(cfg["fov"])
