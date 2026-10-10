extends Control
## Main menu: animated stage backdrop, title, info pills, mode select,
## and navigation buttons. Root screen — Android back exits the app.


var _mode_overlay: Control = null


func _ready() -> void:
	if not bool(SaveSystem.data.get("onboarding_done", false)):
		# Deferred: changing scene inside _ready trips the tree's
		# busy add/remove guard ("Parent node is busy...").
		Router.replace.call_deferred("onboarding")
		return
	_build()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _mode_overlay != null:
		_mode_overlay.queue_free()
		_mode_overlay = null
		return
	# Root screen: exit the app (per CONTRACTS.md).
	get_tree().quit()


func _build() -> void:
	var bd := GCLUI.Backdrop.new()
	bd.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bd)
	var stage: Dictionary = Career.current_stage()
	if not stage.is_empty():
		bd.setup_from_stage(stage)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	# No horizontal scrolling: the inner CenterContainer fills the width.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var col := ThemeHelpers.vbox(12)
	col.custom_minimum_size = Vector2(560, 0)
	center.add_child(col)

	var title := ThemeHelpers.title_label("🏏 GULLY CRICKET LEGENDS", 46, Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	col.add_child(title)

	var pills := ThemeHelpers.hbox(10)
	col.add_child(pills)
	pills.add_child(GCLUI.make_pill("🪙 %d" % Economy.coins()))
	pills.add_child(GCLUI.make_pill("🏟 %s" % str(stage.get("name", "—"))))
	pills.add_child(GCLUI.make_pill("⭐ Lv %d" % int(SaveSystem.data.get("level", 1))))

	var play := GCLUI.fx(ThemeHelpers.make_button("▶  Play Gully Cricket"))
	play.pressed.connect(_on_play_pressed)
	col.add_child(play)
	_add_nav(col, "🏆  Career", "career")
	_add_nav(col, "👤  My Player", "player")
	_add_nav(col, "🏏  My Team", "team")
	_add_nav(col, "🛒  Shop", "shop")
	_add_nav(col, "⚙️  Settings", "settings")


func _add_nav(col: VBoxContainer, text: String, screen_id: String) -> void:
	var b := GCLUI.fx(ThemeHelpers.make_button(text))
	b.pressed.connect(func() -> void: Router.show(screen_id))
	col.add_child(b)


func _on_play_pressed() -> void:
	if _mode_overlay != null:
		return
	var panel := ThemeHelpers.make_panel(Vector2(520, 0))
	var col := ThemeHelpers.vbox(10)
	panel.add_child(col)
	col.add_child(ThemeHelpers.title_label("Select Match Mode", 28, ThemeHelpers.INK))
	for key in ["1v1", "2v2", "5v5", "gully6"]:
		var mc: Dictionary = GCLConfig.MODE_CONFIG[key]
		var b := GCLUI.fx(ThemeHelpers.make_button("▶  %s" % str(mc.get("label", key))))
		b.pressed.connect(_on_mode_chosen.bind(key))
		col.add_child(b)
	var cancel := GCLUI.fx(ThemeHelpers.make_button("✖  Cancel"))
	cancel.pressed.connect(_close_mode_overlay)
	col.add_child(cancel)
	_mode_overlay = GCLUI.make_overlay(panel)
	add_child(_mode_overlay)


func _close_mode_overlay() -> void:
	if _mode_overlay != null:
		_mode_overlay.queue_free()
		_mode_overlay = null


func _on_mode_chosen(mode_key: String) -> void:
	_close_mode_overlay()
	var rng := GCLRng.new(GCLRng.random_seed())
	var stage: Dictionary = Career.current_stage()
	GameState.match_config = GCLUI.build_match_config(mode_key, "NORMAL", stage, rng, {"from": "main_menu"})
	Router.show("match", {"from": "main_menu"})
