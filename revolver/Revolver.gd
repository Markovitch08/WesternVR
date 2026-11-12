class_name Revolver
extends Grabbable
## Colt Single Action Army, .45 Colt, 7.5" barrel.
##
## The visual model is the child named "Model": the procedural placeholder, or
## a real .glb with the same part names (see docs/ASSETS.md).

const PART_NAMES: Array[String] = ["Frame", "Barrel", "Cylinder", "Hammer", "Trigger",
		"LoadingGate", "EjectorRod", "Grip", "Muzzle", "SightRear", "SightFront"]

var model: Node3D
var parts := {}


func _ready() -> void:
	super._ready()
	_find_parts()


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
