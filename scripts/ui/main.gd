extends Node

const LevelSceneScript := preload("res://scripts/gameplay/level_scene.gd")
const ReticleScript := preload("res://scripts/ui/reticle_overlay.gd")
const HitDiagramScript := preload("res://scripts/ui/hit_diagram.gd")

var level_scene: Node3D
var ui_layer: CanvasLayer

var menu_panel: Control
var levels_panel: Control
var help_panel: Control
var settings_panel: Control
var hud_panel: Control
var pause_panel: Control
var result_panel: Control
var attempts_modal: Control

var _current_level_id: int = 1
var _hud_score_lbl: Label
var _hud_combo_lbl: Label
var _hud_wind_lbl: Label
var _hud_arrows_lbl: Label
var _hud_timer_lbl: Label
var _hud_feedback_lbl: Label
var _reticle_overlay: Control
var _hit_diagram: Control
var _hud_feedback_pill: PanelContainer
var _hud_combo_pill: PanelContainer
var _cancel_btn: Button

func _ready() -> void:
	level_scene = LevelSceneScript.new()
	add_child(level_scene)
	level_scene.hud_updated.connect(_on_hud_updated)
	level_scene.hit_feedback.connect(_on_hit_feedback)
	level_scene.level_finished.connect(_on_level_finished)
	level_scene.camera.draw_changed.connect(_on_draw_changed)
	level_scene.camera.input_mode_changed.connect(_on_input_mode_changed)

	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	LocalizationManager.language_changed.connect(_rebuild_all_ui)
	AttemptsManager.attempts_changed.connect(func(_r): _rebuild_all_ui())

	_apply_graphics_quality()
	_rebuild_all_ui()
	_show_screen("menu")

func _apply_graphics_quality() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var q := str(SaveManager.get_setting("graphics_quality", "medium"))
	match q:
		"low":
			vp.msaa_3d = Viewport.MSAA_DISABLED
		"high":
			vp.msaa_3d = Viewport.MSAA_4X
		_:
			vp.msaa_3d = Viewport.MSAA_2X

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
	elif pause_panel and pause_panel.visible:
		prev_visible = "pause"

	for c in ui_layer.get_children():
		ui_layer.remove_child(c)
		c.queue_free()

	_build_menu()
	_build_levels()
	_build_help()
	_build_settings()
	_build_hud()
	_build_pause_modal()
	_build_result_modal()
	_build_attempts_modal()
	_show_screen(prev_visible)

func _make_medieval_style(bg: Color, border: Color, radius: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_size = 6
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	return sb

func _make_backdrop(alpha: float = 0.72) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.05, alpha)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	p.add_theme_stylebox_override("panel", sb)
	ui_layer.add_child(p)
	return p

func _make_button(text: String, cb: Callable, min_w: float = 280.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 54)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	b.add_theme_stylebox_override("normal", _make_medieval_style(Color(0.24, 0.16, 0.10, 0.95), Color(0.76, 0.58, 0.28), 12))
	b.add_theme_stylebox_override("hover", _make_medieval_style(Color(0.34, 0.22, 0.13, 0.98), Color(0.96, 0.78, 0.34), 12))
	b.add_theme_stylebox_override("pressed", _make_medieval_style(Color(0.16, 0.10, 0.06, 0.98), Color(0.96, 0.78, 0.34), 12))
	b.add_theme_stylebox_override("disabled", _make_medieval_style(Color(0.14, 0.11, 0.09, 0.65), Color(0.42, 0.34, 0.22, 0.60), 12))
	b.add_theme_color_override("font_disabled_color", Color(0.65, 0.60, 0.52, 0.75))
	b.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		cb.call()
	)
	return b

func _make_hud_pill(parent: Control, bg: Color = Color(0.18, 0.12, 0.08, 0.86)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _make_medieval_style(bg, Color(0.74, 0.58, 0.32, 0.92), 18))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func _build_menu() -> void:
	# Translucent overlay so the live sunlit 3D medieval tournament arena is visible behind!
	menu_panel = _make_backdrop(0.36)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	menu_panel.add_child(vbox)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", _make_medieval_style(Color(0.14, 0.10, 0.07, 0.88), Color(0.84, 0.66, 0.32), 20))
	vbox.add_child(card)

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 14)
	card.add_child(inner)

	var title := Label.new()
	title.text = LocalizationManager.t("app_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.98, 0.90, 0.66))
	inner.add_child(title)

	var ed := Label.new()
	ed.text = LocalizationManager.t("edition_paid") if GameConfig.is_paid_build() else LocalizationManager.t("edition_free")
	ed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ed.add_theme_color_override("font_color", Color(0.95, 0.78, 0.28))
	inner.add_child(ed)

	var att := Label.new()
	att.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if GameConfig.is_paid_build():
		att.text = LocalizationManager.t("attempts_unlimited")
	else:
		att.text = LocalizationManager.t("attempts_badge", {"left": AttemptsManager.get_remaining(), "base": AttemptsManager.DAILY_BASE_ATTEMPTS})
	inner.add_child(att)

	var btn_box := VBoxContainer.new()
	btn_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_box.add_theme_constant_override("separation", 10)
	inner.add_child(btn_box)

	btn_box.add_child(_make_button(LocalizationManager.t("btn_play"), func(): _try_start_level(int(SaveManager.data.get("unlocked_level", 1)))))
	btn_box.add_child(_make_button(LocalizationManager.t("btn_levels"), func(): _show_screen("levels")))
	btn_box.add_child(_make_button(LocalizationManager.t("btn_help"), func(): _show_screen("help")))
	btn_box.add_child(_make_button(LocalizationManager.t("btn_settings"), func(): _show_screen("settings")))

func _build_levels() -> void:
	levels_panel = _make_backdrop(0.84)
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
	var vp_w := get_viewport().get_visible_rect().size.x
	grid.columns = maxi(2, mini(5, int(vp_w / 240.0)))
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	help_panel = _make_backdrop(0.86)
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
	settings_panel = _make_backdrop(0.86)
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
	if lang_opt.item_count > 0:
		lang_opt.select(sel_idx)
	lang_opt.item_selected.connect(func(idx): LocalizationManager.set_language(LocalizationManager.available_languages[idx]))
	lang_row.add_child(lang_opt)
	vbox.add_child(lang_row)

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
		var setting_key: String = item[1]
		cb.toggled.connect(func(v):
			SaveManager.set_setting(setting_key, v)
			if setting_key == "music_enabled":
				AudioManager.sync_ambient_state()
		)
		row.add_child(cb)
		vbox.add_child(row)

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
	q_opt.item_selected.connect(func(idx):
		SaveManager.set_setting("graphics_quality", q_codes[idx])
		_apply_graphics_quality()
	)
	q_row.add_child(q_opt)
	vbox.add_child(q_row)

func _build_hud() -> void:
	hud_panel = Control.new()
	hud_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(hud_panel)

	# Top-left medieval wood badge: Level & Score
	var score_pill := _make_hud_pill(hud_panel)
	score_pill.position = Vector2(20, 16)
	_hud_score_lbl = Label.new()
	_hud_score_lbl.add_theme_font_size_override("font_size", 22)
	_hud_score_lbl.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	score_pill.add_child(_hud_score_lbl)

	# Combo badge under score pill
	_hud_combo_pill = _make_hud_pill(hud_panel, Color(0.36, 0.18, 0.08, 0.90))
	_hud_combo_pill.position = Vector2(20, 74)
	_hud_combo_pill.visible = false
	_hud_combo_lbl = Label.new()
	_hud_combo_lbl.add_theme_font_size_override("font_size", 18)
	_hud_combo_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	_hud_combo_pill.add_child(_hud_combo_lbl)

	# Top-center slate pill: Wind direction & speed
	var wind_pill := _make_hud_pill(hud_panel, Color(0.24, 0.34, 0.44, 0.84))
	wind_pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wind_pill.offset_top = 16
	wind_pill.offset_left = -115
	wind_pill.offset_right = 115
	_hud_wind_lbl = Label.new()
	_hud_wind_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_wind_lbl.add_theme_font_size_override("font_size", 22)
	wind_pill.add_child(_hud_wind_lbl)

	_hud_timer_lbl = Label.new()
	_hud_timer_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_timer_lbl.offset_top = 72
	_hud_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_timer_lbl.add_theme_font_size_override("font_size", 22)
	_hud_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.36))
	hud_panel.add_child(_hud_timer_lbl)

	# Bottom-left quiver counter pill
	var arrows_pill := _make_hud_pill(hud_panel)
	arrows_pill.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	arrows_pill.offset_left = 20
	arrows_pill.offset_top = -66
	arrows_pill.offset_bottom = -18
	_hud_arrows_lbl = Label.new()
	_hud_arrows_lbl.add_theme_font_size_override("font_size", 22)
	_hud_arrows_lbl.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	arrows_pill.add_child(_hud_arrows_lbl)

	_hud_feedback_pill = _make_hud_pill(hud_panel, Color(0.14, 0.10, 0.07, 0.88))
	_hud_feedback_pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hud_feedback_pill.offset_top = 104
	_hud_feedback_pill.offset_left = -190
	_hud_feedback_pill.offset_right = 190
	_hud_feedback_pill.visible = false
	_hud_feedback_lbl = Label.new()
	_hud_feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_feedback_lbl.add_theme_font_size_override("font_size", 26)
	_hud_feedback_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.28))
	_hud_feedback_pill.add_child(_hud_feedback_lbl)

	# 2D Target Closeup Impact Diagram in top-right (shows exact hit point)
	_hit_diagram = HitDiagramScript.new()
	_hit_diagram.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hit_diagram.offset_left = -182
	_hit_diagram.offset_top = 84
	_hit_diagram.offset_right = -20
	_hit_diagram.offset_bottom = 246
	_hit_diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_diagram.visible = false
	hud_panel.add_child(_hit_diagram)

	var menu_btn := _make_button("II", func(): _open_pause(), 58.0)
	menu_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_btn.offset_left = -78
	menu_btn.offset_top = 16
	menu_btn.offset_right = -20
	menu_btn.offset_bottom = 68
	hud_panel.add_child(menu_btn)

	var cancel_key := "cancel_hint_touch" if level_scene.camera.is_touch_mode else "cancel_hint_desktop"
	_cancel_btn = _make_button(LocalizationManager.t(cancel_key), func(): level_scene.camera.cancel_draw(), 300.0)
	_cancel_btn.add_theme_stylebox_override("normal", _make_medieval_style(Color(0.46, 0.14, 0.10, 0.94), Color(0.96, 0.76, 0.30), 14))
	_cancel_btn.add_theme_stylebox_override("hover", _make_medieval_style(Color(0.58, 0.18, 0.12, 0.98), Color(1.0, 0.86, 0.36), 14))
	_cancel_btn.button_down.connect(func(): level_scene.camera.cancel_draw())
	_cancel_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_cancel_btn.offset_left = -330
	_cancel_btn.offset_top = -76
	_cancel_btn.offset_right = -20
	_cancel_btn.offset_bottom = -18
	_cancel_btn.visible = false
	hud_panel.add_child(_cancel_btn)

	# Circular white reticle + curved golden tension arc
	_reticle_overlay = ReticleScript.new()
	_reticle_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reticle_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_panel.add_child(_reticle_overlay)

func _build_pause_modal() -> void:
	pause_panel = _make_backdrop(0.76)
	pause_panel.visible = false
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	pause_panel.add_child(vbox)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", _make_medieval_style(Color(0.14, 0.10, 0.07, 0.92), Color(0.84, 0.66, 0.32), 20))
	vbox.add_child(card)

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 12)
	card.add_child(inner)

	inner.add_child(_make_button(LocalizationManager.t("btn_resume"), func(): _resume_game()))
	inner.add_child(_make_button(LocalizationManager.t("btn_retry"), func(): _try_start_level(_current_level_id)))
	inner.add_child(_make_button(LocalizationManager.t("btn_main_menu"), func():
		level_scene.show_menu_backdrop()
		_show_screen("menu")
	))

func _open_pause() -> void:
	if not level_scene.level_active or level_scene.is_paused:
		return
	level_scene.set_paused(true)
	_show_screen("pause")

func _resume_game() -> void:
	if not level_scene.level_active:
		return
	_show_screen("hud")
	level_scene.set_paused(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if hud_panel != null and hud_panel.visible and level_scene.level_active and not level_scene.is_paused:
			_open_pause()
			get_viewport().set_input_as_handled()
		elif pause_panel != null and pause_panel.visible:
			_resume_game()
			get_viewport().set_input_as_handled()

func _build_result_modal() -> void:
	result_panel = _make_backdrop(0.80)
	result_panel.visible = false

func _build_attempts_modal() -> void:
	attempts_modal = _make_backdrop(0.84)
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
	pause_panel.visible = (screen_name == "pause")
	result_panel.visible = (screen_name == "result")
	attempts_modal.visible = (screen_name == "no_attempts")
	if screen_name != "hud" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _try_start_level(level_id: int) -> void:
	if not AttemptsManager.can_play():
		_show_screen("no_attempts")
		return
	_current_level_id = level_id
	_show_screen("hud")
	if _hit_diagram != null:
		_hit_diagram.reset_hits()
	if _hud_feedback_pill != null:
		_hud_feedback_pill.visible = false
	level_scene.start_level(level_id)

func _on_input_mode_changed(is_touch: bool) -> void:
	if _cancel_btn != null:
		_cancel_btn.text = LocalizationManager.t("cancel_hint_touch" if is_touch else "cancel_hint_desktop")

func _on_draw_changed(ratio: float, drawing: bool) -> void:
	if _reticle_overlay != null:
		_reticle_overlay.set_draw_state(ratio, drawing)
	if _cancel_btn != null:
		_cancel_btn.visible = drawing
		level_scene.camera.cancel_zone_rect = _cancel_btn.get_global_rect() if drawing else Rect2()

func _on_hud_updated(st: Dictionary) -> void:
	if _hud_score_lbl == null:
		return
	_hud_score_lbl.text = LocalizationManager.t("hud_level_score", {"level": st["level_id"], "score": st["score"], "target": st["target_score"]})
	var w := float(st["wind_speed"])
	var arrow_sym := ">>" if w > 0.1 else ("<<" if w < -0.1 else "--")
	_hud_wind_lbl.text = arrow_sym + " " + LocalizationManager.t("hud_wind", {"speed": "%.1f" % absf(w)})
	_hud_arrows_lbl.text = LocalizationManager.t("hud_arrows", {"left": st["arrows_left"], "total": st["arrows_total"]})
	_hud_timer_lbl.visible = bool(st["has_timer"])
	_hud_timer_lbl.text = LocalizationManager.t("hud_timer", {"sec": st["time_left"]})
	if _hud_combo_pill != null and _hud_combo_lbl != null:
		var c := int(st.get("combo", 0))
		if c >= 2:
			var mult_str := "3" if c >= 4 else "1.5"
			_hud_combo_lbl.text = LocalizationManager.t("hud_combo", {"mult": mult_str})
			_hud_combo_pill.visible = true
		else:
			_hud_combo_pill.visible = false

func _on_hit_feedback(kind: String, pts: int, norm_pos: Vector2) -> void:
	if _hud_feedback_lbl == null:
		return
	match kind:
		"bullseye":
			_hud_feedback_lbl.text = LocalizationManager.t("hit_bullseye", {"pts": pts})
		"barrel":
			_hud_feedback_lbl.text = LocalizationManager.t("hit_barrel", {"pts": pts})
		"penalty":
			_hud_feedback_lbl.text = LocalizationManager.t("hit_penalty", {"pts": pts})
		"all_cleared":
			_hud_feedback_lbl.text = LocalizationManager.t("hit_all_cleared", {"pts": pts})
		_:
			_hud_feedback_lbl.text = LocalizationManager.t("hit_ring", {"pts": pts})
	if _hud_feedback_pill != null:
		_hud_feedback_pill.visible = true
	if _hit_diagram != null:
		_hit_diagram.add_hit(norm_pos, kind, pts)

func _on_level_finished(res: Dictionary) -> void:
	for c in result_panel.get_children():
		result_panel.remove_child(c)
		c.queue_free()
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	result_panel.add_child(vbox)

	var title := Label.new()
	title.text = LocalizationManager.t("result_win") if bool(res["won"]) else LocalizationManager.t("result_fail")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.98, 0.88, 0.42))
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
	btns.add_child(_make_button(LocalizationManager.t("btn_main_menu"), func():
		level_scene.show_menu_backdrop()
		_show_screen("menu")
	, 180.0))

	_show_screen("result")
