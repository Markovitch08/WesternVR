class_name Revolver
extends Grabbable
## Colt Single Action Army, .45 Colt, 7.5" barrel.
##
## The visual model is the child named "Model": the procedural placeholder, or
## a real .glb with the same part names (see docs/ASSETS.md).

const PART_NAMES: Array[String] = ["Frame", "Barrel", "Cylinder", "Hammer", "Trigger",
		"LoadingGate", "EjectorRod", "Grip", "Muzzle", "SightRear", "SightFront"]

@export_group("Ballistics")
## Muzzle velocity of the .45 Colt black-powder load (m/s).
@export var muzzle_velocity := RevolverSpec.MUZZLE_VELOCITY
## Distance at which the sight line meets the bullet's path (m).
@export var zero_distance := RevolverSpec.ZERO_DISTANCE

var model: Node3D
var parts := {}
## Bore direction in the gun's local frame, set so the sights are zeroed.
var bore_direction := Vector3.FORWARD


func _ready() -> void:
	super._ready()
	_find_parts()
	zero_sights()


func _find_parts() -> void:
	model = get_node_or_null("Model") as Node3D
	if model == null:
		push_error("Revolver: no child named 'Model'")
		return
	for n in PART_NAMES:
		var p := model.find_child(n, true, false) as Node3D
		if p == null:
			push_error("Revolver: model is missing part '%s'" % n)
		parts[n] = p


func part(part_name: String) -> Node3D:
	return parts.get(part_name)


## Points the bore so the bullet meets the line over the rear notch and front
## blade at [member zero_distance]. Works for any model with the sight markers.
func zero_sights() -> void:
	var m := part("Muzzle")
	var r := part("SightRear")
	var f := part("SightFront")
	if not (m and r and f):
		return
	var inv := global_transform.affine_inverse()
	bore_direction = Ballistics.bore_direction_for_zero(inv * m.global_position, inv * r.global_position,
			inv * f.global_position, zero_distance, muzzle_velocity, Ballistics.DRAG_K_45_COLT,
			Ballistics.gravity().length())


## Muzzle position and bore direction in world space.
func get_muzzle_position() -> Vector3:
	return part("Muzzle").global_position


func get_bore_direction() -> Vector3:
	return (global_basis * bore_direction).normalized()


## Sends one bullet down the bore. Returns the bullet's state dictionary.
func discharge() -> Dictionary:
	var v := get_bore_direction() * muzzle_velocity + linear_velocity
	var exclude: Array[RID] = [get_rid()]
	return Bullets.fire(get_muzzle_position(), v, exclude)
