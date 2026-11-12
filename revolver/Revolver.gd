class_name Revolver
extends Grabbable
## Colt Single Action Army, .45 Colt, 7.5" barrel.
##
## The visual model is the child named "Model": the procedural placeholder, or
## a real .glb with the same part names (see docs/ASSETS.md).
##
## Default controls (hand holding the gun by its grip; change below):
##   Trigger           pull the trigger (fires only at full cock)
##   A / X             thumb the hammer back to full cock (two clicks)
##   B / Y             hammer down -> half-cock; otherwise lower the hammer
##   Thumbstick click  open / close the loading gate
##   Thumbstick flick  turn the cylinder one chamber (half-cock, gate open)
## Other hand, near the ejector rod head: its trigger pushes the ejector rod.

signal mechanism_event(name: StringName, data: Dictionary)

const PART_NAMES: Array[String] = ["Frame", "Barrel", "Cylinder", "Hammer", "Trigger",
		"LoadingGate", "EjectorRod", "Grip", "Muzzle", "SightRear", "SightFront"]

@export_group("Ballistics")
## Muzzle velocity of the .45 Colt black-powder load (m/s).
@export var muzzle_velocity := RevolverSpec.MUZZLE_VELOCITY
## Distance at which the sight line meets the bullet's path (m).
@export var zero_distance := RevolverSpec.ZERO_DISTANCE

@export_group("Controls")
@export var trigger_action := "trigger"
@export var cock_action := "ax_button"
@export var half_cock_action := "by_button"
@export var gate_action := "primary_click"
@export var spin_action := "primary"
## Action on the other hand that pushes the ejector rod.
@export var ejector_action := "trigger"
## The other hand must be this close to the ejector rod head (m).
@export var ejector_reach := 0.12

@export_group("Reloading")
@export var cartridge_scene: PackedScene = preload("res://ammo/Cartridge.tscn")
## A held live cartridge this close to the open chamber mouth slides in (m).
@export var insert_radius := 0.03
## Speed the ejector rod kicks a case out of the gate (m/s).
@export var eject_speed := 0.9

@export_group("Recoil")
## Recoil momentum: 255 gr bullet at 260 m/s plus black-powder gas (N s).
@export var recoil_impulse := 5.6
## Share of the straight-back kick soaked up by the arm.
@export_range(0.0, 1.0) var arm_absorbs := 0.68
## Extra muzzle flip from the wrist pivoting under the bore line (N m s).
@export var extra_flip := 0.11
## Hold strength just after the shot (fraction), and seconds to recover.
@export_range(0.0, 1.0) var hold_after_shot := 0.08
@export var recoil_recover_time := 0.3

@export_group("Haptics")
@export var shot_haptic := Vector2(1.0, 0.14)   # amplitude, seconds
@export var click_haptic := Vector2(0.3, 0.025)

@export_group("Model")
## Model node names for parts whose names differ from Revolver.PART_NAMES,
## e.g. {"Hammer": "ColtSAA_Hammer"}. Unlisted parts use their own name.
@export var part_aliases: Dictionary = {}
## Model nodes to hide (e.g. cartridges baked into the model's cylinder; the
## gun draws each chamber's state itself).
@export var hide_model_nodes: PackedStringArray = []
## Bore axis to cylinder axis (m): where the chambers sit on the cylinder.
@export var chamber_radius := RevolverSpec.CHAMBER_RADIUS
## Cylinder length (m): its rear face is where case heads show.
@export var cylinder_length := RevolverSpec.CYLINDER_LENGTH
## Ejector rod head, relative to the EjectorRod pivot, in gun axes (m). The
## other hand works the rod from here.
@export var ejector_head_offset := Vector3(0, 0, -0.095)

@export_group("Load")
## Rounds loaded at start (carried with the hammer on an empty chamber).
@export_range(0, 6) var start_loaded := 5

var mechanism: RevolverMechanism
var model: Node3D
var parts := {}

## Rest transforms of the moving parts (in their parents' space).
var _rest := {}
## Each moving part's parent basis expressed in the gun frame, to rotate parts
## about the gun's own axes whatever their local axes are.
var _parent_in_gun := {}
var _hammer_deg := 0.0
var _cylinder_pos := 0.0
var _gate_deg := 0.0
var _ejector := 0.0     # 0..1 stroke
var _trigger_vis := 0.0
var _prev_buttons := {}
var _spin_ready := true
var _round_visuals: Array[MeshInstance3D] = []
var _turn_provider: Node
## Bore direction in the gun's local frame, set so the sights are zeroed.
var bore_direction := Vector3.FORWARD


func _ready() -> void:
	super._ready()
	mechanism = RevolverMechanism.new(start_loaded)
	mechanism.event.connect(_on_mechanism_event)
	_find_parts()
	var inv := global_transform.affine_inverse()
	for n in ["Hammer", "Trigger", "Cylinder", "LoadingGate", "EjectorRod"]:
		if part(n):
			_rest[n] = part(n).transform
			_parent_in_gun[n] = (inv * part(n).get_parent().global_transform).basis
	for n in hide_model_nodes:
		var h := model.find_child(n, true, false) as Node3D if model else null
		if h:
			h.visible = false
	_cylinder_pos = mechanism.cylinder_position()
	_build_round_visuals()
	_update_parts(0.0, true)
	zero_sights()
	released.connect(func(_g): _set_turning_enabled(true))


func _find_parts() -> void:
	model = get_node_or_null("Model") as Node3D
	if model == null:
		push_error("Revolver: no child named 'Model'")
		return
	for n in PART_NAMES:
		# Model first (by alias, then by name), then markers placed on the gun itself.
		var p: Node3D = null
		if part_aliases.has(n):
			p = model.find_child(part_aliases[n], true, false) as Node3D
		if p == null:
			p = model.find_child(n, true, false) as Node3D
		if p == null:
			p = find_child(n, true, false) as Node3D
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


## Kicks the gun back along the bore. The bore line sits above the centre of
## mass and the hand, so the impulse also flips the muzzle up. The hold goes
## soft for a moment, then the hand pulls the gun back on target.
func apply_recoil() -> void:
	var back := -get_bore_direction()
	apply_impulse(back * recoil_impulse * (1.0 - arm_absorbs), Vector3.ZERO)
	apply_torque_impulse(global_basis.x * extra_flip)
	if is_held():
		set_hold_compliance(hold_after_shot, recoil_recover_time)


# --- Input ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if grabber is HandGrabber and held_by_grip:
		_read_gun_hand(grabber)
	else:
		mechanism.set_trigger(0.0)
	_read_ejector_hand(delta)
	_check_insert()


func _edge(g: Node, action: String) -> bool:
	var down: bool = g.is_pressed(action)
	var key := "%d:%s" % [g.get_instance_id(), action]
	var was: bool = _prev_buttons.get(key, false)
	_prev_buttons[key] = down
	return down and not was


func _read_gun_hand(g: Node) -> void:
	if _edge(g, cock_action):
		mechanism.cock()
	if _edge(g, half_cock_action):
		if mechanism.hammer == RevolverMechanism.Hammer.DOWN:
			mechanism.half_cock()
		else:
			mechanism.lower_hammer()
	if _edge(g, gate_action):
		mechanism.toggle_gate()
	var stick: Vector2 = g.get_vector2(spin_action)
	if absf(stick.x) > 0.7 and _spin_ready:
		_spin_ready = false
		mechanism.spin()
	elif absf(stick.x) < 0.3:
		_spin_ready = true
	mechanism.set_trigger(g.get_float(trigger_action))
	# The thumbstick turns the cylinder while loading, not the player.
	_set_turning_enabled(not mechanism.gate_open)


## The other hand works the ejector rod when it is near the rod's head.
func _read_ejector_hand(delta: float) -> void:
	var stroke := 0.0
	var off := _ejector_hand()
	if off:
		stroke = off.get_float(ejector_action)
	if stroke >= 0.9 and _ejector < 0.9:
		mechanism.eject()
	_ejector = move_toward(_ejector, stroke, delta * 12.0)


func _ejector_hand() -> Node:
	if not grabber is HandGrabber:
		return null
	var other: Node3D = grabber.get_other()
	if other == null or other.held != null:
		return null
	var rod := part("EjectorRod")
	if rod == null:
		return null
	return other if other.global_position.distance_to(get_ejector_head()) <= ejector_reach else null


## World position of the ejector rod's head (where the other hand pushes it).
func get_ejector_head() -> Vector3:
	var rod := part("EjectorRod")
	if rod == null:
		return global_position
	return rod.global_position + global_basis * ejector_head_offset


func _set_turning_enabled(on: bool) -> void:
	var ctrl = grabber.get("controller") if grabber else null
	var turn: Node = ctrl.get_node_or_null("MovementTurn") if ctrl else null
	if turn != _turn_provider and _turn_provider:
		_turn_provider.set("enabled", true)
	_turn_provider = turn
	if turn:
		turn.set("enabled", on)


# --- Events -----------------------------------------------------------------------

func _on_mechanism_event(name: StringName, data: Dictionary) -> void:
	match name:
		&"fired":
			discharge()
			apply_recoil()
			_haptic(grabber, shot_haptic)
		&"ejected":
			_spawn_ejected(data["state"] == RevolverMechanism.Chamber.SPENT)
			_haptic(grabber, click_haptic)
			_haptic(_ejector_hand(), click_haptic)
		&"round_inserted", &"ejector_stroke":
			_haptic(grabber, click_haptic * Vector2(0.7, 1.0))
			var off := _ejector_hand()
			if off:
				_haptic(off, click_haptic)
		_:
			_haptic(grabber, click_haptic)
	mechanism_event.emit(name, data)


func _haptic(g: Node, amp_dur: Vector2) -> void:
	if g and g.has_method("haptic"):
		g.haptic(amp_dur.x, amp_dur.y)


# --- Animation --------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_parts(delta, false)


func _update_parts(delta: float, snap: bool) -> void:
	var S := RevolverSpec
	var H := RevolverMechanism.Hammer
	var hammer_target := 0.0
	match mechanism.hammer:
		H.HALF:
			hammer_target = S.HAMMER_HALF_COCK_DEG
		H.FULL:
			hammer_target = S.HAMMER_FULL_COCK_DEG
	# The thumb draws the hammer back in ~0.12 s; the mainspring slams it home.
	var hammer_rate := 400.0 if hammer_target > _hammer_deg else 3000.0
	var cyl_target := mechanism.cylinder_position()
	if cyl_target < _cylinder_pos - 0.01:
		cyl_target += RevolverMechanism.CHAMBERS # always turn forward (clockwise)
	var trig_target := mechanism.trigger * (1.0 if mechanism.hammer == H.FULL else 0.25)
	if snap:
		_hammer_deg = hammer_target
		_cylinder_pos = cyl_target
	else:
		_hammer_deg = move_toward(_hammer_deg, hammer_target, hammer_rate * delta)
		_cylinder_pos = move_toward(_cylinder_pos, cyl_target, 9.0 * delta)
		if _cylinder_pos >= RevolverMechanism.CHAMBERS:
			_cylinder_pos -= RevolverMechanism.CHAMBERS
	_gate_deg = move_toward(_gate_deg, S.GATE_OPEN_DEG if mechanism.gate_open else 0.0, 900.0 * delta) if not snap \
			else (S.GATE_OPEN_DEG if mechanism.gate_open else 0.0)
	_trigger_vis = trig_target

	_pose(&"Hammer", Basis(Vector3.RIGHT, deg_to_rad(_hammer_deg)))
	_pose(&"Trigger", Basis(Vector3.RIGHT, deg_to_rad(S.TRIGGER_PULL_DEG * _trigger_vis)))
	# Clockwise seen from behind = negative rotation about +Z.
	_pose(&"Cylinder", Basis(Vector3.BACK, -deg_to_rad(60.0 * _cylinder_pos)))
	_pose(&"LoadingGate", Basis(Vector3.BACK, deg_to_rad(_gate_deg)))
	if _rest.has("EjectorRod"):
		var t: Transform3D = _rest["EjectorRod"]
		var slide: Vector3 = (_parent_in_gun["EjectorRod"] as Basis).inverse() * Vector3(0, 0, S.EJECTOR_STROKE * _ejector)
		part("EjectorRod").transform = Transform3D(t.basis, t.origin + slide)
	_update_round_visuals()


## Rotates a part about its pivot (its origin) by [param rot], given in the
## gun's frame, so the model's own local axes don't matter.
func _pose(part_name: StringName, rot: Basis) -> void:
	if _rest.has(part_name):
		var t: Transform3D = _rest[part_name]
		var pg: Basis = _parent_in_gun[part_name]
		var rot_in_parent := pg.inverse() * rot * pg
		part(part_name).transform = Transform3D(rot_in_parent * t.basis, t.origin)


## A part's rotation away from its rest pose, in the gun's frame (for tests).
func part_rotation(part_name: String) -> Basis:
	if not _rest.has(part_name):
		return Basis.IDENTITY
	var pg: Basis = _parent_in_gun[part_name]
	var now := pg * part(part_name).transform.basis
	var rest := pg * (_rest[part_name] as Transform3D).basis
	return (now * rest.inverse()).orthonormalized()


## Cartridge heads drawn in the back of the cylinder: brass with a primer (live),
## a dented black primer (spent), nothing (empty).
func _build_round_visuals() -> void:
	var cyl := part("Cylinder")
	if cyl == null:
		return
	var S := RevolverSpec
	var mesh := CylinderMesh.new()
	mesh.top_radius = S.CASE_RIM_RADIUS
	mesh.bottom_radius = S.CASE_RIM_RADIUS
	mesh.height = 0.0015
	mesh.radial_segments = 12
	mesh.rings = 1
	# Placed in world space at the rest pose, so the cylinder's scale and local
	# axes don't matter; as children they then turn with it.
	var center: Vector3 = global_transform.affine_inverse() * cyl.global_position
	for i in RevolverMechanism.CHAMBERS:
		var mi := MeshInstance3D.new()
		mi.name = "RoundHead%d" % i
		mi.mesh = mesh
		cyl.add_child(mi)
		var a := -deg_to_rad(60.0 * i)
		var p := center + Vector3(sin(a), cos(a), 0) * chamber_radius + Vector3(0, 0, cylinder_length * 0.5)
		mi.global_transform = global_transform * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p)
		_round_visuals.append(mi)


func _update_round_visuals() -> void:
	for i in _round_visuals.size():
		var state: int = mechanism.chambers[i]
		var mi := _round_visuals[i]
		mi.visible = state != RevolverMechanism.Chamber.EMPTY
		mi.material_override = _round_material(state)


static var _live_mat: StandardMaterial3D
static var _spent_mat: StandardMaterial3D


static func _round_material(state: int) -> Material:
	if _live_mat == null:
		_live_mat = StandardMaterial3D.new()
		_live_mat.albedo_color = Color(0.85, 0.66, 0.3)
		_live_mat.metallic = 0.9
		_live_mat.roughness = 0.3
		_spent_mat = StandardMaterial3D.new()
		_spent_mat.albedo_color = Color(0.45, 0.36, 0.2)
		_spent_mat.metallic = 0.7
		_spent_mat.roughness = 0.6
	return _spent_mat if state == RevolverMechanism.Chamber.SPENT else _live_mat


# --- Reloading -------------------------------------------------------------------

## The mouth of the chamber behind the loading gate (3 o'clock, rear face), world space.
func get_gate_chamber_mouth() -> Vector3:
	var cyl := part("Cylinder")
	if cyl == null or not _rest.has("Cylinder"):
		return global_position
	var center: Vector3 = cyl.get_parent().global_transform * (_rest["Cylinder"] as Transform3D).origin
	return center + global_basis * Vector3(chamber_radius, 0, cylinder_length * 0.5)


## A live cartridge held in the other hand slides in when brought to the open gate.
func _check_insert() -> void:
	if not mechanism.gate_chamber_accessible():
		return
	if mechanism.chambers[mechanism.gate_chamber()] != RevolverMechanism.Chamber.EMPTY:
		return
	if not grabber is HandGrabber:
		return
	var other: HandGrabber = grabber.get_other()
	if other == null or not other.held is Cartridge:
		return
	var round: Cartridge = other.held
	if round.spent or round.global_position.distance_to(get_gate_chamber_mouth()) > insert_radius:
		return
	if mechanism.insert_round():
		other.release()
		round.queue_free()


## The ejector pushes the case (or a live round) out of the gate, rearward.
func _spawn_ejected(spent: bool) -> void:
	if cartridge_scene == null:
		return
	var c: Cartridge = cartridge_scene.instantiate()
	c.spent = spent
	var world := get_tree().current_scene if get_tree().current_scene else get_parent()
	world.add_child(c)
	var mouth := get_gate_chamber_mouth()
	c.global_transform = Transform3D(global_basis, mouth + global_basis * Vector3(0, 0, RevolverSpec.CASE_LENGTH * 0.5 + 0.002))
	c.linear_velocity = linear_velocity + global_basis * Vector3(0.15, 0.05, 1.0).normalized() * eject_speed
	c.angular_velocity = global_basis * Vector3(randf_range(-6, 6), randf_range(-6, 6), 0)
	c.add_collision_exception_with(self)
	get_tree().create_timer(0.25).timeout.connect(func():
		if is_instance_valid(c):
			c.remove_collision_exception_with(self))
