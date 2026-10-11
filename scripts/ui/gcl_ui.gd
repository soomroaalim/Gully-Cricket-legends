class_name GCLUI
extends RefCounted
## Game-specific UI helpers layered on ThemeHelpers (red/paper brand):
## pills, stat bars, modal overlays, screen chrome, avatar/cosmetic data,
## and match-config building per CONTRACTS.md.

const AVATARS: Array[String] = ["😎", "🙂", "😀", "🧔", "👦", "👩"]
const COSMETIC_COLORS: Array[String] = ["#e53935", "#1e88e5", "#43a047", "#fdd835"]
const STAT_KEYS: Array[String] = ["batting", "bowling", "fielding", "speed", "stamina"]
const STAT_LABELS: Dictionary = {
	"batting": "Batting", "bowling": "Bowling", "fielding": "Fielding",
	"speed": "Speed", "stamina": "Stamina",
}
const SLOT_CATEGORIES: Array = [
	["Bat", "bats", "🏏"], ["Ball", "balls", "⚾"], ["Jersey", "jerseys", "👕"],
	["Shoes", "shoes", "👟"], ["Cap", "caps", "🧢"],
]


static func _click_fx() -> void:
	AudioMan.play("click")
	GameState.vibrate(15)


## Wire click sound + haptic to a button. Returns the button for chaining.
static func fx(b: Button) -> Button:
	b.pressed.connect(Callable(GCLUI, "_click_fx"))
	return b


## Flat paper background for sub-screens.
static func paper_bg() -> ColorRect:
	var c := ColorRect.new()
	c.color = ThemeHelpers.PAPER_DIM
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Standard sub-screen header: red back button, centered title.
static func screen_head(parent: VBoxContainer, title_text: String, back_cb: Callable) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	var back := fx(ThemeHelpers.make_button("‹ Back", 56.0))
	back.custom_minimum_size = Vector2(150, 56)
	back.pressed.connect(back_cb)
	bar.add_child(back)
	var t := ThemeHelpers.title_label(title_text, 30, ThemeHelpers.INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(t)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(150, 0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(pad)
	parent.add_child(bar)


## Dark info chip (for use over the animated backdrop). Update via set_pill_text.
static func make_pill(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	p.add_theme_stylebox_override("panel", sb)
	var l := ThemeHelpers.hud_label(text, 18)
	l.name = "Text"
	p.add_child(l)
	return p


static func set_pill_text(pill: PanelContainer, text: String) -> void:
	(pill.get_node("Text") as Label).text = text


## Label + ProgressBar + value row on paper background.
static func make_stat_bar(label_text: String, value: int, max_value: int = 99) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var lab := ThemeHelpers.body_label(label_text, 18, ThemeHelpers.MUTED)
	lab.custom_minimum_size = Vector2(104, 0)
	row.add_child(lab)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.18)
	bg.set_corner_radius_all(9)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ThemeHelpers.GREEN if value >= 60 else (ThemeHelpers.GOLD if value >= 40 else ThemeHelpers.RED)
	fill.set_corner_radius_all(9)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var val := ThemeHelpers.body_label(str(value), 18, ThemeHelpers.INK)
	val.custom_minimum_size = Vector2(44, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	return row


## Full-rect modal overlay: dim layer + centered panel.
static func make_overlay(panel: Control) -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(ThemeHelpers.dim_layer())
	o.add_child(ThemeHelpers.centered(panel))
	return o


static func clear(c: Control) -> void:
	for child in c.get_children():
		c.remove_child(child)
		child.queue_free()


static func avatar_emoji(idx: int) -> String:
	return AVATARS[absi(idx) % AVATARS.size()]


static func user_player() -> Dictionary:
	var team: Array = SaveSystem.data.get("team", [])
	for p in team:
		if p is Dictionary and bool(p.get("is_user", false)):
			return p
	return {}


static func lineup_players() -> Array:
	var team: Array = SaveSystem.data.get("team", [])
	var ids: Array = SaveSystem.data.get("lineup", [])
	var out: Array = []
	for pid in ids:
		for p in team:
			if p is Dictionary and str(p.get("id", "")) == str(pid):
				out.append(p)
				break
	if out.is_empty():
		for p in team:
			if p is Dictionary:
				out.append(p)
	return out


static func team_name() -> String:
	var n: String = str(SaveSystem.data.get("player_name", "")).strip_edges()
	return "%s XI" % n if n != "" else "Gully XI"


## Builds a MatchEngine-ready config dict per CONTRACTS.md.
static func build_match_config(mode_key: String, difficulty: String, stage: Dictionary, rng: GCLRng, extra: Dictionary = {}) -> Dictionary:
	var mc: Dictionary = GCLConfig.MODE_CONFIG.get(mode_key, GCLConfig.MODE_CONFIG["1v1"])
	var lineup: Array = lineup_players()
	var team_names: Array = stage.get("team_names", [])
	var ai_name: String = "Street XI"
	if not team_names.is_empty():
		ai_name = str(rng.pick(team_names))
	var user_id: String = ""
	for p in lineup:
		if p is Dictionary and bool(p.get("is_user", false)):
			user_id = str(p.get("id", ""))
	# v3.0: role-based batting order (persisted as the lineup order).
	# Base ratings in the save are never modified — effective_stats copies.
	var user_first: bool = str(extra.get("selection_context", "")) == "reserve"
	lineup = GCLDevelopment.batting_order(lineup, user_id, user_first)
	var order_ids: Array = []
	for p in lineup:
		if p is Dictionary:
			order_ids.append(str(p.get("id", "")))
	if not order_ids.is_empty():
		SaveSystem.data["lineup"] = order_ids
	# v3.0: pitch + weather, seeded — real match-engine effects.
	# v4.0: rain is rolled separately (~18%, never every match); a wet match
	# shortens the innings and slows the outfield. "no_rain" opts out.
	var rain_roll: float = -1.0
	if not bool(extra.get("no_rain", false)):
		rain_roll = rng.next()
	var cond: Dictionary = GCLDevelopment.pick_conditions(rng.next(), rng.next(), rain_roll)
	var cfg: Dictionary = {
		"mode": mode_key,
		"overs": int(mc.get("overs", 2)),
		"max_wickets": int(mc.get("max_wickets", 3)),
		"stage_id": str(stage.get("id", "")),
		"stage_name": str(stage.get("name", "")),
		"difficulty": difficulty,
		"player_team_name": team_name(),
		"ai_team_name": ai_name,
		"player_team": lineup,
		"ai_team": GCLPlayers.generate_opponent_team(stage, rng),
		"user_player_id": user_id,
		"user_bats_first": true,
		"seed": GCLRng.random_seed(),
		"pitch": cond["pitch"],
		"weather": cond["weather"],
	}
	for k in extra.keys():
		cfg[k] = extra[k]
	# v4.0: rain shortens the innings (min 1 over) and flags the match so the
	# toss screen can warn and the career history can log it.
	if bool((cfg.get("weather", {}) as Dictionary).get("rain", false)):
		cfg["overs"] = GCLCareerEvents.rain_overs(int(cfg.get("overs", 2)))
		cfg["rain_affected"] = true
	# v3.0: effective stats for the user's player (form/fitness/injury/
	# tactical). Applied last so it covers squad overrides (reserve/debut).
	# Base ratings in the save are never modified — effective_stats copies.
	if user_id != "":
		var final_team: Array = cfg.get("player_team", [])
		for i in final_team.size():
			var pd: Dictionary = final_team[i]
			if pd is Dictionary and str(pd.get("id", "")) == user_id:
				final_team[i] = GCLDevelopment.effective_stats(pd)
				break
		cfg["player_team"] = final_team
	return cfg


## v3.0: injury gate. Returns "" when the user may play a match, else a
## human-readable reason. Call before building a match config.
static func match_block_reason() -> String:
	var u: Dictionary = user_player()
	if u.is_empty():
		return ""
	if not GCLDevelopment.is_available(u):
		return "%s — rest to recover before playing." % GCLDevelopment.injury_label(u)
	return ""


## Small modal notice overlay. Used for injury blocks and similar messages.
static func notice(parent: Control, title: String, text: String) -> void:
	var panel := ThemeHelpers.make_panel(Vector2(520, 0))
	var col := ThemeHelpers.vbox(10)
	panel.add_child(col)
	col.add_child(ThemeHelpers.title_label(title, 26, ThemeHelpers.RED))
	var lab := ThemeHelpers.body_label(text, 19, ThemeHelpers.INK)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(lab)
	var ok := fx(ThemeHelpers.make_button("OK", 56))
	col.add_child(ok)
	var overlay := make_overlay(panel)
	parent.add_child(overlay)
	ok.pressed.connect(func() -> void: overlay.queue_free())


static func bonus_text(bonus: Dictionary) -> String:
	var parts: Array[String] = []
	for k in bonus.keys():
		parts.append("+%d %s" % [int(bonus[k]), str(k).capitalize()])
	return ", ".join(parts) if not parts.is_empty() else "No bonus"


## Parse a hex color string ("#rrggbb") or pass a Color through.
static func col(v: Variant, fallback: Color) -> Color:
	if v is Color:
		return v
	if v is String:
		var s: String = str(v).strip_edges()
		if s.begins_with("#") and (s.length() == 7 or s.length() == 9 or s.length() == 4):
			return Color(s)
	return fallback


## Animated street-cricket backdrop: stage sky/ground colors + drifting clouds.
class Backdrop:
	extends Control

	var sky_top: Color = Color("#7a1f1f")
	var sky_bottom: Color = Color("#d98a4b")
	var ground_color: Color = Color("#2e7d32")
	var accent_color: Color = Color("#f2b134")

	var _clouds: Array = []
	var _sky_tex: GradientTexture2D = null


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r := RandomNumberGenerator.new()
		r.seed = 424242
		for i in 6:
			_clouds.append({
				"x": r.randf_range(-240.0, 1180.0),
				"y": r.randf_range(16.0, 170.0),
				"s": r.randf_range(0.6, 1.4),
				"speed": r.randf_range(8.0, 26.0),
			})
		_rebuild_sky()


	func setup_from_stage(stage: Dictionary) -> void:
		var g: Dictionary = stage.get("ground", {})
		var sky: Array = g.get("sky", [])
		if sky.size() >= 2:
			sky_top = GCLUI.col(sky[0], sky_top)
			sky_bottom = GCLUI.col(sky[1], sky_bottom)
		ground_color = GCLUI.col(g.get("ground", ""), ground_color)
		accent_color = GCLUI.col(g.get("accent", ""), accent_color)
		_rebuild_sky()
		queue_redraw()


	func _rebuild_sky() -> void:
		var grad := Gradient.new()
		grad.set_color(0, sky_top)
		grad.set_color(1, sky_bottom)
		_sky_tex = GradientTexture2D.new()
		_sky_tex.gradient = grad
		_sky_tex.fill_from = Vector2(0.5, 0.0)
		_sky_tex.fill_to = Vector2(0.5, 1.0)


	func _process(delta: float) -> void:
		for c in _clouds:
			c["x"] = float(c["x"]) + float(c["speed"]) * delta
			if float(c["x"]) > 1220.0:
				c["x"] = -280.0
		queue_redraw()


	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if w <= 0.0 or h <= 0.0 or _sky_tex == null:
			return
		var horizon: float = h * 0.62
		draw_texture_rect(_sky_tex, Rect2(0, 0, w, horizon), false)
		# Floodlight glow.
		draw_circle(Vector2(w * 0.10, h * 0.10), 90.0, Color(1.0, 0.85, 0.4, 0.10))
		draw_circle(Vector2(w * 0.90, h * 0.10), 90.0, Color(1.0, 0.85, 0.4, 0.10))
		draw_circle(Vector2(w * 0.10, h * 0.10), 26.0, Color(1.0, 0.92, 0.6, 0.85))
		draw_circle(Vector2(w * 0.90, h * 0.10), 26.0, Color(1.0, 0.92, 0.6, 0.85))
		# Drifting clouds.
		for c in _clouds:
			var p := Vector2(float(c["x"]), float(c["y"]))
			var s: float = float(c["s"])
			var cc := Color(1, 1, 1, 0.18)
			draw_circle(p, 34.0 * s, cc)
			draw_circle(p + Vector2(30.0 * s, 6.0 * s), 26.0 * s, cc)
			draw_circle(p + Vector2(-30.0 * s, 8.0 * s), 24.0 * s, cc)
		# Ground.
		draw_rect(Rect2(0, horizon, w, h - horizon), ground_color)
		draw_rect(Rect2(0, horizon, w, 6.0), accent_color)
		# Pitch strip.
		var pw: float = 130.0
		draw_rect(Rect2((w - pw) * 0.5, horizon + 34.0, pw, h - horizon - 68.0), ground_color.lightened(0.18))
		# Crease line.
		draw_line(Vector2((w - pw) * 0.5, horizon + 60.0), Vector2((w + pw) * 0.5, horizon + 60.0), Color(1, 1, 1, 0.5), 3.0)
