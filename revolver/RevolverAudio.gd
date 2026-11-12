class_name RevolverAudio
extends Node
## All of the revolver's sounds. Lives as child "Audio" of the Revolver.
##
## The shot is three layers: a sharp close crack and a deep boom at the muzzle,
## then the tail: one echo per reflecting surface (nodes in group
## "echo_reflector"), delayed by the extra path length and played from the
## reflector, plus a soft far tail.

const SPEED_OF_SOUND := 343.0

## Event name -> [sound key, volume_db, part it comes from].
const MECHANICAL := {
	&"half_cock": ["hammer_half_cock", -8.0, "Hammer"],
	&"full_cock": ["hammer_full_cock", -5.0, "Hammer"],
	&"hammer_lowered": ["hammer_lower", -10.0, "Hammer"],
	&"trigger_break": ["trigger_break", -10.0, "Trigger"],
	&"dry_fire": ["dry_fire", -2.0, "Hammer"],
	&"gate_opened": ["gate_open", -8.0, "LoadingGate"],
	&"gate_closed": ["gate_close", -8.0, "LoadingGate"],
	&"chamber_click": ["cylinder_click", -10.0, "Cylinder"],
	&"ejector_stroke": ["ejector_rod", -9.0, "EjectorRod"],
	&"ejected": ["case_eject", -7.0, "LoadingGate"],
	&"round_inserted": ["round_insert", -7.0, "LoadingGate"],
}

@export var crack_db := 8.0
@export var boom_db := 6.0
@export var echo_db := 2.0
## Soft tail that always plays (the open desert), even with no reflectors.
@export var far_tail_db := -8.0
@export var far_tail_delay := 0.22

var gun: Revolver


func _ready() -> void:
	gun = get_parent() as Revolver
	if gun:
		gun.mechanism_event.connect(_on_event)


func _on_event(name: StringName, _data: Dictionary) -> void:
	if name == &"fired":
		play_shot()
		return
	if MECHANICAL.has(name):
		var m: Array = MECHANICAL[name]
		var src := gun.part(m[2])
		var pos: Vector3 = src.global_position if src else gun.global_position
		SoundPool.play(m[0], pos, {"volume_db": m[1], "unit_size": 0.6, "pitch_var": 0.05})


func play_shot() -> void:
	var muzzle := gun.get_muzzle_position()
	SoundPool.play("shot_crack", muzzle, {"volume_db": crack_db, "unit_size": 14.0, "max_db": 6.0, "pitch_var": 0.03})
	SoundPool.play("shot_boom", muzzle, {"volume_db": boom_db, "unit_size": 25.0, "max_db": 6.0, "pitch_var": 0.06})
	var listener := _listener_position(muzzle)
	for e in echoes(muzzle, listener, _reflectors()):
		SoundPool.play("shot_tail", e["position"], {"volume_db": echo_db + e["gain_db"],
				"unit_size": 30.0, "delay": e["delay"], "pitch_var": 0.08})
	SoundPool.play("shot_tail", muzzle + Vector3.UP * 3.0, {"volume_db": far_tail_db,
			"unit_size": 20.0, "delay": far_tail_delay, "pitch": 0.85})


## For each reflector: when its echo arrives after the direct sound, and how
## much quieter it is from the extra distance. Pure, for tests.
static func echoes(source: Vector3, listener: Vector3, reflectors: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var direct := source.distance_to(listener)
	for r in reflectors:
		var pos: Vector3 = r["position"]
		var to_wall := source.distance_to(pos)
		var back := pos.distance_to(listener)
		var delay := (to_wall + back - direct) / SPEED_OF_SOUND
		# Spreading loss on the way out; the 3D player handles the way back.
		var gain := float(r.get("reflectivity_db", 0.0)) - 20.0 * log(maxf(to_wall, 5.0) / 5.0) / log(10.0)
		out.append({"position": pos, "delay": delay, "gain_db": gain})
	return out


func _reflectors() -> Array:
	var list := []
	for n in gun.get_tree().get_nodes_in_group(&"echo_reflector"):
		if n is Node3D:
			list.append({"position": n.global_position,
					"reflectivity_db": float(n.get_meta(&"reflectivity_db", 0.0))})
	return list


func _listener_position(fallback: Vector3) -> Vector3:
	var cam := gun.get_viewport().get_camera_3d()
	return cam.global_position if cam else fallback
