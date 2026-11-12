class_name ShootingRange
extends Node3D
## The pass-1 test range. Sets the wind for smoke.

## Wind velocity (m/s): +X blows left to right, -Z blows down range.
@export var wind := Vector3(1.4, 0.0, 0.4)


func _ready() -> void:
	Wind.velocity = wind


## Steel plates (RigidBody3D) on the range.
func get_plates() -> Array[Node]:
	return find_children("Plate*", "RigidBody3D", true, false)
