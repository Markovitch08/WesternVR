extends GutTest
## The player rig has the parts the pass needs.

var player: Node


func before_each() -> void:
	player = load("res://player/Player.tscn").instantiate()
	add_child_autofree(player)


func test_rig_has_camera_and_two_tracked_hands() -> void:
	assert_true(player is XROrigin3D)
	assert_true(player.get_node("XRCamera3D") is XRCamera3D)
	var left: XRController3D = player.get_node("LeftHand")
	var right: XRController3D = player.get_node("RightHand")
	assert_eq(left.tracker, &"left_hand")
	assert_eq(right.tracker, &"right_hand")


func test_hands_are_xr_tools_collision_hands() -> void:
	for side in ["LeftHand", "RightHand"]:
		var coll = player.get_node(side + "/CollisionHand")
		assert_true(coll is XRToolsCollisionHand, side + " collision hand")


func test_turning_on_right_thumbstick_defaults_to_snap() -> void:
	var turn = player.get_node("RightHand/MovementTurn")
	assert_true(turn is XRToolsMovementTurn)
	assert_eq(turn.turn_mode, XRToolsMovementTurn.TurnMode.SNAP)
	assert_eq(turn.input_action, "primary")


func test_main_uses_local_floor_reference_space() -> void:
	# 2 = local floor in Godot's OpenXR settings.
	assert_eq(ProjectSettings.get_setting("xr/openxr/reference_space"), 2)
