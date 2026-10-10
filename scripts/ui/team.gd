extends Control
## My Team (v1.2): roster as coherent cards — AvatarMedallion, name with
## a "YOU" badge for the user's own player, role, OVR, mini stat bars,
## level. Tapping a card opens that player's profile. Management actions
## (Upgrade, Make Captain, Move Up/Down) live on the player profile
## screen now (relocated, not removed). Recruit section keeps its logic.
## Reachable only via the Career hub.

var _coins_pill: PanelContainer

const Selection = preload("res://scripts/career/selection.gd")


func _ready() -> void:
	_build()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	Router.back()


func _refresh() -> void:
	GCLUI.clear(self)
	_build()


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

	GCLUI.screen_head(root, "🏏 My Team", func() -> void: Router.back())
	_coins_pill = GCLUI.make_pill("🪙 %d" % Economy.coins())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	# v2.0: Main XI vs Reserves — derived from the real lineup, so the
	# two groups always reflect actual selection state.
	var lineup: Array = SaveSystem.data.get("lineup", [])
	var captain: String = str(SaveSystem.data.get("captain_id", ""))
	var xi: Array = []
	var res: Array = []
	for p in SaveSystem.data.get("team", []):
		if p is Dictionary:
			if lineup.has(str(p.get("id", ""))):
				xi.append(p)
			else:
				res.append(p)
	body.add_child(ThemeHelpers.title_label("⭐ Main XI", 24, ThemeHelpers.RED))
	if xi.is_empty():
		body.add_child(ThemeHelpers.body_label("No players in the starting XI yet.", 17, ThemeHelpers.MUTED))
	for p in xi:
		body.add_child(_roster_card(p, lineup, captain))
	body.add_child(ThemeHelpers.title_label("🔄 Reserves", 24, ThemeHelpers.RED))
	if res.is_empty():
		body.add_child(ThemeHelpers.body_label("No reserve players. Recruit to build depth.", 17, ThemeHelpers.MUTED))
	for p in res:
		body.add_child(_roster_card(p, lineup, captain))

	var recrow := HBoxContainer.new()
	recrow.add_theme_constant_override("separation", 12)
	recrow.alignment = BoxContainer.ALIGNMENT_BEGIN
	body.add_child(recrow)
	var rectitle := ThemeHelpers.title_label("🎯 Recruit", 24, ThemeHelpers.RED)
	rectitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recrow.add_child(rectitle)
	recrow.add_child(_coins_pill)
	var stage_index: int = int(SaveSystem.data.get("career", {}).get("stage_index", 0))
	var any_recruit := false
	for def in GCLPlayers.recruits():
		if def is Dictionary and int(def.get("min_stage_index", 0)) <= stage_index:
			body.add_child(_recruit_row(def))
			any_recruit = true
	if not any_recruit:
		body.add_child(ThemeHelpers.body_label("No new players around yet — win matches to attract talent.", 18, ThemeHelpers.MUTED))


## Coherent roster card: medallion, name (+YOU badge), role, OVR, mini
## BAT/BOWL/FIELD bars, level, lineup position, captain star.
## Tapping opens the player's profile — it changes nothing.
func _roster_card(p: Dictionary, lineup: Array, captain: String) -> Button:
	var pid: String = str(p.get("id", ""))
	var is_user: bool = bool(p.get("is_user", false))
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 132)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.97) if not is_user else Color(1.0, 0.96, 0.88, 0.99)
	sb.set_corner_radius_all(14)
	sb.border_color = ThemeHelpers.GOLD if is_user else Color(0, 0, 0, 0.25)
	sb.set_border_width_all(3 if is_user else 1)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("normal", sb)
	card.add_theme_stylebox_override("hover", sb)
	card.add_theme_stylebox_override("pressed", sb)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Inset the row from the button edges: anchored children ignore the
	# StyleBox content margins, so the padding is applied via offsets.
	# The extra right inset keeps the position/chevron column clear of the
	# ScrollContainer's overlay scrollbar.
	row.offset_left = 12.0
	row.offset_top = 8.0
	row.offset_right = -24.0
	row.offset_bottom = -8.0

	var jersey := Color(str(GCLUI.COSMETIC_COLORS[absi(int(p.get("jersey", 0))) % GCLUI.COSMETIC_COLORS.size()]))
	var name: String = str(p.get("name", "?"))
	row.add_child(MenuArt.AvatarMedallion.new(name.left(1).to_upper(), jersey))

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var cap_mark := "  ⭐" if pid == captain else ""
	var title := name + ("  [YOU]" if is_user else cap_mark)
	var t := ThemeHelpers.body_label(title, 21, ThemeHelpers.INK)
	if is_user:
		t.add_theme_color_override("font_color", ThemeHelpers.RED)
	info.add_child(t)
	info.add_child(ThemeHelpers.body_label(
		"%s · OVR %d · Lv %d" % [str(p.get("role", "?")), int(p.get("overall", 0)), int(p.get("level", 1))],
		17, ThemeHelpers.MUTED))
	# v2.0: the user's squad status is real game state, shown on their card.
	if is_user:
		var st: String = Career.selection_status()
		var stc: Color = ThemeHelpers.MUTED
		if st == "MAIN_XI":
			stc = ThemeHelpers.GREEN
		elif st == "SELECTED_FOR_DEBUT":
			stc = ThemeHelpers.GOLD
		elif st == "DROPPED":
			stc = ThemeHelpers.RED
		info.add_child(ThemeHelpers.body_label("Status: " + str(Selection.status_label(st)), 15, stc))
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 10)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(bars)
	for key in ["batting", "bowling", "fielding"]:
		bars.add_child(_mini_bar(str(GCLUI.STAT_LABELS[key]).left(3).to_upper(), int(p.get(key, 50))))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.custom_minimum_size = Vector2(56, 0)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)
	var pos: int = lineup.find(pid) + 1
	var pos_l := ThemeHelpers.body_label("#%d" % pos if pos > 0 else "—", 18, ThemeHelpers.MUTED)
	pos_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	pos_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(pos_l)
	var go := ThemeHelpers.body_label("›", 34, ThemeHelpers.RED)
	go.autowrap_mode = TextServer.AUTOWRAP_OFF
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(go)

	card.pressed.connect(_on_open_player.bind(pid))
	return GCLUI.fx(card)


## Compact label + bar + value for the three core stats.
func _mini_bar(label_text: String, value: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lab := ThemeHelpers.body_label(label_text, 14, ThemeHelpers.MUTED)
	lab.custom_minimum_size = Vector2(34, 0)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lab)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 99
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.18)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ThemeHelpers.GREEN if value >= 60 else (ThemeHelpers.GOLD if value >= 40 else ThemeHelpers.RED)
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var val := ThemeHelpers.body_label(str(value), 14, ThemeHelpers.INK)
	val.custom_minimum_size = Vector2(30, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val)
	return row


func _on_open_player(pid: String) -> void:
	Router.show("player", {"player_id": pid})


func _recruit_row(def: Dictionary) -> PanelContainer:
	var panel := ThemeHelpers.make_panel(Vector2(0, 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(row)
	var info := ThemeHelpers.body_label("%s  %s\n%s · OVR %d" % [
		GCLUI.avatar_emoji(int(def.get("avatar", 0))),
		str(def.get("name", "?")),
		str(def.get("role", "?")),
		int(def.get("overall", 0)),
	], 20, ThemeHelpers.INK)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var price: int = int(def.get("price", 0))
	var b := GCLUI.fx(ThemeHelpers.make_button("🪙 %d" % price, 52.0))
	b.custom_minimum_size = Vector2(170, 52)
	b.disabled = Economy.coins() < price
	b.pressed.connect(_on_recruit.bind(str(def.get("id", ""))))
	row.add_child(b)
	return panel


func _on_recruit(def_id: String) -> void:
	if Economy.recruit_player(def_id):
		AudioMan.play("coin")
		SaveSystem.save_game()
		_refresh()
	else:
		AudioMan.play("loss")
