extends Control
## Post-match result screen: outcome banner, innings scores, top performers,
## coin/XP count-up, achievements, tournament/stage progression, random events.

var _coins_label: Label
var _xp_label: Label
var _tourney_box: VBoxContainer
var _stage_box: VBoxContainer
var _event_overlay: Control = null
var _dest: String = "main_menu"

const Selection = preload("res://scripts/career/selection.gd")


## v2.0: selection outcome panel after reserve/debut/main-XI matches.
## Shows the manager's decision and the honest reason behind it.
func _maybe_selection_panel(body: VBoxContainer, result: Dictionary) -> void:
	var ctx: String = str(result.get("selection_context", ""))
	if ctx == "":
		return
	var sel: Dictionary = result.get("selection", {})
	if sel.is_empty():
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeHelpers.panel_style())
	body.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var career: Node = get_node_or_null("/root/Career")
	var status: String = str(sel.get("status", ""))
	if ctx == "reserve" and bool(sel.get("selected", false)):
		col.add_child(ThemeHelpers.title_label("SELECTED FOR DEBUT!", 26, ThemeHelpers.GOLD))
		col.add_child(ThemeHelpers.body_label(str(sel.get("feedback", "")), 17))
		var b := ThemeHelpers.make_button("View Debut Announcement")
		b.pressed.connect(func() -> void: Router.show("career"))
		col.add_child(b)
	elif ctx == "debut":
		col.add_child(ThemeHelpers.title_label("DEBUT COMPLETE — MAIN XI", 24, ThemeHelpers.GREEN))
		col.add_child(ThemeHelpers.body_label("You are now in the main XI. Your debut performance has been recorded in your career history.", 17))
	elif ctx == "mainxi" and bool(sel.get("dropped", false)):
		col.add_child(ThemeHelpers.title_label("DROPPED TO RESERVES", 24, ThemeHelpers.RED))
		col.add_child(ThemeHelpers.body_label(str(sel.get("feedback", "")), 17))
	else:
		var chance_txt: String = "Selection chance: %d%%" % int(round(float(sel.get("chance", 0.0)) * 100.0))
		col.add_child(ThemeHelpers.title_label(chance_txt, 22, ThemeHelpers.INK))
		col.add_child(ThemeHelpers.body_label(str(sel.get("feedback", "")), 17))
	if career != null:
		var st: String = str(career.call("selection_status"))
		col.add_child(ThemeHelpers.body_label("Squad status: %s" % Selection.status_label(st), 15))


func _ready() -> void:
	var params: Dictionary = GameState.screen_params
	var result: Dictionary = params.get("result", {})
	if result.is_empty():
		result = GameState.last_result
	_dest = str(params.get("from", GameState.match_config.get("from", "main_menu")))
	if _dest != "career" and _dest != "main_menu":
		_dest = "main_menu"
	_build(params, result)


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _event_overlay != null:
		_event_overlay.queue_free()
		_event_overlay = null
		return
	_on_continue()


func _build(params: Dictionary, result: Dictionary) -> void:
	add_child(GCLUI.paper_bg())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	if result.is_empty():
		root.add_child(ThemeHelpers.title_label("No result data", 32, ThemeHelpers.RED))
		_add_buttons(root)
		return

	var winner: String = str(result.get("winner", "tie"))
	var title_text := "🤝 TIE"
	var title_color := ThemeHelpers.GOLD
	if winner == "player":
		title_text = "🏆 VICTORY!"
		title_color = ThemeHelpers.GREEN
	elif winner == "ai":
		title_text = "😞 DEFEAT"
		title_color = ThemeHelpers.RED
	root.add_child(ThemeHelpers.title_label(title_text, 44, title_color))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	# Innings scores.
	var ptn: String = str(GameState.match_config.get("player_team_name", "You"))
	var atn: String = str(GameState.match_config.get("ai_team_name", "Opponents"))
	_add_line(body, "%s   %d/%d (%s)" % [ptn, int(result.get("player_runs", 0)), int(result.get("player_wickets", 0)), str(result.get("player_overs", ""))], 24)
	_add_line(body, "%s   %d/%d (%s)" % [atn, int(result.get("ai_runs", 0)), int(result.get("ai_wickets", 0)), str(result.get("ai_overs", ""))], 24)

	# Top performers.
	var ts: Dictionary = result.get("top_scorer", {})
	if not ts.is_empty():
		_add_line(body, "🌟 Top scorer: %s — %d (%d balls)" % [str(ts.get("name", "?")), int(ts.get("runs", 0)), int(ts.get("balls", 0))], 20)
	var bb: Dictionary = result.get("best_bowler", {})
	if not bb.is_empty():
		_add_line(body, "🎯 Best bowler: %s — %d/%d" % [str(bb.get("name", "?")), int(bb.get("wickets", 0)), int(bb.get("runs", 0))], 20)

	# Coins / XP with count-up tween.
	var rw := HBoxContainer.new()
	rw.alignment = BoxContainer.ALIGNMENT_CENTER
	rw.add_theme_constant_override("separation", 30)
	body.add_child(rw)
	_coins_label = ThemeHelpers.title_label("🪙 +0", 28, ThemeHelpers.INK)
	_xp_label = ThemeHelpers.title_label("✨ +0 XP", 28, ThemeHelpers.INK)
	# No wrapping: inside the centered HBox an autowrap label collapses to a
	# 1px minimum width and stacks its text one character per line.
	_coins_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_xp_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	rw.add_child(_coins_label)
	rw.add_child(_xp_label)
	_animate_counts(int(result.get("coins", 0)), int(result.get("xp", 0)))

	# Achievements + unlocks.
	for aid in result.get("achievements_unlocked", []):
		var aname: String = str(GCLAchievements.by_id(str(aid)).get("name", str(aid)))
		_add_line(body, "🏅 Achievement: %s" % aname, 20)
	for u in result.get("new_unlocks", []):
		if u is Dictionary:
			_add_line(body, "🔓 %s" % str(u.get("name", u.get("id", "?"))), 20)
		else:
			_add_line(body, "🔓 %s" % str(u), 20)

	# Tournament / stage progression sections.
	_tourney_box = VBoxContainer.new()
	_tourney_box.add_theme_constant_override("separation", 6)
	body.add_child(_tourney_box)
	_stage_box = VBoxContainer.new()
	_stage_box.add_theme_constant_override("separation", 6)
	body.add_child(_stage_box)
	_handle_tournament(params, result)
	_handle_stage_complete(params, result)
	_maybe_selection_panel(body, result)
	_maybe_event_match_panel(body, result)

	_add_buttons(root)
	_maybe_event()


func _add_line(parent: VBoxContainer, text: String, size: int) -> void:
	var l := ThemeHelpers.body_label(text, size, ThemeHelpers.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)


func _add_buttons(root: VBoxContainer) -> void:
	var bar := ThemeHelpers.hbox(12)
	root.add_child(bar)
	var cont := GCLUI.fx(ThemeHelpers.make_button("▶  Continue"))
	cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cont.pressed.connect(_on_continue)
	bar.add_child(cont)
	var again := GCLUI.fx(ThemeHelpers.make_button("🔄  Play Again"))
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func() -> void: Router.replace("match"))
	bar.add_child(again)
	var home := GCLUI.fx(ThemeHelpers.make_button("🏠  Main Menu"))
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.pressed.connect(func() -> void: Router.reset_to("main_menu"))
	bar.add_child(home)


func _on_continue() -> void:
	Router.show(_dest)


func _animate_counts(coins: int, xp: int) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_tick_coins, 0.0, float(coins), 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_tick_xp, 0.0, float(xp), 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _tick_coins(v: float) -> void:
	_coins_label.text = "🪙 +%d" % int(v)


func _tick_xp(v: float) -> void:
	_xp_label.text = "✨ +%d XP" % int(v)


func _tournament_id(params: Dictionary) -> String:
	return str(params.get("tournament_id", GameState.match_config.get("tournament_id", "")))


func _stage_id(params: Dictionary) -> String:
	return str(params.get("stage_id", GameState.match_config.get("stage_id", "")))


func _player_won(result: Dictionary) -> bool:
	return bool(result.get("player_won", str(result.get("winner", "")) == "player"))


func _handle_tournament(params: Dictionary, result: Dictionary) -> void:
	var tid: String = _tournament_id(params)
	if tid == "":
		return
	var won: bool = _player_won(result)
	var rec: Dictionary = Career.record_tournament_match(tid, won)
	if bool(rec.get("champion", false)):
		var rew: Dictionary = Career.on_tournament_won(_stage_id(params))
		_add_line(_tourney_box, "🏆 CHAMPIONS! Tournament won!", 24)
		_add_line(_tourney_box, "🪙 +%d coins   ✨ +%d XP" % [int(rew.get("coins", 0)), int(rew.get("xp", 0))], 20)
		_add_line(_tourney_box, "🔓 Next stage unlocked!", 20)
		AudioMan.play("win")
	elif bool(rec.get("eliminated", false)):
		_add_line(_tourney_box, "😞 Knocked out of the tournament.", 22)
		_add_line(_tourney_box, "Retry the round from the Career map!", 20)
	elif won:
		_add_line(_tourney_box, "✅ Round won! Next: %s" % str(rec.get("next_round_name", "…")), 22)


func _handle_stage_complete(params: Dictionary, result: Dictionary) -> void:
	if _tournament_id(params) != "":
		return
	var stage_id: String = _stage_id(params)
	if stage_id == "" or not _player_won(result):
		return
	if Career.is_completed(stage_id):
		return
	var cur: Dictionary = Career.current_stage()
	if str(cur.get("id", "")) != stage_id:
		return
	var res: Dictionary = Career.complete_stage(stage_id)
	_add_line(_stage_box, "🎉 Stage complete: %s!" % str(cur.get("name", "")), 24)
	if bool(res.get("unlocked_next", false)):
		_add_line(_stage_box, "🔓 New stage unlocked!", 20)
	if int(res.get("coins", 0)) > 0:
		_add_line(_stage_box, "🪙 +%d stage reward" % int(res.get("coins", 0)), 20)


## v4.0: after a match the scheduler may surface a new event. It is shown as
## a "Street News" notice pointing at the Career Hub, where the full
## Accept/Decline card lives. The scheduler itself never rerolls.
func _maybe_event() -> void:
	var new_ev: Dictionary = Career.check_events()
	if new_ev.is_empty():
		return
	var panel := ThemeHelpers.make_panel(Vector2(560, 0))
	var col := ThemeHelpers.vbox(10)
	panel.add_child(col)
	col.add_child(ThemeHelpers.title_label("📯 Street News", 28, ThemeHelpers.RED))
	col.add_child(ThemeHelpers.title_label(
		"%s %s" % [str(new_ev.get("icon", "🎲")), str(new_ev.get("title", "New Event"))], 24, ThemeHelpers.INK))
	var txt := ThemeHelpers.body_label(
		"A new event is waiting in the Career Hub. Accept or decline it there — it stays until you decide.", 19, ThemeHelpers.INK)
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(txt)
	var view := GCLUI.fx(ThemeHelpers.make_button("📋  View in Career Hub"))
	view.pressed.connect(func() -> void:
		if _event_overlay != null:
			_event_overlay.queue_free()
			_event_overlay = null
		Router.show("career"))
	col.add_child(view)
	var later := GCLUI.fx(ThemeHelpers.make_button("Later"))
	later.pressed.connect(func() -> void:
		if _event_overlay != null:
			_event_overlay.queue_free()
			_event_overlay = null)
	col.add_child(later)
	_event_overlay = GCLUI.make_overlay(panel)
	add_child(_event_overlay)
	AudioMan.play("unlock")


## v4.0: outcome panel for event matches (team challenge / rival / target
## challenge) — success/failure, real rewards granted, rematch offer.
func _maybe_event_match_panel(body: VBoxContainer, result: Dictionary) -> void:
	var em: Dictionary = result.get("event_match", {})
	if em.is_empty() or not bool(em.get("resolved", false)):
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeHelpers.panel_style())
	body.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var success: bool = bool(em.get("success", false))
	col.add_child(ThemeHelpers.title_label(
		"🎉 %s — Complete!" % str(em.get("title", "Event")) if success
		else "💪 %s — Failed" % str(em.get("title", "Event")),
		24, ThemeHelpers.GREEN if success else ThemeHelpers.RED))
	var detail: String = str(em.get("detail", ""))
	if detail != "":
		col.add_child(ThemeHelpers.body_label(detail, 18, ThemeHelpers.INK))
	var coins_r: int = int(em.get("coins", 0))
	var xp_r: int = int(em.get("xp", 0))
	var rep: int = int(em.get("reputation_gain", 0))
	var rline := "Reward: 🪙+%d   ✨+%d XP" % [coins_r, xp_r]
	if rep > 0:
		rline += "   📈+%d reputation" % rep
	if coins_r == 0 and xp_r == 0:
		rline = "No reward this time — the event has been recorded."
	col.add_child(ThemeHelpers.body_label(rline, 19, ThemeHelpers.INK))
	if bool(em.get("rematch", false)):
		var rb := GCLUI.fx(ThemeHelpers.make_button("🔁  Request Rematch"))
		rb.pressed.connect(_on_request_rematch.bind(rb))
		col.add_child(rb)


func _on_request_rematch(btn: Button) -> void:
	Career.request_rematch()
	btn.disabled = true
	btn.text = "✅ Rematch requested — check the Career Hub"
