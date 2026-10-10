extends Control
## Settings: music/SFX/vibration toggles, language, reset save, version.

var _confirm: ConfirmationDialog = null


func _ready() -> void:
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Router.back()


func _build() -> void:
	add_child(GCLUI.paper_bg())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	GCLUI.screen_head(root, "⚙️ Settings", func() -> void: Router.back())

	var center := ScrollContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	var inner := CenterContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(inner)
	var panel := ThemeHelpers.make_panel(Vector2(620, 0))
	inner.add_child(panel)
	var col := ThemeHelpers.vbox(12)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(col)

	col.add_child(ThemeHelpers.title_label("🔊 Audio & Feel", 24, ThemeHelpers.RED))
	var music := ThemeHelpers.make_check("🎵  Music", bool(SaveSystem.setting("music")))
	music.toggled.connect(_on_music_toggled)
	col.add_child(music)
	var sfx := ThemeHelpers.make_check("🔔  Sound Effects", bool(SaveSystem.setting("sfx")))
	sfx.toggled.connect(_on_sfx_toggled)
	col.add_child(sfx)
	var vib := ThemeHelpers.make_check("📳  Vibration", bool(SaveSystem.setting("vibration")))
	vib.toggled.connect(_on_vib_toggled)
	col.add_child(vib)

	col.add_child(ThemeHelpers.title_label("🌐 Language", 24, ThemeHelpers.RED))
	var lang := OptionButton.new()
	lang.add_item("English", 0)
	lang.add_item("More soon…", 1)
	lang.selected = 0
	lang.custom_minimum_size = Vector2(0, 56)
	lang.add_theme_font_size_override("font_size", 20)
	lang.item_selected.connect(_on_lang_selected.bind(lang))
	col.add_child(lang)

	col.add_child(ThemeHelpers.title_label("🗑 Danger Zone", 24, ThemeHelpers.RED))
	var reset := GCLUI.fx(ThemeHelpers.make_button("Reset Save Data"))
	reset.pressed.connect(_on_reset_pressed)
	col.add_child(reset)

	var ver := ThemeHelpers.body_label("Gully Cricket Legends  v1.0.0", 17, ThemeHelpers.MUTED)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(ver)


func _on_music_toggled(on: bool) -> void:
	SaveSystem.data["settings"]["music"] = on
	SaveSystem.save_game()
	AudioMan.set_music_enabled(on)


func _on_sfx_toggled(on: bool) -> void:
	SaveSystem.data["settings"]["sfx"] = on
	SaveSystem.save_game()
	AudioMan.set_sfx_enabled(on)


func _on_vib_toggled(on: bool) -> void:
	SaveSystem.data["settings"]["vibration"] = on
	SaveSystem.save_game()
	GameState.vibrate(40)


func _on_lang_selected(idx: int, lang: OptionButton) -> void:
	if idx != 0:
		lang.selected = 0  # Only English for now.
	SaveSystem.data["settings"]["language"] = "en"
	SaveSystem.save_game()


func _on_reset_pressed() -> void:
	if _confirm != null:
		_confirm.queue_free()
	_confirm = ConfirmationDialog.new()
	_confirm.dialog_text = "Are you sure? This will permanently delete your career progress."
	_confirm.ok_button_text = "Reset"
	_confirm.cancel_button_text = "Cancel"
	add_child(_confirm)
	_confirm.confirmed.connect(_do_reset)
	_confirm.popup_centered()


func _do_reset() -> void:
	SaveSystem.reset_game()
	GCLOnboarding.reset_flow()
	AudioMan.set_music_enabled(true)
	AudioMan.set_sfx_enabled(true)
	Router.reset_to("onboarding")
