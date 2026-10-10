extends Control
## Match scene: toss -> ball loop -> innings break -> result.
## Reads GameState.match_config, drives MatchEngine (loaded dynamically via
## load() so this script parses even while sibling scripts are still in
## flight), renders the ground via FieldView, HUD via Controls.
##
## Debug seam: GameState.match_config["debug_autoplay"] = true makes the whole
## match play itself (toss, shots, needle, innings break). Also honors
## GameState.screen_params["engine_override"] as a test double for the engine.

enum Phase {
	IDLE, INTRO, TOSS_CALL, TOSS_CHOICE, RUNUP, FLIGHT, AWAIT_INPUT,
	RESULT, BOWL_PICK, NEEDLE, INNINGS_BREAK, DONE,
}

const ENGINE_PATH := "res://scripts/gameplay/match_engine.gd"
const TAP_MAX_PX := 24.0
const INPUT_TIMEOUT_S := 1.4
const NEEDLE_PERIOD_S := 1.4
const NEEDLE_HALF_PX := 260.0
const NEEDLE_CX := 480.0

const TIMING_COLORS := {
	"PERFECT": Color("2e7d32"), "GOOD": Color("558b2f"),
	"EARLY": Color("ef6c00"), "LATE": Color("ef6c00"),
	"MISS": Color("757575"),
}

# Survives scene reloads (e.g. Router.back() from the scoreboard screen).
static var resume_engine: Variant = null

var engine: Variant = null
var config: Dictionary = {}
var phase: int = Phase.IDLE

var _paused := false
var _debug_autoplay := false
var _rng: GCLRng = GCLRng.new(1234)

# Ball-flow state.
var _delivery: Dictionary = {}
var _pending_flight := 0.7
var _pending_drift := 0.0
var _ball_kind := "bat" # bat | bowl | ai
var _arrival_ms := 0
var _input_left := 0.0

# Touch gesture state.
var _pressing := false
var _press_pos := Vector2.ZERO

# Bowling state.
var _bowl_line := "Middle"
var _bowl_length := "Good"
var _bowl_type := "Normal"
var _needle_t := 0.0
var _needle_active := false
var _auto_lock_in := -1.0

# Debug autoplay scheduling.
var _auto_in := -1.0
var _auto_action := ""

var _confirm_cb := Callable()

@onready var field: FieldView = $World
@onready var hud_layer: CanvasLayer = $HUD

# HUD refs.
var _hud_score: Label
var _hud_overs: Label
var _hud_target: Label
var _hud_striker: Label
var _hud_bowler: Label
var _balls_box: HBoxContainer
var _timing_panel: PanelContainer
var _timing_label: Label
var _banner_label: Label
var _hint_label: Label
# Panels.
var _panel_root: Control
var _dim: ColorRect
var _panels: Dictionary = {}
# Needle overlay.
var _needle: Control
var _needle_marker: ColorRect


static func classify_gesture(vec: Vector2) -> String:
	if vec.length() < TAP_MAX_PX:
		return "tap"
	if absf(vec.x) >= absf(vec.y):
		return "swipeRight" if vec.x > 0.0 else "swipeLeft"
	return "swipeUp" if vec.y < 0.0 else "tap"


func _ready() -> void:
	config = GameState.match_config
	_debug_autoplay = bool(config.get("debug_autoplay", false))
	_rng = GCLRng.new(int(config.get("seed", 1234)) ^ 0x5F3759DF)
	_build_hud()
	_build_panels()
	_build_needle()
	field.set_stage(_stage_dict())
	field.runup_finished.connect(_on_runup_done)
	field.ball_arrived.connect(_on_ball_arrived)
	field.ball_bounced.connect(_on_ball_bounced)
	field.result_anim_finished.connect(_on_result_anim_done)
	if not _config_ok():
		_show_error("Match config is missing.\nStart the match from the menu or career map.")
		return
	if resume_engine != null:
		engine = resume_engine
		resume_engine = null
		_wire_engine()
		_hide_panels()
		_next_ball()
		return
	_show_intro()


func _config_ok() -> bool:
	return not (config.get("player_team", []) as Array).is_empty() \
		and not (config.get("ai_team", []) as Array).is_empty()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _confirm_cb.is_valid():
		_confirm_cb = Callable()
		_hide_panels()
	elif _paused:
		_set_paused(false)
	elif _any_panel_visible():
		Router.back()
	else:
		_set_paused(true)


func _process(delta: float) -> void:
	if _paused:
		return
	if _needle_active:
		_needle_t += delta
		var cyc: float = fmod(_needle_t / NEEDLE_PERIOD_S, 2.0)
		var tri: float = 1.0 - absf(cyc - 1.0)
		_needle_marker.position.x = NEEDLE_CX - NEEDLE_HALF_PX + tri * 2.0 * NEEDLE_HALF_PX - 6.0
	if phase == Phase.AWAIT_INPUT:
		_input_left -= delta
		if _input_left <= 0.0:
			_resolve_batting("", 0.0)
	if _auto_lock_in > 0.0:
		_auto_lock_in -= delta
		if _auto_lock_in <= 0.0 and _needle_active:
			_lock_needle()
	if _auto_in > 0.0:
		_auto_in -= delta
		if _auto_in <= 0.0:
			_run_auto_action()


func _run_auto_action() -> void:
	var action := _auto_action
	_auto_action = ""
	_auto_in = -1.0
	match action:
		"intro":
			_show_toss()
		"toss":
			_on_toss_pick("Heads")
		"choice_bat":
			_on_toss_choice(true)
		"bowl":
			_on_bowl_pressed()
		"hit":
			_resolve_batting("tap", 12.0)
		"break":
			_on_start_second_innings()


func _schedule_auto(action: String, delay: float) -> void:
	if _debug_autoplay:
		_auto_action = action
		_auto_in = delay


func _input(event: InputEvent) -> void:
	if _paused:
		return
	if phase == Phase.NEEDLE and _needle_active:
		if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			_lock_needle()
		return
	if phase != Phase.AWAIT_INPUT:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_pressing = true
			_press_pos = t.position
		elif _pressing:
			_pressing = false
			var shot := classify_gesture(t.position - _press_pos)
			var offset := float(Time.get_ticks_msec() - _arrival_ms)
			_resolve_batting(shot, offset)


# ------------------------------------------------------------- HUD build ---

func _build_hud() -> void:
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 78.0
	top.add_theme_stylebox_override("panel", ThemeHelpers.hud_bar_style())
	hud_layer.add_child(top)
	var hb := ThemeHelpers.hbox(14)
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_child(hb)

	var score_v := VBoxContainer.new()
	score_v.add_theme_constant_override("separation", 0)
	hb.add_child(score_v)
	_hud_score = ThemeHelpers.hud_label("0/0", 30)
	score_v.add_child(_hud_score)
	_hud_overs = ThemeHelpers.hud_label("0.0/6 ov", 16, Color("b9c4d0"))
	score_v.add_child(_hud_overs)

	_hud_target = ThemeHelpers.hud_label("", 20, ThemeHelpers.GOLD)
	_hud_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_target.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(_hud_target)

	var who_v := VBoxContainer.new()
	who_v.add_theme_constant_override("separation", 2)
	hb.add_child(who_v)
	_hud_striker = ThemeHelpers.hud_label("", 16, Color.WHITE)
	who_v.add_child(_hud_striker)
	_hud_bowler = ThemeHelpers.hud_label("", 16, Color("b9c4d0"))
	who_v.add_child(_hud_bowler)

	var score_btn := ThemeHelpers.make_button("Score", 56)
	score_btn.custom_minimum_size = Vector2(110, 56)
	score_btn.pressed.connect(_on_score_pressed)
	hb.add_child(score_btn)
	var pause_btn := ThemeHelpers.make_button("II", 56)
	pause_btn.custom_minimum_size = Vector2(64, 56)
	pause_btn.pressed.connect(func() -> void: _set_paused(true))
	hb.add_child(pause_btn)

	_balls_box = HBoxContainer.new()
	_balls_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_balls_box.position = Vector2(16, 86)
	_balls_box.add_theme_constant_override("separation", 6)
	_balls_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(_balls_box)

	_timing_panel = PanelContainer.new()
	_timing_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timing_panel.position = Vector2(-90, 86)
	_timing_panel.custom_minimum_size = Vector2(180, 52)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0, 0, 0, 0.62)
	tsb.set_corner_radius_all(12)
	tsb.content_margin_left = 12.0
	tsb.content_margin_right = 12.0
	_timing_panel.add_theme_stylebox_override("panel", tsb)
	_timing_label = ThemeHelpers.hud_label("", 22, Color.WHITE)
	_timing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timing_panel.add_child(_timing_label)
	_timing_panel.visible = false
	hud_layer.add_child(_timing_panel)

	_banner_label = Label.new()
	_banner_label.set_anchors_preset(Control.PRESET_CENTER)
	_banner_label.position = Vector2(-300, -70)
	_banner_label.custom_minimum_size = Vector2(600, 120)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 64)
	_banner_label.add_theme_color_override("font_color", Color.WHITE)
	_banner_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_banner_label.add_theme_constant_override("shadow_offset_x", 3)
	_banner_label.add_theme_constant_override("shadow_offset_y", 3)
	_banner_label.visible = false
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(_banner_label)

	_hint_label = ThemeHelpers.hud_label("", 20, Color.WHITE)
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_label.position = Vector2(-300, -64)
	_hint_label.custom_minimum_size = Vector2(600, 40)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_hint_label.add_theme_constant_override("shadow_offset_x", 2)
	_hint_label.add_theme_constant_override("shadow_offset_y", 2)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(_hint_label)


func _build_panels() -> void:
	_panel_root = Control.new()
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(_panel_root)
	_dim = ThemeHelpers.dim_layer()
	_dim.visible = false
	_panel_root.add_child(_dim)
	_panels["intro"] = _build_intro_panel()
	_panels["toss"] = _build_toss_panel()
	_panels["choice"] = _build_choice_panel()
	_panels["bowl"] = _build_bowl_panel()
	_panels["pause"] = _build_pause_panel()
	_panels["break"] = _build_break_panel()
	_panels["error"] = _build_error_panel()
	_panels["confirm"] = _build_confirm_panel()
	for k in _panels.keys():
		(_panels[k] as Control).visible = false
		_panel_root.add_child(_panels[k] as Control)


func _show_only(panel_name: String) -> void:
	_dim.visible = panel_name != ""
	for k in _panels.keys():
		(_panels[k] as Control).visible = (k == panel_name)


func _hide_panels() -> void:
	_show_only("")
	_confirm_cb = Callable()


func _any_panel_visible() -> bool:
	for k in _panels.keys():
		if (_panels[k] as Control).visible:
			return true
	return false


func _banner(text: String, color: Color) -> void:
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", color)
	_banner_label.visible = true
	_banner_label.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_interval(0.75)
	tw.tween_property(_banner_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: _banner_label.visible = false)


func _timing_chip(text: String, color: Color) -> void:
	_timing_label.text = text
	_timing_label.add_theme_color_override("font_color", color)
	_timing_panel.visible = true
	_timing_panel.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(_timing_panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		_timing_panel.visible = false
		_timing_panel.modulate = Color(1, 1, 1, 1))


# ---------------------------------------------------------- panel builds ---

func _build_intro_panel() -> CenterContainer:
	var panel := ThemeHelpers.make_panel(Vector2(600, 0))
	var v := ThemeHelpers.vbox(14)
	panel.add_child(v)
	v.add_child(ThemeHelpers.title_label(str(config.get("stage_name", "Gully Match"))))
	var mode_cfg: Dictionary = GCLConfig.MODE_CONFIG.get(str(config.get("mode", "gully6")), {})
	var info := ThemeHelpers.body_label(
		"%s  vs  %s\n%s  -  %s overs  -  %s" % [
			str(config.get("player_team_name", "You")),
			str(config.get("ai_team_name", "Opponents")),
			str(mode_cfg.get("label", "")), str(config.get("overs", 6)),
			str(config.get("difficulty", "NORMAL"))],
		20, ThemeHelpers.MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var start := ThemeHelpers.make_button("Start Match")
	start.pressed.connect(_show_toss)
	v.add_child(start)
	return ThemeHelpers.centered(panel)


## v3.0 toss screen: format, teams + ratings, venue, pitch/weather with
## their REAL gameplay effects (only implemented effects are described),
## then the fair toss call. Phase guards prevent re-toss exploits.
func _build_toss_panel() -> CenterContainer:
	var panel := ThemeHelpers.make_panel(Vector2(600, 0))
	var v := ThemeHelpers.vbox(12)
	panel.add_child(v)
	v.add_child(ThemeHelpers.title_label("Match Toss", 30))
	var mode_label: String = str(GCLConfig.MODE_CONFIG.get(
		str(config.get("mode", "1v1")), {}).get("label", "Match"))
	v.add_child(ThemeHelpers.body_label(mode_label, 20, ThemeHelpers.MUTED))
	# Teams + ratings + venue.
	var p_ovr: int = _team_overall(config.get("player_team", []))
	var a_ovr: int = _team_overall(config.get("ai_team", []))
	var teams := ThemeHelpers.body_label(
		"%s  (OVR %d)\nvs\n%s  (OVR %d)" % [
			str(config.get("player_team_name", "You")), p_ovr,
			str(config.get("ai_team_name", "Opponents")), a_ovr], 21)
	teams.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(teams)
	var venue: String = str(config.get("stage_name", ""))
	if venue != "":
		var vl := ThemeHelpers.body_label("Venue: %s" % venue, 18, ThemeHelpers.MUTED)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(vl)
	# Conditions with honest effect descriptions.
	var pitch: Dictionary = config.get("pitch", {})
	var weather: Dictionary = config.get("weather", {})
	if not pitch.is_empty() or not weather.is_empty():
		var cond := ThemeHelpers.body_label("", 18, ThemeHelpers.MUTED)
		var lines: Array[String] = []
		if not pitch.is_empty():
			lines.append("Pitch: %s — %s" % [str(pitch.get("name", "")), str(pitch.get("desc", ""))])
		if not weather.is_empty():
			lines.append("Weather: %s — %s" % [str(weather.get("name", "")), str(weather.get("desc", ""))])
		cond.text = "\n".join(lines)
		cond.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cond.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(cond)
	var sub := ThemeHelpers.body_label("Call it. Winner chooses to bat or bowl first.", 20, ThemeHelpers.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var row := ThemeHelpers.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var heads := ThemeHelpers.make_button("Heads")
	heads.custom_minimum_size = Vector2(200, 64)
	heads.pressed.connect(_on_toss_pick.bind("Heads"))
	row.add_child(heads)
	var tails := ThemeHelpers.make_button("Tails")
	tails.custom_minimum_size = Vector2(200, 64)
	tails.pressed.connect(_on_toss_pick.bind("Tails"))
	row.add_child(tails)
	var result := ThemeHelpers.body_label("", 22)
	result.name = "Result"
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(result)
	return ThemeHelpers.centered(panel)


static func _team_overall(team: Array) -> int:
	if team.is_empty():
		return 50
	var total: int = 0
	var n: int = 0
	for p in team:
		if p is Dictionary:
			total += int((p as Dictionary).get("overall", 50))
			n += 1
	return int(round(float(total) / float(maxi(n, 1))))


func _build_choice_panel() -> CenterContainer:
	var panel := ThemeHelpers.make_panel(Vector2(520, 0))
	var v := ThemeHelpers.vbox(14)
	panel.add_child(v)
	v.add_child(ThemeHelpers.title_label("You won the toss!"))
	var sub := ThemeHelpers.body_label("What will your team do first?", 20, ThemeHelpers.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var row := ThemeHelpers.hbox(16)
	v.add_child(row)
	var bat := ThemeHelpers.make_button("Bat First")
	bat.custom_minimum_size = Vector2(200, 64)
	bat.pressed.connect(_on_toss_choice.bind(true))
	row.add_child(bat)
	var bowl := ThemeHelpers.make_button("Bowl First")
	bowl.custom_minimum_size = Vector2(200, 64)
	bowl.pressed.connect(_on_toss_choice.bind(false))
	row.add_child(bowl)
	return ThemeHelpers.centered(panel)


func _build_bowl_panel() -> CenterContainer:
	var panel := ThemeHelpers.make_panel(Vector2(640, 0))
	var v := ThemeHelpers.vbox(10)
	panel.add_child(v)
	v.add_child(ThemeHelpers.title_label("Your ball", 28))
	v.add_child(_bowl_row("Line", ["Off", "Middle", "Leg"], "_bowl_line"))
	v.add_child(_bowl_row("Length", ["Yorker", "Good", "Short"], "_bowl_length"))
	v.add_child(_bowl_row("Type", ["Normal", "Fast", "Bouncer", "Slower", "Yorker"], "_bowl_type"))
	var bowl := ThemeHelpers.make_button("Bowl!")
	bowl.pressed.connect(_on_bowl_pressed)
	v.add_child(bowl)
	return ThemeHelpers.centered(panel)


func _bowl_row(caption: String, options: Array, field_name: String) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	wrap.add_child(ThemeHelpers.body_label(caption, 18, ThemeHelpers.MUTED))
	var row := ThemeHelpers.hbox(8)
	wrap.add_child(row)
	var group := ButtonGroup.new()
	for i in options.size():
		var opt := str(options[i])
		var t := ThemeHelpers.make_toggle(opt, str(get(field_name)) == opt)
		t.button_group = group
		t.custom_minimum_size = Vector2(0, 56)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.toggled.connect(_on_bowl_option.bind(field_name, opt))
		row.add_child(t)
	return wrap


func _on_bowl_option(on: bool, field_name: String, opt: String) -> void:
	if on:
		set(field_name, opt)


func _build_needle() -> void:
	_needle = Control.new()
	_needle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_needle.visible = false
	_needle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(_needle)
	_needle.add_child(ThemeHelpers.dim_layer())
	var label := ThemeHelpers.title_label("TAP TO LOCK!", 30, Color.WHITE)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position = Vector2(-200, 150)
	label.custom_minimum_size = Vector2(400, 50)
	_needle.add_child(label)
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.25)
	track.position = Vector2(NEEDLE_CX - NEEDLE_HALF_PX, 330)
	track.custom_minimum_size = Vector2(NEEDLE_HALF_PX * 2.0, 26)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_needle.add_child(track)
	var zone := ColorRect.new()
	zone.color = Color("2e7d32")
	zone.position = Vector2(NEEDLE_CX - 45, 330)
	zone.custom_minimum_size = Vector2(90, 26)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_needle.add_child(zone)
	_needle_marker = ColorRect.new()
	_needle_marker.color = ThemeHelpers.RED
	_needle_marker.position = Vector2(NEEDLE_CX - 6, 318)
	_needle_marker.custom_minimum_size = Vector2(12, 50)
	_needle_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_needle.add_child(_needle_marker)


func _build_pause_panel() -> CenterContainer:
	var panel := ThemeHelpers.make_panel(Vector2(520, 0))
	var v := ThemeHelpers.vbox(12)
	panel.add_child(v)
	v.add_child(ThemeHelpers.title_label("Paused", 30))
	var resume := ThemeHelpers.make_button("Resume")
	resume.pressed.connect(func() -> void: _set_paused(false))
	v.add_child(resume)
	var restart := ThemeHelpers.make_button("Restart Match")
	restart.pressed.connect(_on_restart_pressed)
	v.add_child(restart)
	v.add_child(ThemeHelpers.body_label("Quick settings", 18, ThemeHelpers.MUTED))
	var music := ThemeHelpers.make_check("Music", bool(SaveSystem.setting("music")))
	music.toggled.connect(_on_music_toggled)
	v.add_child(music)
	var sfx := ThemeHelpers.make_check("Sound effects", bool(SaveSystem.setting("sfx")))
	sfx.toggled.connect(_on_sfx_toggled)
	v.add_child(sfx)
	var vib := ThemeHelpers.make_check("Vibration", bool(SaveSystem.setting("vibration")))
	vib.toggled.connect(_on_vib_toggled)
	v.add_child(vib)
	var quit := ThemeHelpers.make_button("Quit Match")
	quit.pressed.connect(_on_quit_pressed)
	v.add_child(quit)
	return ThemeHelpers.centered(panel)


func _build_break_panel() -> CenterContainer:
	var panel := ThemeHelpers.make_panel(Vector2(600, 0))
	var v := ThemeHelpers.vbox(14)
	panel.add_child(v)
	v.add_child(ThemeHelpers.title_label("Innings Break", 30))
	var summary := ThemeHelpers.body_label("", 20, ThemeHelpers.MUTED)
	summary.name = "Summary"
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(summary)
	var go := ThemeHelpers.make_button("Start 2nd Innings")
	go.pressed.connect(_on_start_second_innings)
	v.add_child(go)
	return ThemeHelpers.centered(panel)


func _build_error_panel() -> CenterContainer:
	var panel := ThemeHelpers.make_panel(Vector2(560, 0))
	var v := ThemeHelpers.vbox(14)
	panel.add_child(v)
	v.add_child(ThemeHelpers.title_label("Can't start match", 28, ThemeHelpers.RED))
	var msg := ThemeHelpers.body_label("", 20, ThemeHelpers.MUTED)
	msg.name = "Msg"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(msg)
	var back := ThemeHelpers.make_button("Back")
	back.pressed.connect(func() -> void: Router.back())
	v.add_child(back)
	return ThemeHelpers.centered(panel)


func _build_confirm_panel() -> CenterContainer:
	var panel := ThemeHelpers.make_panel(Vector2(520, 0))
	var v := ThemeHelpers.vbox(14)
	panel.add_child(v)
	var msg := ThemeHelpers.body_label("", 22)
	msg.name = "Msg"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(msg)
	var row := ThemeHelpers.hbox(16)
	v.add_child(row)
	var yes := ThemeHelpers.make_button("Yes")
	yes.custom_minimum_size = Vector2(180, 60)
	yes.pressed.connect(_on_confirm_yes)
	row.add_child(yes)
	var no := ThemeHelpers.make_button("No")
	no.custom_minimum_size = Vector2(180, 60)
	no.pressed.connect(_on_confirm_no)
	row.add_child(no)
	return ThemeHelpers.centered(panel)


func _show_confirm(text: String, on_yes: Callable) -> void:
	_confirm_cb = on_yes
	var msg := _find_in(_panels["confirm"], "Msg") as Label
	if msg != null:
		msg.text = text
	_show_only("confirm")


func _find_in(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for c in root.get_children():
		var f := _find_in(c, node_name)
		if f != null:
			return f
	return null


func _on_confirm_yes() -> void:
	var cb := _confirm_cb
	_confirm_cb = Callable()
	_hide_panels()
	if cb.is_valid():
		cb.call()


func _on_confirm_no() -> void:
	_confirm_cb = Callable()
	if _paused:
		_show_only("pause")
	else:
		_hide_panels()


# ------------------------------------------------------------------ flow ---

func _show_intro() -> void:
	phase = Phase.INTRO
	_show_only("intro")
	_schedule_auto("intro", 0.4)


func _show_toss() -> void:
	phase = Phase.TOSS_CALL
	_show_only("toss")
	_schedule_auto("toss", 0.4)


func _on_toss_pick(call: String) -> void:
	if phase != Phase.TOSS_CALL:
		return
	var landed := "Heads" if _rng.next() < 0.5 else "Tails"
	var user_won := landed == call
	var msg := _find_in(_panels["toss"], "Result") as Label
	if user_won:
		if msg != null:
			msg.text = landed + "! You won the toss."
		phase = Phase.TOSS_CHOICE
		_show_only("choice")
		_schedule_auto("choice_bat", 0.4)
	else:
		var ai_bats := _rng.next() < 0.6
		var chose := "bat" if ai_bats else "bowl"
		if msg != null:
			msg.text = landed + "! " + str(config.get("ai_team_name", "Opponents")) + " won the toss and chose to " + chose + "."
		config["user_bats_first"] = not ai_bats
		var tw := create_tween()
		tw.tween_interval(1.2)
		tw.tween_callback(_begin_match)


func _on_toss_choice(user_bats: bool) -> void:
	if phase != Phase.TOSS_CHOICE:
		return
	config["user_bats_first"] = user_bats
	_begin_match()


func _begin_match() -> void:
	if phase == Phase.DONE:
		return
	_hide_panels()
	_create_engine()
	if engine == null:
		_show_error("Match engine is not available yet.\nPlease update the game.")
		return
	_wire_engine()
	engine.setup(config)
	_after_setup()


func _create_engine() -> void:
	var override: Variant = GameState.screen_params.get("engine_override", null)
	if override != null:
		engine = override
		return
	if not ResourceLoader.exists(ENGINE_PATH):
		engine = null
		return
	var cls: GDScript = load(ENGINE_PATH) as GDScript
	engine = cls.new() if cls != null else null


func _wire_engine() -> void:
	if engine == null:
		return
	engine.connect("ball_completed", _on_ball_completed)
	engine.connect("innings_ended", _on_innings_ended)
	engine.connect("match_ended", _on_match_ended)


func _after_setup() -> void:
	var view: Dictionary = engine.current_view()
	_update_sides(view)
	_refresh_hud(view)
	_next_ball()


func _next_ball() -> void:
	if engine == null or phase == Phase.DONE:
		return
	_hide_panels()
	var view: Dictionary = engine.current_view()
	_update_sides(view)
	_refresh_hud(view)
	if engine.is_player_striker():
		_start_batting_ball()
	elif engine.is_player_bowling():
		_start_bowling_ball()
	else:
		_start_ai_ball()


func _update_sides(view: Dictionary) -> void:
	field.set_sides(str(view.get("batting_team_name", "")) == str(config.get("player_team_name", "")))


# --------------------------------------------------------------- batting ---

func _start_batting_ball() -> void:
	phase = Phase.RUNUP
	_ball_kind = "bat"
	field.reset_for_ball()
	_delivery = engine.ai_bowl_delivery()
	_pending_flight = clampf(float(_delivery.get("flight_ms", 700)) / 1000.0, 0.3, 2.0)
	_pending_drift = float(_delivery.get("drift", 0.0))
	field.play_runup(0.8)


func _on_runup_done() -> void:
	if phase != Phase.RUNUP:
		return
	phase = Phase.FLIGHT
	field.bowl_ball(_pending_flight, _pending_drift)


func _on_ball_bounced() -> void:
	_sfx("bounce")


func _on_ball_arrived() -> void:
	if phase != Phase.FLIGHT:
		return
	if _ball_kind == "bat":
		phase = Phase.AWAIT_INPUT
		_arrival_ms = Time.get_ticks_msec()
		_input_left = INPUT_TIMEOUT_S
		_pressing = false
		_hint_label.text = "Tap or swipe to play your shot!"
		_schedule_auto("hit", 0.15)
	elif _ball_kind == "bowl":
		phase = Phase.RESULT
		field.play_batter_swing()
		_present_outcome(engine.resolve_bowling(_delivery), "bowl")
	else:
		phase = Phase.RESULT
		field.play_batter_swing()
		_present_outcome(engine.simulate_ai_ball(), "ai")


func _resolve_batting(shot: String, offset_ms: float) -> void:
	if phase != Phase.AWAIT_INPUT:
		return
	phase = Phase.RESULT
	_pressing = false
	_hint_label.text = ""
	field.play_batter_swing()
	_present_outcome(engine.resolve_batting(shot, offset_ms), "bat")


func _present_outcome(outcome: Dictionary, kind: String) -> void:
	var runs := int(outcome.get("runs", 0))
	var wicket := bool(outcome.get("wicket", false))
	if kind == "bat":
		var timing := str(outcome.get("timing", "MISS"))
		_timing_chip(timing, TIMING_COLORS.get(timing, Color("757575")))
	elif kind == "bowl":
		var acc := float(_delivery.get("accuracy", 0.0))
		var acc_col := Color("2e7d32") if acc >= 0.7 else Color("ef6c00")
		_timing_chip("Accuracy " + str(int(round(acc * 100.0))) + "%", acc_col)
	if wicket:
		_banner("WICKET!", ThemeHelpers.RED)
		_sfx("wicket")
		_sfx("crowd")
		GameState.vibrate(80)
	else:
		if kind == "bat" and str(outcome.get("timing", "MISS")) != "MISS":
			_sfx("hit")
			GameState.vibrate(30)
		if runs >= 6:
			_banner("SIX!", ThemeHelpers.GOLD)
			_sfx("six")
			_sfx("crowd")
		elif runs >= 4:
			_banner("FOUR!", ThemeHelpers.BLUE)
			_sfx("four")
			_sfx("crowd")
		elif runs > 0:
			var plural := "" if runs == 1 else "S"
			_banner(str(runs) + " RUN" + plural, Color.WHITE)
		else:
			_banner("DOT BALL", Color("b9c4d0"))
	field.play_batting_result(outcome)


func _on_result_anim_done() -> void:
	if phase != Phase.RESULT:
		return
	phase = Phase.IDLE
	var wait := 0.9 if _ball_kind == "bat" else 0.6
	get_tree().create_timer(wait).timeout.connect(_after_ball)


func _after_ball() -> void:
	if not is_inside_tree() or engine == null or phase == Phase.DONE:
		return
	if engine.is_match_over():
		_finish_match()
	elif engine.is_innings_over():
		_show_innings_break()
	else:
		_next_ball()


# --------------------------------------------------------------- bowling ---

func _start_bowling_ball() -> void:
	phase = Phase.BOWL_PICK
	_ball_kind = "bowl"
	field.reset_for_ball()
	_show_only("bowl")
	_schedule_auto("bowl", 0.4)


func _on_bowl_pressed() -> void:
	if phase != Phase.BOWL_PICK:
		return
	phase = Phase.NEEDLE
	_hide_panels()
	_needle.visible = true
	_needle_t = 0.0
	_needle_active = true
	_needle_marker.position.x = NEEDLE_CX - NEEDLE_HALF_PX - 6.0
	_auto_lock_in = 0.4 if _debug_autoplay else -1.0
	_hint_label.text = "Tap to lock your line!"


func _lock_needle() -> void:
	if not _needle_active:
		return
	_needle_active = false
	_needle.visible = false
	_hint_label.text = ""
	var marker_cx: float = _needle_marker.position.x + 6.0
	var acc: float = clampf(1.0 - absf(marker_cx - NEEDLE_CX) / NEEDLE_HALF_PX, 0.0, 1.0)
	_delivery = {"line": _bowl_line, "length": _bowl_length, "type": _bowl_type, "accuracy": acc}
	var flights := {"Fast": 0.55, "Normal": 0.7, "Slower": 0.95, "Bouncer": 0.75, "Yorker": 0.6}
	_pending_flight = float(flights.get(_bowl_type, 0.7))
	_pending_drift = 0.0
	phase = Phase.RUNUP
	field.play_runup(0.35)


# ---------------------------------------------------------------- AI ball ---

func _start_ai_ball() -> void:
	phase = Phase.RUNUP
	_ball_kind = "ai"
	field.reset_for_ball()
	_pending_flight = 0.55
	_pending_drift = 0.0
	field.play_runup(0.4)


# ------------------------------------------------------------ innings end ---

func _on_innings_ended(_view: Dictionary) -> void:
	pass # Flow is driven manually via _after_ball().


func _show_innings_break() -> void:
	phase = Phase.INNINGS_BREAK
	var card: Dictionary = engine.scorecard()
	var lines: Array[String] = []
	for inn in card.get("innings", []):
		var idict: Dictionary = inn
		var line := str(idict.get("team_name", "")) + ": " + str(idict.get("total", 0)) \
			+ "/" + str(idict.get("wickets", 0)) + " (" + str(idict.get("overs_text", "")) + " ov)"
		lines.append(line)
	var msg := _find_in(_panels["break"], "Summary") as Label
	if msg != null:
		msg.text = "\n".join(lines)
	_show_only("break")
	_schedule_auto("break", 0.6)


func _on_start_second_innings() -> void:
	if phase != Phase.INNINGS_BREAK:
		return
	engine.start_next_innings()
	_hide_panels()
	_next_ball()


# ------------------------------------------------------------------ end ---

func _on_match_ended(_result: Dictionary) -> void:
	pass # Flow is driven manually via _after_ball().


func _finish_match() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	resume_engine = null
	var result: Dictionary = engine.get_result()
	var econ: Node = get_node_or_null("/root/Economy")
	if econ != null:
		var finalized: Variant = econ.call("finalize_match", result,
			str(config.get("mode", "gully6")), str(config.get("difficulty", "NORMAL")))
		if finalized is Dictionary:
			result = finalized
	# v2.0 selection loop: reserve/debut/main-XI matches feed the career
	# selection system with the user's REAL per-player performance.
	var career: Node = get_node_or_null("/root/Career")
	if career != null:
		var sel_ctx: String = str(config.get("selection_context", ""))
		if sel_ctx == "reserve" or sel_ctx == "debut":
			var uperf: Dictionary = engine.user_performance()
			var won: bool = bool(result.get("player_won", false))
			var sel_out: Dictionary = {}
			if sel_ctx == "reserve":
				sel_out = career.call("record_reserve_match", uperf, won)
			else:
				sel_out = career.call("record_debut_match", uperf, won)
			result["selection"] = sel_out
			result["selection_context"] = sel_ctx
		elif str(career.call("selection_status")) == "MAIN_XI":
			var mout: Dictionary = career.call("record_mainxi_match", engine.user_performance())
			if bool(mout.get("dropped", false)):
				result["selection"] = mout
				result["selection_context"] = "mainxi"
	GameState.last_result = result
	Router.show("result", {"result": result})


# ------------------------------------------------------------------ HUD ---

func _on_ball_completed(_outcome: Dictionary, view: Dictionary) -> void:
	_refresh_hud(view)


func _refresh_hud(view: Dictionary) -> void:
	_hud_score.text = str(int(view.get("runs", 0))) + "/" + str(int(view.get("wickets", 0)))
	_hud_overs.text = str(view.get("overs_text", "0.0")) + "/" + str(int(view.get("overs_total", 6))) + " ov"
	# view["target"] is null when no chase is on; int(null) throws.
	var target := int(view.get("target", 0) or 0)
	if target > 0:
		var need: int = maxi(0, target - int(view.get("runs", 0)))
		var balls_left: int = maxi(0, int(view.get("overs_total", 6)) * 6 - int(view.get("balls", 0)))
		_hud_target.text = "Need " + str(need) + " off " + str(balls_left)
	else:
		_hud_target.text = ""
	_hud_striker.text = str(view.get("striker_name", "")) + " " + str(int(view.get("striker_runs", 0))) \
		+ "(" + str(int(view.get("striker_balls", 0))) + ")"
	_hud_bowler.text = "Bowl: " + str(view.get("bowler_name", ""))
	for c in _balls_box.get_children():
		c.queue_free()
	var recent: Array = Array(view.get("recent_balls", []))
	var start: int = maxi(0, recent.size() - 10)
	for i in range(start, recent.size()):
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", ThemeHelpers.chip_style())
		chip.add_child(ThemeHelpers.hud_label(str(recent[i]), 16))
		_balls_box.add_child(chip)


func _on_score_pressed() -> void:
	if engine == null:
		return
	resume_engine = engine
	Router.show("scoreboard", {"engine": engine})


# ----------------------------------------------------------------- pause ---

func _set_paused(p: bool) -> void:
	if phase == Phase.DONE:
		return
	_paused = p
	field.set_paused(p)
	if p:
		_show_only("pause")
	elif not _any_panel_visible():
		_hide_panels()


func _on_restart_pressed() -> void:
	_show_confirm("Restart the match from the first ball?", _do_restart)


func _do_restart() -> void:
	_paused = false
	field.set_paused(false)
	phase = Phase.IDLE
	engine.setup(config)
	_after_setup()


func _on_quit_pressed() -> void:
	_show_confirm("Quit this match? Progress will be lost.", _do_quit)


func _do_quit() -> void:
	_paused = false
	resume_engine = null
	Router.back()


func _on_music_toggled(on: bool) -> void:
	_audio_setting("set_music_enabled", "music", on)


func _on_sfx_toggled(on: bool) -> void:
	_audio_setting("set_sfx_enabled", "sfx", on)


func _on_vib_toggled(on: bool) -> void:
	SaveSystem.data["settings"]["vibration"] = on
	SaveSystem.save_game()


func _audio_setting(method: String, key: String, on: bool) -> void:
	var am: Node = get_node_or_null("/root/AudioMan")
	if am != null:
		am.call(method, on)
	SaveSystem.data["settings"][key] = on
	SaveSystem.save_game()


# --------------------------------------------------------------- helpers ---

func _sfx(sound_name: String) -> void:
	var am: Node = get_node_or_null("/root/AudioMan")
	if am != null:
		am.call("play", sound_name)


func _stage_dict() -> Dictionary:
	var stage_id := str(config.get("stage_id", ""))
	if stage_id != "":
		var career: Node = get_node_or_null("/root/Career")
		if career != null:
			var s: Variant = career.call("stage_by_id", stage_id)
			if s is Dictionary and not (s as Dictionary).is_empty():
				return s
	return {
		"id": "gully", "name": "Gully Ground",
		"ground": {"sky": ["#79c7e8", "#d9f1fb"], "ground": "#4d8a3f",
			"label": "Gully ground", "features": []},
	}


func _show_error(text: String) -> void:
	phase = Phase.IDLE
	var msg := _find_in(_panels["error"], "Msg") as Label
	if msg != null:
		msg.text = text
	_show_only("error")
