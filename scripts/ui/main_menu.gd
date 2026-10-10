extends Control
## Main menu (v1.2 redesign): stadium-vista backdrop, profile top bar,
## logo lockup, one dominant Play button, and exactly three nav cards:
## Career, Shop, Settings. My Player / My Team now live inside the
## Career hub (menu scope per v1.2 PRD).
##
## Display: the content column uses proportional anchors (not a fixed
## 404px strip) so ultrawide aspects (18:9/19.5:9/20:9) get real
## content width instead of a narrow left strip.
## Root screen — Android back exits the app. Scope: menu only.

var _mode_overlay: Control = null
var _busy: bool = false
var _hero: Button = null


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
	var vista := MenuArt.StadiumVista.new()
	vista.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vista)

	_add_top_bar()
	_add_menu_column()


func _profile() -> Dictionary:
	var name: String = str(SaveSystem.data.get("player_name", "")).strip_edges()
	if name == "":
		name = "Player"
	var av_idx: int = absi(int(SaveSystem.data.get("avatar", 0)))
	var jersey := Color(str(GCLUI.COSMETIC_COLORS[av_idx % GCLUI.COSMETIC_COLORS.size()]))
	var stage: Dictionary = Career.current_stage()
	# Trophies live under career.trophies (SaveSystem defaults); read the
	# real value, never the missing top-level key.
	var trophies: Array = SaveSystem.data.get("career", {}).get("trophies", [])
	return {
		"name": name,
		"initial": name.left(1).to_upper(),
		"jersey": jersey,
		"level": int(SaveSystem.data.get("level", 1)),
		"stage": str(stage.get("name", "—")),
		"coins": Economy.coins(),
		"trophies": trophies.size(),
	}


func _add_top_bar() -> void:
	var prof: Dictionary = _profile()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	add_child(margin)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(bar)

	bar.add_child(MenuArt.AvatarMedallion.new(str(prof["initial"]), prof["jersey"]))
	var idcol := VBoxContainer.new()
	idcol.add_theme_constant_override("separation", 0)
	idcol.alignment = BoxContainer.ALIGNMENT_CENTER
	var nm := ThemeHelpers.hud_label(str(prof["name"]), 22)
	idcol.add_child(nm)
	var sub := ThemeHelpers.hud_label("Lv %d · %s" % [int(prof["level"]), str(prof["stage"])], 15, Color(1, 1, 1, 0.75))
	idcol.add_child(sub)
	bar.add_child(idcol)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	bar.add_child(MenuArt.chip("coin", MenuArt.fmt_coins(int(prof["coins"]))))
	bar.add_child(MenuArt.chip("trophy", str(int(prof["trophies"]))))
	var gear := MenuArt.icon_button("gear", 52.0)
	gear.pressed.connect(_on_nav.bind("settings"))
	bar.add_child(GCLUI.fx(gear))


func _add_menu_column() -> void:
	# Proportional anchors: ~47% of the width, so ultrawide screens get a
	# wider column (v1.1's fixed 404px strip stranded content on the left
	# at 18:9+). Min width keeps phones usable.
	var col := VBoxContainer.new()
	col.anchor_left = 0.0
	col.anchor_right = 0.47
	col.anchor_top = 0.0
	col.anchor_bottom = 1.0
	col.offset_left = 40.0
	col.offset_right = 0.0
	col.offset_top = 84.0
	col.offset_bottom = -12.0
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(col)

	col.add_child(MenuArt.logo_lockup())

	_hero = MenuArt.menu_button("PLAY GULLY CRICKET", "play", Vector2(320, 80), 26)
	_hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero.pressed.connect(_on_play_pressed)
	col.add_child(GCLUI.fx(_hero))
	_start_hero_pulse()

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(grid)
	_add_card(grid, "trophy", "Career", "Stages & squad", "career")
	_add_card(grid, "cart", "Shop", "Bats, kits & more", "shop")
	_add_card(grid, "gear", "Settings", "App preferences", "settings")


func _add_card(grid: GridContainer, icon: String, title: String, subtitle: String, screen_id: String) -> void:
	var b := MenuArt.card_button(icon, title, subtitle, Vector2(150, 96))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(_on_nav.bind(screen_id))
	grid.add_child(GCLUI.fx(b))


func _on_nav(screen_id: String) -> void:
	if _busy:
		return
	_busy = true
	Router.show(screen_id)


func _start_hero_pulse() -> void:
	if _hero == null:
		return
	_hero.resized.connect(_on_hero_resized, CONNECT_ONE_SHOT)


func _on_hero_resized() -> void:
	if _hero == null:
		return
	_hero.pivot_offset = _hero.size * 0.5
	var tw := create_tween().set_loops()
	tw.tween_property(_hero, "scale", Vector2(1.03, 1.03), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_hero, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)


func _on_play_pressed() -> void:
	if _mode_overlay != null or _busy:
		return
	var panel := ThemeHelpers.make_panel(Vector2(560, 0))
	var col := ThemeHelpers.vbox(12)
	panel.add_child(col)
	col.add_child(ThemeHelpers.title_label("SELECT MATCH MODE", 26, ThemeHelpers.INK))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	var icons := {"1v1": "player", "2v2": "team", "5v5": "team", "gully6": "ball"}
	for key in ["1v1", "2v2", "5v5", "gully6"]:
		var mc: Dictionary = GCLConfig.MODE_CONFIG[key]
		var sub := "%d overs · %d wkts" % [int(mc.get("overs", 2)), int(mc.get("max_wickets", 3))]
		var b := MenuArt.card_button(str(icons.get(key, "ball")), str(mc.get("label", key)), sub, Vector2(240, 110))
		b.pressed.connect(_on_mode_chosen.bind(key))
		grid.add_child(GCLUI.fx(b))
	var cancel := MenuArt.menu_button("Cancel", "x", Vector2(0, 60), 20)
	cancel.pressed.connect(_close_mode_overlay)
	col.add_child(GCLUI.fx(cancel))
	_mode_overlay = GCLUI.make_overlay(panel)
	add_child(_mode_overlay)


func _close_mode_overlay() -> void:
	if _mode_overlay != null:
		_mode_overlay.queue_free()
		_mode_overlay = null


func _on_mode_chosen(mode_key: String) -> void:
	if _busy:
		return
	_busy = true
	_close_mode_overlay()
	var rng := GCLRng.new(GCLRng.random_seed())
	var stage: Dictionary = Career.current_stage()
	GameState.match_config = GCLUI.build_match_config(mode_key, "NORMAL", stage, rng, {"from": "main_menu"})
	Router.show("match", {"from": "main_menu"})
