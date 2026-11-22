extends Node

signal attempts_changed(remaining: int)

const DAILY_BASE_ATTEMPTS: int = 10
const RESET_HOUR_LOCAL: int = 6
const MAX_DAILY_BONUS: int = 3
const MAX_PERFECT_PER_DAY: int = 2
const MAX_ECONOMY_PER_DAY: int = 1

var _session_start_unix: int = 0
var _session_start_ticks_ms: int = 0

func _ready() -> void:
	_session_start_unix = int(Time.get_unix_time_from_system())
	_session_start_ticks_ms = Time.get_ticks_msec()
	refresh_if_needed(false)

func _get_effective_unix_time() -> int:
	var elapsed_sec := int((Time.get_ticks_msec() - _session_start_ticks_ms) / 1000)
	var monotonic_now := _session_start_unix + elapsed_sec
	var sys_now := int(Time.get_unix_time_from_system())
	var last_saved := int(SaveManager.data["attempts"].get("last_unix_time", 0))
	# Guard against clock rollback cheating
	return max(sys_now, max(monotonic_now, last_saved))

func _get_game_day_key() -> String:
	var tz := Time.get_time_zone_from_system()
	var local_unix := _get_effective_unix_time() + int(tz.get("bias", 0)) * 60
	# Shift back by RESET_HOUR_LOCAL so the game day flips at 06:00 local time
	var shifted := local_unix - RESET_HOUR_LOCAL * 3600
	var dt := Time.get_datetime_dict_from_unix_time(shifted)
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]

func refresh_if_needed(notify: bool = true) -> void:
	if GameConfig.is_paid_build():
		return
	var state: Dictionary = SaveManager.data["attempts"]
	var today := _get_game_day_key()
	var now_unix := _get_effective_unix_time()
	var changed := false
	if str(state.get("day_key", "")) != today:
		state["day_key"] = today
		state["remaining"] = DAILY_BASE_ATTEMPTS
		state["daily_bonus_earned"] = 0
		state["perfect_count_today"] = 0
		state["economy_count_today"] = 0
		changed = true
	state["last_unix_time"] = now_unix
	if changed:
		SaveManager.save()
		if notify:
			emit_signal("attempts_changed", int(state["remaining"]))

func get_remaining() -> int:
	if GameConfig.is_paid_build():
		return 999
	refresh_if_needed(false)
	return int(SaveManager.data["attempts"].get("remaining", DAILY_BASE_ATTEMPTS))

func can_play() -> bool:
	if GameConfig.is_paid_build():
		return true
	return get_remaining() > 0

func consume_on_fail() -> void:
	if GameConfig.is_paid_build():
		return
	refresh_if_needed(false)
	var state: Dictionary = SaveManager.data["attempts"]
	state["remaining"] = max(0, int(state["remaining"]) - 1)
	state["last_unix_time"] = _get_effective_unix_time()
	SaveManager.save()
	emit_signal("attempts_changed", int(state["remaining"]))

func evaluate_win_bonuses(level_id: int, stars: int, max_bullseye_streak: int, arrows_left: int, is_biome_boss: bool) -> Array[String]:
	var awarded_keys: Array[String] = []
	if GameConfig.is_paid_build():
		return awarded_keys
	refresh_if_needed(false)
	var state: Dictionary = SaveManager.data["attempts"]
	var bonus_earned := int(state.get("daily_bonus_earned", 0))

	# 1. Perfect Shot (+1, max 2/day, subject to daily cap +3)
	if (stars >= 3 or max_bullseye_streak >= 3) and bonus_earned < MAX_DAILY_BONUS:
		if int(state.get("perfect_count_today", 0)) < MAX_PERFECT_PER_DAY:
			state["remaining"] = int(state["remaining"]) + 1
			state["perfect_count_today"] = int(state["perfect_count_today"]) + 1
			bonus_earned += 1
			state["daily_bonus_earned"] = bonus_earned
			awarded_keys.append("bonus_perfect")

	# 2. Sniper Economy (+1, max 1/day, subject to daily cap +3)
	if arrows_left >= 2 and bonus_earned < MAX_DAILY_BONUS:
		if int(state.get("economy_count_today", 0)) < MAX_ECONOMY_PER_DAY:
			state["remaining"] = int(state["remaining"]) + 1
			state["economy_count_today"] = int(state["economy_count_today"]) + 1
			bonus_earned += 1
			state["daily_bonus_earned"] = bonus_earned
			awarded_keys.append("bonus_economy")

	# 3. Biome Boss First Clear (+2, one-time per biome act, outside daily cap)
	var bosses: Array = SaveManager.data.get("completed_bosses", [])
	if is_biome_boss and not (level_id in bosses):
		bosses.append(level_id)
		SaveManager.data["completed_bosses"] = bosses
		state["remaining"] = int(state["remaining"]) + 2
		awarded_keys.append("bonus_boss")

	state["last_unix_time"] = _get_effective_unix_time()
	SaveManager.save()
	emit_signal("attempts_changed", int(state["remaining"]))
	return awarded_keys
