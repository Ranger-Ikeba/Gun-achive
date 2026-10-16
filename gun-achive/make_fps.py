"""
fix_heat_per_weapon.py — heat сохраняется per-weapon.
"""
import os

PROJECT = r"C:/Users/maksi/OneDrive/Документы/gun-achive"
p = os.path.join(PROJECT, "scripts", "weapon_manager.gd")

with open(p, encoding="utf-8") as f:
    src = f.read()

# Заменяем weapon_manager.gd целиком
NEW = '''extends Node
class_name WeaponManager

signal heat_changed(heat: float, max_heat: float, jammed: bool)
signal weapon_changed(w_type: int, w_data: Dictionary)
signal jam_state_changed(jammed: bool)

var current_type: int = WeaponData.Type.RIFLE
var current_data: Dictionary = {}
var heat: float = 0.0
var jammed: bool = false
var jam_timer: float = 0.0
var post_jam_cooling: bool = false
var reloading: bool = false
var _fire_cooldown: float = 0.0

# Heat per weapon
var _heat_by_weapon: Dictionary = {}      # тип -> текущий heat
var _jammed_by_weapon: Dictionary = {}    # тип -> bool
var _jam_timer_by_weapon: Dictionary = {} # тип -> остаток клина

const JAM_DURATION := 3.0
const POST_JAM_COOL_RATE := 25.0

func _ready() -> void:
	set_process(true)

func _ensure_weapon_state(t: int) -> void:
	if not _heat_by_weapon.has(t):
		_heat_by_weapon[t] = 0.0
	if not _jammed_by_weapon.has(t):
		_jammed_by_weapon[t] = false
	if not _jam_timer_by_weapon.has(t):
		_jam_timer_by_weapon[t] = 0.0

func _load_state(t: int) -> void:
	_ensure_weapon_state(t)
	heat = _heat_by_weapon[t]
	jammed = _jammed_by_weapon[t]
	jam_timer = _jam_timer_by_weapon[t]

func _save_state() -> void:
	_heat_by_weapon[current_type] = heat
	_jammed_by_weapon[current_type] = jammed
	_jam_timer_by_weapon[current_type] = jam_timer

func set_weapon(t: int) -> void:
	# Сохраняем состояние старого оружия
	if current_data.size() > 0:
		_save_state()
	# Загружаем новое
	current_type = t
	current_data = WeaponData.get_weapon(t)
	_ensure_weapon_state(t)
	_load_state(t)
	reloading = false
	post_jam_cooling = false
	_fire_cooldown = 0.0
	emit_signal("weapon_changed", current_type, current_data)
	_emit_heat()

func can_fire() -> bool:
	return not jammed and not reloading and not post_jam_cooling and _fire_cooldown <= 0.0 and heat < current_data.heat_to_jam

func try_fire() -> Dictionary:
	if not can_fire():
		return {}
	var shot: Dictionary = current_data.duplicate()
	heat += 1.0
	_fire_cooldown = current_data.fire_delay
	if heat >= current_data.heat_to_jam:
		_start_jam()
	_save_state()
	_emit_heat()
	return shot

func start_reload() -> void:
	if jammed or reloading or post_jam_cooling or heat <= 0.0:
		return
	reloading = true

func _start_jam() -> void:
	jammed = true
	jam_timer = JAM_DURATION
	heat = current_data.heat_to_jam
	post_jam_cooling = false
	_save_state()
	emit_signal("jam_state_changed", true)

func _process(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	if jammed:
		jam_timer -= delta
		if jam_timer <= 0.0:
			jammed = false
			post_jam_cooling = true
			emit_signal("jam_state_changed", false)
		_save_state()
		return
	if post_jam_cooling:
		heat -= POST_JAM_COOL_RATE * delta
		if heat <= 0.0:
			heat = 0.0
			post_jam_cooling = false
		_save_state()
		_emit_heat()
	elif reloading:
		heat -= current_data.cooldown_rate * delta
		if heat <= 0.0:
			heat = 0.0
			reloading = false
		_save_state()
		_emit_heat()

func get_heat_ratio() -> float:
	if current_data.heat_to_jam <= 0:
		return 0.0
	return clamp(heat / float(current_data.heat_to_jam), 0.0, 1.0)

func _emit_heat() -> void:
	emit_signal("heat_changed", heat, float(current_data.heat_to_jam), jammed)
'''

with open(p, "w", encoding="utf-8") as f:
    f.write(NEW)
print("wrote weapon_manager.gd")

# Проверка
print()
for fn in ["set_weapon", "_load_state", "_save_state", "_ensure_weapon_state",
           "try_fire", "_process", "start_reload", "_start_jam"]:
    print(f"  func {fn}: {NEW.count(f'func {fn}')}")

print()
print("=== fix_heat_per_weapon готово ===")
print("В Godot: Ctrl+Shift+R → F5")
print()
print("Теперь:")
print("  Каждое оружие хранит свой heat")
print("  Переключился с автомата (heat 50) на ПП — heat 0")
print("  Обратно на автомат — heat всё ещё 50")
print("  Клин per-weapon тоже")
