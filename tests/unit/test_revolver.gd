extends GutTest
## The revolver node driven by (simulated) controller input.

const Rig := preload("res://tests/support/rig.gd")
const H := preload("res://revolver/RevolverMechanism.gd").Hammer
const C := preload("res://revolver/RevolverMechanism.gd").Chamber

var gun: Revolver
var rig: Dictionary
var right: HandGrabber
var left: HandGrabber
var events: Array[StringName] = []


func before_each() -> void:
	gun = load("res://revolver/Revolver.tscn").instantiate()
	add_child_autofree(gun)
	gun.global_position = Vector3(0, 1.2, 0)
	gun.gravity_scale = 0.0
	rig = Rig.make(self)
	autofree(rig["origin"])
	right = rig["right"]
	left = rig["left"]
	Rig.hold(right, gun)
	events.clear()
	gun.mechanism_event.connect(func(n, _d): events.append(n))


func after_each() -> void:
	Bullets.clear()


func _press(hand: HandGrabber, action: String) -> void:
	hand.simulate(action, true)
	await wait_physics_frames(2)
	hand.simulate(action, false)
	await wait_physics_frames(2)


func test_starts_with_five_rounds_hammer_on_empty() -> void:
	assert_eq(gun.mechanism.live_count(), 5)
	assert_eq(gun.mechanism.chambers[gun.mechanism.index], C.EMPTY)


func test_thumb_cock_then_trigger_fires_a_bullet() -> void:
	await _press(right, "ax_button")
	assert_eq(gun.mechanism.hammer, H.FULL)
	assert_eq(events.slice(0, 2), [&"half_cock", &"full_cock"] as Array[StringName], "two clicks")
	await wait_frames(20)
	assert_almost_eq(gun.part("Hammer").rotation_degrees.x, RevolverSpec.HAMMER_FULL_COCK_DEG, 1.0,
			"hammer drawn back on its pivot")
	right.simulate("trigger", 1.0)
	await wait_physics_frames(2)
	assert_true(events.has(&"fired"))
	assert_eq(Bullets.active_count(), 1, "a bullet is in flight")
	assert_eq(gun.mechanism.chambers[gun.mechanism.index], C.SPENT)


func test_trigger_without_cocking_does_nothing() -> void:
	right.simulate("trigger", 1.0)
	await wait_physics_frames(3)
	assert_false(events.has(&"fired"))
	assert_false(events.has(&"dry_fire"))
	assert_eq(Bullets.active_count(), 0)


func test_cylinder_turns_one_chamber_when_cocked() -> void:
	var before := gun.part("Cylinder").transform.basis
	await _press(right, "ax_button")
	await wait_frames(30)
	var after := gun.part("Cylinder").transform.basis
	var turned := rad_to_deg(before.get_rotation_quaternion().angle_to(after.get_rotation_quaternion()))
	assert_almost_eq(turned, 60.0, 1.0)


func test_loading_gate_opens_to_the_right() -> void:
	await _press(right, "primary_click")
	assert_true(gun.mechanism.gate_open)
	await wait_frames(30)
	var gate := gun.part("LoadingGate")
	var plate_dir: Vector3 = gate.transform.basis * Vector3.UP
	assert_gt(plate_dir.x, 0.9, "gate swung out to the right (+X)")


func test_spin_with_thumbstick_at_half_cock_with_gate_open() -> void:
	await _press(right, "by_button")
	await _press(right, "primary_click")
	var i := gun.mechanism.index
	right.simulate("primary", Vector2(1, 0))
	await wait_physics_frames(2)
	right.simulate("primary", Vector2.ZERO)
	await wait_physics_frames(2)
	assert_eq(gun.mechanism.index, (i + 1) % 6)
	assert_true(events.has(&"chamber_click"))


func test_other_hand_pushes_the_ejector_rod_to_eject() -> void:
	gun.mechanism.chambers.fill(C.SPENT)
	await _press(right, "by_button")     # half-cock
	await _press(right, "primary_click") # open gate
	var rod := gun.part("EjectorRod")
	left.get_parent().global_position = rod.global_transform * Vector3(0, 0, -0.095)
	left.simulate("trigger", 1.0)
	await wait_physics_frames(3)
	assert_true(events.has(&"ejected"))
	assert_eq(gun.mechanism.chambers[gun.mechanism.gate_chamber()], C.EMPTY)


func test_ejector_does_nothing_with_gate_closed() -> void:
	gun.mechanism.chambers.fill(C.SPENT)
	await _press(right, "by_button")
	var rod := gun.part("EjectorRod")
	left.get_parent().global_position = rod.global_transform * Vector3(0, 0, -0.095)
	left.simulate("trigger", 1.0)
	await wait_physics_frames(3)
	assert_false(events.has(&"ejected"))
	assert_eq(gun.mechanism.chambers.count(C.SPENT), 6)


func test_free_grab_by_the_barrel_cannot_work_the_action() -> void:
	right.release()
	gun.release_from(right)
	right.get_parent().global_position = gun.get_muzzle_position()
	gun.try_grab(right)
	assert_false(gun.held_by_grip)
	await _press(right, "ax_button")
	assert_eq(gun.mechanism.hammer, H.DOWN)
