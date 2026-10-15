extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MAX_PLAYERS := 7
const BASE_RESPAWN := 4.0
const IMPACT_PARTICLES := preload("res://scenes/impact.tscn")

@onready var spawns_root: Node3D = $Spawns
@onready var players_root: Node3D = $Players
@onready var hud: Control = $HUD

var respawn_timers := {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_spawn_for_peer)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	for id in multiplayer.get_peers():
		_spawn_for_peer(id)
	_spawn_for_peer(multiplayer.get_unique_id())
	set_process(true)


func _on_server_disconnected() -> void:
	print("Сервер отключился, возвращаемся в лобби")
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for id in respawn_timers.keys():
		if respawn_timers[id] > 0.0:
			respawn_timers[id] -= delta
			var p: Node = players_root.get_node_or_null(str(id))
			if p and p.has_method("sync_respawn_timer"):
				if id == multiplayer.get_unique_id():
					p.sync_respawn_timer(id, respawn_timers[id])
				else:
					p.sync_respawn_timer.rpc_id(id, id, respawn_timers[id])


func _spawn_for_peer(id: int) -> void:
	if players_root.has_node(str(id)):
		return
	if players_root.get_child_count() >= MAX_PLAYERS:
		return
	var p: Node = PLAYER_SCENE.instantiate()
	p.name = str(id)
	p.set_multiplayer_authority(id)
	players_root.add_child(p)
	p.global_position = get_spawn_pos(id % MAX_PLAYERS)


func get_spawn_pos(idx: int) -> Vector3:
	var n: int = spawns_root.get_child_count()
	if n == 0:
		return Vector3(0, 1.5, 0)
	return spawns_root.get_child(idx % n).global_position


func update_hp(hp: int) -> void:
	hud.set_hp(hp)


func update_armor(armor: int) -> void:
	if hud.has_method("set_armor"):
		hud.set_armor(armor)


func update_respawn_timer(t: float) -> void:
	hud.show_respawn(t)


func hud_hide_respawn() -> void:
	hud.hide_respawn()


func on_local_death() -> void:
	hud.show_respawn_immediate()


func host_on_player_died(dead_id: int, killer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if killer_id != 0 and killer_id != dead_id:
		var killer: Node = players_root.get_node_or_null(str(killer_id))
		if killer:
			killer.kills += 1
	var prev: float = respawn_timers.get(dead_id, 0.0)
	var next_time: float
	if prev <= 0.0:
		next_time = BASE_RESPAWN
	else:
		next_time = min(prev + 1.0, 15.0)
	respawn_timers[dead_id] = next_time


@rpc("any_peer", "call_local", "reliable")
func request_respawn() -> void:
	if not multiplayer.is_server():
		return
	var my_id: int = multiplayer.get_unique_id()
	if respawn_timers.get(my_id, 0.0) > 0.0:
		return
	var p: Node = players_root.get_node_or_null(str(my_id))
	if p:
		var pos: Vector3 = get_spawn_pos(my_id % MAX_PLAYERS)
		p.apply_revive.rpc(pos)
	respawn_timers.erase(my_id)

func broadcast_impact(pos: Vector3, is_player: bool, dir: Vector3) -> void:
	rpc("show_impact", pos, is_player, dir)


@rpc("any_peer", "call_local", "reliable")
func show_impact(pos: Vector3, is_player: bool, dir: Vector3) -> void:
	var n := IMPACT_PARTICLES.instantiate()
	add_child(n)
	n.global_position = pos
	if is_player:
		n.configure_blood()
	else:
		n.configure_spark(dir)
	n.emitting = true
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(n):
		n.queue_free()


func show_hurt() -> void:
	if hud.has_method("show_hurt"):
		hud.show_hurt()


func add_kill_feed(text: String) -> void:
	if hud.has_method("add_kill_feed"):
		hud.add_kill_feed(text)

func server_handle_respawn(dead_id: int) -> void:
	if not multiplayer.is_server():
		return
	if respawn_timers.get(dead_id, 0.0) > 0.0:
		return
	var p: Node = players_root.get_node_or_null(str(dead_id))
	if p:
		var pos: Vector3 = get_spawn_pos(dead_id % MAX_PLAYERS)
		var my_server_id: int = multiplayer.get_unique_id()
		# шлём всем кроме себя
		for peer_id in multiplayer.get_peers():
			if peer_id == my_server_id:
				continue
			p.apply_revive.rpc_id(peer_id, pos)
		# локально у сервера
		p.apply_revive(pos)
	respawn_timers.erase(dead_id)
