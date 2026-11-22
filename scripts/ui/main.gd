extends Node

const LevelSceneScript := preload("res://scripts/gameplay/level_scene.gd")

var level_scene: Node3D
var ui_layer: CanvasLayer

var menu_panel: Control
var levels_panel: Control
var help_panel: Control
var settings_panel: Control
var hud_panel: Control
var result_panel: Control
var attempts_modal: Control

var _current_level_id: int = 1
var _hud_score_lbl: Label
var _hud_wind_lbl: Label
var _hud_arrows_lbl: Label
var _hud_timer_lbl: Label
var _hud_feedback_lbl: Label
var _draw_bar: ProgressBar
var _reticle: ColorRect

func _ready() -> void:
	level_scene = LevelSceneScript.new()
	add_child(level_scene)
	level_scene.hud_updated.connect(_on_hud_updated)
	level_scene.hit_feedback.connect(_on_hit_feedback)
	level_scene.level_finished.connect(_on_level_finished)
	level_scene.camera.draw_changed.connect(_on_draw_changed)

	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	LocalizationManager.language_changed.connect(_rebuild_all_ui)
	AttemptsManager.attempts_changed.connect(func(_r): _rebuild_all_ui())

	_rebuild_all_ui()
	_show_screen("menu")

func _rebuild_all_ui(_unused = null) -> void:
	var prev_visible := "menu"
	if levels_panel and levels_panel.visible:
		prev_visible = "levels"
	elif help_panel and help_panel.visible:
		prev_visible = "help"
	elif settings_panel and settings_panel.visible:
		prev_visible = "settings"
	elif hud_panel and hud_panel.visible:
		prev_visible = "hud"

	for c in ui_layer.get_children():
		ui_layer.remove_child(c)
		c.queue_free()

	_build_menu()
	_build_levels()
	_build_help()
	_build_settings()
	_build_hud()
	_build_result_modal()
	_build_attempts_modal()
	_show_screen(prev_visible)

func _make_backdrop() -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.09, 0.08, 0.90)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	p.add_theme_stylebox_override("panel", sb)
	ui_layer.add_child(p)
	return p

func _make_button(text: String, cb: Callable, min_w: float = 260.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 52)
	b.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		cb.call()
	)
	return b

func _build_menu() -> void:
	menu_panel = _make_backdrop()
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	menu_panel.add_child(vbox)

	var title := Label.new()
	title.text = LocalizationManager.t("app_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)

	var ed := Label.new()
	ed.text = LocalizationManager.t("edition_paid") if GameConfig.is_paid_build() else LocalizationManager.t("edition_free")
	ed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ed.add_theme_color_override("font_color", Color(0.95, 0.78, 0.28))
	vbox.add_child(ed)

	var att := Label.new()
	att.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if GameConfig.is_paid_build():
		att.text = LocalizationManager.t("attempts_unlimited")
	else:
		att.text = LocalizationManager.t("attempts_badge", {"left": AttemptsManager.get_remaining(), "base": AttemptsManager.DAILY_BASE_ATTEMPTS})
	vbox.add_child(att)

	var btn_box := VBoxContainer.new()
	btn_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_box.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_box)

	btn_box.add_child(_make_button(LocalizationManager.t("btn_play"), func(): _try_start_level(int(SaveManager.data.get("unlocked_level", 1)))))
	btn_box.add_child(_make_button(LocalizationManager.t("btn_levels"), func(): _show_screen("levels")))
	btn_box.add_child(_make_button(LocalizationManager.t("btn_help"), func(): _show_screen("help")))
	btn_box.add_child(_make_button(LocalizationManager.t("btn_settings"), func(): _show_screen("settings")))

func _build_levels() -> void:
	levels_panel = _make_backdrop()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	levels_panel.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_child(_make_button(LocalizationManager.t("btn_back"), func(): _show_screen("menu"), 140.0))
	var hdr := Label.new()
	hdr.text = "  " + LocalizationManager.t("btn_levels")
	hdr.add_theme_font_size_override("font_size", 28)
	top.add_child(hdr)
	vbox.add_child(top)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	var unlocked := int(SaveManager.data.get("unlocked_level", 1))
	for lvl in GameConfig.levels:
		var id := int(lvl["id"])
		var stars := int(SaveManager.data["best_stars"].get(str(id), 0))
		var star_str := "★".repeat(stars) + "☆".repeat(3 - stars)
		var bname := LocalizationManager.t("biome_" + str(lvl["biome"]))
		var btn := _make_button("%d\n%s\n%s" % [id, bname.substr(0, 12), star_str], func(): _try_start_level(id), 210.0)
		btn.custom_minimum_size = Vector2(210, 96)
		btn.disabled = (id > unlocked)
		grid.add_child(btn)

func _build_help() -> void:
	help_panel = _make_backdrop()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	help_panel.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_child(_make_button(LocalizationManager.t("btn_back"), func(): _show_screen("menu"), 140.0))
	var hdr := Label.new()
	hdr.text = "  " + LocalizationManager.t("help_title")
	hdr.add_theme_font_size_override("font_size", 30)
	top.add_child(hdr)
	vbox.add_child(top)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	var sections := [
		["help_controls_title", "help_controls_body"],
		["help_ballistics_title", "help_ballistics_body"],
		["help_scoring_title", "help_scoring_body"],
		["help_attempts_title", "help_attempts_body"]
	]
	for s in sections:
		var h := Label.new()
		h.text = LocalizationManager.t(s[0])
		h.add_theme_font_size_override("font_size", 22)
		h.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
		content.add_child(h)
		var body := Label.new()
		body.text = LocalizationManager.t(s[1])
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", 18)
		content.add_child(body)

func _build_settings() -> void:
	settings_panel = _make_backdrop()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	settings_panel.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_child(_make_button(LocalizationManager.t("btn_back"), func(): _show_screen("menu"), 140.0))
	var hdr := Label.new()
	hdr.text = "  " + LocalizationManager.t("settings_title")
	hdr.add_theme_font_size_override("font_size", 30)
	top.add_child(hdr)
	vbox.add_child(top)

	# Language selector (dynamically populated from translations.csv columns)
	var lang_row := HBoxContainer.new()
	var lang_lbl := Label.new()
	lang_lbl.text = LocalizationManager.t("settings_language")
	lang_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(lang_lbl)
	var lang_opt := OptionButton.new()
	lang_opt.custom_minimum_size = Vector2(220, 44)
	var sel_idx := 0
	for i in range(LocalizationManager.available_languages.size()):
		var code := LocalizationManager.available_languages[i]
		lang_opt.add_item(LocalizationManager.get_language_display_name(code), i)
		if code == LocalizationManager.current_language:
			sel_idx = i
	lang_opt.select(sel_idx)
	lang_opt.item_selected.connect(func(idx): LocalizationManager.set_language(LocalizationManager.available_languages[idx]))
	lang_row.add_child(lang_opt)
	vbox.add_child(lang_row)

	# Toggles
	var toggles := [
		["settings_sound", "sound_enabled"],
		["settings_music", "music_enabled"],
		["settings_haptics", "haptics_enabled"],
		["settings_gyro", "gyro_enabled"]
	]
	for item in toggles:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = LocalizationManager.t(item[0])
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var cb := CheckButton.new()
		cb.button_pressed = bool(SaveManager.get_setting(item[1], true))
		cb.toggled.connect(func(v): SaveManager.set_setting(item[1], v))
		row.add_child(cb)
		vbox.add_child(row)

	# Aim sensitivity slider
	var sens_row := HBoxContainer.new()
	var sens_lbl := Label.new()
	sens_lbl.text = LocalizationManager.t("settings_sensitivity")
	sens_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sens_row.add_child(sens_lbl)
	var slider := HSlider.new()
	slider.min_value = 0.4
	slider.max_value = 2.0
	slider.step = 0.1
	slider.value = float(SaveManager.get_setting("aim_sensitivity", 1.0))
	slider.custom_minimum_size = Vector2(220, 36)
	slider.value_changed.connect(func(v): SaveManager.set_setting("aim_sensitivity", v))
	sens_row.add_child(slider)
	vbox.add_child(sens_row)

	# Graphics quality preset
	var q_row := HBoxContainer.new()
	var q_lbl := Label.new()
	q_lbl.text = LocalizationManager.t("settings_quality")
	q_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_row.add_child(q_lbl)
	var q_opt := OptionButton.new()
	q_opt.custom_minimum_size = Vector2(220, 44)
	var q_codes := ["low", "medium", "high"]
	var cur_q := str(SaveManager.get_setting("graphics_quality", "medium"))
	for i in range(q_codes.size()):
		q_opt.add_item(LocalizationManager.t("quality_" + q_codes[i]), i)
		if q_codes[i] == cur_q:
			q_opt.select(i)
	q_opt.item_selected.connect(func(idx): SaveManager.set_setting("graphics_quality", q_codes[idx]))
	q_row.add_child(q_opt)
	vbox.add_child(q_row)

func _build_hud() -> void:
	hud_panel = Control.new()
	hud_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(hud_panel)

	_hud_score_lbl = Label.new()
	_hud_score_lbl.position = Vector2(24, 18)
	_hud_score_lbl.add_theme_font_size_override("font_size", 24)
	hud_panel.add_child(_hud_score_lbl)

	_hud_wind_lbl = Label.new()
	_hud_wind_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_wind_lbl.offset_top = 18
	_hud_wind_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_wind_lbl.add_theme_font_size_override("font_size", 24)
	hud_panel.add_child(_hud_wind_lbl)

	_hud_timer_lbl = Label.new()
	_hud_timer_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_timer_lbl.offset_top = 52
	_hud_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_timer_lbl.add_theme_font_size_override("font_size", 22)
	hud_panel.add_child(_hud_timer_lbl)

	_hud_arrows_lbl = Label.new()
	_hud_arrows_lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hud_arrows_lbl.offset_left = 24
	_hud_arrows_lbl.offset_top = -54
	_hud_arrows_lbl.add_theme_font_size_override("font_size", 24)
	hud_panel.add_child(_hud_arrows_lbl)

	_hud_feedback_lbl = Label.new()
	_hud_feedback_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hud_feedback_lbl.offset_top = 110
	_hud_feedback_lbl.offset_left = -220
	_hud_feedback_lbl.offset_right = 220
	_hud_feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_feedback_lbl.add_theme_font_size_override("font_size", 28)
	hud_panel.add_child(_hud_feedback_lbl)

	var menu_btn := _make_button("II", func():
		level_scene.stop_level()
		_show_screen("menu")
	, 64.0)
	menu_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_btn.offset_left = -84
	menu_btn.offset_top = 16
	menu_btn.offset_right = -20
	menu_btn.offset_bottom = 68
	hud_panel.add_child(menu_btn)

	var cancel_btn := _make_button(LocalizationManager.t("btn_cancel_shot"), func(): level_scene.camera.cancel_draw(), 200.0)
	cancel_btn.button_down.connect(func(): level_scene.camera.cancel_draw())
	cancel_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cancel_btn.offset_left = -224
	cancel_btn.offset_top = -72
	cancel_btn.offset_right = -20
	cancel_btn.offset_bottom = -20
	hud_panel.add_child(cancel_btn)

	_reticle = ColorRect.new()
	_reticle.color = Color(1.0, 1.0, 1.0, 0.9)
	_reticle.size = Vector2(8, 8)
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.offset_left = -4
	_reticle.offset_top = -4
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_panel.add_child(_reticle)

	_draw_bar = ProgressBar.new()
	_draw_bar.min_value = 0.0
	_draw_bar.max_value = 100.0
	_draw_bar.show_percentage = false
	_draw_bar.set_anchors_preset(Control.PRESET_CENTER)
	_draw_bar.offset_left = -60
	_draw_bar.offset_right = 60
	_draw_bar.offset_top = 26
	_draw_bar.offset_bottom = 38
	_draw_bar.visible = false
	_draw_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_panel.add_child(_draw_bar)

func _build_result_modal() -> void:
	result_panel = _make_backdrop()
	result_panel.visible = false

func _build_attempts_modal() -> void:
	attempts_modal = _make_backdrop()
	attempts_modal.visible = false
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	attempts_modal.add_child(vbox)

	var title := Label.new()
	title.text = LocalizationManager.t("attempts_exhausted_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	var body := Label.new()
	body.text = LocalizationManager.t("attempts_exhausted_body")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	var ok_btn := _make_button(LocalizationManager.t("btn_main_menu"), func(): _show_screen("menu"))
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(ok_btn)

func _show_screen(screen_name: String) -> void:
	menu_panel.visible = (screen_name == "menu")
	levels_panel.visible = (screen_name == "levels")
	help_panel.visible = (screen_name == "help")
	settings_panel.visible = (screen_name == "settings")
	hud_panel.visible = (screen_name == "hud")
	result_panel.visible = (screen_name == "result")
	attempts_modal.visible = (screen_name == "no_attempts")

func _try_start_level(level_id: int) -> void:
	if not AttemptsManager.can_play():
		_show_screen("no_attempts")
		return
	_current_level_id = level_id
	_show_screen("hud")
	level_scene.start_level(level_id)

func _on_draw_changed(ratio: float, drawing: bool) -> void:
	if _draw_bar != null:
		_draw_bar.visible = drawing
		_draw_bar.value = ratio * 100.0

func _on_hud_updated(st: Dictionary) -> void:
	if _hud_score_lbl == null:
		return
	_hud_score_lbl.text = LocalizationManager.t("hud_level_score", {"level": st["level_id"], "score": st["score"], "target": st["target_score"]})
	var w := float(st["wind_speed"])
	var arrow_sym := "→" if w > 0.1 else ("←" if w < -0.1 else "•")
	_hud_wind_lbl.text = arrow_sym + " " + LocalizationManager.t("hud_wind", {"speed": "%.1f" % absf(w)})
	_hud_arrows_lbl.text = LocalizationManager.t("hud_arrows", {"left": st["arrows_left"], "total": st["arrows_total"]})
	_hud_timer_lbl.visible = bool(st["has_timer"])
	_hud_timer_lbl.text = LocalizationManager.t("hud_timer", {"sec": st["time_left"]})

func _on_hit_feedback(kind: String, pts: int) -> void:
	if _hud_feedback_lbl == null:
		return
	match kind:
		"bullseye":
			_hud_feedback_lbl.text = LocalizationManager.t("hit_bullseye", {"pts": pts})
		"barrel":
			_hud_feedback_lbl.text = LocalizationManager.t("hit_barrel", {"pts": pts})
		"penalty":
			_hud_feedback_lbl.text = LocalizationManager.t("hit_penalty", {"pts": pts})
		_:
			_hud_feedback_lbl.text = LocalizationManager.t("hit_ring", {"pts": pts})

func _on_level_finished(res: Dictionary) -> void:
	for c in result_panel.get_children():
		c.queue_free()
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	result_panel.add_child(vbox)

	var title := Label.new()
	title.text = LocalizationManager.t("result_win") if bool(res["won"]) else LocalizationManager.t("result_fail")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	var sc := Label.new()
	sc.text = LocalizationManager.t("result_score", {"score": res["score"], "target": res["target_score"]})
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sc)

	var st := Label.new()
	st.text = LocalizationManager.t("result_stars", {"stars": res["stars"]})
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(st)

	for bkey in res.get("bonuses", []):
		var bl := Label.new()
		bl.text = LocalizationManager.t(bkey)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
		vbox.add_child(bl)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 14)
	vbox.add_child(btns)

	btns.add_child(_make_button(LocalizationManager.t("btn_retry"), func(): _try_start_level(_current_level_id), 180.0))
	if bool(res["won"]) and _current_level_id < GameConfig.get_level_count():
		btns.add_child(_make_button(LocalizationManager.t("btn_next_level"), func(): _try_start_level(_current_level_id + 1), 200.0))
	btns.add_child(_make_button(LocalizationManager.t("btn_main_menu"), func(): _show_screen("menu"), 180.0))

	_show_screen("result")
