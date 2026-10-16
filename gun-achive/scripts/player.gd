extends CharacterBody3D

const SPEED_BASE := 7.0
const SPRINT_BASE := 10.5
const JUMP := 6.5
const MOUSE_SENS := 0.0025
const ACCEL_GROUND := 14.0
const ACCEL_AIR := 4.0
const FRICTION := 12.0
const NET_RATE := 0.05
const ARMOR_REGEN := 3.0
const ARMOR_REGEN_DELAY := 4.0
const STEP_INTERVAL := 0.45

const CLASS_BULLET_COLORS: Array[Color] = [
	Color(1.0, 0.2, 0.2),
	Color(0.3, 0.6, 1.0),
	Color(0.3, 1.0, 0.3),
	Color(1.0, 0.9, 0.2),
]

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var muzzle: Node3D = $Head/Camera3D/WeaponPivot/WeaponMount/Muzzle
@onready var weapon_pivot: Node3D = $Head/Camera3D/WeaponPivot
@onready var weapon_mount: Node3D = $Head/Camera3D/WeaponPivot/WeaponMount
@onready var name_label: Label3D = $NameLabel
@onready var mesh: MeshInstance3D = $Model/MeshInstance3D

var _pitch := 0.0
var _target_pitch := 0.0
var hp := 100
var hp_max := 100
var armor := 50.0
var armor_max := 50.0
var alive := true
var visible_state := true
var kills := 0
var nick := "Player"
var class_type: int = 0
var speed_mul := 1.0
var sprint_mul := 1.0
var _bob_time := 0.0
var _recoil_offset := 0.0
var _weapon_base_pos := Vector3.ZERO
var _current_weapon_model: Node3D = null
var _step_timer := 0.0
var _armor_regen_timer := 0.0
var _audio_shoot: AudioStreamPlayer3D
var _audio_extra: AudioStreamPlayer3D
var _wm: WeaponManager
var _mouse_left_held := false
var _aiming := false
var _menu_mode := false
var _ready_for_sync := false
var _net_timer := -3.0
var _net_target_pos := Vector3.ZERO
var _net_target_yaw := 0.0
var _net_target_pitch := 0.0
var _net_body_yaw := 0.0
var _net_target_head_rot := 0.0
var _net_has_data := false
var _target_in_sight := false
var _class_weapons: Array = []
var _current_weapon_index: int = 0


func _ready() -> void:
	var hb_r: Node = get_node_or_null("Hitbox")
	if hb_r:
		hb_r.monitoring = true
		hb_r.monitorable = true
	var is_local_pl: bool = is_multiplayer_authority()
	camera.current = is_local_pl
	set_process_input(is_local_pl)
	_setup_audio()
	_setup_weapon_manager()
	_weapon_base_pos = weapon_pivot.position
	if is_local_pl:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		name_label.visible = false
		weapon_pivot.visible = true
		apply_class(GameState.chosen_class)
		set_nick.rpc_id(1, GameState.nick)
	else:
		name_label.visible = true
		weapon_pivot.visible = true
		call_deferred("_apply_color")
	set_process(true)


func _setup_audio() -> void:
	_audio_shoot = AudioStreamPlayer3D.new()
	_audio_shoot.unit_size = 12.0
	_audio_shoot.max_distance = 120.0
	add_child(_audio_shoot)
	_audio_extra = AudioStreamPlayer3D.new()
	_audio_extra.unit_size = 6.0
	_audio_extra.max_distance = 60.0
	add_child(_audio_extra)


func _setup_weapon_manager() -> void:
	_wm = WeaponManager.new()
	_wm.name = "WeaponManager"
	add_child(_wm)
	_wm.weapon_changed.connect(_on_weapon_changed)
	_wm.heat_changed.connect(_on_heat_changed)
	_wm.jam_state_changed.connect(_on_jam_state_changed)
	_wm.set_weapon(WeaponData.Type.RIFLE)


func apply_class(class_id: int) -> void:
	class_type = class_id
	var cd: Dictionary = ClassData.get_class_info(class_id)
	hp_max = int(cd.hp)
	armor_max = float(cd.armor)
	hp = hp_max
	armor = armor_max
	speed_mul = float(cd.speed_mul)
	sprint_mul = float(cd.sprint_mul)
	_apply_color()
	_class_weapons = ClassData.get_weapons_of(class_id)
	_current_weapon_index = 0
	if _wm and _class_weapons.size() > 0:
		_wm.set_weapon(int(_class_weapons[0]))


func _apply_color() -> void:
	var slot: int = 0
	if has_meta("slot"):
		slot = int(get_meta("slot"))
	elif name.is_valid_int():
		slot = int(name) % 7
	else:
		slot = get_multiplayer_authority() % 7
	var c: Color = ClassData.get_slot_color(slot)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	if mesh:
		mesh.set_surface_override_material(0, mat)


func is_local() -> bool:
	return is_multiplayer_authority()


func _on_weapon_changed(_w_type: int, w_data: Dictionary) -> void:
	_rebuild_weapon_model(w_data)
	if is_local():
		var world: Node = get_tree().current_scene
		if world and world.has_method("hud_set_weapon"):
			world.hud_set_weapon(w_data)


func _on_heat_changed(heat: float, max_heat: float, jammed: bool) -> void:
	if is_local():
		var world: Node = get_tree().current_scene
		if world and world.has_method("update_heat"):
			world.update_heat(heat, max_heat, jammed)


func _on_jam_state_changed(jammed: bool) -> void:
	if jammed:
		_play_extra_sound("jam_start")


func _rebuild_weapon_model(w_data: Dictionary) -> void:
	if _current_weapon_model:
		_current_weapon_model.queue_free()
		_current_weapon_model = null
	var model_path: String = w_data.get("model", "")
	if model_path == "":
		return
	var w_name: String = w_data.get("name", "")
	var is_dual: bool = (w_name == "Двойные пистолеты")
	print("[MODEL] ", w_name)
	if is_dual:
		_current_weapon_model = _create_weapon_mesh(model_path)
		if _current_weapon_model:
			weapon_mount.add_child(_current_weapon_model)
			_current_weapon_model.position = Vector3(0.15, -0.02, 0.0)
			_current_weapon_model.rotation = Vector3(0, deg_to_rad(-4), 0)
		var left_model := _create_weapon_mesh(model_path)
		if left_model:
			weapon_mount.add_child(left_model)
			left_model.position = Vector3(-0.65, -0.02, 0.0)
			left_model.rotation = Vector3(0, deg_to_rad(4), 0)
	else:
		_current_weapon_model = _create_weapon_mesh(model_path)
		if _current_weapon_model:
			weapon_mount.add_child(_current_weapon_model)
			_current_weapon_model.position = Vector3.ZERO


func _create_weapon_mesh(model_path: String) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var loaded: Resource = load(model_path)
	if loaded == null:
		return null
	mesh_inst.mesh = loaded
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.18, 0.2)
	mat.metallic = 0.7
	mat.roughness = 0.35
	mesh_inst.material_override = mat
	return mesh_inst


func _play_shoot_sound(kind: String, heat_ratio: float) -> void:
	if _audio_shoot == null: return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.6
	_audio_shoot.stream = gen
	_audio_shoot.play()
	var pb: AudioStreamGeneratorPlayback = _audio_shoot.get_stream_playback()
	if pb == null: return
	var freq := 200.0
	var duration := 0.10
	var noise_amt := 0.5
	var decay := 40.0
	var volume := 0.6
	match kind:
		"rifle": freq = 200.0; duration = 0.09; decay = 42.0; volume = 0.65
		"carbine": freq = 240.0; duration = 0.10; decay = 38.0; volume = 0.7
		"smg": freq = 280.0; duration = 0.06; decay = 55.0; volume = 0.55
		"sniper": freq = 110.0; duration = 0.40; decay = 10.0; volume = 1.0; noise_amt = 0.75
		"semi_sniper": freq = 140.0; duration = 0.22; decay = 18.0; volume = 0.85
		"heavy_sniper": freq = 80.0; duration = 0.55; decay = 6.0; volume = 1.0; noise_amt = 0.85
		"shotgun": freq = 90.0; duration = 0.30; decay = 13.0; volume = 0.9; noise_amt = 0.85
		"lmg": freq = 170.0; duration = 0.10; decay = 40.0; volume = 0.75
		"handcannon": freq = 95.0; duration = 0.20; decay = 18.0; volume = 0.95
		"pistol": freq = 280.0; duration = 0.08; decay = 55.0; volume = 0.6
		"dual_pistol": freq = 260.0; duration = 0.09; decay = 50.0; volume = 0.65
	var pitch_mul: float = 1.0 + heat_ratio * 0.25
	freq *= pitch_mul
	var frames: int = int(duration * 22050.0)
	for i in range(frames):
		var t: float = float(i) / 22050.0
		var env: float = exp(-t * decay)
		var s: float = sin(TAU * freq * t) * (1.0 - noise_amt) * env * volume
		s += (randf() - 0.5) * noise_amt * env * volume
		pb.push_frame(Vector2(s, s))


func _play_extra_sound(kind: String) -> void:
	if _audio_extra == null: return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	var dur := 0.2
	if kind == "jam_start": dur = 3.2
	elif kind == "reload": dur = 0.06
	elif kind == "step": dur = 0.1
	gen.buffer_length = dur + 0.1
	_audio_extra.stream = gen
	_audio_extra.play()
	var pb: AudioStreamGeneratorPlayback = _audio_extra.get_stream_playback()
	if pb == null: return
	if kind == "jam_start":
		var frames: int = int(3.0 * 22050.0)
		for i in range(frames):
			pb.push_frame(Vector2((randf() - 0.5) * 0.25, (randf() - 0.5) * 0.25))
	elif kind == "reload":
		var frames: int = int(0.05 * 22050.0)
		for i in range(frames):
			var t: float = float(i) / 22050.0
			var env: float = exp(-t * 80.0)
			var s: float = sin(TAU * 600.0 * t) * env * 0.4
			pb.push_frame(Vector2(s, s))
	elif kind == "step":
		var frames: int = int(0.08 * 22050.0)
		for i in range(frames):
			var t: float = float(i) / 22050.0
			var env: float = exp(-t * 45.0)
			var s: float = (randf() - 0.5) * env * 0.25
			pb.push_frame(Vector2(s, s))


func _play_hit_victim() -> void:
	if _audio_extra == null: return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.25
	_audio_extra.stream = gen
	_audio_extra.play()
	var pb: AudioStreamGeneratorPlayback = _audio_extra.get_stream_playback()
	if pb == null: return
	var frames: int = int(0.2 * 22050.0)
	for i in range(frames):
		var t: float = float(i) / 22050.0
		var env: float = exp(-t * 18.0)
		var s: float = sin(TAU * 180.0 * t) * env * 0.7 + (randf() - 0.5) * 0.3 * env
		pb.push_frame(Vector2(s, s))


func _play_kill_sound() -> void:
	if _audio_extra == null: return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.4
	_audio_extra.stream = gen
	_audio_extra.play()
	var pb: AudioStreamGeneratorPlayback = _audio_extra.get_stream_playback()
	if pb == null: return
	var frames: int = int(0.35 * 22050.0)
	for i in range(frames):
		var t: float = float(i) / 22050.0
		var env: float = exp(-t * 12.0)
		var s: float = sin(TAU * 880.0 * t) * env * 0.4
		s += sin(TAU * 1320.0 * t) * env * 0.25
		pb.push_frame(Vector2(s, s))


func _input(event: InputEvent) -> void:
	if _menu_mode: return
	if not alive: return
	if not is_multiplayer_authority(): return
	if event is InputEventMouseMotion:
		var sens: float = MOUSE_SENS
		if _aiming and _wm:
			if _wm.current_type == WeaponData.Type.SNIPER: sens *= 0.15
			elif _wm.current_type == WeaponData.Type.HEAVY_SNIPER: sens *= 0.10
			elif _wm.current_type == WeaponData.Type.SEMI_SNIPER: sens *= 0.25
			elif _wm.current_type == WeaponData.Type.RIFLE: sens *= 0.5
			elif _wm.current_type == WeaponData.Type.CARBINE: sens *= 0.5
		rotate_y(-event.relative.x * sens)
		_target_pitch = clamp(_target_pitch - event.relative.y * sens, -1.5, 1.5)
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_mouse_left_held = true
				_try_fire()
			else:
				_mouse_left_held = false
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_aiming = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			switch_weapon(-1)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			switch_weapon(1)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R: _try_reload()
		elif event.keycode == KEY_1: set_weapon_index(0)
		elif event.keycode == KEY_2: set_weapon_index(1)
		elif event.keycode == KEY_3: set_weapon_index(2)


func switch_weapon(dir: int) -> void:
	if _class_weapons.is_empty(): return
	_current_weapon_index = (_current_weapon_index + dir + _class_weapons.size()) % _class_weapons.size()
	_wm.set_weapon(int(_class_weapons[_current_weapon_index]))


func set_weapon_index(idx: int) -> void:
	if _class_weapons.is_empty() or idx < 0 or idx >= _class_weapons.size(): return
	_current_weapon_index = idx
	_wm.set_weapon(int(_class_weapons[idx]))


func _try_reload() -> void:
	if _wm and not _wm.jammed and _wm.heat > 0.0:
		_wm.start_reload()
		_play_extra_sound("reload")


func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		if _net_has_data:
			global_position = global_position.lerp(_net_target_pos, clamp(delta * 20.0, 0.0, 1.0))
			rotation.y = lerp_angle(rotation.y, _net_body_yaw, clamp(delta * 20.0, 0.0, 1.0))
			head.rotation.x = lerp(head.rotation.x, _net_target_head_rot, clamp(delta * 20.0, 0.0, 1.0))
		return
	_pitch = lerp(_pitch, _target_pitch, clamp(delta * 18.0, 0.0, 1.0))
	head.rotation.x = _pitch
	var w_data: Dictionary = _wm.current_data if _wm else {}
	var rr: float = w_data.get("recoil_return", 8.0)
	_recoil_offset = lerp(_recoil_offset, 0.0, clamp(delta * rr, 0.0, 1.0))
	if _mouse_left_held and alive and _wm:
		if _wm.current_data.get("fire_mode", "semi") == "auto":
			_try_fire()
	_net_timer += delta
	if _net_timer >= NET_RATE:
		_net_timer = 0.0
		if _ready_for_sync:
			_send_transform.rpc(global_position, rotation.y, _pitch)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	if not is_on_floor(): velocity.y -= 18.0 * delta
	if alive and Input.is_action_just_pressed("jump") and is_on_floor(): velocity.y = JUMP
	var input_dir := Vector2.ZERO
	if alive:
		input_dir.x = Input.get_axis("move_left", "move_right")
		input_dir.y = Input.get_axis("move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed_val: float = SPEED_BASE * speed_mul
	var sprint_val: float = SPRINT_BASE * sprint_mul
	var target_speed: float = sprint_val if Input.is_action_pressed("sprint") else speed_val
	var horiz := Vector3(velocity.x, 0, velocity.z)
	if wish_dir.length() > 0.01:
		var accel: float = ACCEL_GROUND if is_on_floor() else ACCEL_AIR
		var desired := wish_dir * target_speed
		horiz = horiz.move_toward(desired, accel * delta * target_speed)
	else:
		if is_on_floor():
			horiz = horiz.move_toward(Vector3.ZERO, FRICTION * delta * speed_val)
	velocity.x = horiz.x
	velocity.z = horiz.z
	move_and_slide()
	if alive and is_on_floor() and horiz.length() > 1.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = STEP_INTERVAL * (0.7 if Input.is_action_pressed("sprint") else 1.0)
			if is_local(): _play_extra_sound("step")
	else:
		_step_timer = STEP_INTERVAL
	var sprinting: bool = Input.is_action_pressed("sprint") and horiz.length() > 3.0
	var base_fov: float = 80.0
	if sprinting: base_fov = 88.0
	var target_fov: float = base_fov
	if _aiming and _wm:
		target_fov = float(_wm.current_data.get("zoom_fov", base_fov))
	camera.fov = lerp(camera.fov, target_fov, delta * 12.0)
	var moving: bool = horiz.length() > 0.5
	if moving and is_on_floor():
		var rate: float = 16.0 if sprinting else 10.0
		_bob_time += delta * rate
	else:
		_bob_time = lerp(_bob_time, 0.0, delta * 8.0)
	var bob_x: float = sin(_bob_time) * 0.012
	var bob_y: float = absf(cos(_bob_time)) * 0.010
	weapon_pivot.position = _weapon_base_pos + Vector3(bob_x, bob_y - _recoil_offset * 0.05, _recoil_offset * 0.10)
	weapon_pivot.rotation.x = _recoil_offset * 0.5
	weapon_pivot.rotation.z = bob_x * 1.5
	if armor < armor_max:
		_armor_regen_timer -= delta
		if _armor_regen_timer <= 0.0:
			armor = min(armor_max, armor + ARMOR_REGEN * delta)
			if is_local():
				var w: Node = get_tree().current_scene
				if w and w.has_method("update_armor"): w.update_armor(int(armor), int(armor_max))
	if is_local():
		var space_x: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var from_x: Vector3 = camera.global_position
		var to_x: Vector3 = from_x - camera.global_transform.basis.z * 1000.0
		var qx := PhysicsRayQueryParameters3D.create(from_x, to_x)
		qx.collision_mask = 0b1101
		qx.exclude = [self]
		var hb_x: Node = get_node_or_null("Hitbox")
		if hb_x and hb_x is CollisionObject3D: qx.exclude.append(hb_x)
		var hbhead_x: Node = get_node_or_null("HitboxHead")
		if hbhead_x and hbhead_x is CollisionObject3D: qx.exclude.append(hbhead_x)
		qx.collide_with_areas = true
		qx.collide_with_bodies = true
		var hit_x: Dictionary = space_x.intersect_ray(qx)
		_target_in_sight = false
		if hit_x and hit_x.has("collider"):
			var col_x: Object = hit_x["collider"]
			if col_x is Node:
				var tgt_x: Node = (col_x as Node).get_parent()
				if tgt_x and tgt_x.has_method("receive_damage_rpc") and tgt_x.get("alive") == true:
					_target_in_sight = true
		var world_h: Node = get_tree().current_scene
		if world_h and world_h.has_method("hud_update_crosshair"):
			var heat_ratio: float = _wm.get_heat_ratio() if _wm else 0.0
			world_h.hud_update_crosshair(_target_in_sight, heat_ratio > 0.8)


func _try_fire() -> void:
	if not alive or _wm == null: return
	if not _wm.can_fire(): return
	var shot: Dictionary = _wm.try_fire()
	if shot.is_empty(): return
	_fire_shot(shot)


func _fire_shot(shot: Dictionary) -> void:
	var w_kind: String = shot.get("sound_kind", "rifle")
	_play_shoot_sound(w_kind, _wm.get_heat_ratio())
	_spawn_muzzle_flash()
	var rc: float = shot.get("recoil", 0.01)
	_target_pitch = clamp(_target_pitch + rc, -1.5, 1.5)
	_recoil_offset = 1.0
	var bullets: int = int(shot.get("bullets_per_shot", 1))
	var spread: float = float(shot.get("spread_deg", 0.0))
	var dmg: int = int(shot.get("damage", 10))
	var spd: float = float(shot.get("bullet_speed", 60.0))
	var bcolor: Color = CLASS_BULLET_COLORS[class_type % CLASS_BULLET_COLORS.size()]
	var bsize: float = float(shot.get("bullet_size", 0.025)) * 1.8
	var blen: float = float(shot.get("bullet_length", 0.18)) * 1.5
	var w_name: String = shot.get("name", "")
	var is_dual: bool = (w_name == "Двойные пистолеты")
	var world: Node = get_tree().current_scene
	var origin: Vector3 = camera.global_position
	var cam_dir: Vector3 = -camera.global_transform.basis.z
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var starts: Array = []
	if is_dual:
		var base_pos: Vector3 = weapon_mount.global_position
		starts.append(base_pos + camera.global_transform.basis.x * 0.4)
		starts.append(base_pos - camera.global_transform.basis.x * 0.4)
	else:
		starts.append(muzzle.global_position)
	for start_pos in starts:
		for i in range(bullets):
			var dir: Vector3 = cam_dir
			if spread > 0.0:
				var ang_x: float = deg_to_rad(randf_range(-spread, spread))
				var ang_y: float = deg_to_rad(randf_range(-spread, spread))
				dir = dir.rotated(Vector3.RIGHT, ang_y).rotated(Vector3.UP, ang_x)
			dir = dir.normalized()
			var to: Vector3 = origin + dir * 1000.0
			var q := PhysicsRayQueryParameters3D.create(origin, to)
			q.collision_mask = 0b1101
			q.exclude = [self]
			var hb_node: Node = get_node_or_null("Hitbox")
			if hb_node and hb_node is CollisionObject3D: q.exclude.append(hb_node)
			var hbhead_node: Node = get_node_or_null("HitboxHead")
			if hbhead_node and hbhead_node is CollisionObject3D: q.exclude.append(hbhead_node)
			q.collide_with_areas = true
			q.collide_with_bodies = true
			var hit: Dictionary = space.intersect_ray(q)
			var hit_pos: Vector3 = to
			var was_player: bool = false
			var is_headshot: bool = false
			if hit and hit.has("position"):
				hit_pos = hit["position"]
				var collider: Object = hit.get("collider")
				if collider is Node:
					var col_node: Node = collider as Node
					var target: Node = col_node.get_parent()
					if col_node.name == "HitboxHead": is_headshot = true
					if target != null and target.has_method("receive_damage_rpc"):
						var final_dmg: int = dmg
						if is_headshot:
							var mult: float = 3.0
							if _wm and _wm.current_type == WeaponData.Type.SNIPER: mult = 5.0
							final_dmg = int(float(dmg) * mult)
						target.rpc_id(1, "receive_damage_rpc", final_dmg, multiplayer.get_unique_id())
						was_player = true
						if world and world.has_method("hud_crosshair_hit"): world.hud_crosshair_hit()
						var tgt_alive = target.get("alive")
						var tgt_hp = target.get("hp")
						if tgt_alive == true and tgt_hp != null:
							if int(tgt_hp) - final_dmg <= 0:
								if world and world.has_method("hud_crosshair_kill"): world.hud_crosshair_kill()
								_play_kill_sound()
			if world and world.has_method("show_remote_shot"):
				world.show_remote_shot(start_pos, hit_pos, bcolor, bsize, blen)
			if world and world.has_method("broadcast_impact"):
				world.broadcast_impact(hit_pos, was_player, dir, bcolor)
			var bullet_scene: PackedScene = load("res://scenes/bullet.tscn")
			var b: Node3D = bullet_scene.instantiate() as Node3D
			if b.has_method("configure"):
				b.configure(bcolor, bsize, blen)
			world.add_child(b)
			b.global_position = start_pos
			b.direction = (hit_pos - start_pos).normalized()
			b.speed = spd
			b.shooter = self
			b.world = world
			if "damage" in b: b.damage = 0
			if "max_dist" in b: b.max_dist = start_pos.distance_to(hit_pos)
			if "hit_done" in b: b.hit_done = true


func _spawn_muzzle_flash() -> void:
	if not is_local(): return
	var w_name: String = ""
	if _wm: w_name = _wm.current_data.get("name", "")
	var is_dual: bool = (w_name == "Двойные пистолеты")
	var positions: Array = []
	if is_dual:
		var base_pos: Vector3 = weapon_mount.global_position
		positions.append(base_pos + camera.global_transform.basis.x * 0.4)
		positions.append(base_pos - camera.global_transform.basis.x * 0.4)
	else:
		positions.append(muzzle.global_position)
	for pos in positions:
		_flash_at(pos)


func _flash_at(pos: Vector3) -> void:
	var scene: Node = get_tree().current_scene
	if not scene: return
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.5)
	light.light_energy = 1.2
	light.omni_range = 1.5
	scene.add_child(light)
	light.global_position = pos
	var spark := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	spark.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.95, 0.6)
	mat.emission_energy_multiplier = 4.0
	spark.material_override = mat
	scene.add_child(spark)
	spark.global_position = pos
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(light, "light_energy", 0.0, 0.06)
	tween.tween_property(spark, "scale", Vector3(0.1, 0.1, 0.1), 0.06)
	tween.chain().tween_callback(light.queue_free)
	tween.chain().tween_callback(spark.queue_free)
	get_tree().create_timer(0.5).timeout.connect(_force_free.bind(light))
	get_tree().create_timer(0.5).timeout.connect(_force_free.bind(spark))


func _force_free(node: Node) -> void:
	if is_instance_valid(node): node.queue_free()


func play_hurt() -> void:
	if not is_local(): return
	_play_hit_victim()
	var world: Node = get_tree().current_scene
	if world and world.has_method("show_hurt"): world.show_hurt()


func add_kill_feed_local(text: String) -> void:
	if not is_local(): return
	var world: Node = get_tree().current_scene
	if world and world.has_method("add_kill_feed"): world.add_kill_feed(text)


func enter_menu_mode() -> void:
	_menu_mode = true
	_ready_for_sync = false
	alive = false
	visible = false
	set_process_input(false)
	set_physics_process(false)
	var hb: Node = get_node_or_null("Hitbox")
	if hb:
		hb.monitoring = false
		hb.monitorable = false
		hb.collision_layer = 0
	var hbh: Node = get_node_or_null("HitboxHead")
	if hbh:
		hbh.monitoring = false
		hbh.monitorable = false
		hbh.collision_layer = 0


func exit_menu_mode() -> void:
	_menu_mode = false
	alive = true
	visible = true
	set_process_input(is_multiplayer_authority())
	set_physics_process(true)
	var hb: Node = get_node_or_null("Hitbox")
	if hb:
		hb.monitoring = true
		hb.monitorable = true
		hb.collision_layer = 4


@rpc("any_peer", "unreliable_ordered")
func _send_transform(pos: Vector3, yaw: float, pitch: float) -> void:
	if is_multiplayer_authority(): return
	_net_target_pos = pos
	_net_body_yaw = yaw
	_net_target_head_rot = pitch
	_net_has_data = true


@rpc("any_peer", "call_local", "reliable")
func set_nick(n: String) -> void:
	nick = n
	name_label.text = n
	if multiplayer.is_server(): rpc("sync_nick", n)


@rpc("authority", "call_local", "reliable")
func sync_nick(n: String) -> void:
	nick = n
	name_label.text = n


@rpc("any_peer", "call_local", "reliable")
func apply_class_rpc(class_id: int) -> void:
	apply_class(class_id)


@rpc("any_peer", "call_local", "reliable")
func receive_damage_rpc(amount: int, from_id: int) -> void:
	if not multiplayer.is_server(): return
	if not alive: return
	print("[DMG] ", name, " получил ", amount, " от ", from_id, " hp=", hp)
	var remaining: int = amount
	if armor > 0.0:
		var absorbed: float = min(armor, float(remaining))
		armor -= absorbed
		remaining -= int(absorbed)
	hp -= remaining
	if hp < 0: hp = 0
	var my_id: int = get_multiplayer_authority()
	var peers: Array = multiplayer.get_peers()
	peers.append(1)
	for peer_id in peers:
		if peer_id == multiplayer.get_unique_id(): continue
		apply_hp_armor.rpc_id(peer_id, hp, int(armor), hp_max, int(armor_max))
		play_hurt_rpc.rpc_id(peer_id)
	apply_hp_armor(hp, int(armor), hp_max, int(armor_max))
	play_hurt_rpc()
	_armor_regen_timer = ARMOR_REGEN_DELAY
	if hp <= 0:
		alive = false
		_mouse_left_held = false
		set_process_input(false)
		for peer_id in peers:
			if peer_id == multiplayer.get_unique_id(): continue
			apply_death.rpc_id(peer_id)
		apply_death()
		var killer: Node = get_parent().get_node_or_null(str(from_id))
		if killer and killer.has_method("add_kill_feed_local"):
			killer.rpc_id(from_id, "add_kill_feed_local", "Ты убил %s" % nick)
		var world: Node = get_tree().current_scene
		if world and world.has_method("host_on_kill"):
			world.host_on_kill(from_id, my_id)


@rpc("any_peer", "call_local", "reliable")
func apply_hp_armor(new_hp: int, new_armor: int, new_hp_max: int, new_armor_max: int) -> void:
	hp = new_hp
	armor = float(new_armor)
	hp_max = new_hp_max
	armor_max = float(new_armor_max)
	if is_local():
		var world: Node = get_tree().current_scene
		if world:
			if world.has_method("update_hp"): world.update_hp(hp, hp_max)
			if world.has_method("update_armor"): world.update_armor(int(armor), int(armor_max))


@rpc("any_peer", "call_local", "reliable")
func play_hurt_rpc() -> void:
	if is_local(): play_hurt()


@rpc("any_peer", "call_local", "reliable")
func apply_death() -> void:
	alive = false
	hp = 0
	armor = 0.0
	visible = false
	var hb: Node = get_node_or_null("Hitbox")
	if hb:
		hb.monitoring = false
		hb.monitorable = false
		hb.collision_layer = 0
	var hbh: Node = get_node_or_null("HitboxHead")
	if hbh:
		hbh.monitoring = false
		hbh.monitorable = false
		hbh.collision_layer = 0
	set_physics_process(false)
	if is_local():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		var world: Node = get_tree().current_scene
		if world:
			if world.has_method("update_hp"): world.update_hp(0, hp_max)
			if world.has_method("update_armor"): world.update_armor(0, int(armor_max))
			if world.has_method("on_local_death"): world.on_local_death()


@rpc("any_peer", "call_local", "reliable")
func apply_revive(new_pos: Vector3) -> void:
	hp = hp_max
	armor = armor_max
	alive = true
	visible = true
	velocity = Vector3.ZERO
	global_position = new_pos
	_menu_mode = false
	_ready_for_sync = true
	set_process_input(is_multiplayer_authority())
	set_process(true)
	set_physics_process(true)
	var hb: Node = get_node_or_null("Hitbox")
	if hb:
		hb.monitoring = true
		hb.monitorable = true
		hb.collision_layer = 4
	var hbh: Node = get_node_or_null("HitboxHead")
	if hbh:
		hbh.monitoring = true
		hbh.monitorable = true
		hbh.collision_layer = 8
	if is_local():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		var world: Node = get_tree().current_scene
		if world:
			if world.has_method("update_hp"): world.update_hp(hp, hp_max)
			if world.has_method("update_armor"): world.update_armor(int(armor), int(armor_max))
			if world.has_method("hud_hide_respawn"): world.hud_hide_respawn()
			if world.has_method("show_game_hud"): world.show_game_hud()


@rpc("any_peer", "call_local", "reliable")
func show_hud_after_spawn() -> void:
	if is_local():
		var world: Node = get_tree().current_scene
		if world and world.has_method("show_game_hud"): world.show_game_hud()


@rpc("any_peer", "call_local", "reliable")
func request_class_and_spawn_rpc(class_id: int) -> void:
	if not multiplayer.is_server(): return
	var caller_id: int = multiplayer.get_remote_sender_id()
	if caller_id == 0: caller_id = multiplayer.get_unique_id()
	var world: Node = get_tree().current_scene
	if world and world.has_method("server_player_ready"):
		world.server_player_ready(caller_id, nick, class_id)


@rpc("any_peer", "call_local", "reliable")
func sync_respawn_timer(dead_id: int, t: float) -> void:
	if dead_id != multiplayer.get_unique_id(): return
	if not is_local(): return
	if alive:
		var w_alive: Node = get_tree().current_scene
		if w_alive and w_alive.has_method("hud_hide_respawn"):
			w_alive.hud_hide_respawn()
		return
	var world: Node = get_tree().current_scene
	if not world: return
	if world.has_method("update_respawn_timer"):
		world.update_respawn_timer(t)


@rpc("any_peer", "call_local", "reliable")
func stop_input() -> void:
	_mouse_left_held = false
	alive = false
	visible = false
	set_process_input(false)
	set_physics_process(false)
	velocity = Vector3.ZERO
