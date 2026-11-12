class_name Cartridge
extends Grabbable
## A .45 Colt cartridge (live) or an empty case (spent). Real size and mass;
## it bounces and rolls with physics and tinks when it lands.

## Spent cases left lying around before the oldest are removed.
const MAX_LOOSE_CASES := 30
const LIVE_MASS := 0.0256   # 255 gr bullet + 40 gr powder + case
const SPENT_MASS := 0.0068

static var _loose: Array[Cartridge] = []

@export var spent := false:
	set(value):
		spent = value
		if is_inside_tree():
			_apply_state()


func _ready() -> void:
	super._ready()
	surface = &"brass"
	impact_min_speed = 0.25
	_apply_state()
	if spent:
		_track_loose()


func _apply_state() -> void:
	mass = SPENT_MASS if spent else LIVE_MASS
	var bullet := get_node_or_null("Model/Bullet") as Node3D
	if bullet:
		bullet.visible = not spent
	var shape := get_node_or_null("Shape") as CollisionShape3D
	if shape and shape.shape is CylinderShape3D:
		var length := RevolverSpec.CASE_LENGTH if spent else RevolverSpec.CARTRIDGE_LENGTH
		(shape.shape as CylinderShape3D).height = length
		shape.position = Vector3(0, 0, -(length - RevolverSpec.CASE_LENGTH) * 0.5)
	var primer := get_node_or_null("Model/Primer") as MeshInstance3D
	if primer:
		primer.material_override = _primer_material(spent)


## Keeps the number of loose spent cases bounded.
func _track_loose() -> void:
	_loose = _loose.filter(func(c): return is_instance_valid(c) and not c.is_queued_for_deletion())
	_loose.append(self)
	while _loose.size() > MAX_LOOSE_CASES:
		var old: Cartridge = _loose.pop_front()
		if is_instance_valid(old) and not old.is_held():
			old.queue_free()


static func loose_case_count() -> int:
	_loose = _loose.filter(func(c): return is_instance_valid(c) and not c.is_queued_for_deletion())
	return _loose.size()


static var _primer_live: StandardMaterial3D
static var _primer_spent: StandardMaterial3D


static func _primer_material(is_spent: bool) -> Material:
	if _primer_live == null:
		_primer_live = StandardMaterial3D.new()
		_primer_live.albedo_color = Color(0.75, 0.75, 0.72)
		_primer_live.metallic = 0.9
		_primer_live.roughness = 0.3
		_primer_spent = StandardMaterial3D.new()
		_primer_spent.albedo_color = Color(0.12, 0.11, 0.1)
		_primer_spent.roughness = 0.8
	return _primer_spent if is_spent else _primer_live
