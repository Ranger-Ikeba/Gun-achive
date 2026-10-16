extends Control

@onready var hp_panel: Panel = $HPPanel
@onready var hp_bar: ProgressBar = $HPPanel/HPBar
@onready var hp_label: Label = $HPPanel/HPLabel
@onready var ar_panel: Panel = $ARPanel
@onready var ar_bar: ProgressBar = $ARPanel/ARBar
@onready var ar_label: Label = $ARPanel/ARLabel
@onready var heat_panel: Panel = $HeatPanel
@onready var heat_bar: ProgressBar = $HeatPanel/HeatBar
@onready var heat_label: Label = $HeatPanel/HeatLabel
@onready var respawn_box: Panel = $RespawnBox
@onready var respawn_label: Label = $RespawnBox/Label
@onready var respawn_btn: Button = $RespawnBox/Button
@onready var change_class_btn: Button = $RespawnBox/ChangeClassBtn
@onready var hurt_rect: ColorRect = $HurtRect
@onready var kill_feed: VBoxContainer = $KillFeed
@onready var crosshair: Control = $Crosshair
@onready var weapon_icon: Panel = $WeaponIcon
@onready var weapon_icon_name: Label = $WeaponIcon/NameLabel
@onready var class_box: Panel = $ClassMenu
@onready var class_cards: HBoxContainer = $ClassMenu/Cards
@onready var class_confirm: Button = $ClassMenu/ConfirmBtn

var _hurt_alpha := 0.0
var _heat_style: StyleBoxFlat
var _selected_class := -1
var _is_dead_waiting := false
var _respawn_ready_at := 0.0
var _class_cards: Array[Button] = []

func _ready() -> void:
	class_box.visible = false
	respawn_box.visible = false
	hurt_rect.color = Color(0.8, 0.0, 0.0, 0.0)
	_set_hud_visible(false)
	if not respawn_btn.pressed.is_connected(_on_respawn_pressed):
		respawn_btn.pressed.connect(_on_respawn_pressed)
	if change_class_btn and not change_class_btn.pressed.is_connected(_on_change_class_pressed):
		change_class_btn.pressed.connect(_on_change_class_pressed)
	if not class_confirm.pressed.is_connected(_on_class_confirm):
		class_confirm.pressed.connect(_on_class_confirm)
	_style_bars()
	_build_class_cards()
	set_hp(100, 100)
	set_armor(50, 50)
	set_heat(0.0, 1.0, false)
	set_process(true)

func _set_hud_visible(v: bool) -> void:
	hp_panel.visible = v
	ar_panel.visible = v
	heat_panel.visible = v
	if crosshair:
		crosshair.visible = v
	if weapon_icon:
		weapon_icon.visible = v
	kill_feed.visible = v

func show_game_hud() -> void:
	_set_hud_visible(true)

func hide_game_hud() -> void:
	_set_hud_visible(false)

func _build_class_cards() -> void:
	_class_cards.clear()
	for child in class_cards.get_children():
		child.queue_free()
	await get_tree().process_frame
	var types: Array = ClassData.all_class_types()
	for i in range(types.size()):
		var t: int = types[i]
		var cd: Dictionary = ClassData.get_class_info(t)
		var card := Button.new()
		card.custom_minimum_size = Vector2(210, 320)
		card.text = ""
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.12, 0.12, 0.16, 0.95)
		normal.border_color = Color(0.4, 0.4, 0.5, 1.0)
		normal.set_border_width_all(2)
		normal.set_corner_radius_all(8)
		card.add_theme_stylebox_override("normal", normal)
		var hover := normal.duplicate()
		hover.bg_color = Color(0.2, 0.2, 0.28, 0.95)
		hover.border_color = Color(0.9, 0.9, 0.5, 1.0)
		card.add_theme_stylebox_override("hover", hover)
		var pressed := normal.duplicate()
		pressed.bg_color = Color(0.3, 0.3, 0.4, 0.95)
		pressed.border_color = Color(1.0, 1.0, 0.4, 1.0)
		card.add_theme_stylebox_override("pressed", pressed)
		var vbox := VBoxContainer.new()
		vbox.anchor_right = 1.0
		vbox.anchor_bottom = 1.0
		vbox.offset_left = 12
		vbox.offset_top = 12
		vbox.offset_right = -12
		vbox.offset_bottom = -12
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 8)
		card.add_child(vbox)
		var icon := ColorRect.new()
		icon.color = cd.color
		icon.custom_minimum_size = Vector2(0, 70)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon)
		var nlabel := Label.new()
		nlabel.text = cd.name
		nlabel.add_theme_font_size_override("font_size", 22)
		nlabel.add_theme_color_override("font_color", Color.WHITE)
		nlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nlabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(nlabel)
		var stats := Label.new()
		stats.text = "HP %d  |  AR %d\nСкорость x%.2f" % [int(cd.hp), int(cd.armor), float(cd.speed_mul)]
		stats.add_theme_font_size_override("font_size", 13)
		stats.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(stats)
		var dlabel := Label.new()
		dlabel.text = cd.desc
		dlabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dlabel.add_theme_font_size_override("font_size", 12)
		dlabel.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		dlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dlabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(dlabel)
		card.pressed.connect(_on_class_card_pressed.bind(i))
		class_cards.add_child(card)
		_class_cards.append(card)
	if _class_cards.size() > 0:
		_on_class_card_pressed(0)

func _process(delta: float) -> void:
	if _hurt_alpha > 0.0:
		_hurt_alpha = max(0.0, _hurt_alpha - delta * 2.5)
		hurt_rect.color = Color(0.8, 0.0, 0.0, _hurt_alpha * 0.35)
	_process_crosshair(delta)

func _on_class_card_pressed(idx: int) -> void:
	_selected_class = idx
	for i in range(_class_cards.size()):
		var card: Button = _class_cards[i]
		var normal: StyleBoxFlat = card.get_theme_stylebox("normal")
		if i == idx:
			normal.border_color = Color(1.0, 1.0, 0.2, 1.0)
			normal.set_border_width_all(4)
		else:
			normal.border_color = Color(0.4, 0.4, 0.5, 1.0)
			normal.set_border_width_all(2)

func _on_class_confirm() -> void:
	if _selected_class < 0:
		return
	GameState.chosen_class = _selected_class
	class_box.visible = false
	respawn_box.visible = false
	var my_id: int = multiplayer.get_unique_id()
	var world := get_tree().current_scene
	if not world:
		return
	var players_root: Node = world.get_node_or_null("Players")
	if not players_root:
		return
	var me: Node = players_root.get_node_or_null(str(my_id))
	if me and me.has_method("request_class_and_spawn_rpc"):
		me.request_class_and_spawn_rpc.rpc_id(1, _selected_class)
	else:
		await get_tree().create_timer(0.4).timeout
		me = players_root.get_node_or_null(str(my_id))
		if me and me.has_method("request_class_and_spawn_rpc"):
			me.request_class_and_spawn_rpc.rpc_id(1, _selected_class)

func show_class_menu() -> void:
	class_box.visible = true
	respawn_box.visible = false
	hide_game_hud()
	_selected_class = GameState.chosen_class
	if _class_cards.size() > 0:
		_on_class_card_pressed(_selected_class)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func hide_class_menu() -> void:
	class_box.visible = false

func show_hurt() -> void:
	_hurt_alpha = 1.0

func add_kill_feed(text: String) -> void:
	if not kill_feed.visible:
		return
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
	var heat_bg := StyleBoxFlat.new()
	heat_bg.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	heat_bg.set_corner_radius_all(3)
	heat_bar.add_theme_stylebox_override("background", heat_bg)
	_heat_style = StyleBoxFlat.new()
	_heat_style.bg_color = Color.WHITE
	_heat_style.set_corner_radius_all(3)
	heat_bar.add_theme_stylebox_override("fill", _heat_style)
	heat_label.add_theme_font_size_override("font_size", 11)
	heat_label.add_theme_color_override("font_color", Color.WHITE)

func set_hp(hp: int, hp_max: int) -> void:
	hp_bar.max_value = hp_max
	hp_bar.value = clamp(hp, 0, hp_max)
	hp_label.text = "%d / %d" % [hp, hp_max]

func set_armor(armor: int, armor_max: int) -> void:
	ar_bar.max_value = armor_max
	ar_bar.value = clamp(armor, 0, armor_max)
	ar_label.text = "%d / %d" % [armor, armor_max]

func set_heat(heat: float, max_heat: float, jammed: bool) -> void:
	var ratio: float = 0.0
	if max_heat > 0:
		ratio = clamp(heat / max_heat, 0.0, 1.0)
	heat_bar.max_value = 100.0
	heat_bar.value = ratio * 100.0
	if _heat_style:
		if jammed or ratio >= 1.0:
			_heat_style.bg_color = Color(1.0, 0.1, 0.1)
		elif ratio >= 0.8:
			_heat_style.bg_color = Color(1.0, 0.85, 0.2)
		else:
			_heat_style.bg_color = Color.WHITE
	if jammed:
		heat_label.text = "ПЕРЕГРЕВ"
	else:
		heat_label.text = ""

func set_weapon_name(w_name: String) -> void:
	if weapon_icon_name:
		weapon_icon_name.text = w_name
	var style: String = "cross"
	if w_name.find("Снайпер") >= 0 or w_name.find("снайпер") >= 0 or w_name.find("винтовка") >= 0:
		style = "sniper"
	elif w_name == "Дробовик" or w_name.find("Дробовик") >= 0:
		style = "wide"
	elif w_name.find("Пистолет") >= 0 or w_name.find("пистолет") >= 0:
		style = "dot"
	set_aim_style(style)

func show_respawn_immediate() -> void:
	respawn_box.visible = true
	respawn_label.text = "Возрождение..."
	respawn_btn.disabled = true
	change_class_btn.disabled = false

func show_respawn(t: float) -> void:
	respawn_box.visible = true
	change_class_btn.disabled = false
	_is_dead_waiting = true
	if t > 0.05:
		respawn_label.text = "Возрождение через %0.1f" % t
		respawn_btn.disabled = true
		_respawn_ready_at = Time.get_ticks_msec() / 1000.0 + t
	else:
		respawn_label.text = "Можно возродиться!"
		respawn_btn.disabled = false

func hide_respawn() -> void:
	respawn_box.visible = false
	_is_dead_waiting = false

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
	if me and me.has_method("request_class_and_spawn_rpc"):
		me.request_class_and_spawn_rpc.rpc_id(1, GameState.chosen_class)

func _on_change_class_pressed() -> void:
	show_class_menu()


var _cross_hit_flash := 0.0
var _cross_kill_flash := 0.0
var _cross_scale := 1.0
var _cross_target := false
var _cross_heat := false
var _aim_style: String = "cross"

func set_aim_style(style: String) -> void:
	_aim_style = style
	if not crosshair:
		return
	var lines: Array = []
	for child in crosshair.get_children():
		if child is ColorRect:
			lines.append(child)
	if lines.size() < 4:
		return
	var l1: ColorRect = lines[0]
	var l2: ColorRect = lines[1]
	var l3: ColorRect = lines[2]
	var l4: ColorRect = lines[3]
	match style:
		"cross":
			l1.offset_top = -12.0; l1.offset_bottom = -4.0; l1.offset_left = -1.0; l1.offset_right = 1.0
			l2.offset_top = 4.0; l2.offset_bottom = 12.0; l2.offset_left = -1.0; l2.offset_right = 1.0
			l3.offset_left = -12.0; l3.offset_right = -4.0; l3.offset_top = -1.0; l3.offset_bottom = 1.0
			l4.offset_left = 4.0; l4.offset_right = 12.0; l4.offset_top = -1.0; l4.offset_bottom = 1.0
		"wide":
			l1.offset_top = -28.0; l1.offset_bottom = -8.0; l1.offset_left = -1.5; l1.offset_right = 1.5
			l2.offset_top = 8.0; l2.offset_bottom = 28.0; l2.offset_left = -1.5; l2.offset_right = 1.5
			l3.offset_left = -28.0; l3.offset_right = -8.0; l3.offset_top = -1.5; l3.offset_bottom = 1.5
			l4.offset_left = 8.0; l4.offset_right = 28.0; l4.offset_top = -1.5; l4.offset_bottom = 1.5
		"dot":
			l1.offset_top = -2.0; l1.offset_bottom = 2.0; l1.offset_left = -10.0; l1.offset_right = -5.0
			l2.offset_top = -2.0; l2.offset_bottom = 2.0; l2.offset_left = 5.0; l2.offset_right = 10.0
			l3.offset_top = -10.0; l3.offset_bottom = -5.0; l3.offset_left = -2.0; l3.offset_right = 2.0
			l4.offset_top = 5.0; l4.offset_bottom = 10.0; l4.offset_left = -2.0; l4.offset_right = 2.0
		"sniper":
			l1.offset_top = -24.0; l1.offset_bottom = -8.0; l1.offset_left = -1.0; l1.offset_right = 1.0
			l2.offset_top = 8.0; l2.offset_bottom = 24.0; l2.offset_left = -1.0; l2.offset_right = 1.0
			l3.offset_left = -24.0; l3.offset_right = -8.0; l3.offset_top = -1.0; l3.offset_bottom = 1.0
			l4.offset_left = 8.0; l4.offset_right = 24.0; l4.offset_top = -1.0; l4.offset_bottom = 1.0
	_update_cross_color()

func update_crosshair(target_in_sight: bool, overheated: bool) -> void:
	_cross_target = target_in_sight
	_cross_heat = overheated
	_update_cross_color()

func crosshair_hit_flash() -> void:
	_cross_hit_flash = 0.2

func crosshair_kill_flash() -> void:
	_cross_kill_flash = 0.5

func _process_crosshair(delta: float) -> void:
	if _cross_hit_flash > 0.0:
		_cross_hit_flash = max(0.0, _cross_hit_flash - delta)
	if _cross_kill_flash > 0.0:
		_cross_kill_flash = max(0.0, _cross_kill_flash - delta)
	if _cross_kill_flash > 0.0:
		var t: float = 1.0 - _cross_kill_flash / 0.5
		_cross_scale = 1.0 + sin(t * PI) * 1.2
	else:
		_cross_scale = 1.0
	_update_cross_color()

func _update_cross_color() -> void:
	if not crosshair:
		return
	var base: Color = Color(1, 1, 1, 0.9)
	if _cross_heat:
		base = Color(1, 0.15, 0.15, 0.95)
	elif _cross_target:
		base = Color(0.3, 1.0, 0.3, 0.95)
	if _cross_kill_flash > 0.0:
		base = Color(1, 0.05, 0.05, 1.0)
	elif _cross_hit_flash > 0.0:
		var amt: float = _cross_hit_flash / 0.2
		base = base.lerp(Color(1, 0.4, 0.4, 1.0), amt * 0.5)
	for child in crosshair.get_children():
		if child is ColorRect:
			child.color = base
	crosshair.scale = Vector2(_cross_scale, _cross_scale)
