extends Node

const SAVE_PATH := "user://save_data.json"

var data: Dictionary = {
	"unlocked_level": 1,
	"best_scores": {},
	"best_stars": {},
	"completed_bosses": [],
	"settings": {
		"language": "ru",
		"sound_enabled": true,
		"music_enabled": true,
		"haptics_enabled": true,
		"gyro_enabled": false,
		"aim_sensitivity": 1.0,
		"graphics_quality": "medium"
	},
	"attempts": {
		"day_key": "",
		"remaining": 10,
		"daily_bonus_earned": 0,
		"perfect_count_today": 0,
		"economy_count_today": 0,
		"last_unix_time": 0
	}
}

func _ready() -> void:
	load_save()

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_merge_dict(data, parsed)

func _merge_dict(target: Dictionary, incoming: Dictionary) -> void:
	for k in incoming.keys():
		if target.has(k) and typeof(target[k]) == TYPE_DICTIONARY and typeof(incoming[k]) == TYPE_DICTIONARY:
			_merge_dict(target[k], incoming[k])
		else:
			target[k] = incoming[k]

func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))

func record_level_win(level_id: int, score: int, stars: int) -> void:
	var key := str(level_id)
	var prev_score := int(data["best_scores"].get(key, 0))
	if score > prev_score:
		data["best_scores"][key] = score
	var prev_stars := int(data["best_stars"].get(key, 0))
	if stars > prev_stars:
		data["best_stars"][key] = stars
	var max_lvl := GameConfig.get_level_count()
	if level_id >= int(data["unlocked_level"]) and level_id < max_lvl:
		data["unlocked_level"] = level_id + 1
	save()

func get_setting(key: String, default_val = null):
	return data["settings"].get(key, default_val)

func set_setting(key: String, val) -> void:
	data["settings"][key] = val
	save()
