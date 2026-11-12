extends GutTest
## Single-action rules: chambers, cocking, firing, gate, ejection, loading.

const M := preload("res://revolver/RevolverMechanism.gd")

var mech: RevolverMechanism
var events: Array[StringName] = []


func before_each() -> void:
	mech = RevolverMechanism.new()
	events.clear()
	mech.event.connect(func(n, _d): events.append(n))


func _fill(state: int) -> void:
	mech.chambers.fill(state)


func test_six_chambers_tracked_separately() -> void:
	assert_eq(mech.chambers.size(), 6)
	mech.chambers[2] = M.Chamber.LIVE
	mech.chambers[4] = M.Chamber.SPENT
	assert_eq(mech.chambers, [0, 0, 1, 0, 2, 0] as Array[int])


func test_loaded_five_with_hammer_on_empty_chamber() -> void:
	var m := RevolverMechanism.new(5)
	assert_eq(m.live_count(), 5)
	assert_eq(m.chambers[m.index], M.Chamber.EMPTY, "hammer rests on the empty chamber")


func test_no_shot_without_full_cock() -> void:
	_fill(M.Chamber.LIVE)
	assert_eq(mech.set_trigger(1.0), &"", "hammer down: trigger does nothing")
	mech.set_trigger(0.0)
	mech.half_cock()
	assert_eq(mech.set_trigger(1.0), &"", "half-cock: trigger does nothing")
	assert_eq(mech.hammer, M.Hammer.HALF)
	assert_eq(mech.live_count(), 6)
	assert_false(events.has(&"fired"))


func test_full_cock_then_trigger_fires_and_spends_the_round() -> void:
	_fill(M.Chamber.LIVE)
	assert_true(mech.cock())
	assert_eq(mech.hammer, M.Hammer.FULL)
	var c := mech.index
	assert_eq(mech.set_trigger(0.5), &"", "not past the break yet")
	assert_eq(mech.set_trigger(0.8), &"fired")
	assert_eq(mech.chambers[c], M.Chamber.SPENT)
	assert_eq(mech.hammer, M.Hammer.DOWN)
	assert_eq(events, [&"half_cock", &"full_cock", &"trigger_break", &"fired"] as Array[StringName])


func test_hammer_must_be_cocked_for_every_shot() -> void:
	_fill(M.Chamber.LIVE)
	mech.cock()
	mech.set_trigger(1.0)
	mech.set_trigger(0.0)
	assert_eq(mech.set_trigger(1.0), &"", "second pull without cocking: nothing")
	assert_eq(mech.live_count(), 5)


func test_cocking_turns_the_cylinder_one_chamber_with_two_clicks() -> void:
	assert_eq(mech.index, 0)
	mech.cock()
	assert_eq(mech.index, 1)
	assert_eq(events, [&"half_cock", &"full_cock"] as Array[StringName])
	mech.set_trigger(1.0)
	mech.set_trigger(0.0)
	mech.cock()
	assert_eq(mech.index, 2)
	assert_false(mech.cock(), "already at full cock")
	assert_eq(mech.index, 2)


func test_trigger_held_while_cocking_does_not_fire_until_pulled_again() -> void:
	_fill(M.Chamber.LIVE)
	mech.set_trigger(1.0)
	mech.cock()
	assert_eq(mech.set_trigger(1.0), &"", "trigger was already back")
	mech.set_trigger(0.1)
	assert_eq(mech.set_trigger(0.9), &"fired")


func test_dry_fire_on_empty_and_spent_chambers() -> void:
	mech.cock() # chamber 1 empty
	assert_eq(mech.set_trigger(1.0), &"dry_fire")
	mech.set_trigger(0.0)
	mech.chambers[2] = M.Chamber.SPENT
	mech.cock()
	assert_eq(mech.set_trigger(1.0), &"dry_fire")
	assert_eq(mech.chambers[2], M.Chamber.SPENT)


func test_six_shots_then_clicks() -> void:
	_fill(M.Chamber.LIVE)
	var shots := 0
	for i in 8:
		mech.cock()
		if mech.set_trigger(1.0) == &"fired":
			shots += 1
		mech.set_trigger(0.0)
	assert_eq(shots, 6)
	assert_eq(mech.chambers.count(M.Chamber.SPENT), 6)


func test_cylinder_turns_freely_only_at_half_cock_with_gate_open() -> void:
	assert_false(mech.spin(), "hammer down, gate shut")
	mech.open_gate()
	assert_false(mech.spin(), "gate open but hammer down")
	mech.close_gate()
	mech.half_cock()
	assert_false(mech.spin(), "half-cock but gate shut")
	mech.open_gate()
	var before := mech.index
	assert_true(mech.spin())
	assert_eq(mech.index, (before + 1) % 6)
	assert_true(events.has(&"chamber_click"))
	mech.close_gate()
	mech.lower_hammer()
	mech.cock()
	mech.open_gate()
	assert_false(mech.spin(), "full cock: locked")


func test_gate_lines_up_with_a_chamber_only_at_half_cock() -> void:
	mech.open_gate()
	assert_false(mech.gate_chamber_accessible(), "hammer down: gate sits between chambers")
	mech.half_cock()
	assert_true(mech.gate_chamber_accessible())
	assert_eq(mech.gate_chamber(), posmod(mech.index - 1, 6))
	assert_almost_eq(mech.cylinder_position(), mech.index + 0.5, 0.001)


func test_case_ejection_only_with_the_gate_open() -> void:
	_fill(M.Chamber.SPENT)
	mech.half_cock()
	assert_eq(mech.eject(), -1, "gate shut: the case stays in")
	assert_eq(mech.chambers.count(M.Chamber.SPENT), 6)
	mech.open_gate()
	var g := mech.gate_chamber()
	assert_eq(mech.eject(), M.Chamber.SPENT)
	assert_eq(mech.chambers[g], M.Chamber.EMPTY)
	assert_eq(mech.chambers.count(M.Chamber.SPENT), 5, "only that one case")
	assert_eq(mech.eject(), -1, "nothing left in that chamber")


func test_ejection_needs_half_cock_too() -> void:
	_fill(M.Chamber.SPENT)
	mech.open_gate()
	assert_eq(mech.eject(), -1, "hammer down: no chamber behind the gate")
	mech.cock()
	assert_eq(mech.eject(), -1, "full cock: no chamber behind the gate")


func test_live_round_can_be_ejected_too() -> void:
	_fill(M.Chamber.LIVE)
	mech.half_cock()
	mech.open_gate()
	assert_eq(mech.eject(), M.Chamber.LIVE)


func test_insert_round_only_into_empty_gate_chamber() -> void:
	assert_false(mech.insert_round(), "gate shut")
	mech.half_cock()
	mech.open_gate()
	var g := mech.gate_chamber()
	assert_true(mech.insert_round())
	assert_eq(mech.chambers[g], M.Chamber.LIVE)
	assert_false(mech.insert_round(), "already loaded")


func test_full_saa_reload_cycle() -> void:
	# Six spent cases: half-cock, open gate, eject + load each chamber in turn.
	_fill(M.Chamber.SPENT)
	mech.half_cock()
	mech.open_gate()
	for i in 6:
		assert_eq(mech.eject(), M.Chamber.SPENT)
		assert_true(mech.insert_round())
		mech.spin()
	assert_eq(mech.live_count(), 6)
	mech.close_gate()
	mech.cock()
	assert_eq(mech.set_trigger(1.0), &"fired")


func test_lowering_from_half_cock_moves_to_the_next_stop() -> void:
	mech.half_cock()
	var i := mech.index
	assert_true(mech.lower_hammer())
	assert_eq(mech.hammer, M.Hammer.DOWN)
	assert_eq(mech.index, (i + 1) % 6)
	assert_false(mech.lower_hammer(), "already down")


func test_decocking_from_full_keeps_the_chamber() -> void:
	mech.cock()
	var i := mech.index
	mech.lower_hammer()
	assert_eq(mech.index, i)
	assert_eq(mech.hammer, M.Hammer.DOWN)
