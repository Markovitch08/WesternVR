class_name FrameRateGuard
extends Node
## Requests a high refresh rate, then drops to the fallback rate for good if the
## game can't hold it. Physics ticks always follow the display rate, so held
## objects track the hands once per displayed frame.
##
## Default: try 90 Hz, fall back to 72 Hz if the frame rate stays below
## [member hold_threshold] of the target for [member grace_seconds].
## Set [member preferred_rate] to 72 to stay at 72 Hz from the start.

## Rate to ask for first (Hz). 0 keeps the headset's default.
@export var preferred_rate := 90.0
## Rate to fall back to when the preferred rate isn't held (Hz).
@export var fallback_rate := 72.0
## Fraction of the target rate that counts as "held".
@export_range(0.5, 1.0) var hold_threshold := 0.97
## How long the rate may stay below the threshold before falling back (s).
@export var grace_seconds := 3.0
## Seconds to ignore after a rate change (loading hitches).
@export var settle_seconds := 5.0

## XR Tools StartXR node; it applies [member preferred_rate] when the session starts.
@export var start_xr: XRToolsStartXR

var _xr: XRInterface
var _below_time := 0.0
var _settle := 0.0
var _fell_back := false


func _ready() -> void:
	_xr = XRServer.find_interface("OpenXR")
	if start_xr:
		# StartXR picks the closest supported rate and matches physics to it.
		start_xr.target_refresh_rate = preferred_rate
		start_xr.physics_rate_multiplier = 1


func _apply_rate(rate: float) -> void:
	if not _xr:
		return
	_xr.set_display_refresh_rate(rate)
	Engine.physics_ticks_per_second = int(roundf(rate))
	_settle = settle_seconds
	_below_time = 0.0
	print("FrameRateGuard: display + physics rate set to %d Hz" % int(rate))


func _process(delta: float) -> void:
	if _fell_back or not _xr or not _xr.is_initialized():
		return
	var rate: float = _xr.get_display_refresh_rate()
	if rate <= fallback_rate + 0.5:
		return
	if _settle > 0.0:
		_settle -= delta
		return
	if Engine.get_frames_per_second() < rate * hold_threshold:
		_below_time += delta
		if _below_time >= grace_seconds:
			_fell_back = true
			push_warning("FrameRateGuard: %d Hz not held, falling back to %d Hz" % [int(rate), int(fallback_rate)])
			_apply_rate(fallback_rate)
	else:
		_below_time = maxf(0.0, _below_time - delta)
