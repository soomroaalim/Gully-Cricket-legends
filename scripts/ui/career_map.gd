extends Control
## Career map: horizontal stage cards, stage detail panel (quick match /
## tournament bracket), and the challenges list.

var _overlay: Control = null
var _coins_pill: PanelContainer


func _ready() -> void:
	_build()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _overlay != null:
		_close_overlay()
		return
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

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(head)
	var back := GCLUI.fx(ThemeHelpers.make_button("‹ Back", 56.0))
	back.custom_minimum_size = Vector2(150, 56)
	back.pressed.connect(func() -> void: Router.back())
	head.add_child(back)
	var t := ThemeHelpers.title_label("🏆 Career", 30, ThemeHelpers.INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_coins_pill = GCLUI.make_pill("🪙 %d" % Economy.coins())
	head.add_child(_coins_pill)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	body.add_child(ThemeHelpers.title_label("🗺 Stages", 24, ThemeHelpers.RED))
	var hscroll := ScrollContainer.new()
	hscroll.custom_minimum_size = Vector2(0, 250)
	hscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hscroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(hscroll)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	hscroll.add_child(cards)
	for stage in Career.stages():
		if stage is Dictionary:
			cards.add_child(_stage_card(stage))

	body.add_child(ThemeHelpers.title_label("⚔ Challenges", 24, ThemeHelpers.RED))
	for ch in GCLChallenges.all():
		if ch is Dictionary:
			body.add_child(_challenge_row(ch))


func _stage_card(stage: Dictionary) -> Button:
	var sid: String = str(stage.get("id", ""))
	var cur: Dictionary = Career.current_stage()
	var is_current: bool = str(cur.get("id", "")) == sid
	var done: bool = Career.is_completed(sid)
	var locked: bool = not Career.is_unlocked(sid)
	var state_line := "🔒 Locked"
	if done:
		state_line = "🏆 Done"
	elif is_current:
		state_line = "▶ Current"
	var b := GCLUI.fx(ThemeHelpers.make_button("%s\n%s\n%s\n%s" % [
		str(stage.get("icon", "🏟")),
		str(stage.get("name", "?")),
		str(stage.get("difficulty", "")),
		state_line,
	]))
	b.custom_minimum_size = Vector2(216, 230)
	b.disabled = locked
	if is_current and not locked:
		b.pressed.connect(_show_stage_panel.bind(stage))
	return b


func _show_stage_panel(stage: Dictionary) -> void:
	_close_overlay()
	var panel := ThemeHelpers.make_panel(Vector2(580, 0))
	var col := ThemeHelpers.vbox(10)
	panel.add_child(col)
	col.add_child(ThemeHelpers.title_label("%s %s" % [str(stage.get("icon", "🏟")), str(stage.get("name", "?"))], 30, ThemeHelpers.RED))
	var desc := ThemeHelpers.body_label(str(stage.get("description", "")), 19, ThemeHelpers.INK)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(desc)
	col.add_child(ThemeHelpers.body_label("Difficulty: %s" % str(stage.get("difficulty", "NORMAL")), 20, ThemeHelpers.MUTED))
	var t: Dictionary = stage.get("tournament", {})
	if not t.is_empty():
		col.add_child(ThemeHelpers.body_label("🏆 %s — Prize 🪙%d" % [str(t.get("name", "")), int(t.get("prize", 0))], 20, ThemeHelpers.MUTED))
	var quick := GCLUI.fx(ThemeHelpers.make_button("▶  Quick Match"))
	quick.pressed.connect(_play_quick_match.bind(stage))
	col.add_child(quick)
	if not t.is_empty():
		var tour := GCLUI.fx(ThemeHelpers.make_button("🏆  Tournament"))
		tour.pressed.connect(_show_bracket.bind(stage))
		col.add_child(tour)
	var close := GCLUI.fx(ThemeHelpers.make_button("✖  Close"))
	close.pressed.connect(_close_overlay)
	col.add_child(close)
	_overlay = GCLUI.make_overlay(panel)
	add_child(_overlay)


func _play_quick_match(stage: Dictionary) -> void:
	_close_overlay()
	var rng := GCLRng.new(GCLRng.random_seed())
	var cfg: Dictionary = GCLUI.build_match_config("gully6", str(stage.get("difficulty", "NORMAL")), stage, rng, {
		"from": "career", "stage_id": str(stage.get("id", "")),
	})
	GameState.match_config = cfg
	Router.show("match", {"from": "career", "stage_id": str(stage.get("id", ""))})


func _show_bracket(stage: Dictionary) -> void:
	_close_overlay()
	var t: Dictionary = stage.get("tournament", {})
	var tid: String = str(t.get("id", ""))
	var rounds: Array = t.get("rounds", [])
	var ts: Dictionary = Career.tournament_state(tid)
	var cur: int = int(ts.get("round", 0))
	var panel := ThemeHelpers.make_panel(Vector2(600, 0))
	var col := ThemeHelpers.vbox(10)
	panel.add_child(col)
	col.add_child(ThemeHelpers.title_label("🏆 %s" % str(t.get("name", "Tournament")), 28, ThemeHelpers.RED))
	col.add_child(ThemeHelpers.body_label("Prize: 🪙%d  ✨%d XP" % [int(t.get("prize", 0)), int(t.get("prize_xp", 0))], 20, ThemeHelpers.MUTED))
	for i in rounds.size():
		var rn: String = str(rounds[i])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		col.add_child(row)
		if i < cur:
			row.add_child(ThemeHelpers.body_label("✅ %s" % rn, 20, ThemeHelpers.INK))
		elif i == cur:
			row.add_child(ThemeHelpers.body_label("▶ %s" % rn, 20, ThemeHelpers.INK))
			var play := GCLUI.fx(ThemeHelpers.make_button("Play", 48.0))
			play.custom_minimum_size = Vector2(170, 48)
			play.pressed.connect(_play_tournament_round.bind(stage, tid, rn))
			row.add_child(play)
		else:
			row.add_child(ThemeHelpers.body_label("🔒 %s" % rn, 20, ThemeHelpers.MUTED))
	var back := GCLUI.fx(ThemeHelpers.make_button("‹ Back"))
	back.pressed.connect(_show_stage_panel.bind(stage))
	col.add_child(back)
	_overlay = GCLUI.make_overlay(panel)
	add_child(_overlay)


func _play_tournament_round(stage: Dictionary, tid: String, round_name: String) -> void:
	_close_overlay()
	var rng := GCLRng.new(GCLRng.random_seed())
	var cfg: Dictionary = GCLUI.build_match_config("gully6", str(stage.get("difficulty", "NORMAL")), stage, rng, {
		"from": "career",
		"stage_id": str(stage.get("id", "")),
		"tournament_id": tid,
		"round_name": round_name,
	})
	GameState.match_config = cfg
	Router.show("match", {"from": "career", "tournament_id": tid, "stage_id": str(stage.get("id", ""))})


func _challenge_row(ch: Dictionary) -> PanelContainer:
	var panel := ThemeHelpers.make_panel(Vector2(0, 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(row)
	var cid: String = str(ch.get("id", ""))
	var done: bool = SaveSystem.data.get("challenges_done", []).has(cid)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(ThemeHelpers.body_label("%s  %s" % [str(ch.get("icon", "⚔")), str(ch.get("name", "?"))], 22, ThemeHelpers.INK))
	var d := ThemeHelpers.body_label(str(ch.get("description", "")), 17, ThemeHelpers.MUTED)
	info.add_child(d)
	info.add_child(ThemeHelpers.body_label("Difficulty: %s" % str(ch.get("difficulty", "NORMAL")), 17, ThemeHelpers.MUTED))
	var b := GCLUI.fx(ThemeHelpers.make_button("✅ Done" if done else "▶  Play", 52.0))
	b.custom_minimum_size = Vector2(170, 52)
	b.disabled = done
	if not done:
		b.pressed.connect(_play_challenge.bind(ch))
	row.add_child(b)
	return panel


func _play_challenge(ch: Dictionary) -> void:
	var stage: Dictionary = Career.current_stage()
	var sid: String = str(ch.get("stage_id", ""))
	if sid != "":
		var s: Dictionary = Career.stage_by_id(sid)
		if not s.is_empty():
			stage = s
	var rng := GCLRng.new(GCLRng.random_seed())
	var cfg: Dictionary = GCLUI.build_match_config(str(ch.get("mode", "1v1")), str(ch.get("difficulty", "NORMAL")), stage, rng, {
		"from": "career",
		"challenge_id": str(ch.get("id", "")),
	})
	GameState.match_config = cfg
	Router.show("match", {"from": "career", "challenge_id": str(ch.get("id", ""))})


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
