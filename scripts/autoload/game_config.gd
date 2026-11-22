extends Node

# Set to true locally in the editor to test Paid edition behavior without exporting.
@export var debug_force_paid: bool = false

var levels: Array = []

func _ready() -> void:
	_load_levels()

func is_paid_build() -> bool:
	return debug_force_paid or OS.has_feature("paid")

func _load_levels() -> void:
	var path := "res://data/levels.json"
	if not FileAccess.file_exists(path):
		push_error("Missing levels.json at " + path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("levels"):
		levels = parsed["levels"]
	else:
		push_error("Invalid levels.json format")

func get_level(level_id: int) -> Dictionary:
	for lvl in levels:
		if int(lvl.get("id", 0)) == level_id:
			return lvl
	return levels[0] if levels.size() > 0 else {}

func get_level_count() -> int:
	return levels.size()
