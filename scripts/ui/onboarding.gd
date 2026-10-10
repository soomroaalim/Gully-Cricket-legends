class_name GCLOnboarding
extends Control
## First-run flow: splash, intro, name, avatar, starter-team reveal,
## batting tutorial, bowling tutorial, practice match, finale.
## The step survives the practice-match detour via the static resume_step.

const TOTAL_STEPS: int = 9

static var resume_step: int = 0


static func reset_flow() -> void:
	resume_step = 0


var _step: int = 0
var _body: VBoxContainer
var _step_label: Label
var _player_name: String = "Haroon"
var _avatar: int = 0
var _avatar_btns: Array[Button] = []


func _ready() -> void:
	_step = clampi(resume_step, 0, TOTAL_STEPS - 1)
	_player_name = str(SaveSystem.data.get("player_name", "Haroon")).strip_edges()
	if _player_name == "":
		_player_name = "Haroon"
	_avatar = int(SaveSystem.data.get("avatar", 0))
	_build_chrome()
	_show_step()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		pass  # Back is disabled during onboarding.


func _build_chrome() -> void:
	add_child(GCLUI.paper_bg())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := ThemeHelpers.make_panel(Vector2(700, 0))
	center.add_child(panel)
	var col := ThemeHelpers.vbox(12)
	panel.add_child(col)
	_step_label = ThemeHelpers.body_label("", 16, ThemeHelpers.MUTED)
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_step_label)
	_body = ThemeHelpers.vbox(12)
	_body.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_child(_body)


func _next() -> void:
	_step += 1
	resume_step = _step
	_show_step()


func _continue_button(text: String = "Continue ➜") -> Button:
	var b := GCLUI.fx(ThemeHelpers.make_button(text))
	b.pressed.connect(_next)
	_body.add_child(b)
	return b


func _show_step() -> void:
	GCLUI.clear(_body)
	_avatar_btns.clear()
	_step_label.text = "Step %d of %d" % [_step + 1, TOTAL_STEPS]
	match _step:
		0:
			_step_splash()
		1:
			_step_intro()
		2:
			_step_name()
		3:
			_step_avatar()
		4:
			_step_reveal()
		5:
			_step_batting()
		6:
			_step_bowling()
		7:
			_step_practice()
		8:
			_step_finale()


# --- Steps ---------------------------------------------------------------

func _step_splash() -> void:
	var icon := ThemeHelpers.title_label("🏏", 96, ThemeHelpers.INK)
	_body.add_child(icon)
	_body.add_child(ThemeHelpers.title_label("GULLY CRICKET\nLEGENDS", 44, ThemeHelpers.RED))
	var tag := ThemeHelpers.body_label("Street cricket. Real glory.", 20, ThemeHelpers.MUTED)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(tag)
	var b := GCLUI.fx(ThemeHelpers.make_button("👆 Tap to continue"))
	b.pressed.connect(_next)
	_body.add_child(b)


func _step_intro() -> void:
	_body.add_child(ThemeHelpers.title_label("Welcome to the Gullies", 30, ThemeHelpers.RED))
	for line in [
		"🏏 No stadiums. No coaches. Just a bat, a tennis ball, and the street.",
		"💪 Build your squad, smash sixes over rooftops, and become a mohalla legend.",
		"🏆 Conquer 6 stages — from Soomra Colony to the Sindh Championship!",
	]:
		_body.add_child(ThemeHelpers.body_label(line, 20, ThemeHelpers.INK))
	_continue_button()


func _step_name() -> void:
	_body.add_child(ThemeHelpers.title_label("What should the gullies call you?", 28, ThemeHelpers.RED))
	var le := LineEdit.new()
	le.text = _player_name
	le.max_length = 16
	le.custom_minimum_size = Vector2(0, 60)
	le.add_theme_font_size_override("font_size", 24)
	_body.add_child(le)
	var b := GCLUI.fx(ThemeHelpers.make_button("Continue ➜"))
	b.pressed.connect(_on_name_done.bind(le))
	_body.add_child(b)


func _on_name_done(le: LineEdit) -> void:
	_player_name = le.text.strip_edges()
	if _player_name == "":
		_player_name = "Haroon"
	SaveSystem.data["player_name"] = _player_name
	SaveSystem.save_game()
	_next()


func _step_avatar() -> void:
	_body.add_child(ThemeHelpers.title_label("Pick your look", 30, ThemeHelpers.RED))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_body.add_child(grid)
	for i in GCLUI.AVATARS.size():
		var b := GCLUI.fx(Button.new())
		b.text = GCLUI.AVATARS[i]
		b.custom_minimum_size = Vector2(110, 96)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 48)
		b.pressed.connect(_on_avatar_pick.bind(i))
		_avatar_btns.append(b)
		grid.add_child(b)
	_refresh_avatar_buttons()
	_continue_button()


func _on_avatar_pick(i: int) -> void:
	_avatar = i
	_refresh_avatar_buttons()


func _refresh_avatar_buttons() -> void:
	for i in _avatar_btns.size():
		var b: Button = _avatar_btns[i]
		var sb := StyleBoxFlat.new()
		sb.bg_color = ThemeHelpers.PAPER
		sb.set_corner_radius_all(14)
		if i == _avatar:
			sb.border_color = ThemeHelpers.RED
			sb.set_border_width_all(5)
		else:
			sb.border_color = Color(0, 0, 0, 0.2)
			sb.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)


func _step_reveal() -> void:
	SaveSystem.data["avatar"] = _avatar
	var team: Array = GCLPlayers.make_starter_team(_player_name, _avatar)
	SaveSystem.data["team"] = team
	var ids: Array = []
	var cap: String = ""
	for p in team:
		if p is Dictionary:
			ids.append(str(p.get("id", "")))
			if bool(p.get("is_user", false)):
				cap = str(p.get("id", ""))
	SaveSystem.data["lineup"] = ids
	SaveSystem.data["captain_id"] = cap
	SaveSystem.save_game()
	_body.add_child(ThemeHelpers.title_label("🤝 Meet your starter squad", 30, ThemeHelpers.RED))
	for p in team:
		if p is Dictionary:
			var line := "%s  %s · %s · OVR %d" % [
				GCLUI.avatar_emoji(int(p.get("avatar", 0))),
				str(p.get("name", "?")),
				str(p.get("role", "?")),
				int(p.get("overall", 0)),
			]
			if bool(p.get("is_user", false)):
				line += "  ⭐ (you)"
			_body.add_child(ThemeHelpers.body_label(line, 20, ThemeHelpers.INK))
	_continue_button("Let's play! ➜")


func _step_batting() -> void:
	_body.add_child(ThemeHelpers.title_label("🏏 Batting: tap at the right moment!", 26, ThemeHelpers.RED))
	_body.add_child(ThemeHelpers.body_label("The ball flies in from the right. Tap HIT just as it reaches the yellow circle.", 18, ThemeHelpers.MUTED))
	var tutor := BattingTutor.new()
	_body.add_child(tutor)
	var hit := GCLUI.fx(ThemeHelpers.make_button("👆 TAP TO HIT!"))
	hit.pressed.connect(tutor.tap_hit)
	_body.add_child(hit)
	var cont := GCLUI.fx(ThemeHelpers.make_button("Continue ➜"))
	cont.disabled = true
	cont.pressed.connect(_next)
	_body.add_child(cont)
	tutor.completed.connect(func() -> void: cont.disabled = false)


func _step_bowling() -> void:
	_body.add_child(ThemeHelpers.title_label("🎯 Bowling: stop the needle in the green!", 26, ThemeHelpers.RED))
	_body.add_child(ThemeHelpers.body_label("Time your tap to stop the needle inside the green zone for a perfect ball.", 18, ThemeHelpers.MUTED))
	var tutor := BowlingTutor.new()
	_body.add_child(tutor)
	var stop := GCLUI.fx(ThemeHelpers.make_button("🛑 STOP!"))
	stop.pressed.connect(tutor.stop)
	_body.add_child(stop)
	var cont := GCLUI.fx(ThemeHelpers.make_button("Continue ➜"))
	cont.disabled = true
	cont.pressed.connect(_next)
	_body.add_child(cont)
	tutor.completed.connect(func() -> void:
		cont.disabled = false
		stop.disabled = true
	)


func _step_practice() -> void:
	_body.add_child(ThemeHelpers.title_label("Ready for a practice match?", 30, ThemeHelpers.RED))
	_body.add_child(ThemeHelpers.body_label("1 over · Easy difficulty · your squad vs a street XI. Learn the ropes — no pressure!", 20, ThemeHelpers.INK))
	var play := GCLUI.fx(ThemeHelpers.make_button("▶  Play Practice Match"))
	play.pressed.connect(_start_practice)
	_body.add_child(play)
	var skip := GCLUI.fx(ThemeHelpers.make_button("⏭  Skip"))
	skip.pressed.connect(_next)
	_body.add_child(skip)


func _start_practice() -> void:
	resume_step = 8
	var rng := GCLRng.new(GCLRng.random_seed())
	var stage: Dictionary = Career.current_stage()
	var cfg: Dictionary = GCLUI.build_match_config("1v1", "EASY", stage, rng, {"from": "main_menu", "practice": true})
	cfg["overs"] = 1
	GameState.match_config = cfg
	Router.show("match", {"from": "main_menu"})


func _step_finale() -> void:
	_body.add_child(ThemeHelpers.title_label("🎉", 72, ThemeHelpers.INK))
	_body.add_child(ThemeHelpers.title_label("Your career begins!", 34, ThemeHelpers.RED))
	_body.add_child(ThemeHelpers.body_label("Win quick matches, lift tournament trophies, recruit stars, and take your gully team from Soomra Colony to the Sindh Championship.", 20, ThemeHelpers.INK))
	var b := GCLUI.fx(ThemeHelpers.make_button("▶  Start Career"))
	b.pressed.connect(_finish)
	_body.add_child(b)


func _finish() -> void:
	SaveSystem.data["onboarding_done"] = true
	SaveSystem.save_game()
	resume_step = 0
	Router.reset_to("main_menu")


# --- Tutorial widgets ----------------------------------------------------

## Simplified batting timing tutor: a ball flies in, the player taps HIT.
class BattingTutor:
	extends Control

	signal completed

	const ZONE_X: float = 220.0
	const ARRIVAL: float = 1.4

	var _t: float = 0.0
	var _state: int = 0  # 0 = flying, 1 = showing result
	var _result_t: float = 0.0
	var _tries: int = 0
	var _max_tries: int = 3
	var _tapped: bool = false
	var _offset_ms: float = 0.0
	var _grade: String = ""


	func _ready() -> void:
		custom_minimum_size = Vector2(640, 230)
		start_try()


	func start_try() -> void:
		_t = 0.0
		_state = 0
		_tapped = false
		_grade = ""
		queue_redraw()


	func tap_hit() -> void:
		if _state != 0 or _tapped:
			return
		_tapped = true
		_offset_ms = (_t - ARRIVAL) * 1000.0
		_finish_try()


	func _process(delta: float) -> void:
		if _state == 0:
			_t += delta
			if _t >= ARRIVAL + 0.45 and not _tapped:
				_tapped = true
				_offset_ms = 99999.0
				_finish_try()
			queue_redraw()
		elif _state == 1:
			_result_t += delta
			if _result_t > 1.2:
				_tries += 1
				if _tries >= _max_tries:
					_state = 2
					completed.emit()
				else:
					start_try()


	func _finish_try() -> void:
		_state = 1
		_result_t = 0.0
		var a: float = absf(_offset_ms)
		if _offset_ms >= 99999.0:
			_grade = "MISS — no tap!"
		elif a <= 60.0:
			_grade = "PERFECT timing! 🏏💥"
		elif a <= 120.0:
			_grade = "GOOD timing! 👍"
		elif a <= 250.0:
			_grade = "EARLY — wait for it…" if _offset_ms < 0.0 else "LATE — swing earlier…"
		else:
			_grade = "MISS — way off!"
		queue_redraw()


	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var font: Font = ThemeDB.fallback_font
		# Ground.
		draw_line(Vector2(0, h - 40), Vector2(w, h - 40), Color("8a6d3b"), 6.0)
		# Hitting zone.
		draw_circle(Vector2(ZONE_X, h - 60), 34.0, Color(0.95, 0.70, 0.20, 0.30))
		draw_arc(Vector2(ZONE_X, h - 60), 34.0, 0.0, TAU, 32, Color("c98a1b"), 3.0)
		draw_string(font, Vector2(ZONE_X - 26, h - 44), "🏏", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)
		# Ball.
		var prog: float = clampf(_t / ARRIVAL, 0.0, 1.0)
		var bx: float = lerpf(w - 40.0, ZONE_X, prog)
		var by: float = (h - 60.0) - sin(prog * PI) * 70.0
		draw_circle(Vector2(bx, by), 14.0, Color("c62828"))
		draw_arc(Vector2(bx, by), 14.0, 0.0, TAU, 24, Color.WHITE, 2.0)
		# HUD text.
		draw_string(font, Vector2(16, 32), "Try %d/%d — tap HIT in the yellow circle!" % [_tries + 1, _max_tries], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ThemeHelpers.INK)
		if _grade != "":
			draw_string(font, Vector2(16, 66), _grade, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ThemeHelpers.RED)


## Simplified bowling tutor: stop the oscillating needle in the green zone.
class BowlingTutor:
	extends Control

	signal completed

	const ZONE := Vector2(0.42, 0.58)

	var _t: float = 0.0
	var _stopped: bool = false
	var _marker: float = 0.5
	var _result: String = ""


	func _ready() -> void:
		custom_minimum_size = Vector2(640, 130)


	func stop() -> void:
		if _stopped:
			return
		_stopped = true
		var d: float = absf(_marker - 0.5)
		if d <= 0.08:
			_result = "🎯 PERFECT release! Unplayable!"
		elif d <= 0.16:
			_result = "👍 Good ball — right on the spot."
		else:
			_result = "😅 Wayward — the batter says thanks."
		queue_redraw()
		completed.emit()


	func _process(delta: float) -> void:
		if not _stopped:
			_t += delta
			_marker = 0.5 + 0.48 * sin(_t * 3.4)
			queue_redraw()


	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var font: Font = ThemeDB.fallback_font
		draw_rect(Rect2(20, h * 0.5 - 14, w - 40, 28), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(20 + (w - 40) * ZONE.x, h * 0.5 - 14, (w - 40) * (ZONE.y - ZONE.x), 28), Color("2e7d32"))
		var mx: float = 20 + (w - 40) * _marker
		draw_line(Vector2(mx, h * 0.5 - 32), Vector2(mx, h * 0.5 + 32), Color("c62828"), 6.0)
		draw_string(font, Vector2(20, 28), "Stop the needle in the GREEN zone!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ThemeHelpers.INK)
		if _result != "":
			draw_string(font, Vector2(20, h - 14), _result, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ThemeHelpers.RED)
