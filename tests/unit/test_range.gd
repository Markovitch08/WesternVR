extends GutTest
## The test range layout and its physical behaviour.

var range_node: ShootingRange


func before_each() -> void:
	range_node = load("res://range/Range.tscn").instantiate()
	add_child_autofree(range_node)


func after_each() -> void:
	Bullets.clear()


func test_targets_are_between_5_and_25_m() -> void:
	var plates := range_node.get_plates()
	assert_gte(plates.size(), 3, "a few steel plates")
	for p in plates:
		assert_between(-p.global_position.z, 5.0, 25.0, p.name)
		assert_eq(Surface.of(p), &"metal")
	var posts := range_node.get_node("Posts").get_children()
	assert_gte(posts.size(), 3, "a few wooden posts")
	for p in posts:
		assert_between(-p.global_position.z, 5.0, 25.0, p.name)
		assert_eq(Surface.of(p), &"wood")


func test_surfaces_are_tagged() -> void:
	assert_eq(Surface.of(range_node.get_node("Ground")), &"dirt")
	assert_eq(Surface.of(range_node.get_node("Bench/Top")), &"wood")
	assert_eq(Surface.of(range_node.get_node("RockWall/Rock0")), &"rock")


func test_rock_wall_and_building_reflect_echoes() -> void:
	var refl := get_tree().get_nodes_in_group(&"echo_reflector")
	assert_gte(refl.size(), 2)
	var far := 0.0
	for r in refl:
		far = maxf(far, r.global_position.length())
	assert_gt(far, 30.0, "the rock wall stands well behind the targets")


func test_bench_is_at_standing_height() -> void:
	var top: StaticBody3D = range_node.get_node("Bench/Top")
	var shape: BoxShape3D = top.get_node("Collision").shape
	assert_almost_eq(top.global_position.y + shape.size.y * 0.5, 0.91, 0.005)


func test_steel_plate_swings_on_its_hinge_when_shot() -> void:
	await wait_physics_frames(30)
	var plate: RigidBody3D = range_node.get_plates()[0]
	var rest := plate.global_position
	var b := Bullets.fire(Vector3(rest.x, rest.y, 0), Vector3(0, 0, -RevolverSpec.MUZZLE_VELOCITY))
	await wait_physics_frames(12)
	assert_eq(b["hits"].size(), 1)
	if b["hits"].size() > 0:
		assert_eq(b["hits"][0]["collider"], plate, "hit the plate")
	var max_back := 0.0
	for i in 40:
		await wait_physics_frames(1)
		max_back = maxf(max_back, rest.z - plate.global_position.z)
	assert_gt(max_back, 0.01, "swung back away from the shooter")
	await wait_physics_frames(240)
	assert_almost_eq(plate.global_position.y, rest.y, 0.05, "still hanging from the bar")
	assert_almost_eq(plate.global_position.x, rest.x, 0.02, "swings only fore and aft")


func test_main_scene_layout_gun_rests_on_the_bench() -> void:
	# Read the scene text (loading it would start XR and load the hand rig).
	var text := FileAccess.get_file_as_string("res://main/Main.tscn")
	for n in ["StartXR", "FrameRateGuard", "Range", "Player", "Revolver", "AmmoBox"]:
		assert_string_contains(text, '[node name="%s"' % n)
	# Same placement as Main, without starting XR.
	var gun: Revolver = load("res://revolver/Revolver.tscn").instantiate()
	add_child_autofree(gun)
	gun.global_position = Vector3(-0.1, 0.935, -0.05)
	gun.rotation_degrees = Vector3(0, 80, 90)
	await wait_physics_frames(120)
	assert_between(gun.global_position.y, 0.91, 0.96, "lying on the bench top")
	assert_lt(gun.linear_velocity.length(), 0.05, "at rest")
