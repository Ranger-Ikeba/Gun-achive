extends Control

@onready var hp_bar: ProgressBar = $HPPanel/HPBar
@onready var hp_label: Label = $HPPanel/HPLabel
@onready var ar_bar: ProgressBar = $ARPanel/ARBar
@onready var ar_label: Label = $ARPanel/ARLabel
@onready var respawn_box: Panel = $RespawnBox
@onready var respawn_label: Label = $RespawnBox/Label
@onready var respawn_btn: Button = $RespawnBox/Button
@onready var hurt_rect: ColorRect = $HurtRect
@onready var kill_feed: VBoxContainer = $KillFeed

var _hurt_alpha := 0.0


func _ready() -> void:
	respawn_box.visible = false
	hurt_rect.color = Color(0.8, 0.0, 0.0, 0.0)
	respawn_btn.pressed.connect(_on_respawn_pressed)
	_style_bars()
	set_hp(100)
	set_armor(50)
	set_process(true)


func _process(delta: float) -> void:
	if _hurt_alpha > 0.0:
		_hurt_alpha = max(0.0, _hurt_alpha - delta * 2.5)
		hurt_rect.color = Color(0.8, 0.0, 0.0, _hurt_alpha * 0.35)


func show_hurt() -> void:
	_hurt_alpha = 1.0


func add_kill_feed(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1, 1, 0.4))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	kill_feed.add_child(lbl)
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(lbl):
		lbl.queue_free()


func _style_bars() -> void:
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	hp_bg.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("background", hp_bg)
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.85, 0.15, 0.15, 1.0)
	hp_fill.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_label.add_theme_color_override("font_color", Color.WHITE)

	var ar_bg := StyleBoxFlat.new()
	ar_bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	ar_bg.set_corner_radius_all(4)
	ar_bar.add_theme_stylebox_override("background", ar_bg)
	var ar_fill := StyleBoxFlat.new()
	ar_fill.bg_color = Color(0.25, 0.55, 0.95, 1.0)
	ar_fill.set_corner_radius_all(4)
	ar_bar.add_theme_stylebox_override("fill", ar_fill)
	ar_label.add_theme_font_size_override("font_size", 12)
	ar_label.add_theme_color_override("font_color", Color.WHITE)


func set_hp(hp: int) -> void:
	var v: int = clamp(hp, 0, 100)
	hp_bar.value = v
	hp_label.text = "%d" % v


func set_armor(armor: int) -> void:
	var v: int = clamp(armor, 0, 50)
	ar_bar.value = v
	ar_label.text = "%d" % v


func show_respawn_immediate() -> void:
	respawn_box.visible = true
	respawn_label.text = "Возрождение..."
	respawn_btn.disabled = true


func show_respawn(t: float) -> void:
	respawn_box.visible = true
	if t > 0.05:
		respawn_label.text = "Возрождение через %0.1f" % t
		respawn_btn.disabled = true
	else:
		respawn_label.text = "Можно возродиться!"
		respawn_btn.disabled = false


func hide_respawn() -> void:
	respawn_box.visible = false


func _on_respawn_pressed() -> void:
	respawn_btn.disabled = true
	var my_id: int = multiplayer.get_unique_id()
	var world := get_tree().current_scene
	if not world:
		return
	var players_root: Node = world.get_node_or_null("Players")
	if not players_root:
		return
	var me: Node = players_root.get_node_or_null(str(my_id))
	if me and me.has_method("request_respawn_rpc"):
		me.request_respawn_rpc.rpc_id(1)
