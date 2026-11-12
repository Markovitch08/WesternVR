extends Node
## Autoload "Bullets". Flies every live bullet in short ray-cast segments each
## physics frame, with gravity and drag (see Ballistics). On a hit it pushes
## rigid bodies, asks Impacts for effects and decals, and may ricochet off
## steel at shallow angles.

signal bullet_hit(info: Dictionary)

const MAX_AGE := 4.0
const MAX_RICOCHETS := 2

## What bullets can hit: static world, dynamic world, pickables, held objects.
@export_flags_3d_physics var collision_mask := (1 << 0) | (1 << 1) | (1 << 2) | (1 << 16)
var drag_k := Ballistics.DRAG_K_45_COLT
var rng := RandomNumberGenerator.new()

var _bullets: Array[Dictionary] = []


func _ready() -> void:
	rng.randomize()


## Launches a bullet. [param exclude]: RIDs it can't hit (the gun itself).
## Returns the bullet's state dictionary (position, velocity, age, path...).
func fire(origin: Vector3, velocity: Vector3, exclude: Array[RID] = [], mass := RevolverSpec.BULLET_MASS) -> Dictionary:
	var b := {
		"position": origin, "velocity": velocity, "age": 0.0, "exclude": exclude,
		"mass": mass, "ricochets": 0, "alive": true, "hits": [],
	}
	_bullets.append(b)
	return b


func active_count() -> int:
	return _bullets.size()


func clear() -> void:
	_bullets.clear()


func _physics_process(delta: float) -> void:
	if _bullets.is_empty():
		return
	var world := get_viewport().world_3d
	if world == null:
		return
	var space := world.direct_space_state
	var g := Ballistics.gravity()
	for b in _bullets.duplicate():
		_advance(b, delta, space, g)
	_bullets = _bullets.filter(func(b): return b["alive"])


func _advance(b: Dictionary, dt: float, space: PhysicsDirectSpaceState3D, g: Vector3) -> void:
	var from: Vector3 = b["position"]
	var r := Ballistics.step(from, b["velocity"], dt, g, drag_k)
	var to: Vector3 = r[0]
	b["age"] += dt
	var q := PhysicsRayQueryParameters3D.create(from, to, collision_mask, b["exclude"])
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		b["position"] = to
		b["velocity"] = r[1]
		if b["age"] > MAX_AGE or to.y < -50.0:
			b["alive"] = false
		return

	var frac := from.distance_to(hit.position) / maxf(from.distance_to(to), 1e-6)
	var v_hit: Vector3 = (b["velocity"] as Vector3).lerp(r[1], frac)
	var surface := Surface.of(hit.collider)
	var graze := Ballistics.grazing_angle_deg(v_hit, hit.normal)
	var ricochet: bool = b["ricochets"] < MAX_RICOCHETS \
			and rng.randf() < Ballistics.ricochet_chance(surface, graze)
	var info := {
		"position": hit.position, "normal": hit.normal, "collider": hit.collider,
		"velocity": v_hit, "surface": surface, "mass": b["mass"], "ricochet": ricochet,
		"grazing_deg": graze,
	}
	_push(info)
	var impacts := get_node_or_null(^"/root/Impacts")
	if impacts:
		impacts.spawn_impact(info)
	b["hits"].append(info)
	bullet_hit.emit(info)

	if ricochet:
		b["velocity"] = Ballistics.ricochet_velocity(v_hit, hit.normal, rng)
		b["position"] = hit.position + hit.normal * 0.002
		b["ricochets"] += 1
		b["exclude"] = [] as Array[RID]
	else:
		b["alive"] = false


## Transfers the bullet's momentum to a rigid body it hits.
func _push(info: Dictionary) -> void:
	var body = info["collider"]
	if body is RigidBody3D and not body.freeze:
		var share := 0.35 if info["ricochet"] else 1.0
		var impulse: Vector3 = info["velocity"] * info["mass"] * share
		body.apply_impulse(impulse, info["position"] - body.global_position)
