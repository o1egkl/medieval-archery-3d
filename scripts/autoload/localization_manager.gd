extends Node

signal language_changed(lang_code: String)

const JSON_PATH := "res://localization/translations.json"

var available_languages: Array[String] = []
var current_language: String = "ru"
var _strings: Dictionary = {} # key -> { lang: text }

const LANGUAGE_LABELS := {
	"en": "English",
	"ru": "Русский",
	"he": "עברית",
	"es": "Español",
	"de": "Deutsch",
	"fr": "Français"
}

func _ready() -> void:
	_load_json()
	var saved_lang := str(SaveManager.get_setting("language", "ru"))
	if saved_lang in available_languages:
		current_language = saved_lang
	elif available_languages.size() > 0:
		current_language = available_languages[0]

func _load_json() -> void:
	if not FileAccess.file_exists(JSON_PATH):
		push_error("Missing translations JSON: " + JSON_PATH)
		return
	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid translations JSON")
		return
	available_languages.clear()
	for lang in parsed.get("languages", ["en", "ru"]):
		available_languages.append(str(lang))
	_strings = parsed.get("strings", {})

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
	if _strings.has(key) and typeof(_strings[key]) == TYPE_DICTIONARY:
		var entry: Dictionary = _strings[key]
		if entry.has(current_language):
			text = str(entry[current_language])
		elif entry.has("en"):
			text = str(entry["en"])
	for p in params.keys():
		text = text.replace("{" + str(p) + "}", str(params[p]))
	return text
