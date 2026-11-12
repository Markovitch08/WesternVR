class_name RevolverMechanism
extends RefCounted
## The Colt Single Action Army's lockwork as pure rules (no nodes), so it can
## be unit-tested and reused by the visual gun.
##
## Cylinder model (viewed from behind, the Colt cylinder turns clockwise):
## [member index] is the chamber lined up with the barrel when the hammer is down
## or at full cock. Cocking turns the cylinder one chamber (index + 1).
## Half-cock frees the cylinder half a chamber further round, which lines the
## chamber at 3 o'clock (index - 1) up with the loading gate.

## Emitted for everything that should make a sound or a haptic pulse.
## Names: half_cock, full_cock, hammer_lowered, trigger_break, fired, dry_fire,
## gate_opened, gate_closed, chamber_click, ejector_stroke, ejected, round_inserted.
signal event(name: StringName, data: Dictionary)

enum Hammer { DOWN, HALF, FULL }
enum Chamber { EMPTY, LIVE, SPENT }

const CHAMBERS := 6
## At half-cock the loading gate exposes this chamber relative to [member index].
const GATE_OFFSET := -1
## Trigger value at which the sear releases a fully cocked hammer.
const TRIGGER_BREAK := 0.75
## Trigger value below which the trigger counts as released again.
const TRIGGER_RESET := 0.35

var chambers: Array[int] = []
var index := 0
var hammer := Hammer.DOWN
var gate_open := false
var trigger := 0.0
var _trigger_armed := true


func _init(loaded := 0) -> void:
	chambers.resize(CHAMBERS)
	chambers.fill(Chamber.EMPTY)
	for i in loaded:
		# Load the way it was carried: the chamber under the hammer stays empty.
		chambers[(i + 1) % CHAMBERS] = Chamber.LIVE


func live_count() -> int:
	return chambers.count(Chamber.LIVE)


## Chamber lined up with the loading gate (only meaningful at half-cock).
func gate_chamber() -> int:
	return posmod(index + GATE_OFFSET, CHAMBERS)


## True when a chamber is lined up with the open gate.
func gate_chamber_accessible() -> bool:
	return gate_open and hammer == Hammer.HALF


func can_spin() -> bool:
	return gate_open and hammer == Hammer.HALF


## Cylinder position in chambers, for drawing (half-cock sits half a chamber on).
func cylinder_position() -> float:
	return float(index) + (0.5 if hammer == Hammer.HALF else 0.0)


# --- Hammer ---------------------------------------------------------------------

## Thumbs the hammer to full cock (clicking past half-cock). Turns the cylinder.
func cock() -> bool:
	if hammer == Hammer.FULL:
		return false
	if hammer == Hammer.DOWN:
		_emit(&"half_cock")
	index = posmod(index + 1, CHAMBERS)
	hammer = Hammer.FULL
	_emit(&"full_cock", {"chamber": index})
	return true


## Hammer down -> half-cock (the loading notch).
func half_cock() -> bool:
	if hammer != Hammer.DOWN:
		return false
	hammer = Hammer.HALF
	_emit(&"half_cock")
	return true


## Lowers the hammer under thumb control. From half-cock the cylinder clicks on
## to the next stop; from full cock it stays where it is.
func lower_hammer() -> bool:
	match hammer:
		Hammer.HALF:
			index = posmod(index + 1, CHAMBERS)
		Hammer.FULL:
			pass
		_:
			return false
	hammer = Hammer.DOWN
	_emit(&"hammer_lowered", {"chamber": index})
	return true


# --- Trigger --------------------------------------------------------------------

## Feeds the analog trigger value (0..1). Fires only when the hammer is at full
## cock and the trigger is pulled through the break; nothing happens otherwise.
## Returns "fired", "dry_fire" or "" (nothing).
func set_trigger(value: float) -> StringName:
	trigger = clampf(value, 0.0, 1.0)
	if trigger <= TRIGGER_RESET:
		_trigger_armed = true
		return &""
	if not _trigger_armed or trigger < TRIGGER_BREAK:
		return &""
	_trigger_armed = false
	if hammer != Hammer.FULL:
		return &""
	hammer = Hammer.DOWN
	_emit(&"trigger_break")
	if chambers[index] == Chamber.LIVE:
		chambers[index] = Chamber.SPENT
		_emit(&"fired", {"chamber": index})
		return &"fired"
	_emit(&"dry_fire", {"chamber": index, "state": chambers[index]})
	return &"dry_fire"


# --- Gate, cylinder, ejector ------------------------------------------------------

func open_gate() -> bool:
	if gate_open:
		return false
	gate_open = true
	_emit(&"gate_opened")
	return true


func close_gate() -> bool:
	if not gate_open:
		return false
	gate_open = false
	_emit(&"gate_closed")
	return true


func toggle_gate() -> void:
	if gate_open:
		close_gate()
	else:
		open_gate()


## Turns the free cylinder one chamber (half-cock with the gate open only).
func spin() -> bool:
	if not can_spin():
		return false
	index = posmod(index + 1, CHAMBERS)
	_emit(&"chamber_click", {"gate_chamber": gate_chamber()})
	return true


## A full stroke of the ejector rod. Pushes out whatever is in the gate chamber,
## but only when the gate is open at half-cock. Returns the ejected state
## (Chamber.LIVE or SPENT) or -1 if nothing came out.
func eject() -> int:
	_emit(&"ejector_stroke")
	if not gate_chamber_accessible():
		return -1
	var c := gate_chamber()
	var state := chambers[c]
	if state == Chamber.EMPTY:
		return -1
	chambers[c] = Chamber.EMPTY
	_emit(&"ejected", {"chamber": c, "state": state})
	return state


## Slides a cartridge into the gate chamber if it is empty and reachable.
func insert_round() -> bool:
	if not gate_chamber_accessible():
		return false
	var c := gate_chamber()
	if chambers[c] != Chamber.EMPTY:
		return false
	chambers[c] = Chamber.LIVE
	_emit(&"round_inserted", {"chamber": c})
	return true


func _emit(name: StringName, data := {}) -> void:
	event.emit(name, data)
