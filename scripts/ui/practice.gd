extends Control
## Practice panel (v3.0): train skills within the daily session budget.
## Gains are role-weighted and diminishing; injured players are restricted;
## everything persists offline via Career.do_practice().

var _content: VBoxContainer = null
var _msg: Label = null


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
	GCLUI.screen_head(root, "Practice", func() -> void: Router.back())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_content = ThemeHelpers.vbox(10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	_refresh()


func _refresh() -> void:
	for c in _content.get_children():
		c.queue_free()
	_msg = null
	var u: Dictionary = Career.user_player()
	if u.is_empty():
		_content.add_child(ThemeHelpers.body_label("No player found.", 20, ThemeHelpers.MUTED))
		return
	# Header: career day + session budget.
	var st: Dictionary = Career.practice_state()
	var head := ThemeHelpers.make_panel(Vector2(0, 0))
	var hcol := ThemeHelpers.vbox(6)
	head.add_child(hcol)
	var bonus_n: int = int(st.get("bonus", 0))
	var head_line: String = "Day %d  ·  %d/%d sessions left" % [Career.career_day(),
		int(st["sessions_left"]), int(st["sessions_total"])]
	if bonus_n > 0:
		head_line = "Day %d  ·  %d sessions left (%d daily + %d bonus)" % [Career.career_day(),
			int(st["sessions_left"]), int(st["sessions_total"]), bonus_n]
	hcol.add_child(ThemeHelpers.title_label(head_line, 24, ThemeHelpers.RED))
	# v4.0: legendary bonus sessions are always explicitly labeled — they
	# stack ON TOP of the daily budget and never silently bypass it.
	if bonus_n > 0:
		hcol.add_child(ThemeHelpers.body_label(
			"⭐ +%d BONUS session%s from legendary training (beyond the daily budget)" % [
				bonus_n, "" if bonus_n == 1 else "s"], 18, ThemeHelpers.GOLD))
	var inj: String = Career.user_injury_label()
	var status_line: String = "Role: %s   ·   Form: %s   ·   Fitness: %d" % [
		GCLDevelopment.role_label(str(u.get("role", "Batter"))),
		GCLDevelopment.form_word(float(u.get("form", 0.5))), int(u.get("fitness", 90))]
	if inj != "":
		status_line += "\n" + inj
		hcol.add_child(ThemeHelpers.body_label(status_line, 19, ThemeHelpers.MUTED))
	else:
		hcol.add_child(ThemeHelpers.body_label(status_line, 19, ThemeHelpers.MUTED))
	_content.add_child(head)
	# Tactical style picker for all-rounders.
	if str(u.get("role", "")) == "AllRounder":
		_content.add_child(_tactical_row(u))
	# Activity cards.
	for act in GCLDevelopment.PRACTICE_ACTIVITIES.keys():
		_content.add_child(_activity_card(str(act), u, int(st["sessions_left"])))
	# Rest button.
	var rest := GCLUI.fx(ThemeHelpers.make_button("Rest — advance one day", 60))
	rest.pressed.connect(_on_rest)
	_content.add_child(rest)
	# History.
	_content.add_child(_history_card(u))
	_msg = ThemeHelpers.body_label("", 19, ThemeHelpers.MUTED)
	_content.add_child(_msg)


func _tactical_row(u: Dictionary) -> PanelContainer:
	var card := ThemeHelpers.make_panel(Vector2(0, 0))
	var col := ThemeHelpers.vbox(6)
	card.add_child(col)
	col.add_child(ThemeHelpers.title_label("Tactical style", 22, ThemeHelpers.INK))
	col.add_child(ThemeHelpers.body_label(
		"Affects in-match priorities only — never changes base attributes.", 17, ThemeHelpers.MUTED))
	var opt := OptionButton.new()
	for t in GCLDevelopment.TACTICAL_STYLES:
		opt.add_item(GCLDevelopment.tactical_label(t))
	opt.selected = GCLDevelopment.TACTICAL_STYLES.find(str(u.get("tactical", "balanced")))
	opt.item_selected.connect(_on_tactical.bind(u))
	col.add_child(opt)
	return card


func _on_tactical(idx: int, u: Dictionary) -> void:
	u["tactical"] = GCLDevelopment.TACTICAL_STYLES[idx]
	SaveSystem.save_game()
	_refresh()


func _activity_card(activity: String, u: Dictionary, sessions_left: int) -> PanelContainer:
	var info: Dictionary = GCLDevelopment.PRACTICE_ACTIVITIES[activity]
	var card := ThemeHelpers.make_panel(Vector2(0, 0))
	var col := ThemeHelpers.vbox(6)
	card.add_child(col)
	col.add_child(ThemeHelpers.title_label(str(info["label"]), 22, ThemeHelpers.INK))
	col.add_child(ThemeHelpers.body_label(str(info["desc"]), 18, ThemeHelpers.MUTED))
	col.add_child(ThemeHelpers.body_label(_gain_preview(activity, u), 18, ThemeHelpers.MUTED))
	var btn := GCLUI.fx(ThemeHelpers.make_button("Train", 56))
	var res: Dictionary = GCLDevelopment.practice_result(activity, u)
	var reason: String = str(res.get("blocked_reason", ""))
	if sessions_left <= 0:
		reason = "No sessions left today."
	btn.disabled = reason != ""
	if reason != "":
		btn.tooltip_text = reason
		col.add_child(ThemeHelpers.body_label(reason, 17, ThemeHelpers.RED))
	btn.pressed.connect(_on_train.bind(activity))
	col.add_child(btn)
	return card


func _gain_preview(activity: String, u: Dictionary) -> String:
	var res: Dictionary = GCLDevelopment.practice_result(activity, u)
	if str(res.get("blocked_reason", "")) != "":
		return "Not available right now."
	var gains: Dictionary = res.get("gains", {})
	var parts: Array[String] = []
	for sk in gains.keys():
		parts.append("+%d %s" % [int(gains[sk]), str(sk).capitalize()])
	if int(res.get("fitness_gain", 0)) > 0:
		parts.append("+%d Fitness" % int(res["fitness_gain"]))
	if parts.is_empty():
		return "No gains at current level."
	return "Expected: " + ", ".join(parts) + "  ·  small form boost"


func _on_train(activity: String) -> void:
	var res: Dictionary = Career.do_practice(activity)
	_refresh()
	if _msg != null:
		_msg.text = str(res.get("message", ""))
		_msg.add_theme_color_override("font_color",
			ThemeHelpers.INK if bool(res.get("ok", false)) else ThemeHelpers.RED)


func _on_rest() -> void:
	var res: Dictionary = Career.rest_day()
	_refresh()
	if _msg != null:
		var txt: String = "Rested. Day %d — fitness +%d." % [int(res.get("day", 0)), int(res.get("fitness_gain", 0))]
		var inj: String = str(res.get("injury", ""))
		if inj != "":
			txt += " " + inj
		_msg.text = txt


func _history_card(u: Dictionary) -> PanelContainer:
	var card := ThemeHelpers.make_panel(Vector2(0, 0))
	var col := ThemeHelpers.vbox(6)
	card.add_child(col)
	col.add_child(ThemeHelpers.title_label("Training history", 22, ThemeHelpers.INK))
	var hist: Array = u.get("practice", [])
	if hist.is_empty():
		col.add_child(ThemeHelpers.body_label("No sessions yet — train to develop your player.", 18, ThemeHelpers.MUTED))
		return card
	for h in hist.slice(0, 5):
		if not (h is Dictionary):
			continue
		var gains: Dictionary = (h as Dictionary).get("gains", {})
		var parts: Array[String] = []
		for sk in gains.keys():
			parts.append("+%d %s" % [int(gains[sk]), str(sk).capitalize()])
		var label: String = str(GCLDevelopment.PRACTICE_ACTIVITIES.get(
			str((h as Dictionary).get("activity", "")), {}).get("label", "Session"))
		col.add_child(ThemeHelpers.body_label("Day %d — %s: %s" % [
			int((h as Dictionary).get("day", 0)), label,
			", ".join(parts) if not parts.is_empty() else "—"], 18, ThemeHelpers.MUTED))
	return card
