extends Control
## Scoreboard screen: full scorecard for both innings from MatchEngine.
## Engine arrives via GameState.screen_params["engine"]. Back -> Router.back().

var _engine: Variant = null


func _ready() -> void:
	_engine = GameState.screen_params.get("engine", null)
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Router.back()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("101820")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)

	var top := ThemeHelpers.hbox(12)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.add_child(top)
	var back := ThemeHelpers.make_button("Back", 56)
	back.custom_minimum_size = Vector2(130, 56)
	back.pressed.connect(func() -> void: Router.back())
	top.add_child(back)
	var title := ThemeHelpers.title_label("Scorecard", 30, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(title)
	top.add_child(ThemeHelpers.spacer(130))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)

	if _engine == null:
		list.add_child(ThemeHelpers.body_label("No scorecard data available.", 22, Color.WHITE))
		return
	var card: Variant = _engine.call("scorecard")
	if not (card is Dictionary):
		list.add_child(ThemeHelpers.body_label("No scorecard data available.", 22, Color.WHITE))
		return
	var innings: Array = (card as Dictionary).get("innings", [])
	if innings.is_empty():
		list.add_child(ThemeHelpers.body_label("No innings played yet.", 22, Color.WHITE))
		return
	for inn in innings:
		list.add_child(_innings_block(inn))


func _innings_block(inn: Dictionary) -> PanelContainer:
	var panel := ThemeHelpers.make_panel(Vector2(0, 0))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := ThemeHelpers.vbox(8)
	panel.add_child(v)
	var head := ThemeHelpers.title_label(
		str(inn.get("team_name", "")) + "  " + str(inn.get("total", 0)) + "/" \
		+ str(inn.get("wickets", 0)) + "  (" + str(inn.get("overs_text", "")) + " ov)",
		26, ThemeHelpers.INK)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(head)
	v.add_child(_section_label("Batting"))
	for b in inn.get("batters", []):
		v.add_child(_batter_row(b))
	v.add_child(_section_label("Bowling"))
	for b in inn.get("bowlers", []):
		v.add_child(_bowler_row(b))
	var recent: Array = inn.get("recent_balls", [])
	if not recent.is_empty():
		var rb := ThemeHelpers.body_label("Recent: " + " ".join(recent), 18, ThemeHelpers.MUTED)
		v.add_child(rb)
	return panel


func _section_label(text: String) -> Label:
	var l := ThemeHelpers.body_label(text, 20, ThemeHelpers.RED)
	return l


func _batter_row(b: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_l := ThemeHelpers.body_label(str(b.get("name", "")), 20)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	row.add_child(name_l)
	var out := str(b.get("out_str", "not out"))
	var score := ThemeHelpers.body_label(
		str(b.get("runs", 0)) + "(" + str(b.get("balls", 0)) + ")", 20)
	row.add_child(score)
	var bounds := ThemeHelpers.body_label(
		"4s:" + str(b.get("fours", 0)) + " 6s:" + str(b.get("sixes", 0)), 18, ThemeHelpers.MUTED)
	row.add_child(bounds)
	var out_l := ThemeHelpers.body_label(out, 18, ThemeHelpers.MUTED)
	out_l.custom_minimum_size = Vector2(220, 0)
	out_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	out_l.clip_text = true
	row.add_child(out_l)
	return row


func _bowler_row(b: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_l := ThemeHelpers.body_label(str(b.get("name", "")), 20)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	row.add_child(name_l)
	var figs := ThemeHelpers.body_label(
		str(b.get("overs_text", "0")) + " ov  " + str(b.get("runs", 0)) + "/" \
		+ str(b.get("wickets", 0)), 20)
	row.add_child(figs)
	return row
