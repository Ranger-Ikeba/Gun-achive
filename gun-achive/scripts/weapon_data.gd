extends Node
class_name WeaponData

enum Type {
	# Штурмовик
	RIFLE, CARBINE, SMG,
	# Снайпер
	SNIPER, SEMI_SNIPER, HEAVY_SNIPER,
	# Тяжёлый
	SHOTGUN, LMG, HANDCANNON,
	# Разведчик
	PISTOL, DUAL_PISTOLS, LIGHT_SMG
}

const WEAPONS := {
	# ====== ШТУРМОВИК ======
	Type.RIFLE: {
		"name": "Автомат",
		"fire_mode": "auto",
		"damage": 8,
		"bullets_per_shot": 1,
		"spread_deg": 2.0,
		"bullet_speed": 60.0,
		"fire_delay": 0.10,
		"heat_to_jam": 75,
		"cooldown_rate": 22.0,
		"recoil": 0.008,
		"recoil_return": 8.0,
		"zoom_fov": 35.0,
		"model": "res://models/weapon_rifle.obj",
		"sound_kind": "rifle",
		"bullet_color": Color(1.0, 0.9, 0.4),
		"bullet_size": 0.025,
		"bullet_length": 0.18
	},
	Type.CARBINE: {
		"name": "Карабин",
		"fire_mode": "auto",
		"damage": 15,
		"bullets_per_shot": 1,
		"spread_deg": 0.8,
		"bullet_speed": 80.0,
		"fire_delay": 0.22,
		"heat_to_jam": 45,
		"cooldown_rate": 18.0,
		"recoil": 0.018,
		"recoil_return": 7.0,
		"zoom_fov": 30.0,
		"model": "res://models/weapon_carbine.obj",
		"sound_kind": "rifle",
		"bullet_color": Color(1.0, 0.95, 0.5),
		"bullet_size": 0.022,
		"bullet_length": 0.20
	},
	Type.SMG: {
		"name": "ПП",
		"fire_mode": "auto",
		"damage": 6,
		"bullets_per_shot": 1,
		"spread_deg": 3.5,
		"bullet_speed": 55.0,
		"fire_delay": 0.06,
		"heat_to_jam": 100,
		"cooldown_rate": 30.0,
		"recoil": 0.005,
		"recoil_return": 10.0,
		"zoom_fov": 45.0,
		"model": "res://models/weapon_smg.obj",
		"sound_kind": "pistol",
		"bullet_color": Color(1.0, 0.85, 0.3),
		"bullet_size": 0.02,
		"bullet_length": 0.15
	},
	# ====== СНАЙПЕР ======
	Type.SNIPER: {
		"name": "Снайперская винтовка",
		"fire_mode": "semi",
		"damage": 80,
		"bullets_per_shot": 1,
		"spread_deg": 0.0,
		"bullet_speed": 100.0,
		"fire_delay": 1.0,
		"heat_to_jam": 15,
		"cooldown_rate": 5.0,
		"recoil": 0.08,
		"recoil_return": 6.0,
		"zoom_fov": 8.0,
		"model": "res://models/weapon_sniper.obj",
		"sound_kind": "sniper",
		"bullet_color": Color(0.5, 0.9, 1.0),
		"bullet_size": 0.04,
		"bullet_length": 0.30
	},
	Type.SEMI_SNIPER: {
		"name": "Полуавтомат. снайперская",
		"fire_mode": "semi",
		"damage": 50,
		"bullets_per_shot": 1,
		"spread_deg": 0.5,
		"bullet_speed": 90.0,
		"fire_delay": 0.4,
		"heat_to_jam": 30,
		"cooldown_rate": 10.0,
		"recoil": 0.04,
		"recoil_return": 8.0,
		"zoom_fov": 15.0,
		"model": "res://models/weapon_semi_sniper.obj",
		"sound_kind": "sniper",
		"bullet_color": Color(0.6, 0.95, 1.0),
		"bullet_size": 0.035,
		"bullet_length": 0.25
	},
	Type.HEAVY_SNIPER: {
		"name": "Крупнокалиберная винтовка",
		"fire_mode": "semi",
		"damage": 120,
		"bullets_per_shot": 1,
		"spread_deg": 0.0,
		"bullet_speed": 120.0,
		"fire_delay": 1.5,
		"heat_to_jam": 8,
		"cooldown_rate": 3.0,
		"recoil": 0.12,
		"recoil_return": 4.0,
		"zoom_fov": 5.0,
		"model": "res://models/weapon_heavy_sniper.obj",
		"sound_kind": "sniper",
		"bullet_color": Color(1.0, 0.5, 0.8),
		"bullet_size": 0.05,
		"bullet_length": 0.4
	},
	# ====== ТЯЖЁЛЫЙ ======
	Type.SHOTGUN: {
		"name": "Дробовик",
		"fire_mode": "auto",
		"damage": 8,
		"bullets_per_shot": 6,
		"spread_deg": 8.0,
		"bullet_speed": 50.0,
		"fire_delay": 0.8,
		"heat_to_jam": 18,
		"cooldown_rate": 6.0,
		"recoil": 0.05,
		"recoil_return": 7.0,
		"zoom_fov": 65.0,
		"model": "res://models/weapon_shotgun.obj",
		"sound_kind": "shotgun",
		"bullet_color": Color(1.0, 0.6, 0.2),
		"bullet_size": 0.03,
		"bullet_length": 0.12
	},
	Type.LMG: {
		"name": "Пулемёт",
		"fire_mode": "auto",
		"damage": 10,
		"bullets_per_shot": 1,
		"spread_deg": 4.0,
		"bullet_speed": 65.0,
		"fire_delay": 0.08,
		"heat_to_jam": 200,
		"cooldown_rate": 40.0,
		"recoil": 0.012,
		"recoil_return": 6.0,
		"zoom_fov": 55.0,
		"model": "res://models/weapon_lmg.obj",
		"sound_kind": "rifle",
		"bullet_color": Color(1.0, 0.8, 0.4),
		"bullet_size": 0.03,
		"bullet_length": 0.22
	},
	Type.HANDCANNON: {
		"name": "Ручная пушка",
		"fire_mode": "auto",
		"damage": 45,
		"bullets_per_shot": 1,
		"spread_deg": 1.5,
		"bullet_speed": 70.0,
		"fire_delay": 0.7,
		"heat_to_jam": 12,
		"cooldown_rate": 8.0,
		"recoil": 0.06,
		"recoil_return": 5.0,
		"zoom_fov": 50.0,
		"model": "res://models/weapon_handcannon.obj",
		"sound_kind": "shotgun",
		"bullet_color": Color(1.0, 0.4, 0.2),
		"bullet_size": 0.05,
		"bullet_length": 0.15
	},
	# ====== РАЗВЕДЧИК ======
	Type.PISTOL: {
		"name": "Пистолет",
		"fire_mode": "semi",
		"damage": 30,
		"bullets_per_shot": 1,
		"spread_deg": 0.8,
		"bullet_speed": 70.0,
		"fire_delay": 0.4,
		"heat_to_jam": 45,
		"cooldown_rate": 12.0,
		"recoil": 0.02,
		"recoil_return": 9.0,
		"zoom_fov": 45.0,
		"model": "res://models/weapon_pistol.obj",
		"sound_kind": "pistol",
		"bullet_color": Color(1.0, 1.0, 0.5),
		"bullet_size": 0.02,
		"bullet_length": 0.12
	},
	Type.DUAL_PISTOLS: {
		"name": "Двойные пистолеты",
		"fire_mode": "semi",
		"damage": 15,
		"bullets_per_shot": 1,
		"spread_deg": 2.5,
		"bullet_speed": 70.0,
		"fire_delay": 0.15,
		"heat_to_jam": 60,
		"cooldown_rate": 18.0,
		"recoil": 0.015,
		"recoil_return": 10.0,
		"zoom_fov": 50.0,
		"model": "res://models/weapon_dual_pistols.obj",
		"sound_kind": "pistol",
		"bullet_color": Color(1.0, 1.0, 0.6),
		"bullet_size": 0.02,
		"bullet_length": 0.12,
		"dual": false
	},
	Type.LIGHT_SMG: {
		"name": "Лёгкий ПП",
		"fire_mode": "semi",
		"damage": 5,
		"bullets_per_shot": 1,
		"spread_deg": 5.0,
		"bullet_speed": 50.0,
		"fire_delay": 0.05,
		"heat_to_jam": 120,
		"cooldown_rate": 35.0,
		"recoil": 0.004,
		"recoil_return": 12.0,
		"zoom_fov": 50.0,
		"model": "res://models/weapon_light_smg.obj",
		"sound_kind": "pistol",
		"bullet_color": Color(1.0, 0.9, 0.4),
		"bullet_size": 0.018,
		"bullet_length": 0.14
	}
}

static func get_weapon(t: int) -> Dictionary:
	return WEAPONS.get(t, WEAPONS[Type.RIFLE])

static func all_types() -> Array:
	return [
		Type.RIFLE, Type.CARBINE, Type.SMG,
		Type.SNIPER, Type.SEMI_SNIPER, Type.HEAVY_SNIPER,
		Type.SHOTGUN, Type.LMG, Type.HANDCANNON,
		Type.PISTOL, Type.DUAL_PISTOLS, Type.LIGHT_SMG
	]

static func weapons_of_class(class_type: int) -> Array:
	match class_type:
		0: return [Type.RIFLE, Type.CARBINE, Type.SMG]
		1: return [Type.SNIPER, Type.SEMI_SNIPER, Type.HEAVY_SNIPER]
		2: return [Type.SHOTGUN, Type.LMG, Type.HANDCANNON]
		3: return [Type.PISTOL, Type.DUAL_PISTOLS, Type.LIGHT_SMG]
	return [Type.RIFLE]
