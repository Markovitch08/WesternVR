extends RefCounted
## A minimal two-hand rig for tests: XROrigin3D with two XRController3D, each
## with a HandGrabber whose inputs are simulated.


static func make(parent: Node) -> Dictionary:
	var origin := XROrigin3D.new()
	parent.add_child(origin)
	var hands := {}
	for side in ["left", "right"]:
		var c := XRController3D.new()
		c.name = side.capitalize() + "Hand"
		c.tracker = StringName(side + "_hand")
		origin.add_child(c)
		var g := HandGrabber.new()
		g.name = "HandGrabber"
		c.add_child(g)
		hands[side] = g
	return {"origin": origin, "left": hands["left"], "right": hands["right"]}


## Places a hand on a gun's grip and grabs it.
static func hold(hand: HandGrabber, gun: Grabbable) -> void:
	hand.get_parent().global_transform = gun.get_grip_point().global_transform
	hand.held = gun
	gun.try_grab(hand)
