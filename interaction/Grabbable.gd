class_name Grabbable
extends RigidBody3D
## A rigid body that can be held by a HandGrabber.
##
## While held it is driven toward the hand with clamped forces and torques
## (a velocity-tracking PD controller), never by setting its transform. So it
## keeps colliding with the world: it can't pass through tables or walls, and
## can be knocked out of the way. Released, it keeps its velocity (throwing).

signal grabbed(grabber: Node3D)
signal released(grabber: Node3D)
## Emitted when the body hits something hard enough to make a sound.
signal impacted(surface: StringName, speed: float, at: Vector3)

@export_group("Holding")
## Maximum force the hand can apply (N). Limits how hard it pushes into walls.
@export var max_hold_force := 300.0
## Maximum torque the hand can apply (N m).
@export var max_hold_torque := 18.0
## How quickly position error is closed (1/s). Keep below the physics rate.
@export var linear_stiffness := 45.0
## How quickly rotation error is closed (1/s).
@export var angular_stiffness := 45.0
## Position error (m) beyond which the object counts as obstructed (e.g. the hand
## went through a table) and the hold backs off so it doesn't grind into it.
@export var obstruction_distance := 0.05
## Lowest fraction of hold strength used while obstructed.
@export_range(0.05, 1.0) var obstructed_strength := 0.2
## Grab by the grip point if the hand is within this distance of it (m).
@export var snap_grab_distance := 0.12
## Collision layer while held (layer 17 "Held Objects": hands ignore it).
@export_flags_3d_physics var held_layer := 1 << 16

@export_group("Impacts")
## Surface type of this object, for sounds of other things hitting it.
@export var surface := &"metal"
## Slowest impact that makes a sound (m/s).
@export var impact_min_speed := 0.5

var grabber: Node3D = null
## True when held by its grip point (the "proper" hold), false for a free grab.
var held_by_grip := false
## Object transform expressed in the grabber's frame.
var hold_offset := Transform3D.IDENTITY

var _free_layer := 0
var _prev_target := Transform3D.IDENTITY
var _has_prev_target := false
var _strength := 1.0
var _strength_recover := 0.0
var _hand_anchor: Node3D
var _last_velocity := Vector3.ZERO
var _impact_cooldown := 0.0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = maxi(max_contacts_reported, 4)
	body_entered.connect(_on_body_entered)
	_free_layer = collision_layer


func is_held() -> bool:
	return grabber != null


## The Marker3D the hand holds by (null if the object has none).
func get_grip_point() -> Node3D:
	return find_child("GripPoint", true, false) as Node3D


## Called by a HandGrabber. Returns true if the grab succeeded.
func try_grab(by: Node3D) -> bool:
	if grabber == by:
		return true
	if grabber and grabber.has_method("force_release"):
		grabber.force_release()
		_detach()
	grabber = by
	var gp := get_grip_point()
	held_by_grip = gp != null and gp.global_position.distance_to(by.global_position) <= snap_grab_distance
	if held_by_grip:
		var gp_local := global_transform.affine_inverse() * gp.global_transform
		hold_offset = gp_local.affine_inverse()
	else:
		hold_offset = by.global_transform.affine_inverse() * global_transform
	_has_prev_target = false
	collision_layer = held_layer
	can_sleep = false
	sleeping = false
	_attach_hand_visual()
	grabbed.emit(by)
	return true


## Called by the HandGrabber that holds this object.
func release_from(by: Node3D) -> void:
	if grabber != by:
		return
	_detach()
	released.emit(by)


func _detach() -> void:
	_detach_hand_visual()
	grabber = null
	held_by_grip = false
	collision_layer = _free_layer
	can_sleep = true


## Temporarily weakens the hold (e.g. recoil), recovering over [param recover_time].
func set_hold_compliance(strength: float, recover_time: float) -> void:
	_strength = clampf(strength, 0.0, 1.0)
	_strength_recover = maxf(recover_time, 0.001)


## Where the hand should be drawn: the controller pose that would hold the object perfectly.
func _attach_hand_visual() -> void:
	var hand = grabber.get("collision_hand")
	if not held_by_grip or hand == null or not hand.has_method("add_target_override"):
		return
	_hand_anchor = Node3D.new()
	_hand_anchor.name = "HandAnchor"
	add_child(_hand_anchor)
	_hand_anchor.transform = hold_offset.affine_inverse()
	hand.add_target_override(_hand_anchor, 10)


func _detach_hand_visual() -> void:
	if _hand_anchor == null:
		return
	var hand = grabber.get("collision_hand") if grabber else null
	if hand and hand.has_method("remove_target_override"):
		hand.remove_target_override(_hand_anchor)
	_hand_anchor.queue_free()
	_hand_anchor = null


func _physics_process(delta: float) -> void:
	if _impact_cooldown > 0.0:
		_impact_cooldown -= delta
	if _strength < 1.0:
		_strength = minf(1.0, _strength + delta / _strength_recover)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_last_velocity = state.linear_velocity
	if grabber == null or not is_instance_valid(grabber):
		return
	var dt := state.step
	var target := grabber.global_transform * hold_offset
	var xf := state.transform

	var target_vel := Vector3.ZERO
	var target_ang := Vector3.ZERO
	if _has_prev_target:
		target_vel = (target.origin - _prev_target.origin) / dt
		target_ang = _rotation_vector(_prev_target.basis, target.basis) / dt
	_prev_target = target
	_has_prev_target = true

	# Linear: drive the centre of mass toward where it should be.
	var com_local := state.center_of_mass_local
	var com_err := target * com_local - xf * com_local
	# Obstructed: the hand is far from where the object can get to. Push gently
	# instead of grinding it into whatever is in the way.
	var reach := clampf(obstruction_distance / maxf(com_err.length(), 1e-4), obstructed_strength, 1.0)
	var strength := _strength * reach
	var desired_v := target_vel + com_err * linear_stiffness
	var force := (desired_v - state.linear_velocity) * mass / dt - state.total_gravity * mass
	force = force.limit_length(max_hold_force * strength)
	state.apply_central_force(force)

	# Angular: same idea with the inertia tensor.
	var desired_w := target_ang + _rotation_vector(xf.basis, target.basis) * angular_stiffness
	var inertia := state.inverse_inertia_tensor.inverse()
	var torque := inertia * ((desired_w - state.angular_velocity) / dt)
	torque = torque.limit_length(max_hold_torque * strength)
	state.apply_torque(torque)


## Axis * angle (rad) that rotates [param from] onto [param to], shortest way.
static func _rotation_vector(from: Basis, to: Basis) -> Vector3:
	var q := (to.orthonormalized() * from.orthonormalized().inverse()).get_rotation_quaternion()
	if q.w < 0.0:
		q = -q
	var angle := 2.0 * acos(clampf(q.w, -1.0, 1.0))
	if angle < 1e-6:
		return Vector3.ZERO
	return Vector3(q.x, q.y, q.z).normalized() * angle


func _on_body_entered(body: Node) -> void:
	var speed := _last_velocity.length()
	if speed < impact_min_speed or _impact_cooldown > 0.0:
		return
	_impact_cooldown = 0.08
	impacted.emit(Surface.of(body), speed, global_position)
