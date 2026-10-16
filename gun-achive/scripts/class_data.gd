extends Node
class_name ClassData

enum Type { ASSAULT, SNIPER, HEAVY, SCOUT }

const CLASSES := {
	Type.ASSAULT: {
		"name": "Штурмовик",
		"desc": "Универсал. Автомат, карабин, ПП.",
		"hp": 100, "armor": 50,
		"speed_mul": 1.0, "sprint_mul": 1.0,
		"weapon": 0,  # RIFLE
		"color": Color(0.85, 0.30, 0.30),
		"weapons": [0, 1, 2]
	},
	Type.SNIPER: {
		"name": "Снайпер",
		"desc": "Дальний бой. 3 вида снайперских.",
		"hp": 90, "armor": 30,
		"speed_mul": 0.9, "sprint_mul": 0.9,
		"weapon": 3,
		"color": Color(0.30, 0.55, 0.90),
		"weapons": [3, 4, 5]
	},
	Type.HEAVY: {
		"name": "Тяжёлый",
		"desc": "Танк. Дробовик, пулемёт, пушка.",
		"hp": 150, "armor": 80,
		"speed_mul": 0.8, "sprint_mul": 0.8,
		"weapon": 6,
		"color": Color(0.40, 0.65, 0.30),
		"weapons": [6, 7, 8]
	},
	Type.SCOUT: {
		"name": "Разведчик",
		"desc": "Быстрый. Пистолет, двойные, ПП.",
		"hp": 80, "armor": 20,
		"speed_mul": 1.25, "sprint_mul": 1.25,
		"weapon": 9,
		"color": Color(0.90, 0.75, 0.20),
		"weapons": [9, 10, 11]
	}
}

const SLOT_COLORS: Array[Color] = [
	Color(0.90, 0.20, 0.20),
	Color(0.20, 0.45, 0.90),
	Color(0.25, 0.75, 0.30),
	Color(0.95, 0.80, 0.15),
	Color(0.75, 0.30, 0.85),
	Color(0.95, 0.55, 0.15),
	Color(0.20, 0.85, 0.85),
]

static func get_class_info(t: int) -> Dictionary:
	return CLASSES.get(t, CLASSES[Type.ASSAULT])

static func all_class_types() -> Array:
	return [Type.ASSAULT, Type.SNIPER, Type.HEAVY, Type.SCOUT]

static func get_weapon_of(t: int) -> int:
	var cd: Dictionary = get_class_info(t)
	return int(cd.get("weapon", 0))

static func get_weapons_of(t: int) -> Array:
	var cd: Dictionary = get_class_info(t)
	return cd.get("weapons", [0])

static func get_slot_color(slot: int) -> Color:
	return SLOT_COLORS[slot % SLOT_COLORS.size()]
