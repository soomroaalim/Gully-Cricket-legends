class_name MatchEngine
extends RefCounted
## Orchestrates a full gully match: two innings, human batting input, human
## bowling input, and AI-vs-AI simulation. Pure logic + GCLRng — no
## SaveSystem/Economy/UI references. Deterministic from config.seed.
## Gully rules: no wides, no no-balls — every ball counts.
## When the player's team bowls, the human ALWAYS bowls (bowler = user player).

signal ball_completed(outcome: Dictionary, view: Dictionary)
signal innings_ended(view: Dictionary)
signal match_ended(result: Dictionary)

var _cfg: Dictionary = {}
var _rng: GCLRng
var _innings: Array = []
var _current: int = 0
var _difficulty: String = "NORMAL"
var _player_team: Array = []
var _ai_team: Array = []
var _player_team_name: String = "You"
var _ai_team_name: String = "Opponents"
var _user_id: String = ""
var _player_bats_first: bool = true
var _last_delivery: Dictionary = {}
var _pitch: Dictionary = {}
var _weather: Dictionary = {}


func setup(config: Dictionary) -> void:
	_cfg = config
	_difficulty = str(config.get("difficulty", "NORMAL"))
	_player_team = config.get("player_team", [])
	_ai_team = config.get("ai_team", [])
	_player_team_name = str(config.get("player_team_name", "You"))
	_ai_team_name = str(config.get("ai_team_name", "Opponents"))
	_user_id = str(config.get("user_player_id", ""))
	_player_bats_first = bool(config.get("user_bats_first", true))
	_rng = GCLRng.new(int(config.get("seed", 0)))
	_last_delivery = {}
	_pitch = config.get("pitch", {})
	_weather = config.get("weather", {})
	var overs: int = int(config.get("overs", 2))
	var max_wkts: int = int(config.get("max_wickets", 3))
	_innings.clear()
	_current = 0
	if _player_bats_first:
		_innings.append(GCLInnings.new(_player_team, _ai_team, overs, max_wkts, null, _rng))
		_innings.append(GCLInnings.new(_ai_team, _player_bowling_order(), overs, max_wkts, null, _rng))
	else:
		_innings.append(GCLInnings.new(_ai_team, _player_bowling_order(), overs, max_wkts, null, _rng))
		_innings.append(GCLInnings.new(_player_team, _ai_team, overs, max_wkts, null, _rng))


## AI bowls at the human batter: delivery + cosmetic flight data for the UI.
func ai_bowl_delivery() -> Dictionary:
	var inn: GCLInnings = _innings[_current]
	var bowler: Dictionary = inn.bowler()
	if not _bowling_is_player():
		bowler = _boosted(bowler, "ai_bowling_boost")
	var d: Dictionary = AIDirector.choose_delivery(_difficulty, _rng, bowler)
	d["flight_ms"] = _rng.int_range(650, 1050)
	d["drift"] = _rng.normal() * 24.0
	d["bounce"] = _rng.next()
	_last_delivery = d
	return d


## Human batting input. shot in "tap"|"swipeLeft"|"swipeRight"|"swipeUp"|""
## ("" = no input -> MISS).
func resolve_batting(shot: String, timing_offset_ms: float) -> Dictionary:
	var inn: GCLInnings = _innings[_current]
	if inn.is_over():
		return _dead_ball()
	var use_shot: String = shot
	var timing: String
	if use_shot == "":
		timing = "MISS"
		use_shot = "tap"
	else:
		timing = BattingSystem.grade_timing(timing_offset_ms)
	var batter: Dictionary = inn.striker()
	var bowler: Dictionary = inn.bowler()
	if not _bowling_is_player():
		bowler = _boosted(bowler, "ai_bowling_boost")
	var delivery: Dictionary = _last_delivery if not _last_delivery.is_empty() else {"line": "Middle", "length": "Good", "type": "Fast"}
	var fielding_avg: float = _team_fielding_avg(_ai_team if _batting_is_player() else _player_team)
	var outcome: Dictionary = BattingSystem.resolve({
		"batter": batter,
		"bowler": bowler,
		"delivery": delivery,
		"shot": use_shot,
		"timing": timing,
		"rng": _rng,
		"fielding_avg": fielding_avg,
		"difficulty": _difficulty,
		"pitch": _pitch,
		"weather": _weather,
	})
	_after_ball(inn, outcome)
	return outcome


## Human bowling input. delivery = {line, length, type, accuracy 0..1}.
## The bowler is always the user's player.
func resolve_bowling(delivery: Dictionary) -> Dictionary:
	var inn: GCLInnings = _innings[_current]
	if inn.is_over():
		return _dead_ball()
	var batter: Dictionary = inn.striker()
	if not _batting_is_player():
		batter = _boosted(batter, "ai_batting_boost")
	var bowler: Dictionary = _user_player()
	var outcome: Dictionary = BowlingSystem.resolve({
		"delivery": delivery,
		"batter": batter,
		"bowler": bowler,
		"rng": _rng,
		"difficulty": _difficulty,
		"pitch": _pitch,
		"weather": _weather,
	})
	_after_ball(inn, outcome)
	return outcome


## Simulates one ball where at least one side is AI-driven (used for fast
## sim and for AI-vs-AI passages). Works from any match state.
func simulate_ai_ball() -> Dictionary:
	var inn: GCLInnings = _innings[_current]
	if inn.is_over():
		return _dead_ball()
	var batting_player_side: bool = _batting_is_player()
	var delivery: Dictionary
	var bowler: Dictionary
	if _bowling_is_player():
		# Human's over, simulated: a neutral club-level delivery.
		delivery = {"line": "Middle", "length": "Good", "type": "Fast", "accuracy": 0.55}
		bowler = _user_player()
	else:
		var raw_bowler: Dictionary = inn.bowler()
		bowler = _boosted(raw_bowler, "ai_bowling_boost")
		delivery = AIDirector.choose_delivery(_difficulty, _rng, bowler)
		var p: Dictionary = AIDirector.params_for(_difficulty)
		delivery["accuracy"] = clampf(_rng.next() * 0.5 + float(p["bowling_accuracy"]) * 0.5, 0.0, 1.0)
	var batter: Dictionary = inn.striker()
	if not batting_player_side:
		batter = _boosted(batter, "ai_batting_boost")
	var timing: String = BattingSystem.grade_timing(AIDirector.ai_batting_offset(_difficulty, _rng))
	var shot: String = AIDirector.ai_shot(_difficulty, _rng, delivery)
	var fielding_avg: float = _team_fielding_avg(_ai_team if batting_player_side else _player_team)
	var outcome: Dictionary = BattingSystem.resolve({
		"batter": batter,
		"bowler": bowler,
		"delivery": delivery,
		"shot": shot,
		"timing": timing,
		"rng": _rng,
		"fielding_avg": fielding_avg,
		"difficulty": _difficulty,
		"accuracy": clampf(float(delivery.get("accuracy", 0.6)), 0.0, 1.0),
		"pitch": _pitch,
		"weather": _weather,
	})
	_after_ball(inn, outcome)
	return outcome


func is_player_striker() -> bool:
	if _innings.is_empty():
		return false
	return bool((_innings[_current] as GCLInnings).striker().get("is_user", false))


func is_player_bowling() -> bool:
	if _innings.is_empty():
		return false
	return bool((_innings[_current] as GCLInnings).bowler().get("is_user", false))


func current_view() -> Dictionary:
	if _innings.is_empty():
		return {}
	var inn: GCLInnings = _innings[_current]
	var batting_player_side: bool = _batting_is_player()
	var bat_name: String = _player_team_name if batting_player_side else _ai_team_name
	var bowl_name: String = _ai_team_name if batting_player_side else _player_team_name
	return inn.view(bat_name, bowl_name, _current + 1)


func is_innings_over() -> bool:
	if _innings.is_empty():
		return true
	return (_innings[_current] as GCLInnings).is_over()


func is_match_over() -> bool:
	if _innings.size() < 2:
		return false
	return _current == 1 and (_innings[1] as GCLInnings).is_over()


func start_next_innings() -> void:
	if _innings.size() < 2 or _current != 0:
		return
	var first: GCLInnings = _innings[0]
	if not first.is_over():
		return
	_current = 1
	(_innings[1] as GCLInnings).set_target(first.runs() + 1)


func get_result() -> Dictionary:
	var p_inn: GCLInnings = _innings[0] if _player_bats_first else _innings[1]
	var a_inn: GCLInnings = _innings[1] if _player_bats_first else _innings[0]
	var pr: int = p_inn.runs()
	var ar: int = a_inn.runs()
	var winner: String = "tie"
	if pr > ar:
		winner = "player"
	elif ar > pr:
		winner = "ai"
	var names: Dictionary = {}
	for p in _player_team + _ai_team:
		var pd: Dictionary = p
		names[str(pd.get("id", ""))] = str(pd.get("name", ""))
	var top: Dictionary = {"name": "-", "runs": -1, "balls": 0}
	var best: Dictionary = {"name": "-", "wickets": -1, "runs": 0}
	var pom: String = "-"
	var pom_score: float = -1.0
	var sixes: int = 0
	var fours: int = 0
	var pwickets: int = 0
	for i in 2:
		var inn: GCLInnings = _innings[i]
		var is_player_inn: bool = (_player_bats_first == (i == 0))
		for pid in inn.bat_stats():
			var st: Dictionary = inn.bat_stats()[pid]
			var nm: String = str(names.get(pid, pid))
			var r: int = int(st.get("runs", 0))
			var b: int = int(st.get("balls", 0))
			if r > int(top["runs"]):
				top = {"name": nm, "runs": r, "balls": b}
			var bscore: float = float(r) + float(st.get("sixes", 0)) * 4.0
			if bscore > pom_score:
				pom_score = bscore
				pom = nm
			if is_player_inn:
				sixes += int(st.get("sixes", 0))
				fours += int(st.get("fours", 0))
		for pid2 in inn.bowl_stats():
			var st2: Dictionary = inn.bowl_stats()[pid2]
			var nm2: String = str(names.get(pid2, pid2))
			var wk: int = int(st2.get("wickets", 0))
			var br: int = int(st2.get("runs", 0))
			if wk > int(best["wickets"]):
				best = {"name": nm2, "wickets": wk, "runs": br}
			var wscore: float = float(wk) * 22.0 - float(br) * 0.4
			if wscore > pom_score:
				pom_score = wscore
				pom = nm2
			if not is_player_inn:
				pwickets += wk
	return {
		"winner": winner,
		"player_runs": pr,
		"player_wickets": p_inn.wickets(),
		"ai_runs": ar,
		"ai_wickets": a_inn.wickets(),
		"player_overs": p_inn.overs_text(),
		"ai_overs": a_inn.overs_text(),
		"player_won": winner == "player",
		"tied": winner == "tie",
		"coins": 0,
		"xp": 0,
		"new_unlocks": [],
		"achievements_unlocked": [],
		"top_scorer": top,
		"best_bowler": best,
		"player_of_match": pom,
		"perf": {"sixes": sixes, "fours": fours, "wickets": pwickets},
	}


## v2.0: real per-player performance of the human's player, aggregated
## across both innings. Only stats the engine actually records per player
## (batting runs/balls/fours/sixes, bowling wickets/runs/balls). Fielding
## contributions (catches/run-outs) are NOT tracked per player by the engine,
## so they are reported as 0 and never fabricated.
func user_performance() -> Dictionary:
	var perf: Dictionary = {
		"runs": 0, "balls_faced": 0, "fours": 0, "sixes": 0, "dismissed": false,
		"wickets": 0, "runs_conceded": 0, "balls_bowled": 0, "catches": 0,
	}
	for i in _innings.size():
		var inn: GCLInnings = _innings[i]
		var bs: Dictionary = inn.bat_stats().get(_user_id, {})
		if not bs.is_empty():
			perf["runs"] = int(perf["runs"]) + int(bs.get("runs", 0))
			perf["balls_faced"] = int(perf["balls_faced"]) + int(bs.get("balls", 0))
			perf["fours"] = int(perf["fours"]) + int(bs.get("fours", 0))
			perf["sixes"] = int(perf["sixes"]) + int(bs.get("sixes", 0))
			perf["dismissed"] = bool(perf["dismissed"]) or bool(bs.get("out", false))
		var bw: Dictionary = inn.bowl_stats().get(_user_id, {})
		if not bw.is_empty():
			perf["wickets"] = int(perf["wickets"]) + int(bw.get("wickets", 0))
			perf["runs_conceded"] = int(perf["runs_conceded"]) + int(bw.get("runs", 0))
			perf["balls_bowled"] = int(perf["balls_bowled"]) + int(bw.get("balls", 0))
	return perf


func scorecard() -> Dictionary:
	var arr: Array = []
	for i in _innings.size():
		var inn: GCLInnings = _innings[i]
		var line: Dictionary = inn.scorecard_line()
		var batting_player_side: bool = (_player_bats_first == (i == 0))
		line["team_name"] = _player_team_name if batting_player_side else _ai_team_name
		arr.append(line)
	return {"innings": arr}


func _after_ball(inn: GCLInnings, outcome: Dictionary) -> void:
	inn.apply_ball(outcome)
	emit_signal("ball_completed", outcome, current_view())
	if inn.is_over():
		emit_signal("innings_ended", current_view())
		if _current == 1:
			emit_signal("match_ended", get_result())


func _batting_is_player() -> bool:
	return _player_bats_first == (_current == 0)


func _bowling_is_player() -> bool:
	return not _batting_is_player()


func _user_player() -> Dictionary:
	for p in _player_team:
		var pd: Dictionary = p
		if str(pd.get("id", "")) == _user_id:
			return pd
	if not _player_team.is_empty():
		return _player_team[0]
	return {}


func _player_bowling_order() -> Array:
	var u: Dictionary = _user_player()
	if u.is_empty():
		return _player_team.duplicate()
	# The human always bowls when their team is in the field.
	return [u]


## Applies an AI difficulty stat boost (ai_batting_boost / ai_bowling_boost)
## to a copy of a player dictionary. The only way AI stats change.
func _boosted(p: Dictionary, key: String) -> Dictionary:
	var c: Dictionary = p.duplicate()
	var params: Dictionary = AIDirector.params_for(_difficulty)
	var boost: float = float(params.get(key, 1.0))
	var stat: String = "batting" if key == "ai_batting_boost" else "bowling"
	c[stat] = clampf(float(p.get(stat, 50)) * boost, 1.0, 99.0)
	return c


func _team_fielding_avg(team: Array) -> float:
	if team.is_empty():
		return 55.0
	var total: float = 0.0
	for p in team:
		total += float((p as Dictionary).get("fielding", 50))
	return total / float(team.size())


func _dead_ball() -> Dictionary:
	return {
		"runs": 0, "wicket": false, "timing": "MISS",
		"description": "That innings is already over.", "shot_quality": 0.0,
		"lofted": false, "dismissal": "",
	}
