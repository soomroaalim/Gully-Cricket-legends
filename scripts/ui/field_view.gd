class_name FieldView
extends Node2D
## Flat-color street-cricket ground for the match scene: sky gradient, sun,
## drifting clouds, house/stand silhouettes, pitch, creases, stumps, players
## and the ball. No external textures. Animation runs as a small state machine
## in _process so it freezes cleanly when paused.

signal runup_finished
signal ball_arrived
signal ball_bounced
signal result_anim_finished

const VIEW_W: float = 960.0
const VIEW_H: float = 540.0
const HORIZON_Y: float = 300.0

const PITCH_L: float = 438.0
const PITCH_R: float = 522.0
const PITCH_TOP: float = 246.0
const PITCH_BOT: float = 506.0
const BOWL_STUMP_Y: float = 264.0
const BAT_STUMP_Y: float = 494.0
const BAT_POS := Vector2(480.0, 448.0)
const BOWL_START := Vector2(480.0, 132.0)
const BOWL_END := Vector2(480.0, 224.0)
const RELEASE_POS := Vector2(480.0, 246.0)
const HIT_POS := Vector2(480.0, 402.0)
const KEEPER_POS := Vector2(480.0, 518.0)
const FIELDER_SPOTS: Array[Vector2] = [
	Vector2(186.0, 398.0), Vector2(774.0, 398.0),
	Vector2(298.0, 326.0), Vector2(662.0, 326.0),
	Vector2(480.0, 196.0),
]

const PLAYER_JERSEY := Color("c62828")
const AI_JERSEY := Color("1565c0")
const SKIN := Color("c68642")
const PANTS := Color("2b3440")
const BALL_COL := Color("f5f0e6")
const STUMP_COL := Color("f2e3b3")
const BAT_COL := Color("8a5a2b")

var _sky_top := Color("79c7e8")
var _sky_bot := Color("d9f1fb")
var _ground_col := Color("4d8a3f")
var _label := "Gully ground"
var _big_ground := false

var _paused := false
var _player_batting := true

var _clouds: Array[Dictionary] = []
var _bowler_pos := BOWL_START
var _swing_t := -1.0
var _stumps_broken := false
var _ball_visible := false
var _ball_pos := Vector2.ZERO
var _ball_scale := 1.0

var _anim := "none" # none | runup | flight | result
var _anim_t := 0.0
var _anim_dur := 1.0
var _anim_from := Vector2.ZERO
var _anim_to := Vector2.ZERO
var _anim_drift := 0.0
var _did_bounce := false
var _result_kind := ""
var _chase_fielder := -1
var _fielder_pos: Array[Vector2] = []
var _fielder_from: Array[Vector2] = []

# Paint extents for the current frame: on wide/tall screens stretch-expand
# shows more canvas than the 960x540 design. The 960x540 play area stays
# centered; backgrounds fill the whole visible rect.
var _ox := 0.0
var _oy := 0.0
var _vw := VIEW_W
var _vh := VIEW_H


func _ready() -> void:
	_fielder_pos = FIELDER_SPOTS.duplicate()
	_clouds = [
		{"x": 140.0, "y": 70.0, "s": 1.0, "speed": 9.0},
		{"x": 480.0, "y": 120.0, "s": 0.7, "speed": 13.0},
		{"x": 800.0, "y": 55.0, "s": 1.25, "speed": 7.0},
	]
	queue_redraw()


static func _parse_color(s: String, fallback: Color) -> Color:
	var t: String = s.strip_edges()
	if t.is_valid_html_color():
		return Color(t)
	return fallback


## Stage Dictionary from Career.stage_by_id (ground: {sky:[c1,c2], ground, label, features}).
func set_stage(stage: Dictionary) -> void:
	var g: Dictionary = stage.get("ground", {})
	var sky: Array = g.get("sky", ["#79c7e8", "#d9f1fb"])
	_sky_top = _parse_color(str(sky[0]) if sky.size() > 0 else "#79c7e8", Color("79c7e8"))
	_sky_bot = _parse_color(str(sky[1]) if sky.size() > 1 else "#d9f1fb", Color("d9f1fb"))
	_ground_col = _parse_color(str(g.get("ground", "#4d8a3f")), Color("4d8a3f"))
	_label = str(g.get("label", "Gully ground"))
	# NOTE: stage data stores features as a comma-separated String.
	var feats: String = str(g.get("features", ""))
	_big_ground = feats.contains("stands") or feats.contains("stadium") \
		or _label.to_lower().contains("stadium") or _label.to_lower().contains("championship")
	queue_redraw()


func set_sides(player_batting: bool) -> void:
	_player_batting = player_batting
	queue_redraw()


func set_paused(p: bool) -> void:
	_paused = p


func reset_for_ball() -> void:
	_stumps_broken = false
	_ball_visible = false
	_anim = "none"
	_swing_t = -1.0
	_chase_fielder = -1
	_bowler_pos = BOWL_START
	_fielder_pos = FIELDER_SPOTS.duplicate()
	queue_redraw()


func play_runup(dur: float) -> void:
	_anim = "runup"
	_anim_t = 0.0
	_anim_dur = maxf(0.15, dur)
	_anim_from = BOWL_START
	_anim_to = BOWL_END


func bowl_ball(flight_s: float, drift: float) -> void:
	_ball_visible = true
	_ball_scale = 0.75
	_anim = "flight"
	_anim_t = 0.0
	_anim_dur = clampf(flight_s, 0.25, 2.0)
	_anim_from = RELEASE_POS
	_anim_to = HIT_POS
	_anim_drift = drift
	_did_bounce = false


func play_batter_swing() -> void:
	_swing_t = 0.0


## outcome: {runs, wicket, ...} per CONTRACTS.
func play_batting_result(outcome: Dictionary) -> void:
	var runs := int(outcome.get("runs", 0))
	var wicket := bool(outcome.get("wicket", false))
	_ball_visible = true
	_anim_t = 0.0
	_anim_drift = 0.0
	if wicket:
		_stumps_broken = true
		_result_kind = "wicket"
		_anim_from = HIT_POS
		_anim_to = KEEPER_POS
		_anim_dur = 0.55
	elif runs >= 6:
		_result_kind = "six"
		_anim_from = HIT_POS
		_anim_to = Vector2(872.0, 96.0)
		_anim_dur = 1.0
	elif runs >= 4:
		_result_kind = "four"
		_anim_from = HIT_POS
		_anim_to = Vector2(848.0, 452.0)
		_anim_dur = 0.8
	else:
		_result_kind = "field"
		_anim_from = HIT_POS
		_chase_fielder = _nearest_fielder(HIT_POS)
		_fielder_from = _fielder_pos.duplicate()
		_anim_to = _fielder_pos[_chase_fielder]
		_anim_dur = 0.8
	_anim = "result"


func _nearest_fielder(p: Vector2) -> int:
	var best := 0
	var best_d := 1e20
	for i in _fielder_pos.size():
		var d: float = _fielder_pos[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


func _process(delta: float) -> void:
	if _paused:
		return
	_update_extents()
	for c in _clouds:
		var nx: float = float(c["x"]) + float(c["speed"]) * delta
		# Wrap across the full visible width (local coords start at -_ox).
		c["x"] = -_ox - 140.0 if nx > _vw - _ox + 140.0 else nx
	if _swing_t >= 0.0:
		_swing_t += delta / 0.35
		if _swing_t >= 1.0:
			_swing_t = -1.0
	if _anim != "none":
		_anim_t += delta
		var p: float = clampf(_anim_t / _anim_dur, 0.0, 1.0)
		match _anim:
			"runup":
				_bowler_pos = _anim_from.lerp(_anim_to, p * p * (3.0 - 2.0 * p))
			"flight":
				_ball_pos = _anim_from.lerp(_anim_to, p)
				_ball_pos.x += _anim_drift * p * 40.0
				_ball_pos.y -= sin(p * PI) * 34.0
				_ball_scale = lerpf(0.75, 1.25, p)
				if p >= 0.55 and not _did_bounce:
					_did_bounce = true
					ball_bounced.emit()
			"result":
				_apply_result_anim(p)
		if _anim_t >= _anim_dur:
			var done_kind := _anim
			_anim = "none"
			_finish_anim(done_kind)
	queue_redraw()


func _apply_result_anim(p: float) -> void:
	match _result_kind:
		"six":
			var e: float = 1.0 - (1.0 - p) * (1.0 - p)
			_ball_pos = _anim_from.lerp(_anim_to, e)
			_ball_pos.y -= sin(e * PI) * 170.0
			_ball_scale = lerpf(1.2, 1.7, e)
		"four", "field":
			_ball_pos = _anim_from.lerp(_anim_to, p)
			_ball_pos.y -= absf(sin(p * PI * 4.0)) * 6.0
			_ball_scale = 1.1
			if _result_kind == "field" and _chase_fielder >= 0:
				_fielder_pos[_chase_fielder] = _fielder_from[_chase_fielder].lerp(
					_anim_to + Vector2(-24.0, 0.0), p)
		"wicket":
			_ball_pos = _anim_from.lerp(_anim_to, p)
			_ball_scale = 1.0


func _finish_anim(done_kind: String) -> void:
	if done_kind == "runup":
		runup_finished.emit()
	elif done_kind == "flight":
		ball_arrived.emit()
	elif done_kind == "result":
		if _result_kind == "six" or _result_kind == "four":
			_ball_visible = false
		result_anim_finished.emit()


# ---------------------------------------------------------------- drawing ---

## Visible canvas size in local coordinates. With stretch mode canvas_items /
## expand, wide phones show more than the 960x540 design area.
func _update_extents() -> void:
	var t: Transform2D = get_canvas_transform()
	var sx: float = t.x.x
	var sy: float = t.y.y
	var vp: Vector2 = get_viewport_rect().size
	_vw = VIEW_W
	_vh = VIEW_H
	if sx > 0.0:
		_vw = maxf(VIEW_W, vp.x / sx)
	if sy > 0.0:
		_vh = maxf(VIEW_H, vp.y / sy)
	_ox = (_vw - VIEW_W) * 0.5
	_oy = (_vh - VIEW_H) * 0.5


func _draw() -> void:
	_update_extents()
	# Center the 960x540 play area; backgrounds paint the full visible rect.
	draw_set_transform(Vector2(_ox, _oy))
	_draw_sky()
	_draw_backdrop()
	_draw_ground()
	_draw_pitch()
	_draw_stumps(480.0, BOWL_STUMP_Y, false, 0.7)
	_draw_stumps(480.0, BAT_STUMP_Y, _stumps_broken, 1.0)
	# Fielders + keeper (bowling side).
	var bowl_jersey := AI_JERSEY if _player_batting else PLAYER_JERSEY
	for fp in _fielder_pos:
		_draw_person(fp, 34.0, bowl_jersey, SKIN, 0.0, false)
	_draw_person(KEEPER_POS, 30.0, bowl_jersey.darkened(0.15), SKIN, 0.0, false)
	# Bowler.
	_draw_person(_bowler_pos, 44.0, bowl_jersey, SKIN, 0.0, false)
	# Batsman.
	var bat_jersey := PLAYER_JERSEY if _player_batting else AI_JERSEY
	var ang := -0.6
	if _swing_t >= 0.0:
		ang = lerpf(-1.35, 1.15, _swing_t)
	_draw_person(BAT_POS, 52.0, bat_jersey, SKIN, ang, true)
	# Ball.
	if _ball_visible:
		var r := 7.0 * _ball_scale
		draw_ellipse_shadow(_ball_pos, r)
		draw_circle(_ball_pos, r, BALL_COL)
		draw_arc(_ball_pos, r, 0.0, TAU, 16, Color(0, 0, 0, 0.25), 1.5)


func draw_ellipse_shadow(pos: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a: float = TAU * float(i) / 16.0
		pts.append(pos + Vector2(cos(a) * r * 1.1, 10.0 + sin(a) * r * 0.35))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.22))


func _draw_sky() -> void:
	var top: float = -_oy
	var sky_h: float = HORIZON_Y - top
	var bands := 24
	for i in bands:
		var t: float = float(i) / float(bands - 1)
		var c: Color = _sky_top.lerp(_sky_bot, t)
		draw_rect(Rect2(-_ox, top + t * sky_h, _vw, sky_h / bands + 1.0), c)
	# Sun.
	draw_circle(Vector2(858.0, 66.0), 44.0, Color(1.0, 0.95, 0.75, 0.35))
	draw_circle(Vector2(858.0, 66.0), 30.0, Color("ffe9a8"))
	# Clouds.
	for c in _clouds:
		_draw_cloud(Vector2(float(c["x"]), float(c["y"])), float(c["s"]))


func _draw_cloud(pos: Vector2, s: float) -> void:
	var col := Color(1, 1, 1, 0.92)
	draw_circle(pos + Vector2(-34, 6) * s, 20.0 * s, col)
	draw_circle(pos + Vector2(0, -6) * s, 26.0 * s, col)
	draw_circle(pos + Vector2(34, 6) * s, 20.0 * s, col)
	draw_rect(Rect2(pos + Vector2(-52, -2) * s, Vector2(104, 18) * s), col)


func _draw_backdrop() -> void:
	if _big_ground:
		_draw_stands()
	else:
		_draw_houses()


func _draw_houses() -> void:
	var cols: Array[Color] = [Color("b08968"), Color("a3a380"), Color("c1a477"), Color("98a2a8")]
	var w := 150.0
	for i in 5:
		var x: float = -_ox + 20.0 + float(i) * (_vw - 40.0 - w) / 4.0
		var h := 64.0 + float((i * 37) % 42)
		var base := cols[i % cols.size()].darkened(0.08)
		draw_rect(Rect2(x, HORIZON_Y - h, w, h), base)
		var roof := PackedVector2Array([
			Vector2(x - 8, HORIZON_Y - h), Vector2(x + w + 8, HORIZON_Y - h),
			Vector2(x + w * 0.5, HORIZON_Y - h - 34.0)])
		draw_colored_polygon(roof, base.darkened(0.25))
		# Windows.
		for wx in 3:
			draw_rect(Rect2(x + 18.0 + float(wx) * 44.0, HORIZON_Y - h + 20.0, 24.0, 20.0),
				Color("fdf6d8").darkened(0.05))


func _draw_stands() -> void:
	for side in 2:
		var x0: float = -_ox + 30.0 if side == 0 else -_ox + _vw - 300.0
		for tier in 3:
			var y: float = HORIZON_Y - 40.0 - float(tier) * 34.0
			draw_rect(Rect2(x0, y, 270.0, 34.0), Color("5a6470").darkened(float(tier) * 0.08))
			# Crowd dots.
			for d in 12:
				var dx: float = x0 + 14.0 + float(d) * 21.0
				var dy: float = y + 12.0 + float((d * 13 + tier * 7) % 12)
				var dc := Color("e8e0d0") if d % 3 == 0 else Color("c62828") if d % 3 == 1 else Color("f2b134")
				draw_circle(Vector2(dx, dy), 4.0, dc)


func _draw_ground() -> void:
	var bot: float = _vh - _oy
	draw_rect(Rect2(-_ox, HORIZON_Y, _vw, bot - HORIZON_Y), _ground_col)
	# Mowing stripes.
	for i in 8:
		if i % 2 == 0:
			draw_rect(Rect2(-_ox + float(i) * _vw / 8.0, HORIZON_Y, _vw / 8.0, bot - HORIZON_Y),
				Color(1, 1, 1, 0.05))
	# Boundary arc.
	draw_arc(Vector2(480.0, 430.0), 400.0, PI * 0.12, PI * 0.88, 48, Color(1, 1, 1, 0.55), 5.0)


func _draw_pitch() -> void:
	draw_rect(Rect2(PITCH_L, PITCH_TOP, PITCH_R - PITCH_L, PITCH_BOT - PITCH_TOP), Color("cbb26a"))
	draw_rect(Rect2(PITCH_L, PITCH_TOP, PITCH_R - PITCH_L, PITCH_BOT - PITCH_TOP),
		Color(0, 0, 0, 0.08), false, 3.0)
	# Creases.
	draw_line(Vector2(PITCH_L - 14, BOWL_STUMP_Y + 26), Vector2(PITCH_R + 14, BOWL_STUMP_Y + 26),
		Color.WHITE, 3.0)
	draw_line(Vector2(PITCH_L - 14, BAT_STUMP_Y - 26), Vector2(PITCH_R + 14, BAT_STUMP_Y - 26),
		Color.WHITE, 3.0)


func _draw_stumps(x: float, y: float, broken: bool, s: float) -> void:
	var h := 26.0 * s
	if not broken:
		for sx in [-7.0, 0.0, 7.0]:
			draw_line(Vector2(x + sx * s, y), Vector2(x + sx * s, y - h), STUMP_COL, 3.5 * s)
		draw_line(Vector2(x - 7.0 * s, y - h), Vector2(x + 7.0 * s, y - h), STUMP_COL, 2.5 * s)
	else:
		draw_line(Vector2(x - 16.0 * s, y - 4.0), Vector2(x - 12.0 * s, y - h * 0.7), STUMP_COL, 3.5 * s)
		draw_line(Vector2(x + 14.0 * s, y - 2.0), Vector2(x + 18.0 * s, y - h), STUMP_COL, 3.5 * s)
		draw_line(Vector2(x - 4.0 * s, y - h - 8.0), Vector2(x + 10.0 * s, y - h - 16.0), STUMP_COL, 2.5 * s)


func _draw_person(base: Vector2, h: float, jersey: Color, skin: Color, bat_angle: float, has_bat: bool) -> void:
	var hip := base + Vector2(0, -h * 0.45)
	var shoulder := base + Vector2(0, -h * 0.80)
	var head_c := base + Vector2(0, -h * 0.93)
	draw_line(hip, base + Vector2(-h * 0.13, 0), PANTS, h * 0.10)
	draw_line(hip, base + Vector2(h * 0.13, 0), PANTS, h * 0.10)
	draw_rect(Rect2(shoulder + Vector2(-h * 0.17, 0), Vector2(h * 0.34, h * 0.40)), jersey)
	draw_line(shoulder, shoulder + Vector2(-h * 0.22, h * 0.26), jersey.darkened(0.12), h * 0.09)
	draw_line(shoulder, shoulder + Vector2(h * 0.22, h * 0.26), jersey.darkened(0.12), h * 0.09)
	draw_circle(head_c, h * 0.135, skin)
	draw_arc(head_c, h * 0.135, PI, TAU, 10, jersey.darkened(0.25), maxf(2.0, h * 0.06))
	if has_bat:
		var hand := shoulder + Vector2(h * 0.22, h * 0.26)
		var dir := Vector2(cos(bat_angle), sin(bat_angle))
		draw_line(hand, hand + dir * h * 0.58, BAT_COL, maxf(3.0, h * 0.10))
		draw_line(hand + dir * h * 0.30, hand + dir * h * 0.58, Color("d9b06a"), maxf(3.0, h * 0.10))
