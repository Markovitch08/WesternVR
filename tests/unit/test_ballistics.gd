extends GutTest
## Bullet flight, drop, sight zero, hits, impulses and ricochets.

const World := preload("res://tests/support/physics_world.gd")
const V0 := RevolverSpec.MUZZLE_VELOCITY


func after_each() -> void:
	Bullets.clear()


func test_muzzle_velocity_is_realistic() -> void:
	assert_between(V0, 250.0, 270.0)


func test_drop_grows_with_distance_like_gravity() -> void:
	var prev := 0.0
	for d in [5.0, 10.0, 15.0, 25.0]:
		var r := Ballistics.fly_level(d, V0)
		var vacuum_drop := 0.5 * 9.8 * pow(d / V0, 2)
		assert_gt(r["drop"], prev, "drop increases at %d m" % d)
		# Drag makes it fall a little more than in a vacuum, never much more.
		assert_between(r["drop"], vacuum_drop, vacuum_drop * 1.1, "drop at %d m" % d)
		prev = r["drop"]
	var at25 := Ballistics.fly_level(25.0, V0)
	assert_between(at25["drop"], 0.040, 0.050, "about 4.5 cm at 25 m")
	assert_between(at25["velocity"], 245.0, 255.0, "a few percent slower at 25 m")
	assert_between(at25["time"], 0.095, 0.1, "about 0.1 s to 25 m")


func test_zero_angle_makes_bullet_meet_the_sight_line_at_15m() -> void:
	var below := 0.017
	var a := Ballistics.zero_angle(below, 15.0, V0)
	assert_gt(a, 0.0, "bore tilts up relative to the sights")
	assert_almost_eq(Ballistics.height_over_los(a, below, 15.0, V0), 0.0, 0.0005)
	assert_lt(Ballistics.height_over_los(a, below, 25.0, V0), -0.005, "shoots low past the zero")
	assert_lt(Ballistics.height_over_los(a, below, 2.0, V0), 0.0, "starts below the sight line")


func test_placeholder_revolver_sights_are_zeroed_at_15m() -> void:
	var gun: Revolver = load("res://revolver/Revolver.tscn").instantiate()
	add_child_autofree(gun)
	gun.freeze = true
	# Aim so the sight line is level, then trace the real bullet path.
	var rear := gun.part("SightRear").global_position
	var front := gun.part("SightFront").global_position
	var los := (front - rear).normalized()
	gun.global_basis = Basis(Quaternion(los, Vector3.FORWARD)) * gun.global_basis
	rear = gun.part("SightRear").global_position
	los = (gun.part("SightFront").global_position - rear).normalized()
	assert_almost_eq(los.y, 0.0, 1e-4, "sight line is level")
	assert_almost_eq(gun.bore_direction.angle_to(Vector3.FORWARD), 0.0, 0.001,
			"placeholder front blade is cut for the bore to lie along -Z")
	var pos := gun.get_muzzle_position()
	var vel := gun.get_bore_direction() * gun.muzzle_velocity
	var dt := 1.0 / 720.0
	var g := Ballistics.gravity()
	var muzzle_dist := (pos - rear).dot(los)
	while (pos - rear).dot(los) < muzzle_dist + 15.0:
		var r := Ballistics.step(pos, vel, dt, g, Ballistics.DRAG_K_45_COLT)
		pos = r[0]
		vel = r[1]
	var off := (pos - rear) - los * (pos - rear).dot(los)
	assert_lt(off.length(), 0.003, "bullet within 3 mm of the sight line at 15 m")


func test_zeroing_adapts_to_any_model() -> void:
	# A model with a taller front sight must get a bore pointed further up.
	var muzzle := RevolverSpec.MUZZLE
	var rear := RevolverSpec.SIGHT_REAR
	var front := Vector3(0, 0.0175, RevolverSpec.SIGHT_FRONT_Z)
	var tall := front + Vector3(0, 0.002, 0)
	var d1 := Ballistics.bore_direction_for_zero(muzzle, rear, front, 15.0, V0)
	var d2 := Ballistics.bore_direction_for_zero(muzzle, rear, tall, 15.0, V0)
	assert_gt(d2.y, d1.y)


func test_bullet_is_traced_over_time_not_hitscan() -> void:
	var wall := World.floor_box(self, 1.0, &"wood", Vector3(2, 2, 0.1), Vector2(0, -20))
	autofree(wall)
	var b := Bullets.fire(Vector3(0, 1, 0), Vector3(0, 0, -V0))
	await wait_physics_frames(1)
	assert_eq(b["hits"].size(), 0, "no hit after one frame")
	assert_lt(b["position"].z, -1.0, "moved down range")
	await wait_physics_frames(12)
	assert_eq(b["hits"].size(), 1, "hits the wall at 20 m about 0.08 s later")
	assert_false(b["alive"])
	assert_eq(b["hits"][0]["surface"], &"wood")


func test_hit_pushes_rigid_bodies() -> void:
	var floor_body := World.floor_box(self, 0.0)
	autofree(floor_body)
	var box := RigidBody3D.new()
	box.mass = 0.5
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	cs.shape.size = Vector3(0.2, 0.2, 0.2)
	box.add_child(cs)
	add_child_autofree(box)
	box.global_position = Vector3(0, 0.1, -5)
	await wait_physics_frames(10)
	Bullets.fire(Vector3(0, 0.15, 0), Vector3(0, 0, -V0))
	await wait_physics_frames(10)
	assert_lt(box.linear_velocity.z + box.global_position.z + 5.0, -0.001, "pushed down range")


func test_bullet_leaves_a_decal() -> void:
	var wall := World.floor_box(self, 1.0, &"metal", Vector3(2, 2, 0.1), Vector2(0, -5))
	autofree(wall)
	var before: int = Impacts.decal_count()
	Bullets.fire(Vector3(0, 1, 0), Vector3(0, 0, -V0))
	await wait_physics_frames(6)
	assert_eq(Impacts.decal_count(), before + 1)


func test_ricochet_only_off_steel_at_shallow_angles() -> void:
	assert_eq(Ballistics.ricochet_chance(&"dirt", 5.0), 0.0)
	assert_eq(Ballistics.ricochet_chance(&"wood", 5.0), 0.0)
	assert_eq(Ballistics.ricochet_chance(&"metal", 45.0), 0.0)
	assert_eq(Ballistics.ricochet_chance(&"metal", 90.0), 0.0)
	assert_gt(Ballistics.ricochet_chance(&"metal", 5.0), 0.5)
	assert_gt(Ballistics.ricochet_chance(&"metal", 5.0), Ballistics.ricochet_chance(&"metal", 15.0))
	assert_almost_eq(Ballistics.grazing_angle_deg(Vector3(0, 0, -1), Vector3(0, 0, 1)), 90.0, 0.01)
	assert_almost_eq(Ballistics.grazing_angle_deg(Vector3(1, -0.1, 0).normalized(), Vector3.UP), 5.71, 0.05)


func test_ricochet_reflects_and_slows_the_bullet() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var v := Vector3(250, -20, 0)
	var out := Ballistics.ricochet_velocity(v, Vector3.UP, rng)
	assert_gt(out.y, 0.0, "leaves away from the surface")
	assert_gt(out.x, 0.0, "keeps going forward")
	assert_lt(out.length(), v.length(), "loses speed")


func test_shallow_hit_on_steel_ricochets_in_the_tracer() -> void:
	var plate := World.floor_box(self, 0.0, &"metal", Vector3(10, 0.1, 30))
	autofree(plate)
	Bullets.rng.seed = 1
	var ricochets := 0
	for i in 10:
		var b := Bullets.fire(Vector3(0, 0.5, 0), Vector3(0, -12, -V0))
		await wait_physics_frames(10)
		if b["hits"].size() > 0 and b["hits"][0]["ricochet"]:
			ricochets += 1
	assert_gt(ricochets, 3, "most 3 degree hits on steel glance off")
	Bullets.rng.randomize()
