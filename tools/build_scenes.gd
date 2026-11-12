extends Node
## Generates the project's scenes from code, with real dimensions.
##
##   godot --headless --path . res://tools/BuildScenes.tscn
##
## Runs as a normal scene (not with -s) so autoloads exist and XR Tools
## scripts compile. After generation the .tscn files are normal scenes you can
## edit in the editor; re-running overwrites them.

const SceneBuilders := preload("res://tools/scene_builders.gd")


func _ready() -> void:
	var ok: bool = SceneBuilders.new().build_all()
	get_tree().quit(0 if ok else 1)
