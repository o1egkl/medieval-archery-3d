extends Node

var _sfx_cache: Dictionary = {}
var _player_pool: Array[AudioStreamPlayer] = []
var _ambient_player: AudioStreamPlayer

func _ready() -> void:
	for i in range(6):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_player_pool.append(p)
	_ambient_player = AudioStreamPlayer.new()
	add_child(_ambient_player)
	_build_procedural_sfx()
	_ambient_player.stream = _make_wind_ambient(4.0, 0.055)
	sync_ambient_state()

func _build_procedural_sfx() -> void:
	_sfx_cache["ui_click"] = _make_tone(620.0, 480.0, 0.06, 0.25)
	_sfx_cache["bow_draw"] = _make_tone(140.0, 210.0, 0.14, 0.18)
	_sfx_cache["arrow_release"] = _make_noise_burst(0.14, 0.32)
	_sfx_cache["hit_target"] = _make_tone(190.0, 90.0, 0.12, 0.45)
	_sfx_cache["hit_bullseye"] = _make_tone(880.0, 1320.0, 0.22, 0.35)
	_sfx_cache["hit_penalty"] = _make_tone(240.0, 110.0, 0.25, 0.4)
	_sfx_cache["target_fall"] = _make_tone(125.0, 52.0, 0.26, 0.50)
	_sfx_cache["win"] = _make_tone(523.0, 784.0, 0.35, 0.35)
	_sfx_cache["fail"] = _make_tone(310.0, 180.0, 0.38, 0.35)

func _make_tone(freq_start: float, freq_end: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in range(count):
		var t := float(i) / float(maxi(count, 1))
		var freq := lerpf(freq_start, freq_end, t)
		phase += TAU * freq / float(sample_rate)
		var env := sin(t * PI)
		var sample := int(clampf(sin(phase) * env * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

func _make_noise_burst(duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(maxi(count, 1))
		var env := (1.0 - t) * (1.0 - t)
		var sample := int(clampf(randf_range(-1.0, 1.0) * env * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

func _make_wind_ambient(duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var lp := 0.0
	for i in range(count):
		var t := float(i) / float(maxi(count, 1))
		var swell := 0.65 + 0.35 * sin(t * TAU)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.025)
		var sample := int(clampf(lp * swell * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = count
	wav.data = data
	return wav

func sync_ambient_state() -> void:
	if _ambient_player == null or _ambient_player.stream == null:
		return
	var enabled := bool(SaveManager.get_setting("music_enabled", true))
	if enabled and not _ambient_player.playing:
		_ambient_player.play()
	elif not enabled and _ambient_player.playing:
		_ambient_player.stop()

func play_sfx(sfx_name: String) -> void:
	if not bool(SaveManager.get_setting("sound_enabled", true)):
		return
	if not _sfx_cache.has(sfx_name):
		return
	for p in _player_pool:
		if not p.playing:
			p.stream = _sfx_cache[sfx_name]
			p.play()
			return
	_player_pool[0].stream = _sfx_cache[sfx_name]
	_player_pool[0].play()

func vibrate(duration_ms: int = 25) -> void:
	if not bool(SaveManager.get_setting("haptics_enabled", true)):
		return
	Input.vibrate_handheld(duration_ms)
