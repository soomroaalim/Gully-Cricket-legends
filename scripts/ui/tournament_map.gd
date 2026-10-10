extends Control
## Tournament progression map (v3.0): the 6 stage tournaments in progression
## order with locked / unlocked / active / completed states, unlock
## conditions, and Resume / New actions. Presents EXISTING tournament data —
## it does not rebuild the tournament system.

const DrawnIcon = preload("res://scripts/ui/menu_art.gd").DrawnIcon


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
	GCLUI.screen_head(root, "Tournament Map", func() -> void: Router.back())
	var tier: Dictionary = Career.ladder_tier()
	root.add_child(ThemeHelpers.body_label(
		"Career tier: %s — win tournaments to climb." % str(tier.get("name", "")),
		19, ThemeHelpers.MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var col := ThemeHelpers.vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	var stages: Array = Career.stages()
	for i in stages.size():
		var stage: Dictionary = stages[i]
		col.add_child(_node_card(stage, i, stages))
		if i < stages.size() - 1:
			col.add_child(_connector())


func _connector() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 14)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _node_state(stage: Dictionary, idx: int, stages: Array) -> Dictionary:
	var t: Dictionary = stage.get("tournament", {})
	var tid: String = str(t.get("id", ""))
	var sid: String = str(stage.get("id", ""))
	var trophies: Array = SaveSystem.data["career"].get("trophies", [])
	var unlocked: Array = SaveSystem.data["career"].get("unlocked", [])
	if trophies.has(tid):
		return {"state": "completed", "icon": "trophy", "line": "Completed — champions!",
			"action": "new", "action_label": "New Tournament"}
	var ts: Dictionary = Career.tournament_state(tid)
	var cur: int = int(ts.get("round", 0))
	var rounds: Array = t.get("rounds", [])
	if cur > 0 and cur < rounds.size():
		return {"state": "active", "icon": "play",
			"line": "In progress — next: %s" % str(rounds[cur]),
			"action": "resume", "action_label": "Resume"}
	if unlocked.has(sid):
		return {"state": "unlocked", "icon": "star", "line": "Unlocked — ready to play",
			"action": "new", "action_label": "Start"}
	var prev_name: String = "previous stage"
	if idx > 0:
		prev_name = str(stages[idx - 1].get("name", "previous stage"))
	return {"state": "locked", "icon": "lock", "line": "Locked — complete %s first" % prev_name,
		"action": "", "action_label": ""}


func _node_card(stage: Dictionary, idx: int, stages: Array) -> PanelContainer:
	var t: Dictionary = stage.get("tournament", {})
	var info: Dictionary = _node_state(stage, idx, stages)
	var card := ThemeHelpers.make_panel(Vector2(0, 0))
	if str(info["state"]) == "completed":
		var sb := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		sb.border_color = ThemeHelpers.GOLD
		sb.set_border_width_all(3)
		card.add_theme_stylebox_override("panel", sb)
	var row := ThemeHelpers.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	card.add_child(row)
	var icon := DrawnIcon.new(str(info["icon"]) if str(info["icon"]) != "lock" else "x",
		ThemeHelpers.GOLD if str(info["state"]) == "completed" else ThemeHelpers.RED)
	icon.custom_minimum_size = Vector2(52, 52)
	row.add_child(icon)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 4)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	mid.add_child(ThemeHelpers.title_label(str(t.get("name", "Tournament")), 22, ThemeHelpers.INK))
	mid.add_child(ThemeHelpers.body_label(str(stage.get("name", "")), 18, ThemeHelpers.MUTED))
	mid.add_child(ThemeHelpers.body_label(str(info["line"]), 18,
		ThemeHelpers.MUTED if str(info["state"]) == "locked" else ThemeHelpers.INK))
	var prize := ThemeHelpers.body_label("Prize: %d coins · %d XP" % [
		int(t.get("prize", 0)), int(t.get("prize_xp", 0))], 17, ThemeHelpers.MUTED)
	mid.add_child(prize)
	if str(info["action"]) != "":
		var btn := GCLUI.fx(ThemeHelpers.make_button(str(info["action_label"]), 52.0))
		btn.custom_minimum_size = Vector2(170, 52)
		btn.pressed.connect(_on_action.bind(stage, info))
		row.add_child(btn)
	return card


func _on_action(stage: Dictionary, info: Dictionary) -> void:
	var block: String = GCLUI.match_block_reason()
	if block != "":
		GCLUI.notice(self, "Unavailable", block)
		return
	var t: Dictionary = stage.get("tournament", {})
	var tid: String = str(t.get("id", ""))
	var action: String = str(info["action"])
	if action == "new":
		# Fresh run (also used to replay a completed tournament).
		Career.reset_tournament(tid)
	var ts: Dictionary = Career.tournament_state(tid)
	var rounds: Array = t.get("rounds", [])
	var cur: int = clampi(int(ts.get("round", 0)), 0, maxi(0, rounds.size() - 1))
	var rng := GCLRng.new(GCLRng.random_seed())
	var cfg: Dictionary = GCLUI.build_match_config("gully6",
		str(stage.get("difficulty", "NORMAL")), stage, rng, {
			"from": "career", "stage_id": str(stage.get("id", "")),
			"tournament_id": tid, "round_name": str(rounds[cur]) if not rounds.is_empty() else "",
		})
	GameState.match_config = cfg
	Router.show("match", {"from": "career", "tournament_id": tid,
		"stage_id": str(stage.get("id", ""))})
