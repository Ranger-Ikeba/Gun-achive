extends CharacterBody3D

const SPEED := 6.0
const SPRINT := 9.0
const JUMP := 6.0
const MOUSE_SENS := 0.0025
const ACCEL_GROUND := 8.0
const ACCEL_AIR := 2.0
const FRICTION := 8.0
const NET_RATE := 0.05

const DAMAGE := 15
const ARMOR_MAX := 50.0
const ARMOR_REGEN := 3.0
const ARMOR_REGEN_DELAY := 4.0

const COLORS: Array[Color] = [
	Color(0.85, 0.30, 0.30),
	Color(0.30, 0.55, 0.90),
	Color(0.35, 0.80, 0.40),
	Color(0.90, 0.75, 0.20),
	Color(0.75, 0.40, 0.85),
	Color(0.95, 0.55, 0.20),
	Color(0.20, 0.85, 0.85),
]

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var muzzle: Node3D = $Head/Camera3D/WeaponPivot/Weapon/Muzzle
@onready var weapon_pivot: Node3D = $Head/Camera3D/WeaponPivot
@onready var name_label: Label3D = $NameLabel
@onready var mesh: MeshInstance3D = $Model/MeshInstance3D

var _pitch := 0.0
var _target_pitch := 0.0
var hp := 100
var armor := 50.0
var alive := true
var kills := 0
var nick := "Player"
var _bob_time := 0.0
var _recoil := 0.0
var _weapon_base_pos := Vector3.ZERO

var _net_timer := 0.0
var _net_target_pos := Vector3.ZERO
var _net_target_head_rot := 0.0
var _net_body_yaw := 0.0
var _net_has_target := false

var _armor_regen_timer := 0.0
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	var is_local_pl: bool = is_multiplayer_authority()
	camera.current = is_local_pl
	set_process_input(is_local_pl)
	call_deferred("_apply_color")
	_setup_audio()
	if is_local_pl:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		name_label.visible = false
		weapon_pivot.visible = true
		_weapon_base_pos = weapon_pivot.position
	else:
		name_label.visible = true
		weapon_pivot.visible = false
	if is_local_pl:
		set_nick.rpc_id(1, GameState.nick)


func _setup_audio() -> void:
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 8.0
	_audio.max_distance = 60.0
	_audio.bus = "Master"
	add_child(_audio)


func _play_proc_sound(kind: String) -> void:
	if _audio == null:
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.3
	_audio.stream = gen
	_audio.play()
	var pb: AudioStreamGeneratorPlayback = _audio.get_stream_playback()
	if pb == null:
		return
	var frames: int = int(0.15 * 22050.0)
	var freq := 500.0
	var decay := 40.0
	var volume := 0.3
	if kind == "shoot":
		freq = 320.0
		decay = 30.0
		volume = 0.6
	elif kind == "hit":
		freq = 900.0
		decay = 60.0
		volume = 0.45
	elif kind == "hit_victim":
		freq = 180.0
		decay = 20.0
		volume = 0.7
	elif kind == "hit_attacker":
		freq = 1500.0
		decay = 120.0
		volume = 0.35
	elif kind == "death":
		freq = 90.0
		decay = 8.0
		volume = 0.7
	for i in range(frames):
		var t: float = float(i) / 22050.0
		var env: float = exp(-t * decay)
		var s: float = sin(TAU * freq * t) * env * volume
		s += (randf() - 0.5) * 0.15 * env
		pb.push_frame(Vector2(s, s))


func _apply_color() -> void:
	var id: int = 0
	if name.is_valid_int():
		id = name.to_int()
	else:
		id = get_multiplayer_authority()
	var c: Color = COLORS[id % COLORS.size()]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mesh.set_surface_override_material(0, mat)


func is_local() -> bool:
	return is_multiplayer_authority()


func _input(event: InputEvent) -> void:
	if not alive:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		_target_pitch = clamp(_target_pitch - event.relative.y * MOUSE_SENS, -1.5, 1.5)
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event.is_action_pressed("shoot"):
		_try_shoot()
		_recoil = 1.0


func _process(delta: float) -> void:
	_pitch = lerp(_pitch, _target_pitch, clamp(delta * 18.0, 0.0, 1.0))
	head.rotation.x = _pitch

	if not is_multiplayer_authority() and _net_has_target:
		global_position = global_position.lerp(_net_target_pos, clamp(delta * 15.0, 0.0, 1.0))
		rotation.y = lerp_angle(rotation.y, _net_body_yaw, clamp(delta * 15.0, 0.0, 1.0))
		head.rotation.x = lerp(head.rotation.x, _net_target_head_rot, clamp(delta * 15.0, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	if alive and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP

	var input_dir := Vector2.ZERO
	if alive:
		input_dir.x = Input.get_axis("move_left", "move_right")
		input_dir.y = Input.get_axis("move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target_speed: float = SPRINT if Input.is_action_pressed("sprint") else SPEED

	var horiz := Vector3(velocity.x, 0, velocity.z)
	if wish_dir.length() > 0.01:
		var accel: float = ACCEL_GROUND if is_on_floor() else ACCEL_AIR
		var desired := wish_dir * target_speed
		horiz = horiz.move_toward(desired, accel * delta * target_speed)
	else:
		if is_on_floor():
			horiz = horiz.move_toward(Vector3.ZERO, FRICTION * delta * SPEED)
	velocity.x = horiz.x
	velocity.z = horiz.z
	move_and_slide()

	var sprinting: bool = Input.is_action_pressed("sprint") and horiz.length() > 3.0
	var target_fov: float = 88.0 if sprinting else 80.0
	camera.fov = lerp(camera.fov, target_fov, delta * 4.0)

	var moving := horiz.length() > 0.5
	if moving and is_on_floor():
		var rate: float = 16.0 if sprinting else 10.0
		_bob_time += delta * rate
	else:
		_bob_time = lerp(_bob_time, 0.0, delta * 8.0)
	var bob_x: float = sin(_bob_time) * 0.015
	var bob_y: float = absf(cos(_bob_time)) * 0.012
	_recoil = lerp(_recoil, 0.0, delta * 12.0)
	weapon_pivot.position = _weapon_base_pos + Vector3(bob_x, bob_y - _recoil * 0.03, _recoil * 0.08)
	weapon_pivot.rotation.x = _recoil * 0.35
	weapon_pivot.rotation.z = bob_x * 2.0

	if armor < ARMOR_MAX:
		_armor_regen_timer -= delta
		if _armor_regen_timer <= 0.0:
			armor = min(ARMOR_MAX, armor + ARMOR_REGEN * delta)
			if is_local():
				var w: Node = get_tree().current_scene
				if w and w.has_method("update_armor"):
					w.update_armor(int(armor))

	_net_timer += delta
	if _net_timer >= NET_RATE:
		_net_timer = 0.0
		_send_transform.rpc(global_position, rotation.y, head.rotation.x)


func _try_shoot() -> void:
	if not alive:
		return
	_spawn_muzzle_flash()
	_play_proc_sound("shoot")
	var world: Node = get_tree().current_scene
	var bullet_scene: PackedScene = load("res://scenes/bullet.tscn")
	var b: Node3D = bullet_scene.instantiate() as Node3D
	var from: Vector3 = muzzle.global_position
	var dir: Vector3 = -camera.global_transform.basis.z
	world.add_child(b)
	b.global_position = from
	b.direction = dir
	b.speed = 400.0
	b.shooter = self
	b.world = world


func _spawn_muzzle_flash() -> void:
	if not is_local():
		return
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.85, 0.5)
	flash.light_energy = 3.0
	flash.omni_range = 5.0
	muzzle.add_child(flash)
	var spark := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	spark.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.5)
	mat.emission_energy_multiplier = 3.0
	spark.material_override = mat
	muzzle.add_child(spark)
	await get_tree().create_timer(0.04).timeout
	if is_instance_valid(flash):
		flash.queue_free()
	if is_instance_valid(spark):
		spark.queue_free()


func play_hurt() -> void:
	if not is_local():
		return
	_play_proc_sound("hit_victim")
	var world: Node = get_tree().current_scene
	if world and world.has_method("show_hurt"):
		world.show_hurt()


func add_kill_feed_local(text: String) -> void:
	if not is_local():
		return
	var world: Node = get_tree().current_scene
	if world and world.has_method("add_kill_feed"):
		world.add_kill_feed(text)


# =====================================================================
# RPC
# =====================================================================

@rpc("any_peer", "unreliable_ordered")
func _send_transform(pos: Vector3, yaw: float, pitch: float) -> void:
	if is_multiplayer_authority():
		return
	_net_target_pos = pos
	_net_body_yaw = yaw
	_net_target_head_rot = pitch
	_net_has_target = true


@rpc("any_peer", "call_local", "reliable")
func set_nick(n: String) -> void:
	nick = n
	name_label.text = n
	if multiplayer.is_server():
		rpc("sync_nick", n)


@rpc("authority", "call_local", "reliable")
func sync_nick(n: String) -> void:
	nick = n
	name_label.text = n


@rpc("any_peer", "call_local", "reliable")
func receive_damage_rpc(amount: int, from_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not alive:
		return

	var remaining: int = amount
	if armor > 0.0:
		var absorbed: float = min(armor, float(remaining))
		armor -= absorbed
		remaining -= int(absorbed)
	hp -= remaining
	if hp < 0:
		hp = 0

	var my_id: int = get_multiplayer_authority()
	var peers: Array = multiplayer.get_peers()
	peers.append(1)
	for peer_id in peers:
		if peer_id == multiplayer.get_unique_id():
			continue
		apply_hp_armor.rpc_id(peer_id, hp, int(armor))
		play_hurt_rpc.rpc_id(peer_id)
	apply_hp_armor(hp, int(armor))
	play_hurt_rpc()
	_armor_regen_timer = ARMOR_REGEN_DELAY

	if hp <= 0:
		alive = false
		for peer_id in peers:
			if peer_id == multiplayer.get_unique_id():
				continue
			apply_death.rpc_id(peer_id)
		apply_death()
		var killer: Node = get_parent().get_node_or_null(str(from_id))
		if killer and killer.has_method("add_kill_feed_local"):
			killer.rpc_id(from_id, "add_kill_feed_local", "Ты убил %s" % nick)
		var world: Node = get_tree().current_scene
		if world and world.has_method("host_on_player_died"):
			world.host_on_player_died(my_id, from_id)

@rpc("any_peer", "call_local", "reliable")
func apply_hp_armor(new_hp: int, new_armor: int) -> void:
	hp = new_hp
	armor = float(new_armor)
	if is_local():
		var world: Node = get_tree().current_scene
		if world:
			if world.has_method("update_hp"):
				world.update_hp(hp)
			if world.has_method("update_armor"):
				world.update_armor(int(armor))


@rpc("any_peer", "call_local", "reliable")
func play_hurt_rpc() -> void:
	if is_local():
		play_hurt()


@rpc("any_peer", "call_local", "reliable")
func apply_death() -> void:
	print("[DEATH] player=", name, " alive_was=", alive, " local=", is_local())
	alive = false
	hp = 0
	armor = 0.0
	visible = false
	var hb: Node = get_node_or_null("Hitbox")
	if hb:
		hb.monitoring = false
		hb.monitorable = false
	set_physics_process(false)
	if is_local():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_play_proc_sound("death")
		var world: Node = get_tree().current_scene
		if world:
			if world.has_method("update_hp"):
				world.update_hp(0)
			if world.has_method("update_armor"):
				world.update_armor(0)
			if world.has_method("on_local_death"):
				world.on_local_death()


@rpc("any_peer", "call_local", "reliable")
func apply_revive(new_pos: Vector3) -> void:
	print("[REVIVE-IN] player=", name, " local=", is_local(), " self_id=", multiplayer.get_unique_id(), " alive_before=", alive)
	if alive and hp >= 100 and armor >= ARMOR_MAX:
		print("[REVIVE-SKIP] уже жив")
		return
	print("[REVIVE-EXEC] player=", name)
	hp = 100
	armor = ARMOR_MAX
	alive = true
	visible = true
	velocity = Vector3.ZERO
	global_position = new_pos
	set_physics_process(true)
	var hb: Node = get_node_or_null("Hitbox")
	if hb:
		hb.monitoring = true
		hb.monitorable = true
	if is_local():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		var world: Node = get_tree().current_scene
		if world:
			if world.has_method("update_hp"):
				world.update_hp(hp)
			if world.has_method("update_armor"):
				world.update_armor(int(armor))
			if world.has_method("hud_hide_respawn"):
				world.hud_hide_respawn()

@rpc("any_peer", "call_local", "reliable")
func sync_respawn_timer(dead_id: int, t: float) -> void:
	if dead_id != multiplayer.get_unique_id():
		return
	if not is_local():
		return
	if alive:
		var w_alive: Node = get_tree().current_scene
		if w_alive and w_alive.has_method("hud_hide_respawn"):
			w_alive.hud_hide_respawn()
		return
	var world: Node = get_tree().current_scene
	if not world:
		return
	if world.has_method("update_respawn_timer"):
		world.update_respawn_timer(t)

@rpc("any_peer", "call_local", "reliable")
func request_respawn_rpc() -> void:
	if not multiplayer.is_server():
		return
	var caller_id: int = multiplayer.get_remote_sender_id()
	if caller_id == 0:
		caller_id = multiplayer.get_unique_id()
	var world: Node = get_tree().current_scene
	if world and world.has_method("server_handle_respawn"):
		world.server_handle_respawn(caller_id)
