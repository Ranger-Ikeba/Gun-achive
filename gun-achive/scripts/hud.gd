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
var _class_cards: Array[Button] = []
var _cross_hit_flash := 0.0
var _cross_kill_flash := 0.0
var _cross_scale := 1.0
var _cross_target := false
var _cross_heat := false
var _aim_style: String = "cross"
var _last_results: Array = []
var _last_winner_id: int = 0
var _last_by_time: bool = false


func _ready() -> void:
	if class_box: class_box.visible = false
	if respawn_box: respawn_box.visible = false
	if hurt_rect: hurt_rect.color = Color(0, 0, 0, 0)
	hide_all_ui()
	if respawn_btn and not respawn_btn.pressed.is_connected(_on_respawn_pressed):
		respawn_btn.pressed.connect(_on_respawn_pressed)
	if change_class_btn and not change_class_btn.pressed.is_connected(_on_change_class_pressed):
		change_class_btn.pressed.connect(_on_change_class_pressed)
	if class_confirm and not class_confirm.pressed.is_connected(_on_class_confirm):
		class_confirm.pressed.connect(_on_class_confirm)
	_style_bars()
	_build_class_cards()
	set_hp(100, 100)
	set_armor(50, 50)
	set_heat(0.0, 1.0, false)
	set_process(true)


func _process(delta: float) -> void:
	if _hurt_alpha > 0.0:
		_hurt_alpha = max(0.0, _hurt_alpha - delta * 2.5)
		if hurt_rect: hurt_rect.color = Color(0.8, 0, 0, _hurt_alpha * 0.35)
	_process_crosshair(delta)


# ============ СКРЫТИЕ ============
func hide_all_ui() -> void:
	if class_box: class_box.visible = false
	if respawn_box: respawn_box.visible = false
	if has_node("ModeMenu"): get_node("ModeMenu").visible = false
	if has_node("LobbyMenu"): get_node("LobbyMenu").visible = false
	if has_node("DefeatBox"): get_node("DefeatBox").visible = false
	if has_node("VictoryBox"): get_node("VictoryBox").visible = false
	if has_node("ResultsBox"): get_node("ResultsBox").visible = false
	if has_node("GrayOverlay"): get_node("GrayOverlay").visible = false
	if has_node("InfoPanel"): get_node("InfoPanel").visible = false
	if hurt_rect: hurt_rect.color = Color(0, 0, 0, 0)
	_set_hud_visible(false)

func _set_hud_visible(v: bool) -> void:
	if hp_panel: hp_panel.visible = v
	if ar_panel: ar_panel.visible = v
	if heat_panel: heat_panel.visible = v
	if crosshair: crosshair.visible = v
	if weapon_icon: weapon_icon.visible = v
	if kill_feed: kill_feed.visible = v
	if has_node("InfoPanel"): get_node("InfoPanel").visible = v

func show_game_hud() -> void:
	_set_hud_visible(true)

func hide_game_hud() -> void:
	_set_hud_visible(false)


# ============ МЕНЮ РЕЖИМА ============
func show_mode_menu() -> void:
	hide_all_ui()
	if has_node("ModeMenu"): get_node("ModeMenu").visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_mode_cards()

func hide_mode_menu() -> void:
	if has_node("ModeMenu"): get_node("ModeMenu").visible = false

func _build_mode_cards() -> void:
	if not has_node("ModeMenu/Cards"): return
	var cards: HBoxContainer = get_node("ModeMenu/Cards")
	for c in cards.get_children(): c.queue_free()
	var modes := [
		{"name": "Быстрый раунд", "desc": "Последний выживший побеждает", "id": 0},
		{"name": "По очкам", "desc": "Скоро...", "id": 1}
	]
	for m in modes:
		var card := Button.new()
		card.custom_minimum_size = Vector2(260, 280)
		card.text = ""
		card.focus_mode = Control.FOCUS_NONE
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
		card.add_theme_stylebox_override("pressed", hover)
		var vbox := VBoxContainer.new()
		vbox.anchor_right = 1.0
		vbox.anchor_bottom = 1.0
		vbox.offset_left = 12
		vbox.offset_top = 12
		vbox.offset_right = -12
		vbox.offset_bottom = -12
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 10)
		card.add_child(vbox)
		var nl := Label.new()
		nl.text = m["name"]
		nl.add_theme_font_size_override("font_size", 26)
		nl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(nl)
		var dl := Label.new()
		dl.text = m["desc"]
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.add_theme_font_size_override("font_size", 14)
		dl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8, 1))
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(dl)
		card.pressed.connect(_on_mode_chosen.bind(m["id"]))
		cards.add_child(card)

func _on_mode_chosen(mode_id: int) -> void:
	GameState.chosen_mode = mode_id
	var world := get_tree().current_scene
	if world and world.has_method("server_set_mode"):
		world.rpc_id(1, "server_set_mode", mode_id)
	show_class_menu()


# ============ МЕНЮ КЛАССА ============
func show_class_menu() -> void:
	hide_all_ui()
	if class_box: class_box.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _class_cards.size() > 0:
		_on_class_card_pressed(GameState.chosen_class)

func hide_class_menu() -> void:
	if class_box: class_box.visible = false

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
		card.add_theme_stylebox_override("pressed", hover)
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
		var nl := Label.new()
		nl.text = cd.name
		nl.add_theme_font_size_override("font_size", 22)
		nl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(nl)
		var st := Label.new()
		st.text = "HP %d  |  AR %d" % [int(cd.hp), int(cd.armor)]
		st.add_theme_font_size_override("font_size", 13)
		st.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(st)
		var dl := Label.new()
		dl.text = cd.desc
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.add_theme_font_size_override("font_size", 12)
		dl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1))
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(dl)
		card.pressed.connect(_on_class_card_pressed.bind(i))
		class_cards.add_child(card)
		_class_cards.append(card)
	if _class_cards.size() > 0:
		_on_class_card_pressed(0)

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
	if _selected_class < 0: return
	GameState.chosen_class = _selected_class
	var my_id: int = multiplayer.get_unique_id()
	var world := get_tree().current_scene
	if not world: return
	var players_root: Node = world.get_node_or_null("Players")
	if not players_root: return
	var me: Node = players_root.get_node_or_null(str(my_id))
	if me and me.has_method("request_class_and_spawn_rpc"):
		me.request_class_and_spawn_rpc.rpc_id(1, _selected_class)
	if world.has_method("show_lobby_menu"):
		world.show_lobby_menu()


# ============ ЛОББИ ============
func show_lobby_menu() -> void:
	hide_all_ui()
	if has_node("LobbyMenu"): get_node("LobbyMenu").visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var mode_name: String = "Быстрый раунд" if GameState.chosen_mode == 0 else "По очкам"
	if has_node("LobbyMenu/ModeLabel"):
		get_node("LobbyMenu/ModeLabel").text = "Режим: " + mode_name
	if has_node("LobbyMenu/StartBtn"):
		var sb = get_node("LobbyMenu/StartBtn")
		sb.visible = multiplayer.is_server()
		if not sb.pressed.is_connected(_on_lobby_start):
			sb.pressed.connect(_on_lobby_start)
	if has_node("LobbyMenu/BackBtn"):
		var bb = get_node("LobbyMenu/BackBtn")
		if not bb.pressed.is_connected(_on_lobby_back):
			bb.pressed.connect(_on_lobby_back)

func hide_lobby_menu() -> void:
	if has_node("LobbyMenu"): get_node("LobbyMenu").visible = false

func update_lobby_list(players_info: Array) -> void:
	if not has_node("LobbyMenu/List"): return
	var lst: VBoxContainer = get_node("LobbyMenu/List")
	for c in lst.get_children(): c.queue_free()
	for p in players_info:
		var lbl := Label.new()
		lbl.text = "%s — %s" % [p.get("nick", "?"), "Готов" if p.get("ready", false) else "Выбирает"]
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(0.9, 1, 0.9, 1) if p.get("ready", false) else Color(0.7, 0.7, 0.7, 1))
		lst.add_child(lbl)

func _on_lobby_start() -> void:
	if not multiplayer.is_server(): return
	var world := get_tree().current_scene
	if not world: return
	if world.has_method("server_start_round"):
		world.server_start_round()

func _on_lobby_back() -> void:
	var my_id: int = multiplayer.get_unique_id()
	var world := get_tree().current_scene
	if world and world.has_method("server_player_not_ready"):
		world.rpc_id(1, "server_player_not_ready", my_id)
	show_class_menu()


# ============ ОЧКИ / ЖИВЫЕ / ВРЕМЯ ============
func update_score(score: int) -> void:
	if has_node("InfoPanel/ScoreLabel"):
		get_node("InfoPanel/ScoreLabel").text = "Очки: %d" % score

func update_alive_count(count: int) -> void:
	if has_node("InfoPanel/AliveLabel"):
		get_node("InfoPanel/AliveLabel").text = "Живых: %d" % count

func update_timer(t: float) -> void:
	if has_node("InfoPanel/TimerLabel"):
		var m: int = int(t) / 60
		var s: int = int(t) % 60
		get_node("InfoPanel/TimerLabel").text = "%d:%02d" % [m, s]


# ============ ОВЕРЛЕИ ============
func show_defeat(score: int) -> void:
	hide_all_ui()
	if has_node("GrayOverlay"): get_node("GrayOverlay").visible = true
	if has_node("DefeatBox"): get_node("DefeatBox").visible = true
	if has_node("DefeatBox/ScoreLabel"): get_node("DefeatBox/ScoreLabel").text = "Очки: %d" % score
	if has_node("DefeatBox/ExitBtn"):
		var b = get_node("DefeatBox/ExitBtn")
		if not b.pressed.is_connected(_on_defeat_exit):
			b.pressed.connect(_on_defeat_exit)
	if has_node("DefeatBox/ResultsBtn"):
		var rb = get_node("DefeatBox/ResultsBtn")
		if not rb.pressed.is_connected(_on_show_results):
			rb.pressed.connect(_on_show_results)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func show_victory(score: int) -> void:
	hide_all_ui()
	if has_node("GrayOverlay"): get_node("GrayOverlay").visible = true
	if has_node("VictoryBox"): get_node("VictoryBox").visible = true
	if has_node("VictoryBox/ScoreLabel"): get_node("VictoryBox/ScoreLabel").text = "Очки: %d" % score
	if has_node("VictoryBox/ExitBtn"):
		var b = get_node("VictoryBox/ExitBtn")
		if not b.pressed.is_connected(_on_victory_exit):
			b.pressed.connect(_on_victory_exit)
	if has_node("VictoryBox/ResultsBtn"):
		var rb = get_node("VictoryBox/ResultsBtn")
		if not rb.pressed.is_connected(_on_show_results):
			rb.pressed.connect(_on_show_results)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func show_results(results: Array, winner_id: int, by_time: bool) -> void:
	_last_results = results
	_last_winner_id = winner_id
	_last_by_time = by_time
	hide_all_ui()
	if has_node("GrayOverlay"): get_node("GrayOverlay").visible = true
	if has_node("ResultsBox"): get_node("ResultsBox").visible = true
	if has_node("ResultsBox/Title"):
		get_node("ResultsBox/Title").text = "ИТОГИ РАУНДА" if not by_time else "ВРЕМЯ ВЫШЛО"
	if has_node("ResultsBox/List"):
		var lst = get_node("ResultsBox/List")
		for c in lst.get_children(): c.queue_free()
		var my_id: int = multiplayer.get_unique_id()
		for i in range(results.size()):
			var r: Dictionary = results[i]
			var lbl := Label.new()
			var mark: String = ""
			if i == 0: mark = "🏆  "
			elif r.get("id", 0) == my_id: mark = "▶  "
			lbl.text = "%s%d.  %s  —  %d" % [mark, i+1, r.get("nick", "?"), r.get("score", 0)]
			lbl.add_theme_font_size_override("font_size", 22)
			lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.4, 1) if i == 0 else Color(1, 1, 1, 1))
			lst.add_child(lbl)
	if has_node("ResultsBox/ExitBtn"):
		var b = get_node("ResultsBox/ExitBtn")
		if not b.pressed.is_connected(_on_results_exit):
			b.pressed.connect(_on_results_exit)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_defeat_exit() -> void:
	hide_all_ui()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_victory_exit() -> void:
	hide_all_ui()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_results_exit() -> void:
	hide_all_ui()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ============ HP / AR / HEAT ============
func set_hp(hp: int, hp_max: int) -> void:
	if hp_bar: hp_bar.max_value = hp_max
	if hp_bar: hp_bar.value = clamp(hp, 0, hp_max)
	if hp_label: hp_label.text = "%d / %d" % [hp, hp_max]

func set_armor(armor: int, armor_max: int) -> void:
	if ar_bar: ar_bar.max_value = armor_max
	if ar_bar: ar_bar.value = clamp(armor, 0, armor_max)
	if ar_label: ar_label.text = "%d / %d" % [armor, armor_max]

func set_heat(heat: float, max_heat: float, jammed: bool) -> void:
	var ratio: float = 0.0
	if max_heat > 0: ratio = clamp(heat / max_heat, 0.0, 1.0)
	if heat_bar:
		heat_bar.max_value = 100.0
		heat_bar.value = ratio * 100.0
	if _heat_style:
		if jammed or ratio >= 1.0: _heat_style.bg_color = Color(1.0, 0.1, 0.1, 1)
		elif ratio >= 0.8: _heat_style.bg_color = Color(1.0, 0.85, 0.2, 1)
		else: _heat_style.bg_color = Color(1, 1, 1, 1)
	if heat_label: heat_label.text = "ПЕРЕГРЕВ" if jammed else ""

func set_weapon_name(w_name: String) -> void:
	if weapon_icon_name: weapon_icon_name.text = w_name
	var style: String = "cross"
	if w_name.find("Снайпер") >= 0 or w_name.find("винтовка") >= 0: style = "sniper"
	elif w_name.find("Дробовик") >= 0: style = "wide"
	elif w_name.find("Пистолет") >= 0: style = "dot"
	set_aim_style(style)


# ============ ПРИЦЕЛ ============
func set_aim_style(style: String) -> void:
	_aim_style = style
	if not crosshair: return
	var lines: Array = []
	for child in crosshair.get_children():
		if child is ColorRect: lines.append(child)
	if lines.size() < 4: return
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
			l1.offset_top = -28.0; l1.offset_bottom = -8.0
			l2.offset_top = 8.0; l2.offset_bottom = 28.0
			l3.offset_left = -28.0; l3.offset_right = -8.0
			l4.offset_left = 8.0; l4.offset_right = 28.0
		"dot":
			l1.offset_top = -2.0; l1.offset_bottom = 2.0; l1.offset_left = -10.0; l1.offset_right = -5.0
			l2.offset_top = -2.0; l2.offset_bottom = 2.0; l2.offset_left = 5.0; l2.offset_right = 10.0
			l3.offset_top = -10.0; l3.offset_bottom = -5.0; l3.offset_left = -2.0; l3.offset_right = 2.0
			l4.offset_top = 5.0; l4.offset_bottom = 10.0; l4.offset_left = -2.0; l4.offset_right = 2.0
		"sniper":
			l1.offset_top = -24.0; l1.offset_bottom = -8.0
			l2.offset_top = 8.0; l2.offset_bottom = 24.0
			l3.offset_left = -24.0; l3.offset_right = -8.0
			l4.offset_left = 8.0; l4.offset_right = 24.0
	_update_cross_color()

func update_crosshair(target_in_sight: bool, overheated: bool) -> void:
	_cross_target = target_in_sight
	_cross_heat = overheated
	_update_cross_color()

func crosshair_hit_flash() -> void: _cross_hit_flash = 0.2
func crosshair_kill_flash() -> void: _cross_kill_flash = 0.5

func _process_crosshair(delta: float) -> void:
	if _cross_hit_flash > 0.0: _cross_hit_flash = max(0.0, _cross_hit_flash - delta)
	if _cross_kill_flash > 0.0: _cross_kill_flash = max(0.0, _cross_kill_flash - delta)
	if _cross_kill_flash > 0.0:
		var t: float = 1.0 - _cross_kill_flash / 0.5
		_cross_scale = 1.0 + sin(t * PI) * 1.2
	else:
		_cross_scale = 1.0
	_update_cross_color()

func _update_cross_color() -> void:
	if not crosshair: return
	var base: Color = Color(1, 1, 1, 0.9)
	if _cross_heat: base = Color(1, 0.15, 0.15, 0.95)
	elif _cross_target: base = Color(0.3, 1.0, 0.3, 0.95)
	if _cross_kill_flash > 0.0: base = Color(1, 0.05, 0.05, 1.0)
	elif _cross_hit_flash > 0.0:
		var amt: float = _cross_hit_flash / 0.2
		base = base.lerp(Color(1, 0.4, 0.4, 1.0), amt * 0.5)
	for child in crosshair.get_children():
		if child is ColorRect: child.color = base
	crosshair.scale = Vector2(_cross_scale, _cross_scale)


# ============ РЕСПАВН ============
func show_respawn_immediate() -> void:
	if respawn_box: respawn_box.visible = true
	if respawn_label: respawn_label.text = "Возрождение..."
	if respawn_btn: respawn_btn.disabled = true
	if change_class_btn: change_class_btn.disabled = false

func show_respawn(t: float) -> void:
	if respawn_box: respawn_box.visible = true
	if change_class_btn: change_class_btn.disabled = false
	if t > 0.05:
		if respawn_label: respawn_label.text = "Возрождение через %0.1f" % t
		if respawn_btn: respawn_btn.disabled = true
	else:
		if respawn_label: respawn_label.text = "Можно возродиться!"
		if respawn_btn: respawn_btn.disabled = false

func hide_respawn() -> void:
	if respawn_box: respawn_box.visible = false

func _on_respawn_pressed() -> void:
	if respawn_btn: respawn_btn.disabled = true
	var my_id: int = multiplayer.get_unique_id()
	var world := get_tree().current_scene
	if not world: return
	var players_root: Node = world.get_node_or_null("Players")
	if not players_root: return
	var me: Node = players_root.get_node_or_null(str(my_id))
	if me and me.has_method("request_class_and_spawn_rpc"):
		me.request_class_and_spawn_rpc.rpc_id(1, GameState.chosen_class)

func _on_change_class_pressed() -> void:
	show_class_menu()


# ============ ПРОЧЕЕ ============
func show_hurt() -> void:
	_hurt_alpha = 1.0

func add_kill_feed(text: String) -> void:
	if not kill_feed or not kill_feed.visible: return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1, 1, 0.4, 1))
	kill_feed.add_child(lbl)
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(lbl): lbl.queue_free()

func _style_bars() -> void:
	if hp_bar:
		var hp_bg := StyleBoxFlat.new()
		hp_bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
		hp_bg.set_corner_radius_all(4)
		hp_bar.add_theme_stylebox_override("background", hp_bg)
		var hp_fill := StyleBoxFlat.new()
		hp_fill.bg_color = Color(0.85, 0.15, 0.15, 1.0)
		hp_fill.set_corner_radius_all(4)
		hp_bar.add_theme_stylebox_override("fill", hp_fill)
	if hp_label:
		hp_label.add_theme_font_size_override("font_size", 14)
		hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	if ar_bar:
		var ar_bg := StyleBoxFlat.new()
		ar_bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
		ar_bg.set_corner_radius_all(4)
		ar_bar.add_theme_stylebox_override("background", ar_bg)
		var ar_fill := StyleBoxFlat.new()
		ar_fill.bg_color = Color(0.25, 0.55, 0.95, 1.0)
		ar_fill.set_corner_radius_all(4)
		ar_bar.add_theme_stylebox_override("fill", ar_fill)
	if ar_label:
		ar_label.add_theme_font_size_override("font_size", 12)
		ar_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	if heat_bar:
		var hb := StyleBoxFlat.new()
		hb.bg_color = Color(0.08, 0.08, 0.08, 0.85)
		hb.set_corner_radius_all(3)
		heat_bar.add_theme_stylebox_override("background", hb)
		_heat_style = StyleBoxFlat.new()
		_heat_style.bg_color = Color(1, 1, 1, 1)
		_heat_style.set_corner_radius_all(3)
		heat_bar.add_theme_stylebox_override("fill", _heat_style)
	if heat_label:
		heat_label.add_theme_font_size_override("font_size", 11)
		heat_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))

func _on_show_results() -> void:
	# Запрашиваем актуальные результаты у сервера
	var world := get_tree().current_scene
	if world and world.has_method("client_request_results"):
		world.rpc_id(1, "client_request_results")

func show_current_results(results: Array) -> void:
	# Показываем полученные с сервера
	_last_results = results
	hide_all_ui()
	if has_node("GrayOverlay"): get_node("GrayOverlay").visible = true
	if has_node("ResultsBox"): get_node("ResultsBox").visible = true
	if has_node("ResultsBox/Title"):
		get_node("ResultsBox/Title").text = "ТЕКУЩИЕ РЕЗУЛЬТАТЫ"
	if has_node("ResultsBox/List"):
		var lst = get_node("ResultsBox/List")
		for c in lst.get_children(): c.queue_free()
		var my_id: int = multiplayer.get_unique_id()
		for i in range(results.size()):
			var r: Dictionary = results[i]
			var lbl := Label.new()
			var mark: String = ""
			if i == 0: mark = "🏆  "
			elif r.get("id", 0) == my_id: mark = "▶  "
			lbl.text = "%s%d.  %s  —  %d" % [mark, i+1, r.get("nick", "?"), r.get("score", 0)]
			lbl.add_theme_font_size_override("font_size", 22)
			lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.4, 1) if i == 0 else Color(1, 1, 1, 1))
			lst.add_child(lbl)
	if has_node("ResultsBox/ExitBtn"):
		var b = get_node("ResultsBox/ExitBtn")
		if not b.pressed.is_connected(_on_results_exit):
			b.pressed.connect(_on_results_exit)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
