class_name Surface
extends RefCounted
## Surface types used for impact effects, decals and landing sounds.
## Tag a collider with metadata `surface` = "dirt" / "wood" / "metal" / "rock",
## or put it in a group of the same name. Untagged colliders count as dirt.

const DIRT := &"dirt"
const WOOD := &"wood"
const METAL := &"metal"
const ROCK := &"rock"
const ALL: Array[StringName] = [DIRT, WOOD, METAL, ROCK]


static func of(obj: Object) -> StringName:
	if obj == null:
		return DIRT
	if obj.has_meta(&"surface"):
		return StringName(obj.get_meta(&"surface"))
	if obj is Node:
		for s in ALL:
			if (obj as Node).is_in_group(s):
				return s
	if &"surface" in obj:
		return StringName(obj.get(&"surface"))
	return DIRT
