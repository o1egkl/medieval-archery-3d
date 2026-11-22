extends Node

signal language_changed(lang_code: String)

const CSV_PATH := "res://localization/translations.csv"

var available_languages: Array[String] = []
var current_language: String = "ru"
var _table: Dictionary = {} # lang -> { key: text }

const LANGUAGE_LABELS := {
	"en": "English",
	"ru": "Русский",
	"he": "עברית",
	"es": "Español",
	"de": "Deutsch",
	"fr": "Français"
}

func _ready() -> void:
	_load_csv()
	var saved_lang := str(SaveManager.get_setting("language", "ru"))
	if saved_lang in available_languages:
		current_language = saved_lang
	elif available_languages.size() > 0:
		current_language = available_languages[0]

func _load_csv() -> void:
	if not FileAccess.file_exists(CSV_PATH):
		push_error("Missing translations CSV: " + CSV_PATH)
		return
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	var headers := file.get_csv_line()
	if headers.size() < 2:
		return
	available_languages.clear()
	for i in range(1, headers.size()):
		var code := headers[i].strip_edges()
		if code != "":
			available_languages.append(code)
			_table[code] = {}
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2:
			continue
		var key := row[0].strip_edges()
		if key == "":
			continue
		for i in range(1, min(row.size(), headers.size())):
			var code := headers[i].strip_edges()
			if _table.has(code):
				_table[code][key] = row[i]

func set_language(lang_code: String) -> void:
	if not (lang_code in available_languages):
		return
	current_language = lang_code
	SaveManager.set_setting("language", lang_code)
	emit_signal("language_changed", lang_code)

func get_language_display_name(lang_code: String) -> String:
	return LANGUAGE_LABELS.get(lang_code, lang_code.to_upper())

func t(key: String, params: Dictionary = {}) -> String:
	var text := key
	if _table.has(current_language) and _table[current_language].has(key):
		text = _table[current_language][key]
	elif _table.has("en") and _table["en"].has(key):
		text = _table["en"][key]
	for p in params.keys():
		text = text.replace("{" + str(p) + "}", str(params[p]))
	return text
