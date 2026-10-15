"""
v23 — фикс: server_handle_respawn получает правильный dead_id через
get_remote_sender_id().
"""
import os, re

PROJECT = r"C:/Users/maksi/OneDrive/Документы/gun-achive"

# --- player.gd: request_respawn_rpc передаёт id отправителя ---
p = os.path.join(PROJECT, "scripts", "player.gd")
with open(p, encoding="utf-8") as f:
    src = f.read()

new_fn = '''@rpc("any_peer", "call_local", "reliable")
func request_respawn_rpc() -> void:
	if not multiplayer.is_server():
		return
	var caller_id: int = multiplayer.get_remote_sender_id()
	if caller_id == 0:
		caller_id = multiplayer.get_unique_id()
	var world: Node = get_tree().current_scene
	if world and world.has_method("server_handle_respawn"):
		world.server_handle_respawn(caller_id)
'''
pat = re.compile(
    r'@rpc\("any_peer", "call_local", "reliable"\)\nfunc request_respawn_rpc\(\) -> void:\n(?:.*\n)+?(?=@rpc|func |\Z)',
    re.M
)
if pat.search(src):
    src = pat.sub(new_fn + "\n", src, count=1)
    print("patched request_respawn_rpc")
else:
    src = src.rstrip() + "\n\n" + new_fn
    print("added request_respawn_rpc")

with open(p, "w", encoding="utf-8") as f:
    f.write(src)

# --- Убедимся что get_remote_sender_id не мешает call_local ---
# (при call_local на хосте get_remote_sender_id = 0, обрабатываем)

# --- world.gd: server_handle_respawn работает с любым dead_id ---
p = os.path.join(PROJECT, "scripts", "world.gd")
with open(p, encoding="utf-8") as f:
    src = f.read()

new_fn = '''func server_handle_respawn(dead_id: int) -> void:
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
'''
pat = re.compile(
    r'func server_handle_respawn\(dead_id: int\) -> void:\n(?:.*\n)+?(?=@rpc|func |\Z)',
    re.M
)
if pat.search(src):
    src = pat.sub(new_fn + "\n", src, count=1)
    print("patched server_handle_respawn")
else:
    src = src.rstrip() + "\n\n" + new_fn
    print("added server_handle_respawn")

with open(p, "w", encoding="utf-8") as f:
    f.write(src)

print("\n=== v23 готово ===")
print("В Godot: Ctrl+Shift+R → F5")
