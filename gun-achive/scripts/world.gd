extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MAX_PLAYERS := 7
const BASE_RESPAWN := 4.0
const IMPACT_PARTICLES := preload("res://scenes/impact.tscn")

@onready var spawns_root: Node3D = $Spawns
@onready var players_root: Node3D = $Players
@onready var hud: Control = $HUD

var player_slots: Dictionary = {}
var slot_used: Dictionary = {}
var player_nicks: Dictionary = {}
var player_deaths: Dictionary = {}
var respawn_timers: Dictionary = {}
var ready_players: Dictionary = {}
var round_active: bool = false
var round_ended: bool = false
var round_time_left: float = 300.0
var player_scores: Dictionary = {}
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
	call_deferred("_open_mode_menu")


func _open_mode_menu() -> void:
	if hud and hud.has_method("show_mode_menu"):
		hud.show_mode_menu()


func _assign_slot(id: int) -> int:
	if player_slots.has(id): return player_slots[id]
	for slot in range(MAX_PLAYERS):
		if not slot_used.has(slot):
			slot_used[slot] = id
			player_slots[id] = slot
			print("[SLOT] ", id, " -> ", slot)
			return slot
	var s: int = id % MAX_PLAYERS
	slot_used[s] = id
	player_slots[id] = s
	return s


func get_player_slot(id: int) -> int:
	if not player_slots.has(id): return _assign_slot(id)
	return player_slots[id]


func get_spawn_pos(idx: int) -> Vector3:
	var n: int = spawns_root.get_child_count()
	if n == 0: return Vector3(0, 1.5, 0)
	return spawns_root.get_child(idx % n).global_position


func _server_spawn_self() -> void:
	var my_id: int = multiplayer.get_unique_id()
	client_create_player(my_id)


func _client_hello() -> void:
	if multiplayer.is_server(): return
	await get_tree().create_timer(0.5).timeout
	rpc_id(1, "client_hello")
	print("[CLIENT] отправил hello")


@rpc("any_peer", "call_local", "reliable")
func client_hello() -> void:
	if not multiplayer.is_server(): return
	var caller_id: int = multiplayer.get_remote_sender_id()
	if caller_id == 0: caller_id = multiplayer.get_unique_id()
	print("[CLIENT-HELLO] от ", caller_id)
	await get_tree().create_timer(0.3).timeout
	for existing in players_root.get_children():
		var eid: int = int(existing.name)
		if eid == caller_id: continue
		rpc_id(caller_id, "client_create_player", eid)
	_spawn_player_for(caller_id)
	if ready_players.size() > 0:
		rpc_id(caller_id, "sync_lobby_state", _ready_list())


func _spawn_player_for(id: int) -> void:
	if not multiplayer.is_server(): return
	if players_root.has_node(str(id)): return
	print("[SPAWN-FOR] ", id)
	var my_id: int = multiplayer.get_unique_id()
	for peer_id in multiplayer.get_peers():
		if peer_id == my_id: continue
		rpc_id(peer_id, "client_create_player", id)
	client_create_player(id)


@rpc("authority", "call_local", "reliable")
func client_create_player(id: int) -> void:
	if id < 0: return
	if players_root.has_node(str(id)): return
	var slot: int = get_player_slot(id)
	print("[CREATE] id=", id, " slot=", slot)
	var p: Node = PLAYER_SCENE.instantiate()
	p.name = str(id)
	p.set_multiplayer_authority(id)
	p.set_meta("slot", slot)
	players_root.add_child(p)
	var pos: Vector3 = get_spawn_pos(slot)
	p.global_position = pos
	if id == multiplayer.get_unique_id():
		if p.has_method("enter_menu_mode"): p.enter_menu_mode()
	else:
		if p.has_method("apply_revive"): p.apply_revive(pos)


@rpc("any_peer", "call_local", "reliable")
func server_player_ready(id: int, nick: String, class_id: int) -> void:
	if not multiplayer.is_server(): return
	ready_players[id] = {"nick": nick, "ready": true, "class_id": class_id}
	player_nicks[id] = nick
	print("[LOBBY] готов: ", nick)
	_broadcast_lobby_state()
	rpc_id(id, "sync_lobby_state", _ready_list())


@rpc("any_peer", "call_local", "reliable")
func server_player_not_ready(id: int) -> void:
	if not multiplayer.is_server(): return
	if ready_players.has(id): ready_players.erase(id)
	_broadcast_lobby_state()


func _ready_list() -> Array:
	var list: Array = []
	for pid in ready_players.keys():
		list.append(ready_players[pid])
	return list


func _broadcast_lobby_state() -> void:
	if not multiplayer.is_server(): return
	var list: Array = _ready_list()
	for peer_id in multiplayer.get_peers():
		rpc_id(peer_id, "sync_lobby_state", list)


@rpc("any_peer", "call_local", "reliable")
func sync_lobby_state(players_list: Array) -> void:
	if hud.has_method("update_lobby_list"):
		hud.update_lobby_list(players_list)


func server_start_round() -> void:
	if not multiplayer.is_server(): return
	if ready_players.size() < 2:
		print("[ROUND] Нужно 2 игрока, есть ", ready_players.size())
		return
	print("[ROUND] Старт, игроков: ", ready_players.size())
	player_scores.clear()
	for pid in ready_players.keys():
		player_scores[pid] = 0
	round_time_left = 300.0
	round_ended = false
	round_active = true
	rpc("sync_scores", player_scores)
	rpc("sync_round_timer", round_time_left)
	for pid in ready_players.keys():
		var info: Dictionary = ready_players[pid]
		var pos: Vector3 = get_spawn_pos(get_player_slot(pid))
		server_apply_class_and_revive(pid, info["class_id"], pos)
	rpc("client_start_round")


@rpc("any_peer", "call_local", "reliable")
func client_start_round() -> void:
	if hud and hud.has_method("hide_lobby_menu"): hud.hide_lobby_menu()
	if hud and hud.has_method("hide_class_menu"): hud.hide_class_menu()
	if hud and hud.has_method("hide_mode_menu"): hud.hide_mode_menu()
	if hud and hud.has_method("show_game_hud"): hud.show_game_hud()


func server_apply_class_and_revive(id: int, class_id: int, pos: Vector3) -> void:
	if not multiplayer.is_server(): return
	var p: Node = players_root.get_node_or_null(str(id))
	if p == null:
		_spawn_player_for(id)
		p = players_root.get_node_or_null(str(id))
	if p == null: return
	var my_id: int = multiplayer.get_unique_id()
	for peer_id in multiplayer.get_peers():
		if peer_id == my_id: continue
		p.apply_class_rpc.rpc_id(peer_id, class_id)
		p.apply_revive.rpc_id(peer_id, pos)
	p.apply_class_rpc(class_id)
	p.apply_revive(pos)


func server_revive_player(dead_id: int, class_id: int = -1) -> void:
	if not multiplayer.is_server(): return
	var pos: Vector3 = get_spawn_pos(get_player_slot(dead_id))
	var p: Node = players_root.get_node_or_null(str(dead_id))
	if p == null: return
	if class_id >= 0:
		p.apply_class_rpc(class_id)
	var my_id: int = multiplayer.get_unique_id()
	for peer_id in multiplayer.get_peers():
		if peer_id == my_id: continue
		p.apply_revive.rpc_id(peer_id, pos)
	p.apply_revive(pos)
	respawn_timers[dead_id] = 0.0


func add_score(id: int, amount: int) -> void:
	if not multiplayer.is_server(): return
	var cur: int = player_scores.get(id, 0)
	player_scores[id] = cur + amount
	print("[SCORE] ", id, " +", amount, " = ", player_scores[id])
	rpc("sync_scores", player_scores)


@rpc("any_peer", "call_local", "reliable")
func sync_scores(scores: Dictionary) -> void:
	player_scores = scores
	if hud.has_method("update_score"):
		var my_id: int = multiplayer.get_unique_id()
		hud.update_score(player_scores.get(my_id, 0))


func get_alive_count() -> int:
	var count: int = 0
	for c in players_root.get_children():
		if c.get("alive") == true: count += 1
	return count


func _broadcast_alive_count() -> void:
	rpc("sync_alive_count", get_alive_count())


@rpc("any_peer", "call_local", "reliable")
func sync_alive_count(count: int) -> void:
	if hud.has_method("update_alive_count"):
		hud.update_alive_count(count)


@rpc("any_peer", "call_local", "reliable")
func sync_round_timer(t: float) -> void:
	round_time_left = t
	if hud.has_method("update_timer"):
		hud.update_timer(t)


func host_on_kill(killer_id: int, victim_id: int) -> void:
	if not multiplayer.is_server(): return
	if killer_id != 0 and killer_id != victim_id:
		add_score(killer_id, 10)
	player_died_in_round(victim_id)


func player_died_in_round(dead_id: int) -> void:
	if not multiplayer.is_server(): return
	_broadcast_alive_count()
	rpc_id(dead_id, "notify_local_death", dead_id)
	if ready_players.size() >= 2:
		var alive: int = get_alive_count()
		if alive <= 1:
			_end_round_last_survivor()
	rpc("sync_scores", player_scores)


@rpc("any_peer", "call_local", "reliable")
func notify_local_death(my_id: int) -> void:
	if hud.has_method("show_defeat"):
		hud.show_defeat(player_scores.get(my_id, 0))


@rpc("any_peer", "call_local", "reliable")
func notify_local_victory(my_id: int) -> void:
	if hud.has_method("show_victory"):
		hud.show_victory(player_scores.get(my_id, 0))


func _end_round_last_survivor() -> void:
	if round_ended: return
	round_ended = true
	var winner_id: int = 0
	for c in players_root.get_children():
		if c.get("alive") == true:
			winner_id = int(c.name)
			break
	rpc("stop_round_state")
	for pid in ready_players.keys():
		if pid == winner_id:
			rpc_id(pid, "notify_local_victory", pid)
		else:
			rpc_id(pid, "notify_local_death", pid)
	await get_tree().create_timer(3.0).timeout
	if not multiplayer.is_server(): return
	var results: Array = []
	for pid in player_scores.keys():
		results.append({
			"id": pid,
			"nick": player_nicks.get(pid, str(pid)),
			"score": player_scores[pid]
		})
	results.sort_custom(func(a, b): return a["score"] > b["score"])
	rpc("show_round_results", results, winner_id, false)


func _end_round_by_time() -> void:
	if round_ended: return
	round_ended = true
	var results: Array = []
	for pid in player_scores.keys():
		results.append({
			"id": pid,
			"nick": player_nicks.get(pid, str(pid)),
			"score": player_scores[pid]
		})
	results.sort_custom(func(a, b): return a["score"] > b["score"])
	var winner_id: int = 0
	if results.size() > 0: winner_id = results[0]["id"]
	rpc("stop_round_state")
	for pid in ready_players.keys():
		if pid == winner_id:
			rpc_id(pid, "notify_local_victory", pid)
		else:
			rpc_id(pid, "notify_local_death", pid)
	await get_tree().create_timer(3.0).timeout
	if not multiplayer.is_server(): return
	rpc("show_round_results", results, winner_id, true)


@rpc("any_peer", "call_local", "reliable")
func show_round_results(results: Array, winner_id: int, by_time: bool) -> void:
	if hud.has_method("show_results"):
		hud.show_results(results, winner_id, by_time)


@rpc("any_peer", "call_local", "reliable")
func stop_round_state() -> void:
	round_active = false
	round_ended = true
	for c in players_root.get_children():
		if c.has_method("stop_input"):
			c.stop_input()
		else:
			if c.has_method("set_process_input"): c.set_process_input(false)
			if c.has_method("set_physics_process"): c.set_physics_process(false)
			if "velocity" in c: c.velocity = Vector3.ZERO


func _process_round(delta: float) -> void:
	if not multiplayer.is_server(): return
	if not round_active or round_ended: return
	round_time_left -= delta
	rpc("sync_round_timer", round_time_left)
	if round_time_left <= 0.0:
		_end_round_by_time()


func server_set_mode(mode: int) -> void:
	if not multiplayer.is_server(): return
	GameState.chosen_mode = mode
	rpc("sync_chosen_mode", mode)


@rpc("any_peer", "call_local", "reliable")
func sync_chosen_mode(mode: int) -> void:
	GameState.chosen_mode = mode
	if hud and hud.has_method("show_class_menu"):
		hud.show_class_menu()


func show_mode_menu() -> void:
	if hud and hud.has_method("show_mode_menu"):
		hud.show_mode_menu()


func show_class_menu() -> void:
	if hud and hud.has_method("show_class_menu"):
		hud.show_class_menu()


func show_lobby_menu() -> void:
	if hud and hud.has_method("show_lobby_menu"):
		hud.show_lobby_menu()
	_broadcast_lobby_state()


func on_local_death() -> void:
	if hud and hud.has_method("show_respawn_immediate"):
		hud.show_respawn_immediate()


func update_hp(hp: int, hp_max: int) -> void:
	if hud and hud.has_method("set_hp"): hud.set_hp(hp, hp_max)


func update_armor(armor: int, armor_max: int) -> void:
	if hud and hud.has_method("set_armor"): hud.set_armor(armor, armor_max)


func update_respawn_timer(t: float) -> void:
	if hud and hud.has_method("show_respawn"): hud.show_respawn(t)


func hud_hide_respawn() -> void:
	if hud and hud.has_method("hide_respawn"): hud.hide_respawn()


func hud_set_weapon(w_data: Dictionary) -> void:
	if hud and hud.has_method("set_weapon_name"):
		hud.set_weapon_name(w_data.get("name", ""))


func update_heat(heat: float, max_heat: float, jammed: bool) -> void:
	if hud and hud.has_method("set_heat"): hud.set_heat(heat, max_heat, jammed)


func hud_update_crosshair(target_in_sight: bool, overheated: bool) -> void:
	if hud and hud.has_method("update_crosshair"):
		hud.update_crosshair(target_in_sight, overheated)


func hud_crosshair_hit() -> void:
	if hud and hud.has_method("crosshair_hit_flash"): hud.crosshair_hit_flash()


func hud_crosshair_kill() -> void:
	if hud and hud.has_method("crosshair_kill_flash"): hud.crosshair_kill_flash()


func broadcast_impact(pos: Vector3, is_player: bool, dir: Vector3,
		color: Color = Color(0.75, 0.05, 0.05, 1.0)) -> void:
	rpc("show_impact", pos, is_player, dir, color)


@rpc("any_peer", "call_local", "reliable")
func show_impact(pos: Vector3, is_player: bool, dir: Vector3,
		color: Color = Color(0.75, 0.05, 0.05, 1.0)) -> void:
	var n := IMPACT_PARTICLES.instantiate()
	add_child(n)
	n.global_position = pos
	if is_player:
		n.configure_blood(color)
	else:
		n.configure_spark(dir)
	n.emitting = true
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(n): n.queue_free()


func play_impact_sound_at(pos: Vector3) -> void:
	if _impact_audio == null: return
	_impact_audio.global_position = pos
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	_impact_audio.stream = gen
	_impact_audio.play()
	var pb: AudioStreamGeneratorPlayback = _impact_audio.get_stream_playback()
	if pb == null: return
	var frames: int = int(0.06 * 22050.0)
	for i in range(frames):
		var t: float = float(i) / 22050.0
		var env: float = exp(-t * 70.0)
		var s: float = (randf() - 0.5) * env * 0.4
		s += sin(TAU * 900.0 * t) * env * 0.3
		pb.push_frame(Vector2(s, s))


func show_hurt() -> void:
	if hud and hud.has_method("show_hurt"): hud.show_hurt()


func add_kill_feed(text: String) -> void:
	if hud and hud.has_method("add_kill_feed"): hud.add_kill_feed(text)


func show_remote_shot(from_pos: Vector3, to_pos: Vector3,
		color: Color, size: float, length: float) -> void:
	rpc("client_show_bullet", from_pos, to_pos, color, size, length)


@rpc("any_peer", "call_local", "reliable")
func client_show_bullet(from_pos: Vector3, to_pos: Vector3,
		color: Color, size: float, length: float) -> void:
	var bullet_scene: PackedScene = load("res://scenes/bullet.tscn")
	var b: Node3D = bullet_scene.instantiate() as Node3D
	if b.has_method("configure"):
		b.configure(color, size, length)
	add_child(b)
	b.global_position = from_pos
	b.direction = (to_pos - from_pos).normalized()
	b.speed = 60.0
	b.shooter = null
	b.world = self
	if "damage" in b: b.damage = 0
	if "max_dist" in b: b.max_dist = from_pos.distance_to(to_pos)
	if "hit_done" in b: b.hit_done = true


@rpc("any_peer", "call_local", "reliable")
func client_request_results() -> void:
	if not multiplayer.is_server(): return
	var caller_id: int = multiplayer.get_remote_sender_id()
	if caller_id == 0: caller_id = multiplayer.get_unique_id()
	var results: Array = []
	for pid in player_scores.keys():
		results.append({
			"id": pid,
			"nick": player_nicks.get(pid, str(pid)),
			"score": player_scores[pid]
		})
	results.sort_custom(func(a, b): return a["score"] > b["score"])
	rpc_id(caller_id, "show_current_results_client", results)


@rpc("any_peer", "call_local", "reliable")
func show_current_results_client(results: Array) -> void:
	if hud and hud.has_method("show_current_results"):
		hud.show_current_results(results)


func _on_server_disconnected() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server(): return
	print("[PEER-CONNECTED] ", id)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server(): return
	var p: Node = players_root.get_node_or_null(str(id))
	if p: p.queue_free()
	if player_slots.has(id):
		var s: int = player_slots[id]
		slot_used.erase(s)
		player_slots.erase(id)
	if ready_players.has(id): ready_players.erase(id)
	_broadcast_lobby_state()
	print("[DISCONNECT] ", id)


func _process(delta: float) -> void:
	if not multiplayer.is_server(): return
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
	_process_round(delta)
