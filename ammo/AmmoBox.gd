class_name AmmoBox
extends Area3D
## The grab zone of a box of cartridges: close your hand in it to take one round.

## Rounds left in the box.
@export var rounds := 50
@export var cartridge_scene: PackedScene = preload("res://ammo/Cartridge.tscn")


## Called by a HandGrabber: gives it one live cartridge, or null if empty.
func spawn_for_grabber(grabber: Node3D) -> Node3D:
	if rounds <= 0:
		return null
	rounds -= 1
	var c: Cartridge = cartridge_scene.instantiate()
	c.spent = false
	var world := get_tree().current_scene if get_tree().current_scene else get_parent()
	world.add_child(c)
	c.global_transform = grabber.global_transform
	return c
