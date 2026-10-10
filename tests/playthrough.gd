extends SceneTree
## Scripted full-match playthrough: a complete 2-over 1v1 match mixing
## resolve_batting (varied timing/shots) and resolve_bowling (varied
## deliveries), then Economy.finalize_match + Career.record_tournament_match.
##
## Run:
##   ~/tools/godot/Godot_v4.3-stable_linux.x86_64 --headless \
##     --path ~/workspace/gully-cricket-legends --script tests/playthrough.gd

var _ran: bool = false
var _passed: int = 0
var _total: int = 0
var _failures: Array[String] = []

var Save: Node
var State: Node
var Econ: Node
var CareerA: Node


func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	Save = get_root().get_node_or_null("SaveSystem")
	State = get_root().get_node_or_null("GameState")
	Econ = get_root().get_node_or_null("Economy")
	CareerA = get_root().get_node_or_null("Career")
	_run()
	print("RESULT: %d/%d passed" % [_passed, _total])
	if not _failures.is_empty():
		print("FAILURES:")
		for f in _failures:
			print("  - " + f)
	return true


func _check(cond: bool, label: String) -> void:
	_total += 1
	if cond:
		_passed += 1
		print("PASS: " + label)
	else:
		print("FAIL: " + label)
		_failures.append(label)


func _run() -> void:
	Save.reset_game()
	var team: Array = GCLPlayers.make_starter_team("Playthrough", 0)
	Save.data["team"] = team
	Save.data["player_name"] = "Playthrough"
	# 1v1: only the user player takes the field.
	var uid: String = str(team[0]["id"])
	Save.data["lineup"] = [uid]
	Save.save_game()

	var stage: Dictionary = GCLStages.all()[0]
	var rng := GCLRng.new(31337)
	# NOTE: GCLUI.build_match_config is not used here because gcl_ui.gd
	# references the AudioMan autoload, which does not compile in a --script
	# main-loop context. This mirrors its config shape per CONTRACTS.md.
	var mc: Dictionary = GCLConfig.MODE_CONFIG["1v1"]
	var ai_names: Array = stage.get("team_names", ["Street XI"])
	var cfg: Dictionary = {
		"mode": "1v1",
		"overs": int(mc.get("overs", 2)),
		"max_wickets": int(mc.get("max_wickets", 3)),
		"stage_id": str(stage.get("id", "")),
		"stage_name": str(stage.get("name", "")),
		"difficulty": "EASY",
		"player_team_name": "Playthrough XI",
		"ai_team_name": str(rng.pick(ai_names)),
		"player_team": team.slice(0, 1),
		"ai_team": GCLPlayers.generate_opponent_team(stage, GCLRng.new(4242)).slice(0, 1),
		"user_player_id": uid,
		"user_bats_first": true,
		"seed": 90210,
	}
	State.set("match_config", cfg)

	var eng := MatchEngine.new()
	eng.setup(cfg)

	var shots: Array = ["tap", "swipeLeft", "swipeRight", "swipeUp", ""]
	var offsets: Array = [-300.0, -100.0, -30.0, 0.0, 30.0, 100.0, 300.0]
	var lines: Array = ["Off", "Middle", "Leg"]
	var lengths: Array = ["Yorker", "Full", "Good", "Short"]
	var types: Array = ["Fast", "Swing", "Spin", "Slower"]
	var balls: int = 0
	var bat_balls: int = 0
	var bowl_balls: int = 0
	var guard: int = 0
	while not eng.is_match_over() and guard < 500:
		guard += 1
		if eng.is_innings_over():
			eng.start_next_innings()
			continue
		if eng.is_player_striker() or _player_batting(eng):
			# Innings 1: human bats against AI deliveries.
			eng.ai_bowl_delivery()
			var o: Dictionary = eng.resolve_batting(
				str(shots[balls % shots.size()]),
				float(offsets[balls % offsets.size()]))
			_check(o.has("runs") and o.has("wicket") and o.has("timing"),
				"playthrough: batting outcome has runs/wicket/timing keys")
			bat_balls += 1
		else:
			# Innings 2: human bowls at the AI batter.
			var o2: Dictionary = eng.resolve_bowling({
				"line": str(lines[bowls_mod(lines, balls)]),
				"length": str(lengths[bowls_mod(lengths, balls)]),
				"type": str(types[bowls_mod(types, balls)]),
				"accuracy": 0.3 + 0.15 * float(balls % 5),
			})
			_check(o2.has("runs") and o2.has("wicket"),
				"playthrough: bowling outcome has runs/wicket keys")
			bowl_balls += 1
		balls += 1

	_check(eng.is_match_over(), "playthrough: scripted 2-over match completes")
	_check(bat_balls > 0 and bowl_balls > 0,
		"playthrough: both batting (%d) and bowling (%d) phases were exercised"
		% [bat_balls, bowl_balls])
	var res: Dictionary = eng.get_result()
	_check(str(res.get("winner", "")) in ["player", "ai", "tie"],
		"playthrough: valid winner (%s)" % str(res.get("winner")))
	print("INFO: playthrough score %d/%d vs %d/%d, balls=%d" % [
		int(res["player_runs"]), int(res["player_wickets"]),
		int(res["ai_runs"]), int(res["ai_wickets"]), balls])

	var coins_before: int = Econ.coins()
	var fin: Dictionary = Econ.finalize_match(res, "1v1", "EASY")
	_check(int(fin.get("coins", 0)) > 0 and int(fin.get("xp", 0)) > 0,
		"playthrough: finalize_match produced sane rewards (coins=%d xp=%d)"
		% [int(fin.get("coins", 0)), int(fin.get("xp", 0))])
	_check(Econ.coins() > coins_before, "playthrough: rewards credited to balance")

	var trec: Dictionary = CareerA.record_tournament_match("soomra_cup", bool(fin.get("player_won", false)))
	_check(trec.has("champion") and trec.has("next_round_name") and trec.has("eliminated"),
		"playthrough: record_tournament_match returns sane dict")
	print("INFO: playthrough tournament: champion=%s next=%s" % [
		str(trec.get("champion")), str(trec.get("next_round_name"))])
	_check(int(Save.data["stats"]["matches"]) == 1,
		"playthrough: match recorded in career stats")


func _player_batting(eng: MatchEngine) -> bool:
	# engine.is_player_striker() is only true when the striker is the user
	# player; fall back to innings-level check via current view team names.
	var v: Dictionary = eng.current_view()
	return str(v.get("batting_team_name", "")) == str(
		(State.get("match_config") as Dictionary).get("player_team_name", ""))


func bowls_mod(arr: Array, balls: int) -> int:
	return balls % arr.size()
