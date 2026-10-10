extends Control
## My Team: roster list with detail panel (stats, upgrade, captain,
## lineup order) and the recruit section.

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


func _refresh() -> void:
	_close_overlay()
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

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(head)
	var back := GCLUI.fx(ThemeHelpers.make_button("‹ Back", 56.0))
	back.custom_minimum_size = Vector2(150, 56)
	back.pressed.connect(func() -> void: Router.back())
	head.add_child(back)
	var t := ThemeHelpers.title_label("🏏 My Team", 30, ThemeHelpers.INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_coins_pill = GCLUI.make_pill("🪙 %d" % Economy.coins())
	head.add_child(_coins_pill)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	body.add_child(ThemeHelpers.title_label("📋 Squad", 24, ThemeHelpers.RED))
	var lineup: Array = SaveSystem.data.get("lineup", [])
	var captain: String = str(SaveSystem.data.get("captain_id", ""))
	for p in SaveSystem.data.get("team", []):
		if p is Dictionary:
			body.add_child(_roster_row(p, lineup, captain))

	body.add_child(ThemeHelpers.title_label("🎯 Recruit", 24, ThemeHelpers.RED))
	var stage_index: int = int(SaveSystem.data.get("career", {}).get("stage_index", 0))
	var any_recruit := false
	for def in GCLPlayers.recruits():
		if def is Dictionary and int(def.get("min_stage_index", 0)) <= stage_index:
			body.add_child(_recruit_row(def))
			any_recruit = true
	if not any_recruit:
		body.add_child(ThemeHelpers.body_label("No new players around yet — win matches to attract talent.", 18, ThemeHelpers.MUTED))


func _roster_row(p: Dictionary, lineup: Array, captain: String) -> PanelContainer:
	var panel := ThemeHelpers.make_panel(Vector2(0, 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(row)
	var pid: String = str(p.get("id", ""))
	var cap_mark := "  ⭐" if pid == captain else ""
	var is_user: bool = bool(p.get("is_user", false))
	var info := ThemeHelpers.body_label("%s  %s%s\n%s · OVR %d · Lv %d" % [
		GCLUI.avatar_emoji(int(p.get("avatar", 0))),
		str(p.get("name", "?")),
		" (you)" if is_user else cap_mark,
		str(p.get("role", "?")),
		int(p.get("overall", 0)),
		int(p.get("level", 1)),
	], 20, ThemeHelpers.INK)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var pos: int = lineup.find(pid) + 1
	var pos_l := ThemeHelpers.body_label("#%d" % pos if pos > 0 else "—", 18, ThemeHelpers.MUTED)
	pos_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	pos_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pos_l.custom_minimum_size = Vector2(44, 0)
	row.add_child(pos_l)
	var view := GCLUI.fx(ThemeHelpers.make_button("View ›", 52.0))
	view.custom_minimum_size = Vector2(130, 52)
	view.pressed.connect(_show_detail.bind(pid))
	row.add_child(view)
	return panel


func _player_by_id(pid: String) -> Dictionary:
	for p in SaveSystem.data.get("team", []):
		if p is Dictionary and str(p.get("id", "")) == pid:
			return p
	return {}


func _show_detail(pid: String) -> void:
	_close_overlay()
	var p: Dictionary = _player_by_id(pid)
	if p.is_empty():
		return
	var panel := ThemeHelpers.make_panel(Vector2(600, 0))
	var col := ThemeHelpers.vbox(10)
	panel.add_child(col)
	col.add_child(ThemeHelpers.title_label("%s  %s" % [GCLUI.avatar_emoji(int(p.get("avatar", 0))), str(p.get("name", "?"))], 30, ThemeHelpers.RED))
	var sub := ThemeHelpers.body_label("%s · OVR %d · Level %d · %d XP" % [
		str(p.get("role", "?")), int(p.get("overall", 0)), int(p.get("level", 1)), int(p.get("xp", 0)),
	], 20, ThemeHelpers.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var eff: Dictionary = Economy.effective_stats(p)
	for key in GCLUI.STAT_KEYS:
		var v: int = int(eff.get(key, p.get(key, 50)))
		col.add_child(GCLUI.make_stat_bar(str(GCLUI.STAT_LABELS[key]), v))

	var cost: int = Economy.upgrade_cost(p)
	var up := GCLUI.fx(ThemeHelpers.make_button("⬆  Upgrade  (🪙%d)" % cost))
	up.pressed.connect(_on_upgrade.bind(pid))
	col.add_child(up)

	var row2 := ThemeHelpers.hbox(10)
	col.add_child(row2)
	var cap_b := GCLUI.fx(ThemeHelpers.make_button("⭐  Make Captain"))
	cap_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap_b.pressed.connect(_on_make_captain.bind(pid))
	row2.add_child(cap_b)
	var close := GCLUI.fx(ThemeHelpers.make_button("✖  Close"))
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(_close_overlay)
	row2.add_child(close)

	var row3 := ThemeHelpers.hbox(10)
	col.add_child(row3)
	var up_btn := GCLUI.fx(ThemeHelpers.make_button("▲  Move Up"))
	up_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up_btn.pressed.connect(_on_move.bind(pid, -1))
	row3.add_child(up_btn)
	var dn_btn := GCLUI.fx(ThemeHelpers.make_button("▼  Move Down"))
	dn_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dn_btn.pressed.connect(_on_move.bind(pid, 1))
	row3.add_child(dn_btn)

	_overlay = GCLUI.make_overlay(panel)
	add_child(_overlay)


func _on_upgrade(pid: String) -> void:
	var p: Dictionary = _player_by_id(pid)
	if p.is_empty():
		return
	if Economy.upgrade_player(pid):
		AudioMan.play("coin")
		SaveSystem.save_game()
		_refresh()
	else:
		AudioMan.play("loss")
		GCLUI.set_pill_text(_coins_pill, "🪙 %d — need more!" % Economy.coins())


func _on_make_captain(pid: String) -> void:
	SaveSystem.data["captain_id"] = pid
	SaveSystem.save_game()
	AudioMan.play("unlock")
	_refresh()


func _on_move(pid: String, dir: int) -> void:
	var lineup: Array = SaveSystem.data.get("lineup", [])
	var i: int = lineup.find(pid)
	var j: int = i + dir
	if i < 0 or j < 0 or j >= lineup.size():
		return
	var tmp: Variant = lineup[i]
	lineup[i] = lineup[j]
	lineup[j] = tmp
	SaveSystem.data["lineup"] = lineup
	SaveSystem.save_game()
	_refresh()


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


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
