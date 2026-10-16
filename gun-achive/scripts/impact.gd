extends CPUParticles3D

var _base_color := Color(0.75, 0.05, 0.05, 1.0)

func configure_blood(color: Color = Color(0.75, 0.05, 0.05, 1.0)) -> void:
	_base_color = color
	amount = 30
	lifetime = 0.7
	color = color
	initial_velocity_min = 2.5
	initial_velocity_max = 5.5
	gravity = Vector3(0, -12.0, 0)
	spread = 60.0
	direction = Vector3(0, 1, 0)
	scale_amount_min = 0.5
	scale_amount_max = 1.2
	one_shot = true
	emitting = true

func configure_spark(dir: Vector3) -> void:
	amount = 18
	lifetime = 0.35
	color = Color(1.0, 0.85, 0.35, 1.0)
	initial_velocity_min = 4.0
	initial_velocity_max = 8.0
	gravity = Vector3(0, -10.0, 0)
	spread = 35.0
	direction = -dir
	scale_amount_min = 0.4
	scale_amount_max = 1.0
	one_shot = true
	emitting = true
