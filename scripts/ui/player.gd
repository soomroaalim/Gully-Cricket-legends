extends Control
## My Player: avatar, editable name, level/XP, effective stat bars,
## equipment shortcuts, and free cosmetic kit colors.

var _name_edit: LineEdit


func _ready() -> void:
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
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
	GCLUI.screen_head(root, "👤 My Player", func() -> void: Router.back())

	var p: Dictionary = GCLUI.user_player()
	if p.is_empty():
		root.add_child(ThemeHelpers.body_label("No player found — finish onboarding first.", 20, ThemeHelpers.RED))
		return

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	# Identity card.
	var card := ThemeHelpers.make_panel(Vector2(0, 0))
	body.add_child(card)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	card.add_child(top)
	var av := ThemeHelpers.title_label(GCLUI.avatar_emoji(int(p.get("avatar", 0))), 72, ThemeHelpers.INK)
	top.add_child(av)
	var idcol := VBoxContainer.new()
	idcol.add_theme_constant_override("separation", 6)
	idcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(idcol)
	var namerow := HBoxContainer.new()
	namerow.add_theme_constant_override("separation", 8)
	idcol.add_child(namerow)
	_name_edit = LineEdit.new()
	_name_edit.text = str(p.get("name", ""))
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(0, 56)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", 24)
	namerow.add_child(_name_edit)
	var save_b := GCLUI.fx(ThemeHelpers.make_button("💾", 56.0))
	save_b.custom_minimum_size = Vector2(90, 56)
	save_b.pressed.connect(_on_save_name)
	namerow.add_child(save_b)
	idcol.add_child(ThemeHelpers.body_label("Overall %d · Level %d" % [int(p.get("overall", 0)), int(p.get("level", 1))], 22, ThemeHelpers.INK))
	# XP bar.
	var lvl: int = int(p.get("level", 1))
	var need: int = GCLConfig.xp_for_level(lvl)
	idcol.add_child(ThemeHelpers.body_label("XP %d / %d" % [int(p.get("xp", 0)), need], 17, ThemeHelpers.MUTED))
	var xpbar := ProgressBar.new()
	xpbar.min_value = 0
	xpbar.max_value = maxi(need, 1)
	xpbar.value = int(p.get("xp", 0))
	xpbar.show_percentage = false
	xpbar.custom_minimum_size = Vector2(0, 16)
	var xbg := StyleBoxFlat.new()
	xbg.bg_color = Color(0, 0, 0, 0.18)
	xbg.set_corner_radius_all(8)
	var xfill := StyleBoxFlat.new()
	xfill.bg_color = ThemeHelpers.GOLD
	xfill.set_corner_radius_all(8)
	xpbar.add_theme_stylebox_override("background", xbg)
	xpbar.add_theme_stylebox_override("fill", xfill)
	idcol.add_child(xpbar)

	# Effective stats.
	var scard := ThemeHelpers.make_panel(Vector2(0, 0))
	body.add_child(scard)
	var scol := ThemeHelpers.vbox(8)
	scol.alignment = BoxContainer.ALIGNMENT_BEGIN
	scard.add_child(scol)
	scol.add_child(ThemeHelpers.title_label("📊 Stats (with gear)", 22, ThemeHelpers.RED))
	var eff: Dictionary = Economy.effective_stats(p)
	for key in GCLUI.STAT_KEYS:
		scol.add_child(GCLUI.make_stat_bar(str(GCLUI.STAT_LABELS[key]), int(eff.get(key, p.get(key, 50)))))

	# Equipment shortcuts.
	var ecard := ThemeHelpers.make_panel(Vector2(0, 0))
	body.add_child(ecard)
	var ecol := ThemeHelpers.vbox(8)
	ecol.alignment = BoxContainer.ALIGNMENT_BEGIN
	ecard.add_child(ecol)
	ecol.add_child(ThemeHelpers.title_label("🧤 Equipment", 22, ThemeHelpers.RED))
	var equipped: Dictionary = SaveSystem.data.get("equipped", {})
	for slot in GCLUI.SLOT_CATEGORIES:
		var cat: String = str(slot[1])
		var eid: String = str(equipped.get(cat, ""))
		var iname := "None"
		if eid != "":
			iname = str(GCLShop.by_id(eid).get("name", "Unknown"))
		var b := GCLUI.fx(ThemeHelpers.make_button("%s %s: %s  ›" % [str(slot[2]), str(slot[0]), iname], 52.0))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_open_shop_for.bind(cat))
		ecol.add_child(b)

	# Cosmetic kit colors (free).
	var ccard := ThemeHelpers.make_panel(Vector2(0, 0))
	body.add_child(ccard)
	var ccol := ThemeHelpers.vbox(8)
	ccol.alignment = BoxContainer.ALIGNMENT_BEGIN
	ccard.add_child(ccol)
	ccol.add_child(ThemeHelpers.title_label("🎨 Kit Colors (free)", 22, ThemeHelpers.RED))
	for pair in [["Jersey", "jersey"], ["Cap", "cap"], ["Shoes", "shoes"], ["Bat skin", "bat_skin"]]:
		ccol.add_child(_swatch_row(str(pair[0]), str(pair[1]), p))


func _on_save_name() -> void:
	var p: Dictionary = GCLUI.user_player()
	if p.is_empty():
		return
	var n: String = _name_edit.text.strip_edges()
	if n == "":
		n = "Haroon"
		_name_edit.text = n
	p["name"] = n
	SaveSystem.data["player_name"] = n
	SaveSystem.save_game()
	AudioMan.play("coin")


func _open_shop_for(category: String) -> void:
	Router.show("shop", {"category": category})


func _swatch_row(label_text: String, key: String, p: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var lab := ThemeHelpers.body_label(label_text, 19, ThemeHelpers.MUTED)
	lab.custom_minimum_size = Vector2(110, 0)
	row.add_child(lab)
	var cur: int = int(p.get(key, 0))
	for i in GCLUI.COSMETIC_COLORS.size():
		var b := GCLUI.fx(Button.new())
		b.custom_minimum_size = Vector2(56, 48)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = label_text
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(str(GCLUI.COSMETIC_COLORS[i]))
		sb.set_corner_radius_all(12)
		if i == cur:
			sb.border_color = Color.WHITE
			sb.set_border_width_all(4)
		else:
			sb.border_color = Color(0, 0, 0, 0.25)
			sb.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.pressed.connect(_on_swatch.bind(key, i))
		row.add_child(b)
	return row


func _on_swatch(key: String, idx: int) -> void:
	var p: Dictionary = GCLUI.user_player()
	if p.is_empty():
		return
	p[key] = idx
	SaveSystem.save_game()
	_refresh()
