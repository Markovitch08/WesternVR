class_name Player
extends XROrigin3D
## The VR player rig: XR origin, head camera and two tracked hands.
## Each hand has an XR Tools collision hand (it collides with the world) and a
## HandGrabber that picks up physics objects with the grip button.

@onready var camera: XRCamera3D = $XRCamera3D
@onready var left_controller: XRController3D = $LeftHand
@onready var right_controller: XRController3D = $RightHand


## Returns the HandGrabber of the given controller (or null).
func get_grabber(controller: XRController3D) -> Node:
	return controller.get_node_or_null("HandGrabber") if controller else null
