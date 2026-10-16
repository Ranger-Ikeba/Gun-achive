extends Node3D

var speed := 60.0
var direction := Vector3(0, 0, -1)
var shooter: Node = null
var world: Node = null
var damage := 0
var traveled := 0.0
var max_dist := 60.0
var hit_done := true
var impact_pos := Vector3.ZERO
var bullet_color := Color(1.0, 0.9, 0.4)
var bullet_size := 0.025
var bullet_length := 0.18
var _configured := false

func configure(color: Color, size: float, length: float) -> void:
	bullet_color = color
	bullet_size = size
	bullet_length = length
	_configured = true
	_apply_visual()

func _ready() -> void:
	set_process(true)
	impact_pos = global_position + direction.normalized() * 1000.0
	if _configured:
		_apply_visual()

func _apply_visual() -> void:
	var mesh_inst: MeshInstance3D = get_node_or_null("Mesh")
	if mesh_inst:
		var capsule := CapsuleMesh.new()
		capsule.radius = bullet_size
		capsule.height = bullet_length
		capsule.radial_segments = 6
		capsule.rings = 2
		mesh_inst.mesh = capsule
		mesh_inst.transform = Transform3D(Vector3(1, 0, 0), Vector3(0, 0.7, 0.7), Vector3(0, -0.7, 0.7), Vector3(0, 0, 0))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = bullet_color
		mat.emission_enabled = true
		mat.emission = bullet_color
		mat.emission_energy_multiplier = 15.0
		mat.shading_mode = 0
		mesh_inst.material_override = mat
	var light: OmniLight3D = get_node_or_null("OmniLight3D")
	if light:
		light.light_color = bullet_color
		light.light_energy = 3.0
		light.omni_range = bullet_length * 40

func _process(delta: float) -> void:
	var step: float = speed * delta
	var next_pos: Vector3 = global_position + direction.normalized() * step
	traveled += step
	if traveled >= max_dist:
		global_position = impact_pos
		queue_free()
		return
	global_position = next_pos
