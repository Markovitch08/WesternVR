extends GutTest
## Physical grabbing: the gun is a real rigid body, held by forces.

const World := preload("res://tests/support/physics_world.gd")

var gun: Revolver
var hand: Node3D


func before_each() -> void:
	gun = load("res://revolver/Revolver.tscn").instantiate()
	add_child_autofree(gun)
	hand = Node3D.new()
	add_child_autofree(hand)


func test_revolver_is_a_rigid_body_with_real_mass_and_compound_shape() -> void:
	assert_true(gun is RigidBody3D)
	assert_almost_eq(gun.mass, 1.05, 0.001)
	var shapes := gun.get_children().filter(func(c): return c is CollisionShape3D)
	assert_gte(shapes.size(), 4, "barrel, frame, cylinder, grip at least")
	for s in shapes:
		assert_true(s.shape is ConvexPolygonShape3D or s.shape is BoxShape3D or s.shape is CylinderShape3D,
				"%s is convex" % s.name)


func test_model_has_all_named_parts() -> void:
	for n in Revolver.PART_NAMES:
		assert_not_null(gun.part(n), "part %s" % n)
	assert_true(gun.part("Muzzle") is Marker3D)


func test_held_gun_follows_the_hand_by_forces() -> void:
	gun.global_position = Vector3(0, 1, 0)
	hand.global_position = gun.get_grip_point().global_position
	assert_true(gun.try_grab(hand))
	assert_true(gun.held_by_grip, "grabbed by its grip point")
	hand.global_position += Vector3(0.3, 0.2, -0.1)
	var start := gun.global_position
	await wait_physics_frames(2)
	assert_ne(gun.global_position, start, "moved")
	assert_gt(gun.get_grip_point().global_position.distance_to(hand.global_position), 0.05,
			"not teleported: it takes several physics frames")
	await wait_physics_frames(60)
	assert_lt(gun.get_grip_point().global_position.distance_to(hand.global_position), 0.01,
			"settles in the hand")
	assert_lt(gun.linear_velocity.length(), 0.1, "and stays there")


func test_held_gun_cannot_pass_through_the_bench() -> void:
	var bench := World.floor_box(self, 0.9, &"wood", Vector3(1.4, 0.06, 0.6))
	autofree(bench)
	gun.global_position = Vector3(0, 1.05, 0)
	hand.global_position = gun.get_grip_point().global_position
	gun.try_grab(hand)
	# Push the hand 30 cm down into and through the bench.
	hand.global_position += Vector3(0, -0.3, 0)
	await wait_physics_frames(90)
	assert_gt(World.lowest_point(gun), 0.9 - 0.01, "gun stays on top of the bench")


func test_released_gun_falls_and_rests_on_the_table() -> void:
	var table := World.floor_box(self, 0.9, &"wood")
	autofree(table)
	gun.global_position = Vector3(0, 1.3, 0)
	hand.global_position = gun.get_grip_point().global_position
	gun.try_grab(hand)
	await wait_physics_frames(5)
	var hits := []
	gun.impacted.connect(func(surface, speed, _at): hits.append([surface, speed]))
	gun.release_from(hand)
	assert_false(gun.is_held())
	await wait_physics_frames(150)
	var low := World.lowest_point(gun)
	assert_between(low, 0.88, 0.93, "resting on the table top")
	assert_gt(hits.size(), 0, "landing reported")
	if hits.size() > 0:
		assert_eq(hits[0][0], &"wood", "surface of the table")


func test_resting_gun_can_be_knocked_over() -> void:
	var table := World.floor_box(self, 0.0)
	autofree(table)
	gun.global_position = Vector3(0, 0.08, 0)
	await wait_physics_frames(60)
	var before := gun.global_position
	gun.apply_impulse(Vector3(2.0, 0.5, 0), Vector3(0, 0.02, 0))
	await wait_physics_frames(30)
	assert_gt(gun.global_position.distance_to(before), 0.05)


func test_hand_grabber_grips_and_releases_with_the_grip_button() -> void:
	gun.global_position = Vector3(0, 1, 0)
	gun.freeze = true # keep it still while the grab zone detects it
	var g := HandGrabber.new()
	add_child_autofree(g)
	g.global_position = gun.get_grip_point().global_position
	await wait_physics_frames(3)
	gun.freeze = false
	g.simulate("grip", 1.0)
	await wait_physics_frames(2)
	assert_eq(g.held, gun, "grip pressed: holding the gun")
	assert_true(gun.is_held())
	g.simulate("grip", 0.0)
	await wait_physics_frames(2)
	assert_null(g.held, "grip released: dropped")
	assert_false(gun.is_held())
