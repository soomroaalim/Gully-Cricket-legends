extends SceneTree
## Headless test runner for Gully Cricket Legends v1.0.0.
##
## Run:
##   ~/tools/godot/Godot_v4.3-stable_linux.x86_64 --headless \
##     --path ~/workspace/gully-cricket-legends --script tests/test_runner.gd
##
## Prints PASS:/FAIL: lines and a final RESULT: X/Y passed, then quits.
## All suites are seeded/deterministic. Autoloads (SaveSystem, GameState,
## Economy, Career) are reached via get_node() because bare autoload
## identifiers do not compile in a --script main-loop context.

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
	if Save == null or State == null or Econ == null or CareerA == null:
		print("FAIL: autoloads not available")
		print("RESULT: 0/1 passed")
		return true
	_run_all()
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


func _run_all() -> void:
	_suite_timing_grades()
	_suite_batting()
	_suite_bowling()
	_suite_innings()
	_suite_match_engine()
	_suite_ai()
	_suite_economy()
	_suite_save_roundtrip()
	_suite_career()


# ---------------------------------------------------------------- suites ---

func _suite_timing_grades() -> void:
	_check(BattingSystem.grade_timing(null) == "MISS", "timing: null -> MISS")
	_check(BattingSystem.grade_timing(0.0) == "PERFECT", "timing: 0 -> PERFECT")
	_check(BattingSystem.grade_timing(60.0) == "PERFECT", "timing: +60 -> PERFECT (boundary)")
	_check(BattingSystem.grade_timing(-60.0) == "PERFECT", "timing: -60 -> PERFECT (boundary)")
	_check(BattingSystem.grade_timing(61.0) == "GOOD", "timing: +61 -> GOOD")
	_check(BattingSystem.grade_timing(-120.0) == "GOOD", "timing: -120 -> GOOD (boundary)")
	_check(BattingSystem.grade_timing(120.0) == "GOOD", "timing: +120 -> GOOD (boundary)")
	_check(BattingSystem.grade_timing(-121.0) == "EARLY", "timing: -121 -> EARLY")
	_check(BattingSystem.grade_timing(121.0) == "LATE", "timing: +121 -> LATE")
	_check(BattingSystem.grade_timing(-250.0) == "EARLY", "timing: -250 -> EARLY (boundary)")
	_check(BattingSystem.grade_timing(250.0) == "LATE", "timing: +250 -> LATE (boundary)")
	_check(BattingSystem.grade_timing(-251.0) == "MISS", "timing: -251 -> MISS")
	_check(BattingSystem.grade_timing(251.0) == "MISS", "timing: +251 -> MISS")
	_check(BattingSystem.grade_timing(900.0) == "MISS", "timing: +900 -> MISS")


func _fixed_batter(pid: String, bat: int = 50) -> Dictionary:
	return {"id": pid, "name": "Bat_" + pid, "role": "Batter",
		"batting": bat, "bowling": 40, "fielding": 50, "speed": 50, "stamina": 50,
		"level": 1, "overall": 50, "is_user": false}


func _fixed_bowler(pid: String, bowl: int = 50) -> Dictionary:
	return {"id": pid, "name": "Bowl_" + pid, "role": "Bowler",
		"batting": 40, "bowling": bowl, "fielding": 50, "speed": 50, "stamina": 50,
		"level": 1, "overall": 50, "is_user": false}


func _bat_stats_for(timing: String, balls: int, seed: int) -> Dictionary:
	var batter: Dictionary = _fixed_batter("tb1")
	var bowler: Dictionary = _fixed_bowler("tw1")
	var delivery: Dictionary = {"line": "Middle", "length": "Good", "type": "Fast"}
	var rng := GCLRng.new(seed)
	var runs: int = 0
	var wkts: int = 0
	for _i in balls:
		var o: Dictionary = BattingSystem.resolve({
			"batter": batter, "bowler": bowler, "delivery": delivery,
			"shot": "swipeLeft", "timing": timing, "rng": rng,
			"fielding_avg": 55.0, "difficulty": "NORMAL",
		})
		runs += int(o["runs"])
		if bool(o["wicket"]):
			wkts += 1
	return {"avg": float(runs) / float(balls), "wicket_rate": float(wkts) / float(balls)}


func _suite_batting() -> void:
	var perfect: Dictionary = _bat_stats_for("PERFECT", 600, 101)
	var miss: Dictionary = _bat_stats_for("MISS", 600, 202)
	var good: Dictionary = _bat_stats_for("GOOD", 600, 303)
	var early: Dictionary = _bat_stats_for("EARLY", 600, 404)
	var late: Dictionary = _bat_stats_for("LATE", 600, 505)
	print("INFO: batting avgs P=%.3f M=%.3f G=%.3f E=%.3f L=%.3f | wkt P=%.3f M=%.3f" % [
		perfect["avg"], miss["avg"], good["avg"], early["avg"], late["avg"],
		perfect["wicket_rate"], miss["wicket_rate"]])
	_check(float(perfect["avg"]) - float(miss["avg"]) > 1.5,
		"batting: avg(PERFECT) - avg(MISS) > 1.5 (timing dominates runs)")
	_check(float(miss["wicket_rate"]) > float(perfect["wicket_rate"]),
		"batting: wicket_rate(MISS) > wicket_rate(PERFECT)")
	_check(float(miss["wicket_rate"]) > 0.05,
		"batting: MISS has real wicket risk (>5%)")
	_check(float(good["avg"]) > float(early["avg"]),
		"batting: avg(GOOD) > avg(EARLY)")
	_check(float(good["avg"]) > float(late["avg"]),
		"batting: avg(GOOD) > avg(LATE)")
	_check(float(perfect["avg"]) > float(good["avg"]),
		"batting: avg(PERFECT) > avg(GOOD)")


func _bowl_stats_for(accuracy: float, balls: int, seed: int) -> Dictionary:
	var batter: Dictionary = _fixed_batter("bb1")
	var bowler: Dictionary = _fixed_bowler("bw1")
	var rng := GCLRng.new(seed)
	var runs: int = 0
	var wkts: int = 0
	for _i in balls:
		var o: Dictionary = BowlingSystem.resolve({
			"delivery": {"line": "Middle", "length": "Yorker", "type": "Fast", "accuracy": accuracy},
			"batter": batter, "bowler": bowler, "rng": rng, "difficulty": "NORMAL",
		})
		runs += int(o["runs"])
		if bool(o["wicket"]):
			wkts += 1
	return {"avg": float(runs) / float(balls), "wicket_rate": float(wkts) / float(balls)}


func _suite_bowling() -> void:
	var hi: Dictionary = _bowl_stats_for(0.95, 400, 606)
	var lo: Dictionary = _bowl_stats_for(0.20, 400, 707)
	print("INFO: bowling yorker acc .95 avg=%.3f wkt=%.3f | acc .20 avg=%.3f wkt=%.3f" % [
		hi["avg"], hi["wicket_rate"], lo["avg"], lo["wicket_rate"]])
	_check(float(hi["avg"]) < float(lo["avg"]),
		"bowling: accurate yorker (0.95) concedes fewer runs than loose (0.20)")
	_check(float(hi["wicket_rate"]) > float(lo["wicket_rate"]),
		"bowling: accurate yorker (0.95) takes wickets at higher rate than loose (0.20)")


func _mk_order(prefix: String, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append({"id": "%s_%d" % [prefix, i], "name": "P%d" % i, "role": "Batter",
			"batting": 50, "bowling": 50, "fielding": 50, "speed": 50, "stamina": 50,
			"level": 1, "overall": 50, "is_user": i == 0})
	return out


func _suite_innings() -> void:
	var bat: Array = _mk_order("t", 3)
	var bowl: Array = _mk_order("b", 1)
	var inn := GCLInnings.new(bat, bowl, 2, 3, null, GCLRng.new(42))
	var seq: Array = [1, 4, "W", 6, 2, 0]
	for s in seq:
		if str(s) == "W":
			inn.apply_ball({"runs": 0, "wicket": true, "dismissal": "bowled"})
		else:
			inn.apply_ball({"runs": int(s), "wicket": false})
	_check(inn.runs() == 13, "innings: scripted [1,4,W,6,2,0] scores 13 runs")
	_check(inn.wickets() == 1, "innings: scripted sequence loses 1 wicket")
	_check(inn.overs_text() == "1.0", "innings: overs_text is 1.0 after 6 balls")
	_check(inn.balls() == 6, "innings: 6 balls bowled")
	_check(str(inn.striker().get("id", "")) == "t_0",
		"innings: strike rotates back to t_0 after over (1-run swap, W, over swap)")
	var bs: Dictionary = inn.bat_stats()
	_check(int(bs["t_1"]["runs"]) == 4 and bool(bs["t_1"]["out"]),
		"innings: t_1 made 4 then got out")
	_check(int(bs["t_2"]["runs"]) == 8 and int(bs["t_2"]["sixes"]) == 1,
		"innings: t_2 made 8 with one six")
	var v: Dictionary = inn.view("A", "B", 1)
	_check(str(v["recent_balls"]) == str(PackedStringArray(["1", "4", "W", "6", "2", "0"])),
		"innings: recent_balls tracks symbols")
	_check(not inn.is_over(), "innings: not over after 1 over of a 2-over innings")

	# All-out ends the innings.
	var inn2 := GCLInnings.new(_mk_order("u", 2), _mk_order("v", 1), 2, 1, null, GCLRng.new(9))
	inn2.apply_ball({"runs": 2, "wicket": false})
	_check(not inn2.is_over(), "innings: 1-down chase continues with wickets in hand")
	inn2.apply_ball({"runs": 0, "wicket": true})
	_check(inn2.is_over(), "innings: all-out (max_wickets=1) ends innings immediately")

	# Target chase ends the moment the target is reached.
	var inn3 := GCLInnings.new(_mk_order("x", 2), _mk_order("y", 1), 2, 3, null, GCLRng.new(11))
	inn3.set_target(5)
	inn3.apply_ball({"runs": 4, "wicket": false})
	_check(not inn3.is_over(), "innings: 4/0 chasing 5 is not over")
	inn3.apply_ball({"runs": 2, "wicket": false})
	_check(inn3.is_over() and inn3.balls() == 2,
		"innings: reaching target ends innings immediately (2 balls)")


func _match_config(seed: int) -> Dictionary:
	var pteam: Array = []
	pteam.append({"id": "fx_u0", "name": "User", "role": "Batter",
		"batting": 58, "bowling": 45, "fielding": 50, "speed": 52, "stamina": 50,
		"level": 1, "overall": 55, "is_user": true})
	var ateam: Array = []
	ateam.append({"id": "fx_a0", "name": "Opp", "role": "Batter",
		"batting": 55, "bowling": 55, "fielding": 55, "speed": 55, "stamina": 55,
		"level": 1, "overall": 55, "is_user": false})
	return {
		"mode": "1v1", "overs": 2, "max_wickets": 3,
		"stage_id": "soomra_colony", "stage_name": "Soomra Colony",
		"difficulty": "EASY", "player_team_name": "Test XI", "ai_team_name": "Opp XI",
		"player_team": pteam, "ai_team": ateam,
		"user_player_id": "fx_u0", "user_bats_first": true, "seed": seed,
	}


func _play_ai_match(seed: int) -> Dictionary:
	var eng := MatchEngine.new()
	eng.setup(_match_config(seed))
	var balls: int = 0
	while not eng.is_match_over():
		if eng.is_innings_over():
			eng.start_next_innings()
		else:
			eng.simulate_ai_ball()
			balls += 1
		if balls > 500:
			break
	return {"engine": eng, "balls": balls, "result": eng.get_result()}


func _suite_match_engine() -> void:
	var m1: Dictionary = _play_ai_match(424242)
	var eng: MatchEngine = m1["engine"]
	var balls: int = int(m1["balls"])
	var res: Dictionary = m1["result"]
	_check(balls < 200, "match: full AI-vs-AI 1v1 completes in <200 balls (%d)" % balls)
	_check(balls > 0, "match: at least one ball was simulated")
	_check(str(res.get("winner", "")) in ["player", "ai", "tie"],
		"match: winner is valid (%s)" % str(res.get("winner", "")))
	var sc: Dictionary = eng.scorecard()
	_check((sc.get("innings", []) as Array).size() == 2,
		"match: scorecard has 2 innings")
	# Determinism: same seed -> identical result.
	var m2: Dictionary = _play_ai_match(424242)
	var r2: Dictionary = m2["result"]
	_check(int(r2["player_runs"]) == int(res["player_runs"])
		and int(r2["ai_runs"]) == int(res["ai_runs"])
		and str(r2["winner"]) == str(res["winner"]),
		"match: same seed -> identical result (deterministic)")
	# Different seed still completes.
	var m3: Dictionary = _play_ai_match(777)
	_check(str((m3["result"] as Dictionary).get("winner", "")) in ["player", "ai", "tie"],
		"match: different seed also completes with valid winner")
	# Chase target = innings1 runs + 1.
	var inn1: GCLInnings = eng._innings[0]
	var inn2: GCLInnings = eng._innings[1]
	var target = inn2.view("", "", 2).get("target")
	_check(int(target) == inn1.runs() + 1,
		"match: innings-2 target is innings-1 runs + 1 (%s == %d)" % [str(target), inn1.runs() + 1])


func _suite_ai() -> void:
	var diffs: Array = ["EASY", "NORMAL", "HARD", "LEGEND"]
	var terr: Array = []
	var ferr: Array = []
	var merr: Array = []
	var aggr: Array = []
	for d in diffs:
		var p: Dictionary = AIDirector.params_for(d)
		terr.append(float(p["timing_error_ms"]))
		ferr.append(float(p["fielding_error"]))
		merr.append(float(p["mistake_rate"]))
		aggr.append(float(p["aggression"]))
	_check(terr[0] > terr[1] and terr[1] > terr[2] and terr[2] > terr[3],
		"ai: timing_error_ms strictly decreases EASY->LEGEND %s" % str(terr))
	_check(ferr[0] > ferr[1] and ferr[1] > ferr[2] and ferr[2] > ferr[3],
		"ai: fielding_error strictly decreases EASY->LEGEND %s" % str(ferr))
	_check(merr[0] > merr[1] and merr[1] > merr[2] and merr[2] > merr[3],
		"ai: mistake_rate strictly decreases EASY->LEGEND %s" % str(merr))
	_check(aggr[0] < aggr[1] and aggr[1] < aggr[2] and aggr[2] < aggr[3],
		"ai: aggression strictly increases EASY->LEGEND %s" % str(aggr))
	# LEGEND AI outscores EASY AI over 200 simulated balls.
	var batter: Dictionary = _fixed_batter("ab1", 55)
	var bowler: Dictionary = _fixed_bowler("ab2", 55)
	var totals: Dictionary = {}
	for d in ["EASY", "LEGEND"]:
		var rng := GCLRng.new(808)
		var runs: int = 0
		for _i in 200:
			var o: Dictionary = BowlingSystem.resolve({
				"delivery": {"line": "Middle", "length": "Good", "type": "Fast", "accuracy": 0.6},
				"batter": batter, "bowler": bowler, "rng": rng, "difficulty": d,
			})
			runs += int(o["runs"])
		totals[d] = float(runs) / 200.0
	print("INFO: ai 200-ball avg EASY=%.3f LEGEND=%.3f" % [totals["EASY"], totals["LEGEND"]])
	_check(float(totals["LEGEND"]) > float(totals["EASY"]),
		"ai: LEGEND AI outscores EASY AI over 200 balls (no cheating, just better timing)")


func _suite_economy() -> void:
	Save.reset_game()
	_check(Econ.coins() == 150, "economy: fresh save starts with 150 coins")
	_check(not Econ.spend(99999), "economy: spend fails when insufficient")
	_check(Econ.coins() == 150, "economy: failed spend leaves balance unchanged")
	Save.data["coins"] = 1000
	_check(Econ.purchase("improved_bat"), "economy: purchase deducts and succeeds")
	_check(Econ.coins() == 600, "economy: purchase deducted 400 coins")
	_check((Save.data["equipment_owned"] as Array).has("improved_bat"),
		"economy: purchased item is owned")
	_check(not Econ.purchase("improved_bat"), "economy: cannot buy the same item twice")
	_check(not Econ.purchase("no_such_item"), "economy: cannot buy unknown item")
	Save.data["team"] = GCLPlayers.make_starter_team("Tester", 0)
	var pid: String = str((Save.data["team"] as Array)[0]["id"])
	var lvl_before: int = int((Save.data["team"] as Array)[0]["level"])
	Save.data["coins"] = 1000
	_check(Econ.upgrade_player(pid), "economy: upgrade_player succeeds")
	_check(int((Save.data["team"] as Array)[0]["level"]) == lvl_before + 1,
		"economy: upgrade_player raises level")
	_check(Econ.coins() == 850, "economy: upgrade cost 150 coins deducted")
	_check(not Econ.upgrade_player("bogus_id"), "economy: upgrade_player fails for unknown id")
	var win_res: Dictionary = {"player_won": true, "tied": false,
		"perf": {"sixes": 2, "fours": 1, "wickets": 1}}
	var loss_res: Dictionary = {"player_won": false, "tied": false,
		"perf": {"sixes": 0, "fours": 0, "wickets": 0}}
	var rw_win: Dictionary = Econ.rewards_for_match(win_res, "1v1", "EASY")
	var rw_loss: Dictionary = Econ.rewards_for_match(loss_res, "1v1", "EASY")
	var rw_legend: Dictionary = Econ.rewards_for_match(win_res, "1v1", "LEGEND")
	_check(int(rw_win["coins"]) > int(rw_loss["coins"]),
		"economy: rewards_for_match win pays more than loss (%d > %d)"
		% [int(rw_win["coins"]), int(rw_loss["coins"])])
	_check(int(rw_legend["coins"]) > int(rw_win["coins"]),
		"economy: rewards_for_match LEGEND pays more than EASY (%d > %d)"
		% [int(rw_legend["coins"]), int(rw_win["coins"])])
	# add_xp with multi-level carry: 400 xp = L1(100) + L2(250) -> level 3, 50 xp left.
	Save.data["xp"] = 0
	Save.data["level"] = 1
	var lvls: int = Econ.add_xp(400)
	_check(lvls == 2, "economy: add_xp(400) grants 2 level-ups")
	_check(int(Save.data["level"]) == 3 and int(Save.data["xp"]) == 50,
		"economy: add_xp carries remainder (level 3, 50 xp)")
	# finalize_match fills coins/xp and unlocks first_match.
	State.set("match_config", {})
	var fres: Dictionary = {"player_won": true, "tied": false, "player_runs": 30,
		"perf": {"sixes": 1, "fours": 2, "wickets": 2}}
	var coins_before: int = Econ.coins()
	var out: Dictionary = Econ.finalize_match(fres, "1v1", "EASY")
	_check(int(out.get("coins", 0)) > 0 and int(out.get("xp", 0)) > 0,
		"economy: finalize_match fills coins/xp on the result")
	# Achievement payouts (first_match 50 + first_win 100 + first_six 80) are
	# credited on top of the match reward.
	var ach_bonus: int = 0
	for aid in (out.get("achievements_unlocked", []) as Array):
		ach_bonus += int(GCLAchievements.by_id(str(aid)).get("coins", 0))
	_check(Econ.coins() == coins_before + int(out["coins"]) + ach_bonus,
		"economy: finalize_match credits match coins + achievement bonuses to balance")
	_check((out.get("achievements_unlocked", []) as Array).has("first_match"),
		"economy: finalize_match unlocks first_match achievement")
	_check((out.get("achievements_unlocked", []) as Array).has("first_win"),
		"economy: finalize_match unlocks first_win achievement")
	_check((out.get("achievements_unlocked", []) as Array).has("first_six"),
		"economy: finalize_match unlocks first_six achievement")
	_check(int(Save.data["stats"]["matches"]) == 1 and int(Save.data["stats"]["wins"]) == 1,
		"economy: finalize_match records match stats")


func _suite_save_roundtrip() -> void:
	Save.reset_game()
	Save.data["coins"] = 777
	Save.data["player_name"] = "QA Tester"
	Save.save_game()
	Save.data["coins"] = 0
	Save.data["player_name"] = "wiped"
	Save.load_game()
	_check(int(Save.data["coins"]) == 777, "save: coins persist through save/load round-trip")
	_check(str(Save.data["player_name"]) == "QA Tester",
		"save: player_name persists through save/load round-trip")


func _suite_career() -> void:
	Save.reset_game()
	_check(not CareerA.is_unlocked("mithi"), "career: stage 2 (mithi) locked initially")
	_check(CareerA.is_unlocked("soomra_colony"), "career: stage 1 (soomra_colony) unlocked initially")
	CareerA.complete_stage("soomra_colony")
	_check(CareerA.is_unlocked("mithi"), "career: complete_stage(soomra_colony) unlocks mithi")
	# Tournament: loss retries the same round; wins advance; final win = champion.
	var tid: String = "soomra_cup" # rounds: Semi Final, Final
	var loss: Dictionary = CareerA.record_tournament_match(tid, false)
	_check(not bool(loss["champion"]) and str(loss["next_round_name"]) == "Semi Final"
		and not bool(loss["eliminated"]),
		"career: tournament loss retries same round (not eliminated)")
	var ts0: Dictionary = CareerA.tournament_state(tid)
	_check(int(ts0.get("round", -1)) == 0, "career: loss does not advance round counter")
	var w1: Dictionary = CareerA.record_tournament_match(tid, true)
	_check(not bool(w1["champion"]) and str(w1["next_round_name"]) == "Final",
		"career: semi-final win advances to Final")
	var w2: Dictionary = CareerA.record_tournament_match(tid, true)
	_check(bool(w2["champion"]) and str(w2["next_round_name"]) == "",
		"career: final win -> champion")
	var ts2: Dictionary = CareerA.tournament_state(tid)
	_check(int(ts2.get("wins", 0)) == 2, "career: tournament record counts 2 wins")
