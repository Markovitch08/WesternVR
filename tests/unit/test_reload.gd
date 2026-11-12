extends GutTest
## Reloading the SAA way, with physical cases and cartridges.

const Rig := preload("res://tests/support/rig.gd")
const World := preload("res://tests/support/physics_world.gd")
const C := preload("res://revolver/RevolverMechanism.gd").Chamber

var gun: Revolver
var right: HandGrabber
var left: HandGrabber
var ground: StaticBody3D


func before_each() -> void:
	ground = World.floor_box(self, 0.0, &"dirt")
	autofree(ground)
	gun = load("res://revolver/Revolver.tscn").instantiate()
	add_child_autofree(gun)
	gun.global_position = Vector3(0, 1.2, 0)
	gun.gravity_scale = 0.0
	var rig := Rig.make(self)
	autofree(rig["origin"])
	right = rig["right"]
	left = rig["left"]
	Rig.hold(right, gun)


func after_each() -> void:
	for c in get_tree().get_nodes_in_group(&"_test_cartridges"):
		c.queue_free()
	for n in get_children():
		if n is Cartridge:
			n.queue_free()


func _press(hand: HandGrabber, action: String) -> void:
	hand.simulate(action, true)
	await wait_physics_frames(2)
	hand.simulate(action, false)
	await wait_physics_frames(2)


func _cartridges() -> Array:
	return get_children().filter(func(n): return n is Cartridge and not n.is_queued_for_deletion())


func _open_for_loading() -> void:
	await _press(right, "by_button")
	await _press(right, "primary_click")


func _push_ejector() -> void:
	left.get_parent().global_position = gun.get_ejector_head()
	left.simulate("trigger", 1.0)
	await wait_physics_frames(3)
	left.simulate("trigger", 0.0)
	await wait_physics_frames(6)


func test_ejector_kicks_out_a_physical_spent_case_that_falls_and_tinks() -> void:
	gun.mechanism.chambers.fill(C.SPENT)
	await _open_for_loading()
	await _push_ejector()
	var cases := _cartridges()
	assert_eq(cases.size(), 1, "one case ejected")
	if cases.is_empty():
		return
	var case: Cartridge = cases[0]
	assert_true(case.spent)
	assert_almost_eq(case.mass, Cartridge.SPENT_MASS, 0.0001)
	var hits := []
	case.impacted.connect(func(s, v, _p): hits.append(s))
	await wait_physics_frames(150)
	assert_lt(case.global_position.y, 0.05, "fell to the ground")
	assert_true(hits.has(&"dirt"), "landing reported on dirt")


func test_no_case_comes_out_with_the_gate_closed() -> void:
	gun.mechanism.chambers.fill(C.SPENT)
	await _press(right, "by_button")
	await _push_ejector()
	assert_eq(_cartridges().size(), 0)


func test_take_a_round_from_the_ammo_box() -> void:
	var box: StaticBody3D = load("res://ammo/AmmoBoxBody.tscn").instantiate()
	add_child_autofree(box)
	box.global_position = Vector3(1, 0.9, 0)
	var zone: AmmoBox = box.get_node("GrabZone")
	var start := zone.rounds
	left.get_parent().global_position = zone.global_position
	await wait_physics_frames(3)
	left.simulate("grip", 1.0)
	await wait_physics_frames(2)
	assert_true(left.held is Cartridge, "holding a cartridge")
	if left.held:
		assert_false(left.held.spent, "a live round")
	assert_eq(zone.rounds, start - 1)
	left.simulate("grip", 0.0)
	await wait_physics_frames(2)


func test_insert_a_round_at_the_open_gate() -> void:
	gun.mechanism.chambers.fill(C.EMPTY)
	await _open_for_loading()
	var round: Cartridge = load("res://ammo/Cartridge.tscn").instantiate()
	add_child(round)
	round.gravity_scale = 0.0
	round.global_position = gun.get_gate_chamber_mouth() + Vector3(0.2, 0, 0)
	left.get_parent().global_position = round.global_position
	left.held = round
	round.try_grab(left)
	var g := gun.mechanism.gate_chamber()
	await wait_physics_frames(3)
	assert_eq(gun.mechanism.chambers[g], C.EMPTY, "too far away to go in")
	left.get_parent().global_position = gun.get_gate_chamber_mouth()
	await wait_physics_frames(40)
	assert_eq(gun.mechanism.chambers[g], C.LIVE, "slid into the chamber")
	assert_null(left.held, "hand is empty again")
	assert_true(not is_instance_valid(round) or round.is_queued_for_deletion(), "the loose round is gone")


func test_full_reload_cycle_then_fire() -> void:
	gun.mechanism.chambers.fill(C.SPENT)
	await _open_for_loading()
	await _push_ejector()
	var g := gun.mechanism.gate_chamber()
	assert_eq(gun.mechanism.chambers[g], C.EMPTY)
	var round: Cartridge = load("res://ammo/Cartridge.tscn").instantiate()
	add_child(round)
	round.gravity_scale = 0.0
	left.get_parent().global_position = gun.get_gate_chamber_mouth()
	round.global_position = gun.get_gate_chamber_mouth()
	left.held = round
	round.try_grab(left)
	await wait_physics_frames(5)
	assert_eq(gun.mechanism.chambers[g], C.LIVE)
	await _press(right, "primary_click") # close the gate
	assert_false(gun.mechanism.gate_open)
	# Lower from half-cock, then cock until the new round comes up and fire it.
	await _press(right, "by_button")
	var fired := false
	for i in 6:
		await _press(right, "ax_button")
		right.simulate("trigger", 1.0)
		await wait_physics_frames(2)
		right.simulate("trigger", 0.0)
		await wait_physics_frames(2)
		if gun.mechanism.chambers[g] == C.SPENT:
			fired = true
			break
	assert_true(fired, "the reloaded round fires")
	Bullets.clear()


func test_loose_spent_cases_are_capped() -> void:
	var made := []
	for i in Cartridge.MAX_LOOSE_CASES + 10:
		var c: Cartridge = load("res://ammo/Cartridge.tscn").instantiate()
		c.spent = true
		add_child(c)
		c.global_position = Vector3(i * 0.05, 0.1, 2)
		made.append(c)
	await wait_frames(2)
	assert_eq(Cartridge.loose_case_count(), Cartridge.MAX_LOOSE_CASES)
	for c in made:
		if is_instance_valid(c):
			c.queue_free()
