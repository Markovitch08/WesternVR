class_name SoundLibrary
extends RefCounted
## Finds the stream for a sound key. Real recordings win:
##   res://audio/sounds/<key>.ogg|.wav|.mp3   (one file)
##   res://audio/sounds/<key>_1.ogg, <key>_2.ogg ...  (variations, picked at random)
## otherwise the baked placeholder res://audio/generated/<key>.wav.

const REAL_DIR := "res://audio/sounds/"
const GENERATED_DIR := "res://audio/generated/"
const EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]

static var _cache := {}


static func streams(key: String) -> Array[AudioStream]:
	if _cache.has(key):
		return _cache[key]
	var found: Array[AudioStream] = []
	for ext in EXTENSIONS:
		var single := REAL_DIR + key + "." + ext
		if ResourceLoader.exists(single):
			found.append(load(single))
		for n in range(1, 10):
			var variant := "%s%s_%d.%s" % [REAL_DIR, key, n, ext]
			if ResourceLoader.exists(variant):
				found.append(load(variant))
	if found.is_empty():
		var gen := GENERATED_DIR + key + ".wav"
		if ResourceLoader.exists(gen):
			found.append(load(gen))
		else:
			push_warning("SoundLibrary: no sound for '%s'" % key)
	_cache[key] = found
	return found


static func pick(key: String) -> AudioStream:
	var list := streams(key)
	return list.pick_random() if not list.is_empty() else null


static func clear_cache() -> void:
	_cache.clear()
