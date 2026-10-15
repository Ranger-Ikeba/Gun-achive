extends Node3D

var speed := 400.0
var direction := Vector3(0, 0, -1)
var shooter: Node = null
var world: Node = null
var is_player_hit := false
var traveled := 0.0
var max_dist := 1000.0

@onready var light: OmniLight3D = $OmniLight3D
@onready var mesh_node: MeshInstance3D = $Mesh


func _ready() -> void:
    set_process(true)


func _process(delta: float) -> void:
    var step: float = speed * delta
    var from: Vector3 = global_position
    var to: Vector3 = from + direction * step

    # рейкаст на пути
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var q := PhysicsRayQueryParameters3D.create(from, to)
    q.collision_mask = 0b100 | 0b001  # hitbox (слой 3) + world (слой 1)
    if shooter != null and shooter is CollisionObject3D:
        q.exclude = [shooter]
        var hb: Node = shooter.get_node_or_null("Hitbox")
        if hb and hb is CollisionObject3D:
            q.exclude.append(hb)
    q.collide_with_areas = true
    q.collide_with_bodies = true
    var hit: Dictionary = space.intersect_ray(q)

    if hit and hit.has("position"):
        var pos: Vector3 = hit["position"]
        global_position = pos
        var collider: Object = hit.get("collider")
        var was_player := false
        if collider is Node:
            var target: Node = (collider as Node).get_parent()
            if target != null and target.has_method("receive_damage_rpc") and target.get("alive") == true:
                target.rpc_id(1, "receive_damage_rpc", 15, multiplayer.get_unique_id())
                was_player = true
        if world and world.has_method("broadcast_impact"):
            world.broadcast_impact(pos, was_player, direction)
        queue_free()
        return

    global_position = to
    traveled += step
    if traveled >= max_dist:
        queue_free()
