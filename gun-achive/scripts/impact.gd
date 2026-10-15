extends CPUParticles3D

func configure_blood() -> void:
	amount = 25
	lifetime = 0.6
	color = Color(0.75, 0.05, 0.05, 1.0)
	initial_velocity_min = 2.5
	initial_velocity_max = 5.0
	gravity = Vector3(0, -12.0, 0)
	spread = 60.0
	direction = Vector3(0, 1, 0)
	scale_amount_min = 0.4
	scale_amount_max = 0.9
	one_shot = true
	explosiveness = 1.0

func configure_spark(dir: Vector3) -> void:
	amount = 15
	lifetime = 0.4
	color = Color(1.0, 0.85, 0.35, 1.0)
	initial_velocity_min = 3.0
	initial_velocity_max = 6.5
	gravity = Vector3(0, -10.0, 0)
	spread = 35.0
	direction = -dir
	scale_amount_min = 0.3
	scale_amount_max = 0.8
	one_shot = true
	explosiveness = 1.0
