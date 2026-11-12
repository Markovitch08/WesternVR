class_name HandGrabber
extends Node3D
## Lives under an XRController3D. Hold the grip button near a Grabbable to pick
## it up; let go and it drops. Also reads the controller's buttons for whatever
## it holds, and plays haptics.
##
## Inputs can be simulated (tests, desktop debugging) with [method simulate].

signal grabbed(object: Node3D)
signal released(object: Node3D)

## OpenXR action for grabbing.
@export var grip_action := "grip"
## Grip value that starts a grab.
@export_range(0.0, 1.0) var grab_threshold := 0.7
## Grip value below which the object is released.
@export_range(0.0, 1.0) var release_threshold := 0.35
## Radius of the grab zone around the palm (m).
@export var grab_radius := 0.07
## Layers searched for grabbable things: 3 pickables, 17 held, 19 grab handles.
@export_flags_3d_physics var grab_mask := (1 << 2) | (1 << 16) | (1 << 18)

var controller: XRController3D
var collision_hand: Node3D
var held: Node3D = null

var _area: Area3D
var _grip_down := false
var _sim := {}


func _ready() -> void:
	controller = get_parent() as XRController3D
	if controller:
		collision_hand = controller.get_node_or_null("CollisionHand")
	_area = Area3D.new()
	_area.name = "GrabZone"
	_area.collision_layer = 0
	_area.collision_mask = grab_mask
	_area.monitorable = false
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = grab_radius
	cs.shape = sphere
	_area.add_child(cs)
	add_child(_area)


func is_left() -> bool:
	return controller != null and controller.tracker == &"left_hand"


## The grabber of the other hand (or null).
func get_other() -> HandGrabber:
	if controller == null:
		return null
	for c in controller.get_parent().get_children():
		if c is XRController3D and c != controller:
			return c.get_node_or_null("HandGrabber") as HandGrabber
	return null


# --- Input ------------------------------------------------------------------

## Overrides an action value (float, bool or Vector2). Pass null to clear.
func simulate(action: String, value: Variant) -> void:
	if value == null:
		_sim.erase(action)
	else:
		_sim[action] = value


func get_float(action: String) -> float:
	if _sim.has(action):
		return float(_sim[action])
	return controller.get_float(action) if controller else 0.0


func is_pressed(action: String) -> bool:
	if _sim.has(action):
		return bool(_sim[action])
	return controller.is_button_pressed(action) if controller else false


func get_vector2(action: String) -> Vector2:
	if _sim.has(action):
		return _sim[action]
	return controller.get_vector2(action) if controller else Vector2.ZERO


## Vibrates this controller. Strong for shots, light for clicks.
func haptic(amplitude: float, duration: float, frequency := 0.0) -> void:
	if controller:
		controller.trigger_haptic_pulse("haptic", frequency, clampf(amplitude, 0.0, 1.0), duration, 0.0)


# --- Grabbing ---------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	var grip := get_float(grip_action)
	if not _grip_down and grip >= grab_threshold:
		_grip_down = true
		try_grab()
	elif _grip_down and grip <= release_threshold:
		_grip_down = false
		release()


## Grabs the nearest grabbable object, or takes one from a spawner (ammo box).
func try_grab() -> bool:
	if held:
		return true
	var best: Node3D = null
	var best_d := INF
	for b in _area.get_overlapping_bodies():
		if b is Grabbable:
			var gp: Node3D = b.get_grip_point()
			var p: Vector3 = gp.global_position if gp else b.global_position
			var d := p.distance_to(global_position) - (0.05 if gp else 0.0)
			if d < best_d:
				best_d = d
				best = b
	if best == null:
		for a in _area.get_overlapping_areas():
			if a.has_method("spawn_for_grabber"):
				best = a.spawn_for_grabber(self)
				if best:
					break
	if best == null or not best.try_grab(self):
		return false
	held = best
	grabbed.emit(held)
	return true


func release() -> void:
	if held == null:
		return
	var obj := held
	held = null
	if is_instance_valid(obj):
		obj.release_from(self)
	released.emit(obj)


## Called by an object when the other hand takes it.
func force_release() -> void:
	var obj := held
	held = null
	if obj:
		released.emit(obj)
