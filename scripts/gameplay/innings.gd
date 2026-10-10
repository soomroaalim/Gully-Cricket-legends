class_name GCLInnings
extends RefCounted
## One innings of a gully match: score, wickets, striker rotation, per-player
## batting/bowling figures and recent-ball symbols. Gully rules: no wides or
## no-balls — every ball counts. If the batting order is exhausted, the last
## batter keeps striking with "lives" until max_wickets fall.

var _batting_order: Array = []
var _bowling_order: Array = []
var _overs: int = 2
var _max_wickets: int = 3
var _target: int = -1
var _rng: GCLRng

var _runs: int = 0
var _wickets: int = 0
var _balls: int = 0
var _striker_idx: int = 0
var _non_striker_idx: int = 1
var _bowler_idx: int = 0
var _next_in_idx: int = 2
var _recent: PackedStringArray = []
var _bat_stats: Dictionary = {}
var _bowl_stats: Dictionary = {}


func _init(batting_order: Array, bowling_order: Array, overs: int, max_wickets: int, target: Variant, rng: GCLRng) -> void:
	_batting_order = batting_order
	_bowling_order = bowling_order
	_overs = maxi(1, overs)
	_max_wickets = maxi(1, max_wickets)
	_target = int(target) if target != null and int(target) > 0 else -1
	_rng = rng if rng != null else GCLRng.new(1)
	if _batting_order.size() == 1:
		# 1v1 gully: one batter faces everything.
		_non_striker_idx = 0
		_next_in_idx = 1
	for p in _batting_order:
		var pid: String = str((p as Dictionary).get("id", ""))
		_bat_stats[pid] = {"runs": 0, "balls": 0, "fours": 0, "sixes": 0, "out": false, "how": ""}
	for p in _bowling_order:
		var pid2: String = str((p as Dictionary).get("id", ""))
		if not _bowl_stats.has(pid2):
			_bowl_stats[pid2] = {"balls": 0, "runs": 0, "wickets": 0}


func set_target(t: int) -> void:
	_target = t if t > 0 else -1


func runs() -> int:
	return _runs


func wickets() -> int:
	return _wickets


func balls() -> int:
	return _balls


func overs_text() -> String:
	return "%d.%d" % [_balls / 6, _balls % 6]


func is_over() -> bool:
	if _balls >= _overs * 6:
		return true
	if _wickets >= _max_wickets:
		return true
	if _target > 0 and _runs >= _target:
		return true
	return false


func striker() -> Dictionary:
	if _batting_order.is_empty():
		return {}
	return _batting_order[_striker_idx]


func bowler() -> Dictionary:
	if _bowling_order.is_empty():
		return {}
	return _bowling_order[_bowler_idx]


func bat_stats() -> Dictionary:
	return _bat_stats


func bowl_stats() -> Dictionary:
	return _bowl_stats


func apply_ball(outcome: Dictionary) -> void:
	if is_over():
		return
	if _batting_order.is_empty():
		return
	var runs: int = int(outcome.get("runs", 0))
	var wicket: bool = bool(outcome.get("wicket", false))
	var bat: Dictionary = _batting_order[_striker_idx]
	var bowl: Dictionary = _bowling_order[_bowler_idx] if not _bowling_order.is_empty() else {}
	var sid: String = str(bat.get("id", ""))
	var bid: String = str(bowl.get("id", ""))

	_balls += 1
	_runs += runs

	var bs: Dictionary = _bat_stats.get(sid, {"runs": 0, "balls": 0, "fours": 0, "sixes": 0, "out": false, "how": ""})
	bs["runs"] = int(bs["runs"]) + runs
	bs["balls"] = int(bs["balls"]) + 1
	if runs == 4:
		bs["fours"] = int(bs["fours"]) + 1
	if runs == 6:
		bs["sixes"] = int(bs["sixes"]) + 1
	_bat_stats[sid] = bs

	var bws: Dictionary = _bowl_stats.get(bid, {"balls": 0, "runs": 0, "wickets": 0})
	bws["balls"] = int(bws["balls"]) + 1
	bws["runs"] = int(bws["runs"]) + runs

	var symbol: String = str(runs)
	if wicket:
		_wickets += 1
		bws["wickets"] = int(bws["wickets"]) + 1
		bs["out"] = true
		var dismissal: String = str(outcome.get("dismissal", ""))
		if dismissal == "":
			dismissal = "caught" if bool(outcome.get("lofted", false)) else "bowled"
		var bname: String = str(bowl.get("name", "Bowler"))
		match dismissal:
			"caught":
				bs["how"] = "c b " + bname
			"run out":
				bs["how"] = "run out"
			_:
				bs["how"] = "b " + bname
		symbol = "W"
		_send_next_batter()
	elif runs % 2 == 1:
		_swap_strike()
	_bowl_stats[bid] = bws

	_recent.append(symbol)
	if _recent.size() > 12:
		_recent = _recent.slice(_recent.size() - 12)

	if _balls % 6 == 0 and not is_over():
		_swap_strike()
		if _bowling_order.size() > 1:
			_bowler_idx = (_bowler_idx + 1) % _bowling_order.size()


func view(batting_team_name: String, bowling_team_name: String, innings_no: int) -> Dictionary:
	var s: Dictionary = striker()
	var ns_i: int = _non_striker_idx if _non_striker_idx < _batting_order.size() else _striker_idx
	var ns: Dictionary = _batting_order[ns_i] if not _batting_order.is_empty() else {}
	var bw: Dictionary = bowler()
	var ss: Dictionary = _bat_stats.get(str(s.get("id", "")), {"runs": 0, "balls": 0})
	return {
		"innings": innings_no,
		"runs": _runs,
		"wickets": _wickets,
		"balls": _balls,
		"overs_total": _overs,
		"max_wickets": _max_wickets,
		"overs_text": overs_text(),
		"target": _target if _target > 0 else null,
		"striker_name": str(s.get("name", "")),
		"striker_runs": int(ss.get("runs", 0)),
		"striker_balls": int(ss.get("balls", 0)),
		"non_striker_name": str(ns.get("name", "")),
		"bowler_name": str(bw.get("name", "")),
		"batting_team_name": batting_team_name,
		"bowling_team_name": bowling_team_name,
		"recent_balls": _recent,
	}


func scorecard_line() -> Dictionary:
	var batters: Array = []
	for p in _batting_order:
		var pd: Dictionary = p
		var st: Dictionary = _bat_stats.get(str(pd.get("id", "")), {"runs": 0, "balls": 0, "fours": 0, "sixes": 0, "out": false, "how": ""})
		var out_str: String
		if bool(st.get("out", false)):
			out_str = str(st.get("how", "out"))
		elif int(st.get("balls", 0)) == 0:
			out_str = "DNB"
		else:
			out_str = "not out"
		batters.append({
			"name": str(pd.get("name", "")),
			"runs": int(st.get("runs", 0)),
			"balls": int(st.get("balls", 0)),
			"fours": int(st.get("fours", 0)),
			"sixes": int(st.get("sixes", 0)),
			"out_str": out_str,
		})
	var bowlers: Array = []
	for p in _bowling_order:
		var pd2: Dictionary = p
		var st2: Dictionary = _bowl_stats.get(str(pd2.get("id", "")), {"balls": 0, "runs": 0, "wickets": 0})
		var b: int = int(st2.get("balls", 0))
		if b > 0:
			bowlers.append({
				"name": str(pd2.get("name", "")),
				"overs_text": "%d.%d" % [b / 6, b % 6],
				"runs": int(st2.get("runs", 0)),
				"wickets": int(st2.get("wickets", 0)),
			})
	return {
		"batters": batters,
		"bowlers": bowlers,
		"total": _runs,
		"wickets": _wickets,
		"overs_text": overs_text(),
	}


func _swap_strike() -> void:
	var tmp: int = _striker_idx
	_striker_idx = _non_striker_idx
	_non_striker_idx = tmp


func _send_next_batter() -> void:
	if _next_in_idx < _batting_order.size():
		_striker_idx = _next_in_idx
		_next_in_idx += 1
	# else: gully "lives" rule — the batter carries on.
