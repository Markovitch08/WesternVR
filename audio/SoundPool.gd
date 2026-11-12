extends Node
## Autoload "SoundPool". Plays one-shot 3D sounds from a fixed pool of
## AudioStreamPlayer3D nodes, so audio nodes never pile up. When every player
## is busy the oldest sound is cut. Every play gets a small random pitch and
## volume variation so repeats don't sound identical. Supports delayed plays
## (echoes) without timers or extra nodes.

const POOL_SIZE := 32

var rng := RandomNumberGenerator.new()
var _players: Array[AudioStreamPlayer3D] = []
var _started: Array[float] = []
var _pending: Array[Dictionary] = []
var _clock := 0.0


func _ready() -> void:
	rng.randomize()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.name = "Voice%d" % i
		p.bus = &"World"
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_players.append(p)
		_started.append(-1.0)


## Plays the sound [param key] (see SoundLibrary) at [param position].
## Options: volume_db, pitch, pitch_var (fraction), volume_var (dB), unit_size,
## max_db, max_distance, delay (s), bus.
func play(key: String, position: Vector3, options := {}) -> AudioStreamPlayer3D:
	var stream := SoundLibrary.pick(key)
	if stream == null:
		return null
	return play_stream(stream, position, options)


func play_stream(stream: AudioStream, position: Vector3, options := {}) -> AudioStreamPlayer3D:
	var delay: float = options.get("delay", 0.0)
	if delay > 0.0:
		var o := options.duplicate()
		o.erase("delay")
		_pending.append({"at": _clock + delay, "stream": stream, "position": position, "options": o})
		return null
	var p := _take_player()
	var pv: float = options.get("pitch_var", 0.04)
	var vv: float = options.get("volume_var", 1.5)
	p.stream = stream
	p.global_position = position
	p.pitch_scale = maxf(0.05, options.get("pitch", 1.0) * (1.0 + rng.randf_range(-pv, pv)))
	p.volume_db = options.get("volume_db", 0.0) + rng.randf_range(-vv, vv)
	p.unit_size = options.get("unit_size", 2.0)
	p.max_db = options.get("max_db", 3.0)
	p.max_distance = options.get("max_distance", 0.0)
	p.bus = StringName(options.get("bus", "World"))
	p.play()
	_started[_players.find(p)] = _clock
	return p


func _take_player() -> AudioStreamPlayer3D:
	var oldest := 0
	for i in _players.size():
		if not _players[i].playing:
			return _players[i]
		if _started[i] < _started[oldest]:
			oldest = i
	_players[oldest].stop()
	return _players[oldest]


func _process(delta: float) -> void:
	_clock += delta
	if _pending.is_empty():
		return
	var due := _pending.filter(func(e): return e["at"] <= _clock)
	if due.is_empty():
		return
	_pending = _pending.filter(func(e): return e["at"] > _clock)
	for e in due:
		play_stream(e["stream"], e["position"], e["options"])


func player_count() -> int:
	return _players.size()


func playing_count() -> int:
	return _players.filter(func(p): return p.playing).size()


func pending_count() -> int:
	return _pending.size()
