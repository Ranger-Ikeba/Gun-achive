extends Control

@onready var status: Label = $Panel/VBox/Status
@onready var ip_field: LineEdit = $Panel/VBox/IPField
@onready var nick_field: LineEdit = $Panel/VBox/NickField

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	nick_field.text = "Player%d" % (randi() % 1000)

func _save_nick() -> void:
	var n: String = nick_field.text.strip_edges()
	if n == "":
		n = "Player"
	GameState.nick = n

func _on_host_pressed() -> void:
	_save_nick()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(9999, 8) != OK:
		status.text = "Ошибка сервера"
		return
	multiplayer.multiplayer_peer = peer
	status.text = "Хост. Ждём игроков..."
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_join_pressed() -> void:
	_save_nick()
	var ip := ip_field.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, 9999) != OK:
		status.text = "Ошибка клиента"
		return
	multiplayer.multiplayer_peer = peer
	status.text = "Подключение к %s..." % ip

func _on_connected() -> void:
	status.text = "Подключено!"
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_failed() -> void:
	status.text = "Не удалось подключиться"
