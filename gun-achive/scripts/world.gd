extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MAX_PLAYERS := 7
const BASE_RESPAWN := 4.0
const IMPACT_PARTICLES := preload("res://scenes/impact.tscn")

@onready var spawns_root: Node3D = $Spawns
@onready var players_root: Node3D = $Players
@onready var hud: Control = $HUD

var respawn_timers := {}
var player_deaths := {}
var _impact_audio: AudioStreamPlayer3D

func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_impact_audio = AudioStreamPlayer3D.new()
	_impact_audio.unit_size = 4.0
	_impact_audio.max_distance = 40.0
	add_child(_impact_audio)
	if multiplayer.is_server():
		call_deferred("_server_spawn_self")
	else:
		call_deferred("_client_hello")
	call_deferred("_show_menu")

func _show_menu() -> void:
	if hud.has_method("show_class_menu"):
		hud.show_class_menu()

func _server_spawn_self() -> void:
	var my_id: int = multiplayer.get_unique_id()
	client_create_player(my_id)

func _client_hello() -> void:
	if multiplayer.is_server():
		return
	await get_tree().create_timer(0.5).timeout
	rpc_id(1, "client_hello")
	print("[CLIENT] отправил hello")

func _on_server_disconnected() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	print("[PEER-CONNECTED] ", id)

func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var p: Node = players_root.get_node_or_null(str(id))
	if p:
		p.queue_free()
	print("[PEER-DISCONNECTED] ", id)

@rpc("any_peer", "call_local", "reliable")
func client_hello() -> void:
	if not multiplayer.is_server():
		return
	var caller_id: int = multiplayer.get_remote_sender_id()
	if caller_id == 0:
		caller_id = multiplayer.get_unique_id()
	print("[CLIENT-HELLO] от ", caller_id)
	await get_tree().create_timer(0.5).timeout
	# Синхронизируем существующих игроков
	for existing in players_root.get_children():
		var eid: int = int(existing.name)
		if eid == caller_id:
			continue
		print("[SYNC-EXISTING] шлём ", eid, " клиенту ", caller_id)
		rpc_id(caller_id, "client_create_player", eid)
	# Создаём ноду клиента у всех
	_spawn_player_for(caller_id)

func _spawn_player_for(id: int) -> void:
	if not multiplayer.is_server():
		return
	if players_root.has_node(str(id)):
		return
	print("[SPAWN-FOR] ", id)
	var my_server_id: int = multiplayer.get_unique_id()
	for peer_id in multiplayer.get_peers():
		if peer_id == my_server_id:
			continue
		rpc_id(peer_id, "client_create_player", id)
	client_create_player(id)

@rpc("authority", "call_local", "reliable")
func client_create_player(id: int) -> void:
	if id < 0:
		return
	if players_root.has_node(str(id)):
		return
	print("[CLIENT-CREATE] id=", id, " на пире ", multiplayer.get_unique_id())
	var p: Node = PLAYER_SCENE.instantiate()
	p.name = str(id)
	p.set_multiplayer_authority(id)
	players_root.add_child(p)
	var pos: Vector3 = get_spawn_pos(id % MAX_PLAYERS)
	p.global_position = pos
	if id == multiplayer.get_unique_id():
		if p.has_method("enter_menu_mode"):
			p.enter_menu_mode()
	else:
		if p.has_method("apply_revive"):
			p.apply_revive(pos)

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for id in respawn_timers.keys():
		if respawn_timers[id] > 0.0:
			respawn_timers[id] -= delta
			if respawn_timers[id] < 0.0:
				respawn_timers[id] = 0.0
			var p: Node = players_root.get_node_or_null(str(id))
			if p and p.has_method("sync_respawn_timer"):
				if id == multiplayer.get_unique_id():
					p.sync_respawn_timer(id, respawn_timers[id])
				else:
					p.sync_respawn_timer.rpc_id(id, id, respawn_timers[id])

func server_apply_class_and_revive(id: int, class_id: int, pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var p: Node = players_root.get_node_or_null(str(id))
	if p == null:
		_spawn_player_for(id)
		p = players_root.get_node_or_null(str(id))
	if p == null:
		return
	# Смена класса всем
	var my_server_id: int = multiplayer.get_unique_id()
	for peer_id in multiplayer.get_peers():
		if peer_id == my_server_id:
			continue
		p.apply_class_rpc.rpc_id(peer_id, class_id)
	p.apply_class_rpc(class_id)
	# Логика:
	# 1. Если был таймер респавна (умер) — ревайв только если таймер = 0
	# 2. Если это ПЕРВЫЙ спавн (нет таймера вообще) — ревайв сразу
	var had_timer: bool = respawn_timers.has(id)
	var timer_left: float = respawn_timers.get(id, 0.0)
	if had_timer and timer_left > 0.0:
		print("[CLASS] ", id, " сменил класс, ждём таймер ", timer_left)
		return
	# Ревайвим
	for peer_id in multiplayer.get_peers():
		if peer_id == my_server_id:
			continue
		p.apply_revive.rpc_id(peer_id, pos)
		p.rpc_id(peer_id, "show_hud_after_spawn")
	p.apply_revive(pos)
	p.show_hud_after_spawn()
	respawn_timers[id] = 0.0

func server_revive_player(dead_id: int, class_id: int = -1) -> void:
	if not multiplayer.is_server():
		return
	var pos: Vector3 = get_spawn_pos(dead_id % MAX_PLAYERS)
	var p: Node = players_root.get_node_or_null(str(dead_id))
	if p == null:
		_spawn_player_for(dead_id)
		return
	if class_id >= 0:
		p.apply_class_rpc(class_id)
	var my_server_id: int = multiplayer.get_unique_id()
	for peer_id in multiplayer.get_peers():
		if peer_id == my_server_id:
			continue
		p.apply_revive.rpc_id(peer_id, pos)
		p.rpc_id(peer_id, "show_hud_after_spawn")
	p.apply_revive(pos)
	p.show_hud_after_spawn()
	respawn_timers[dead_id] = 0.0

func get_spawn_pos(idx: int) -> Vector3:
	var n: int = spawns_root.get_child_count()
	if n == 0:
		return Vector3(0, 1.5, 0)
	return spawns_root.get_child(idx % n).global_position

func update_hp(hp: int, hp_max: int) -> void:
	if hud.has_method("set_hp"):
		hud.set_hp(hp, hp_max)

func update_armor(armor: int, armor_max: int) -> void:
	if hud.has_method("set_armor"):
		hud.set_armor(armor, armor_max)

func update_respawn_timer(t: float) -> void:
	if hud.has_method("show_respawn"):
		hud.show_respawn(t)

func hud_hide_respawn() -> void:
	if hud.has_method("hide_respawn"):
		hud.hide_respawn()

func hud_set_weapon(w_data: Dictionary) -> void:
	if hud.has_method("set_weapon_name"):
		hud.set_weapon_name(w_data.get("name", ""))

func update_heat(heat: float, max_heat: float, jammed: bool) -> void:
	if hud.has_method("set_heat"):
		hud.set_heat(heat, max_heat, jammed)

func hud_update_crosshair(target_in_sight: bool, overheated: bool) -> void:
	if hud.has_method("update_crosshair"):
		hud.update_crosshair(target_in_sight, overheated)

func hud_crosshair_hit() -> void:
	if hud.has_method("crosshair_hit_flash"):
		hud.crosshair_hit_flash()

func hud_crosshair_kill() -> void:
	if hud.has_method("crosshair_kill_flash"):
		hud.crosshair_kill_flash()

func show_class_menu() -> void:
	if hud.has_method("show_class_menu"):
		hud.show_class_menu()

func show_game_hud() -> void:
	if hud.has_method("show_game_hud"):
		hud.show_game_hud()

func on_local_death() -> void:
	if hud.has_method("show_respawn_immediate"):
		hud.show_respawn_immediate()

func host_on_player_died(dead_id: int, killer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if killer_id != 0 and killer_id != dead_id:
		var killer: Node = players_root.get_node_or_null(str(killer_id))
		if killer:
			killer.kills += 1
	var deaths: int = player_deaths.get(dead_id, 0) + 1
	player_deaths[dead_id] = deaths
	var next_time: float = min(BASE_RESPAWN + float(deaths - 1), 15.0)
	respawn_timers[dead_id] = next_time
	print("[RESPAWN] ", dead_id, " смертей: ", deaths, " таймер: ", next_time)

func broadcast_impact(pos: Vector3, is_player: bool, dir: Vector3, color: Color = Color(0.75, 0.05, 0.05, 1.0)) -> void:
	rpc("show_impact", pos, is_player, dir, color)

@rpc("any_peer", "call_local", "reliable")
func show_impact(pos: Vector3, is_player: bool, dir: Vector3, color: Color = Color(0.75, 0.05, 0.05, 1.0)) -> void:
	var n := IMPACT_PARTICLES.instantiate()
	add_child(n)
	n.global_position = pos
	if is_player:
		n.configure_blood(color)
	else:
		n.configure_spark(dir)
	n.emitting = true
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(n):
		n.queue_free()

func play_impact_sound_at(pos: Vector3) -> void:
	if _impact_audio == null:
		return
	_impact_audio.global_position = pos
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	_impact_audio.stream = gen
	_impact_audio.play()
	var pb: AudioStreamGeneratorPlayback = _impact_audio.get_stream_playback()
	if pb == null:
		return
	var frames: int = int(0.06 * 22050.0)
	for i in range(frames):
		var t: float = float(i) / 22050.0
		var env: float = exp(-t * 70.0)
		var s: float = (randf() - 0.5) * env * 0.4
		s += sin(TAU * 900.0 * t) * env * 0.3
		pb.push_frame(Vector2(s, s))

func show_hurt() -> void:
	if hud.has_method("show_hurt"):
		hud.show_hurt()

func add_kill_feed(text: String) -> void:
	if hud.has_method("add_kill_feed"):
		hud.add_kill_feed(text)
