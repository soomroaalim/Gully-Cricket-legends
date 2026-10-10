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
	_suite_compare_rows()
	_suite_recent_results()
	_suite_roster_integrity()
	_suite_selection()
	_suite_tiers()
	_suite_user_performance()
	_suite_development()


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


func _suite_compare_rows() -> void:
	var PS = load("res://scripts/ui/player.gd")
	var user := {"overall": 70, "batting": 65, "bowling": 40, "fielding": 50,
		"speed": 55, "stamina": 48, "level": 3}
	var mate := {"overall": 60, "batting": 65, "bowling": 45, "fielding": 48,
		"speed": 50, "stamina": 52, "level": 3}
	var rows: Array = PS.compare_rows(user, mate)
	_check(rows.size() == 9, "compare: 9 rows (Overall, Batting, Bowling, Fielding, Speed, Stamina, Level, Fitness, Form %)")
	var leaders := {}
	for r in rows:
		leaders[str(r.get("key", ""))] = str(r.get("leader", ""))
		_check(r.has("key") and r.has("label") and r.has("uval") and r.has("mval") and r.has("leader"),
			"compare: row has key/label/uval/mval/leader")
	_check(leaders.get("overall") == "user", "compare: overall leader = user (70 > 60)")
	_check(leaders.get("batting") == "tie", "compare: batting leader = tie (65 = 65)")
	_check(leaders.get("bowling") == "mate", "compare: bowling leader = mate (45 > 40)")
	_check(leaders.get("fielding") == "user", "compare: fielding leader = user (50 > 48)")
	_check(leaders.get("speed") == "user", "compare: speed leader = user (55 > 50)")
	_check(leaders.get("stamina") == "mate", "compare: stamina leader = mate (52 > 48)")
	_check(leaders.get("level") == "tie", "compare: level leader = tie (3 = 3)")
	_check(leaders.get("fitness") == "na", "compare: missing fitness -> 'na' (no crash)")
	_check(leaders.get("form") == "tie", "compare: default form 50% vs 50% -> tie")
	# v3.0: real fitness/form values compare correctly.
	var frows: Array = PS.compare_rows(
		{"fitness": 90, "form": 0.8}, {"fitness": 70, "form": 0.4})
	var fl := {}
	for r in frows:
		fl[str(r.get("key", ""))] = str(r.get("leader", ""))
	_check(fl.get("fitness") == "user", "compare: fitness leader = user (90 > 70)")
	_check(fl.get("form") == "user", "compare: form leader = user (80% > 40%)")
	var row0: Dictionary = rows[0]
	_check(int(row0.get("uval", -1)) == 70 and int(row0.get("mval", -1)) == 60,
		"compare: uval/mval carry the raw values")
	# Missing attributes: leader "na", no crash.
	var empty: Array = PS.compare_rows({}, {})
	_check(empty.size() == 9, "compare: empty dicts still yield 9 rows")
	var all_na := true
	for r in empty:
		var lk: String = str(r.get("key", ""))
		var lv: String = str(r.get("leader", ""))
		if lk == "form":
			if lv != "tie":
				all_na = false
		elif lv != "na":
			all_na = false
	_check(all_na, "compare: missing keys -> 'na' (form defaults 50/50 -> tie)")
	var partial: Array = PS.compare_rows({"batting": 50}, {})
	var pleaders := {}
	for r in partial:
		pleaders[str(r.get("key", ""))] = str(r.get("leader", ""))
	_check(pleaders.get("batting") == "na" and pleaders.get("bowling") == "na",
		"compare: one-sided dicts -> 'na' (no crash)")


func _suite_recent_results() -> void:
	Save.reset_game()
	State.set("match_config", {})
	var mk := func(won: bool, tied: bool, pr: int, pw: int, ar: int, aw: int) -> Dictionary:
		return {"player_won": won, "tied": tied, "player_runs": pr,
			"player_wickets": pw, "ai_runs": ar, "ai_wickets": aw,
			"perf": {"sixes": 0, "fours": 0, "wickets": 0}}
	# Old save without the key: finalize must still work (backward compat).
	Save.data.erase("recent_results")
	Econ.finalize_match(mk.call(true, false, 145, 6, 140, 8), "1v1", "EASY")
	_check((Save.data.get("recent_results", []) as Array).size() == 1,
		"results: key created on old saves missing recent_results")
	# Push past the cap of 5.
	Econ.finalize_match(mk.call(false, false, 100, 9, 120, 4), "2v2", "EASY")
	Econ.finalize_match(mk.call(false, true, 90, 8, 90, 8), "1v1", "NORMAL")
	Econ.finalize_match(mk.call(true, false, 160, 3, 150, 9), "5v5", "HARD")
	Econ.finalize_match(mk.call(false, false, 80, 10, 130, 2), "gully6", "EASY")
	Econ.finalize_match(mk.call(true, false, 200, 1, 199, 10), "1v1", "LEGEND")
	var recent: Array = Save.data.get("recent_results", [])
	_check(recent.size() == 5, "results: capped at 5 entries")
	var first: Dictionary = recent[0]
	_check(str(first.get("outcome", "")) == "W", "results: newest first (last match was a win)")
	_check(str(first.get("line", "")) == "200/1 vs 199/10",
		"results: score line format 'player/wkts vs ai/wkts'")
	_check(str(first.get("mode", "")) == "1v1", "results: mode recorded")
	var outcomes: Array = []
	for r in recent:
		outcomes.append(str(r.get("outcome", "")))
	_check(outcomes == ["W", "L", "W", "T", "L"],
		"results: W/L/T outcomes recorded in newest-first order")


func _suite_roster_integrity() -> void:
	Save.reset_game()
	Save.data["team"] = GCLPlayers.make_starter_team("Tester", 0)
	var count := 0
	for p in Save.data["team"]:
		if p is Dictionary and bool(p.get("is_user", false)):
			count += 1
	_check(count == 1, "roster: exactly one is_user in the starter team")
	var user: Dictionary = GCLUI.user_player()
	_check(not user.is_empty() and bool(user.get("is_user", false)),
		"roster: GCLUI.user_player() resolves the single is_user player")


# ------------------------------------------------- v2.0 selection -------
func _setup_selection_team() -> void:
	Save.reset_game()
	var team: Array = GCLPlayers.make_starter_team("Tester", 0)
	Save.data["team"] = team
	var ids: Array = []
	for p in team:
		if p is Dictionary:
			ids.append(str(p.get("id", "")))
	Save.data["lineup"] = ids
	# Fresh post-onboarding selection state.
	var sel: Dictionary = Save.data["career"]["selection"]
	sel["status"] = "RESERVE"
	sel["selection_chance"] = GCLSelection.BASE_CHANCE
	sel["migrated"] = true
	sel["reserve_matches"] = []
	sel["mainxi_matches"] = 0
	sel["form"] = []
	sel["feedback"] = ""


func _user_test_id() -> String:
	for p in Save.data.get("team", []):
		if p is Dictionary and bool(p.get("is_user", false)):
			return str(p.get("id", ""))
	return ""


func _suite_selection() -> void:
	# 1. New career: RESERVE at a 20% base chance.
	_setup_selection_team()
	_check(CareerA.selection_status() == "RESERVE",
		"selection: new career starts as RESERVE")
	_check(absf(CareerA.selection_chance() - 0.20) < 0.0001,
		"selection: newly eligible reserve starts at 20% base chance")
	# 2. The stored chance is never rerolled by reading it (screen opens).
	var c1: float = CareerA.selection_chance()
	var c2: float = CareerA.selection_chance()
	var c3: float = CareerA.selection_chance()
	_check(c1 == c2 and c2 == c3,
		"selection: chance is stable across reads (never rerolled on screen open)")
	# 3. Great reserve performance raises the chance; status becomes eligible.
	_setup_selection_team()
	var great: Dictionary = {"runs": 45, "balls_faced": 18, "fours": 4,
		"sixes": 2, "wickets": 3, "runs_conceded": 12, "balls_bowled": 18}
	var out: Dictionary = CareerA.record_reserve_match(great, true)
	_check(CareerA.selection_chance() > 0.20,
		"selection: great reserve performance raises chance above 20%")
	_check(str(out.get("status", "")) in ["DEBUT_ELIGIBLE", "SELECTED_FOR_DEBUT"],
		"selection: first reserve match confers DEBUT_ELIGIBLE (or selects)")
	_check((Save.data["career"]["selection"].get("reserve_matches", []) as Array).size() == 1,
		"selection: reserve match history recorded")
	# 4. Poor performance lowers the chance.
	_setup_selection_team()
	var poor: Dictionary = {"runs": 2, "balls_faced": 14, "fours": 0,
		"sixes": 0, "wickets": 0, "runs_conceded": 34, "balls_bowled": 18}
	CareerA.record_reserve_match(poor, false)
	_check(CareerA.selection_chance() < 0.20,
		"selection: poor reserve performance lowers chance below 20%")
	# 5. Determinism: the draw matches an independent seeded re-computation.
	_setup_selection_team()
	var uid: String = _user_test_id()
	var perf: Dictionary = {"runs": 20, "balls_faced": 15, "wickets": 1,
		"runs_conceded": 18, "balls_bowled": 12}
	var res2: Dictionary = CareerA.record_reserve_match(perf, true)
	var chance_after: float = CareerA.selection_chance()
	var rng := GCLRng.new(absi(hash(uid + ":sel:1")))
	var expected: bool = GCLSelection.draw_selection(chance_after, rng.next())
	_check(bool(res2.get("selected", false)) == expected,
		"selection: draw is deterministic from (player id, match index)")
	# 6. Role suitability is respected by the model.
	_check(GCLSelection.role_fit("Wicketkeeper",
		["Batter", "Batter", "Wicketkeeper", "Wicketkeeper", "Wicketkeeper"]) < 0.5,
		"selection: oversubscribed role gets low role-fit")
	_check(GCLSelection.role_fit("Bowler",
		["Batter", "Batter", "Bowler", "AllRounder", "Wicketkeeper"]) == 1.0,
		"selection: needed role gets full role-fit")
	# 7. The draw is a probability, not a countdown: ~20% over 200 rolls.
	var hits: int = 0
	for i in 200:
		var rr := GCLRng.new(1000 + i)
		if GCLSelection.draw_selection(0.20, rr.next()):
			hits += 1
	_check(hits > 10 and hits < 90,
		"selection: 20pct draw selects about 20pct over 200 seeded rolls (%d)" % hits)
	# 8. Debut records real performance and promotes to MAIN_XI.
	_setup_selection_team()
	Save.data["career"]["selection"]["status"] = "SELECTED_FOR_DEBUT"
	var dout: Dictionary = CareerA.record_debut_match(
		{"runs": 30, "balls_faced": 20, "wickets": 2, "runs_conceded": 15, "balls_bowled": 18}, true)
	_check(CareerA.selection_status() == "MAIN_XI",
		"selection: debut promotes the player to MAIN_XI")
	_check(int(Save.data["career"]["selection"]["debut"].get("runs", -1)) == 30,
		"selection: debut performance is recorded")
	_check(str(dout.get("status", "")) == "MAIN_XI",
		"selection: debut returns MAIN_XI status")
	# 9. One bad match never drops; sustained poor form does.
	_setup_selection_team()
	Save.data["career"]["selection"]["status"] = "MAIN_XI"
	var bad1: Dictionary = {"runs": 0, "balls_faced": 3, "wickets": 0,
		"runs_conceded": 25, "balls_bowled": 12}
	var r1: Dictionary = CareerA.record_mainxi_match(bad1)
	_check(not bool(r1.get("dropped", false)) and CareerA.selection_status() == "MAIN_XI",
		"selection: a single bad match does not drop the player")
	CareerA.record_mainxi_match({"runs": 1, "balls_faced": 5, "wickets": 0,
		"runs_conceded": 30, "balls_bowled": 12})
	var r3: Dictionary = CareerA.record_mainxi_match({"runs": 0, "balls_faced": 2,
		"wickets": 0, "runs_conceded": 28, "balls_bowled": 12})
	_check(bool(r3.get("dropped", false)) and CareerA.selection_status() == "DROPPED",
		"selection: sustained poor form drops the player to reserves")
	# 10. Migration: pre-v2.0 saves are grandfathered to MAIN_XI.
	Save.reset_game()
	Save.data["career"].erase("selection")
	Save.data["stats"]["matches"] = 12
	Save.data["team"] = GCLPlayers.make_starter_team("Veteran", 0)
	CareerA.ensure_selection_migrated()
	_check(CareerA.selection_status() == "MAIN_XI",
		"selection: existing save migrates to MAIN_XI (no progress loss)")
	_check(bool(Save.data["career"]["selection"].get("migrated", false)),
		"selection: migration marks itself complete")
	# 11. Brand-new saves start as RESERVE.
	Save.reset_game()
	CareerA.ensure_selection_migrated()
	_check(CareerA.selection_status() == "RESERVE",
		"selection: brand-new save starts as RESERVE")
	# 12. Round-trip: status + chance survive save/load.
	_setup_selection_team()
	CareerA.record_reserve_match(
		{"runs": 25, "balls_faced": 16, "wickets": 1, "runs_conceded": 20, "balls_bowled": 12}, true)
	var ch_before: float = CareerA.selection_chance()
	var st_before: String = CareerA.selection_status()
	Save.save_game()
	Save.load_game()
	_check(absf(CareerA.selection_chance() - ch_before) < 0.000001
		and CareerA.selection_status() == st_before,
		"selection: status and chance survive save/load round-trip")
	# 13. Feedback names the actual weakest factor.
	var fb: String = GCLSelection.feedback_for(
		{"form": 0.2, "ability": 0.8, "role_fit": 0.9}, false, "Tester")
	_check("form" in fb.to_lower(),
		"selection: feedback names the weakest factor honestly")


func _suite_tiers() -> void:
	var teams: Array = GCLTiers.generate_teams("colony", 4242)
	_check(teams.size() == 20, "tiers: colony tier generates 20 teams")
	var names: Dictionary = {}
	var loc_eq_name: bool = false
	var rosters_ok: bool = true
	for t in teams:
		names[str(t.get("name", ""))] = true
		if str(t.get("name", "")) == str(t.get("location", "")):
			loc_eq_name = true
		if (t.get("roster", []) as Array).size() != 5:
			rosters_ok = false
	_check(names.size() == 20, "tiers: colony team names are unique")
	_check(not loc_eq_name, "tiers: no team name equals its bare location")
	_check(rosters_ok, "tiers: every colony team has a 5-player roster")
	var again: Array = GCLTiers.generate_teams("colony", 4242)
	_check(str(again[0].get("name", "")) == str(teams[0].get("name", "")),
		"tiers: team generation is deterministic for a seed")
	_check(GCLTiers.all().size() == 6, "tiers: 6 competition tiers defined")
	var counts := {"colony": 20, "city": 20, "district": 20, "provincial": 5, "national": 20}
	for tid in counts.keys():
		_check(int(GCLTiers.by_id(tid).get("team_count", -1)) == int(counts[tid]),
			"tiers: %s has %d teams" % [tid, int(counts[tid])])
	_check((GCLTiers.by_id("international").get("pathways", []) as Array).size() == 2,
		"tiers: international tier has men's + women's pathways")
	_check(not bool(GCLTiers.by_id("city").get("playable", true)),
		"tiers: city tier is honestly scaffolded (not playable)")
	# Promotion: checklist gates, then advances the tier.
	_setup_selection_team()
	_check(not CareerA.can_promote(), "tiers: fresh career cannot promote")
	var s: Dictionary = Save.data["career"]["selection"]
	s["status"] = "MAIN_XI"
	s["mainxi_matches"] = 3
	Save.data["career"]["trophies"] = ["soomra_cup"]
	_check(CareerA.can_promote(), "tiers: main-XI + trophy + 3 matches -> can promote")
	_check(CareerA.promote(), "tiers: promote() succeeds when eligible")
	_check(str(CareerA.ladder_tier().get("id", "")) == "city",
		"tiers: promotion advances the ladder colony -> city")


func _suite_user_performance() -> void:
	var m: Dictionary = _play_ai_match(424242)
	var eng: MatchEngine = m["engine"]
	var up: Dictionary = eng.user_performance()
	_check(int(up.get("balls_faced", 0)) + int(up.get("balls_bowled", 0)) > 0,
		"perf: user_performance shows the user participated")
	var runs: int = 0
	var wkts: int = 0
	for i in eng._innings.size():
		var bs: Dictionary = (eng._innings[i] as GCLInnings).bat_stats().get("fx_u0", {})
		runs += int(bs.get("runs", 0))
		var bw: Dictionary = (eng._innings[i] as GCLInnings).bowl_stats().get("fx_u0", {})
		wkts += int(bw.get("wickets", 0))
	_check(int(up.get("runs", 0)) == runs,
		"perf: user_performance runs match the innings bat_stats")
	_check(int(up.get("wickets", 0)) == wkts,
		"perf: user_performance wickets match the innings bowl_stats")


# ------------------------------------------------- v3.0 development ---

func _dev_player(pid: String, role: String, bat: int, bowl: int) -> Dictionary:
	var p: Dictionary = {"id": pid, "name": "D_" + pid, "role": role,
		"batting": bat, "bowling": bowl, "fielding": 50, "speed": 50, "stamina": 50,
		"level": 1, "overall": 50, "is_user": false}
	GCLDevelopment.ensure_player_dev(p)
	return p


func _cond_wicket_rate(pitch_id: String, weather_id: String, dtype: String, seed: int) -> float:
	var batter: Dictionary = _dev_player("cb1", "Batter", 55, 40)
	var bowler: Dictionary = _dev_player("cb2", "Bowler", 40, 55)
	var rng := GCLRng.new(seed)
	var wkts: int = 0
	var n: int = 80
	for i in n:
		var o: Dictionary = BattingSystem.resolve({
			"batter": batter, "bowler": bowler,
			"delivery": {"line": "Middle", "length": "Good", "type": dtype},
			"shot": "swipeLeft", "timing": "GOOD", "rng": rng,
			"fielding_avg": 55.0, "difficulty": "NORMAL",
			"pitch": GCLDevelopment.pitch_by_id(pitch_id),
			"weather": GCLDevelopment.weather_by_id(weather_id),
		})
		if bool(o.get("wicket")):
			wkts += 1
	return float(wkts) / float(n)


func _cond_boundary_rate(pitch_id: String, weather_id: String, seed: int) -> float:
	var batter: Dictionary = _dev_player("cb1", "Batter", 55, 40)
	var bowler: Dictionary = _dev_player("cb2", "Bowler", 40, 55)
	var rng := GCLRng.new(seed)
	var b: int = 0
	var n: int = 80
	for i in n:
		var o: Dictionary = BattingSystem.resolve({
			"batter": batter, "bowler": bowler,
			"delivery": {"line": "Middle", "length": "Good", "type": "Fast"},
			"shot": "swipeLeft", "timing": "PERFECT", "rng": rng,
			"fielding_avg": 55.0, "difficulty": "NORMAL",
			"pitch": GCLDevelopment.pitch_by_id(pitch_id),
			"weather": GCLDevelopment.weather_by_id(weather_id),
		})
		if int(o.get("runs", 0)) >= 4:
			b += 1
	return float(b) / float(n)


func _suite_development() -> void:
	# --- 1. Role-based batting order: role bands, batting desc within bands.
	var team: Array = [
		_dev_player("t_bowl", "Bowler", 38, 62),
		_dev_player("t_bat2", "Batter", 52, 40),
		_dev_player("t_ar", "AllRounder", 55, 55),
		_dev_player("t_wk", "Wicketkeeper", 50, 35),
		_dev_player("t_bat1", "Batter", 64, 40),
	]
	var ord: Array = GCLDevelopment.batting_order(team, "t_bat1", false)
	var ids: Array = []
	for p in ord:
		ids.append(str((p as Dictionary).get("id", "")))
	_check(ids == ["t_bat1", "t_bat2", "t_wk", "t_ar", "t_bowl"],
		"dev: batting order follows role bands, batting-desc within bands (%s)" % str(ids))
	# --- 2. User opens in reserve context; keeps its band slot otherwise.
	var ord_r: Array = GCLDevelopment.batting_order(team, "t_bowl", true)
	_check(str((ord_r[0] as Dictionary).get("id", "")) == "t_bowl",
		"dev: reserve context puts the user first")
	var ord_n: Array = GCLDevelopment.batting_order(team, "t_bowl", false)
	_check(str((ord_n[4] as Dictionary).get("id", "")) == "t_bowl",
		"dev: non-reserve user stays in their role-band slot")
	# --- 3. Tactical style changes effective stats, never base attributes.
	var ar: Dictionary = _dev_player("t_ar2", "AllRounder", 60, 60)
	ar["tactical"] = "balanced"
	var e_bal: Dictionary = GCLDevelopment.effective_stats(ar)
	ar["tactical"] = "bowling_focused"
	var e_bowl: Dictionary = GCLDevelopment.effective_stats(ar)
	_check(int(ar["batting"]) == 60 and int(ar["bowling"]) == 60,
		"dev: tactical style never modifies base attributes")
	_check(int(e_bowl["bowling"]) > int(e_bal["bowling"])
		and int(e_bowl["batting"]) < int(e_bal["batting"]),
		"dev: bowling-focused style raises effective bowling, lowers effective batting")
	ar["tactical"] = "batting_focused"
	var e_bat: Dictionary = GCLDevelopment.effective_stats(ar)
	_check(int(e_bat["batting"]) > int(e_bal["batting"]),
		"dev: batting-focused style raises effective batting")
	# --- 4. Form is separate from base.
	var fp: Dictionary = _dev_player("t_f1", "Batter", 60, 40)
	fp["form"] = 0.9
	var e_fp: Dictionary = GCLDevelopment.effective_stats(fp)
	_check(int(fp["batting"]) == 60,
		"dev: form does not overwrite the base rating")
	_check(int(e_fp["batting"]) > 60,
		"dev: high form raises the effective rating (got %d)" % int(e_fp["batting"]))
	# --- 5/6/7. Injury lifecycle: minor / moderate / serious.
	var minor: Dictionary = GCLDevelopment.roll_injury(100, 0.02, 0.5, 0.5)
	_check(not minor.is_empty() and str(minor.get("severity", "")) == "minor",
		"dev: low roll at full fitness -> minor injury")
	_check(GCLDevelopment.is_available({"injury": minor}),
		"dev: minor injury keeps the player available")
	_check(int(GCLDevelopment.injury_penalty({"injury": minor})) == -5,
		"dev: minor injury applies a small effective penalty")
	_check(GCLDevelopment.roll_injury(100, 0.05, 0.5, 0.5).is_empty(),
		"dev: roll above the injury probability -> no injury")
	var mod: Dictionary = GCLDevelopment.roll_injury(100, 0.01, 0.7, 0.5)
	_check(str(mod.get("severity", "")) == "moderate"
		and int(mod.get("days_left", 0)) >= 10 and int(mod.get("days_left", 0)) <= 20,
		"dev: moderate injury lasts 10-20 days (got %s)" % str(mod.get("days_left", "?")))
	_check(not GCLDevelopment.is_available({"injury": mod}),
		"dev: moderate injury makes the player unavailable")
	var ser: Dictionary = GCLDevelopment.roll_injury(100, 0.01, 0.95, 0.02)
	_check(str(ser.get("severity", "")) == "serious"
		and int(ser.get("days_left", 0)) >= 40 and int(ser.get("days_left", 0)) <= 90,
		"dev: serious injury lasts 40-90 days (got %s)" % str(ser.get("days_left", "?")))
	_check(not GCLDevelopment.is_available({"injury": ser}),
		"dev: serious injury makes the player unavailable")
	# --- 8. Recovery advances with career days, no attribute loss.
	var rp: Dictionary = _dev_player("t_r1", "Batter", 62, 41)
	rp["injury"] = {"severity": "moderate", "days_left": 2}
	var tick1: Dictionary = GCLDevelopment.tick_injury(rp["injury"])
	_check(int((rp["injury"] as Dictionary).get("days_left", -1)) == 1
		and not bool(tick1.get("recovered", true)),
		"dev: injury ticks down one day at a time")
	var tick2: Dictionary = GCLDevelopment.tick_injury(rp["injury"])
	_check(bool(tick2.get("recovered", false)),
		"dev: injury recovers when days reach zero")
	_check(int(rp["batting"]) == 62 and int(rp["bowling"]) == 41,
		"dev: recovery causes no attribute loss")
	# --- 9. Practice: correct skill gains, role-weighted.
	_setup_selection_team()
	CareerA.ensure_development_migrated()
	var u: Dictionary = CareerA.user_player()
	var bat_before: int = int(u["batting"])
	var pr: Dictionary = CareerA.do_practice("batting")
	_check(bool(pr.get("ok", false)) and int(u["batting"]) == bat_before + 2,
		"dev: batter gains +2 batting from batting practice below 60")
	var bowler_p: Dictionary = _dev_player("t_pb", "Bowler", 40, 58)
	var pw: Dictionary = GCLDevelopment.practice_result("bowling", bowler_p)
	_check(int((pw.get("gains", {}) as Dictionary).get("bowling", 0)) == 2,
		"dev: bowler gains most from bowling practice (role-weighted)")
	var ar_p: Dictionary = _dev_player("t_pa", "AllRounder", 55, 55)
	var pa: Dictionary = GCLDevelopment.practice_result("allround", ar_p)
	var ag: Dictionary = pa.get("gains", {})
	_check(int(ag.get("batting", 0)) > 0 and int(ag.get("bowling", 0)) > 0,
		"dev: all-rounder training develops both skills")
	# --- 10. Daily session limit enforced by career day.
	CareerA.do_practice("fielding")
	CareerA.do_practice("fitness")
	var pst: Dictionary = CareerA.practice_state()
	_check(int(pst["sessions_left"]) == 0,
		"dev: daily session budget exhausted after 3 sessions")
	var blocked: Dictionary = CareerA.do_practice("batting")
	_check(not bool(blocked.get("ok", true)),
		"dev: 4th session on the same day is blocked")
	# --- 11. Reopening never resets the budget; a new day refreshes it.
	var pst2: Dictionary = CareerA.practice_state()
	_check(int(pst2["sessions_left"]) == 0,
		"dev: session budget persists (reopening does not reset it)")
	CareerA.advance_day()
	_check(int(CareerA.practice_state()["sessions_left"]) == 3,
		"dev: a new career day refreshes the session budget")
	# --- 12. Injured players restricted from conflicting activities.
	u["injury"] = {"severity": "moderate", "days_left": 10}
	var ib: Dictionary = GCLDevelopment.practice_result("batting", u)
	_check(str(ib.get("blocked_reason", "")) != "",
		"dev: moderate injury blocks batting practice")
	var ifx: Dictionary = GCLDevelopment.practice_result("fitness", u)
	_check(str(ifx.get("blocked_reason", "")) != "",
		"dev: moderate injury blocks all training (recovery is via Rest)")
	u["injury"] = {"severity": "minor", "days_left": 2}
	_check(str(GCLDevelopment.practice_result("batting", u).get("blocked_reason", "")) == "",
		"dev: minor injury does not block practice")
	u["injury"] = {}
	# --- 13. Diminishing gains capped at 85.
	var cap_p: Dictionary = _dev_player("t_cap", "Batter", 86, 40)
	var cap_r: Dictionary = GCLDevelopment.practice_result("batting", cap_p)
	_check((cap_r.get("gains", {}) as Dictionary).is_empty()
		and str(cap_r.get("blocked_reason", "")) != "",
		"dev: no batting gains at/above the 85 cap (honest message)")
	# --- 14. Injury blocks match start (GCLUI gate).
	u["injury"] = {"severity": "moderate", "days_left": 8}
	_check(str(GCLUI.match_block_reason()) != "",
		"dev: medically unavailable player is blocked from matches")
	u["injury"] = {"severity": "minor", "days_left": 2}
	_check(str(GCLUI.match_block_reason()) == "",
		"dev: minor injury does not block matches")
	u["injury"] = {}
	# --- 15. Selection model: 20% base intact, fitness + injury in factors.
	_check(absf(GCLSelection.BASE_CHANCE - 0.20) < 0.000001,
		"dev: v2.0 20% base selection chance is intact")
	_setup_selection_team()
	CareerA.ensure_development_migrated()
	var fac: Dictionary = CareerA._selection_factors()
	_check(fac.has("fitness") and fac.has("injured"),
		"dev: selection factors include fitness and injury availability")
	var fb: String = GCLSelection.feedback_for(
		{"form": 0.9, "ability": 0.9, "role_fit": 1.0, "injured": true}, false, "T")
	_check("injur" in fb.to_lower(),
		"dev: selection feedback explains injury unavailability")
	var c1: float = CareerA.selection_chance()
	var c2: float = CareerA.selection_chance()
	_check(c1 == c2,
		"dev: reading the chance never rerolls it")
	# --- 16. Injury lifecycle through Career: recovery restores status.
	_setup_selection_team()
	CareerA.ensure_development_migrated()
	var uu: Dictionary = CareerA.user_player()
	var uu_bat: int = int(uu["batting"])
	Save.data["career"]["selection"]["status"] = "MAIN_XI"
	uu["injury"] = {"severity": "moderate", "days_left": 2,
		"_prev_status": "MAIN_XI"}
	Save.data["career"]["selection"]["status"] = "INJURED"
	CareerA.advance_day()
	_check(int((uu["injury"] as Dictionary).get("days_left", -1)) == 1,
		"dev: career day advance ticks injury recovery")
	CareerA.advance_day()
	_check(CareerA.user_available(),
		"dev: player available again after recovery")
	_check(CareerA.selection_status() == "MAIN_XI",
		"dev: pre-injury selection status restored on recovery")
	_check(int(uu["batting"]) == uu_bat,
		"dev: injury lifecycle causes no attribute loss")
	# --- 17. Toss leads to the correct innings order.
	var eng1 := MatchEngine.new()
	var cfg1: Dictionary = _match_config(9001)
	cfg1["user_bats_first"] = true
	eng1.setup(cfg1)
	_check(eng1._batting_is_player(),
		"dev: choosing Bat First -> player team opens the batting")
	var eng2 := MatchEngine.new()
	var cfg2: Dictionary = _match_config(9002)
	cfg2["user_bats_first"] = false
	eng2.setup(cfg2)
	_check(not eng2._batting_is_player(),
		"dev: choosing Bowl First -> opponents open the batting")
	# --- 18. Pitch/weather effects match their descriptions.
	var green: Dictionary = GCLDevelopment.condition_mods(
		GCLDevelopment.pitch_by_id("green"), GCLDevelopment.weather_by_id("sunny"), "Fast")
	_check(float(green.get("wicket_mult", 1.0)) > 1.0,
		"dev: green pitch boosts pace wicket-taking as described")
	_check("seam" in str(GCLDevelopment.pitch_by_id("green").get("desc", "")).to_lower(),
		"dev: green pitch description names the seam effect")
	var dry: Dictionary = GCLDevelopment.condition_mods(
		GCLDevelopment.pitch_by_id("dry"), GCLDevelopment.weather_by_id("sunny"), "Spin")
	_check(float(dry.get("wicket_mult", 1.0)) > 1.0,
		"dev: dry pitch boosts spin wicket-taking as described")
	var flat: Dictionary = GCLDevelopment.condition_mods(
		GCLDevelopment.pitch_by_id("flat"), GCLDevelopment.weather_by_id("sunny"), "Fast")
	_check(float(flat.get("wicket_mult", 1.0)) == 1.0,
		"dev: flat pitch gives bowlers no extra help, as described")
	var slow: Dictionary = GCLDevelopment.condition_mods(
		GCLDevelopment.pitch_by_id("slow"), GCLDevelopment.weather_by_id("sunny"), "Fast")
	_check(float(slow.get("boundary_mult", 1.0)) < 1.0,
		"dev: slow outfield reduces boundaries as described")
	var oc: Dictionary = GCLDevelopment.condition_mods(
		GCLDevelopment.pitch_by_id("flat"), GCLDevelopment.weather_by_id("overcast"), "Fast")
	_check(float(oc.get("wicket_mult", 1.0)) > 1.0,
		"dev: overcast boosts swing wicket-taking as described")
	_check("spill" in str(GCLDevelopment.weather_by_id("humid").get("desc", "")).to_lower(),
		"dev: humid description names the fielding effect")
	# --- 19. Real match stats: green pitch raises the pace wicket rate.
	var w_green: float = _cond_wicket_rate("green", "sunny", "Fast", 31337)
	var w_flat: float = _cond_wicket_rate("flat", "sunny", "Fast", 31337)
	_check(w_green > w_flat,
		"dev: green pitch raises pace wicket rate in real balls (%0.3f > %0.3f)" % [w_green, w_flat])
	var b_slow: float = _cond_boundary_rate("slow", "sunny", 42424)
	var b_flat: float = _cond_boundary_rate("flat", "sunny", 42424)
	_check(b_slow < b_flat,
		"dev: slow outfield lowers the boundary rate in real balls (%0.3f < %0.3f)" % [b_slow, b_flat])
	# --- 20. Tournament lock state + progress persistence.
	Save.reset_game()
	var unlocked: Array = Save.data["career"].get("unlocked", [])
	_check(unlocked.has("soomra_colony") and not unlocked.has("mithi"),
		"dev: later tournaments are locked until earlier stages complete")
	CareerA.record_tournament_match("soomra_cup", true)
	var rnd: int = int(CareerA.tournament_state("soomra_cup").get("round", -1))
	_check(rnd == 1, "dev: tournament win advances the round (got %d)" % rnd)
	Save.save_game()
	Save.load_game()
	_check(int(CareerA.tournament_state("soomra_cup").get("round", -1)) == rnd,
		"dev: tournament progress survives save/load")
	CareerA.reset_tournament("soomra_cup")
	_check(int(CareerA.tournament_state("soomra_cup").get("round", -1)) == 0,
		"dev: tournament reset starts a fresh run")
	# --- 21. Old-save migration fills development fields safely.
	Save.reset_game()
	Save.data["team"] = GCLPlayers.make_starter_team("Legacy", 0)
	Save.data["career"].erase("dev_migrated")
	CareerA.ensure_development_migrated()
	_check(bool(Save.data["career"].get("dev_migrated", false)),
		"dev: migration marks dev_migrated complete")
	var lu: Dictionary = CareerA.user_player()
	_check(float(lu.get("form", -1.0)) == 0.5 and int(lu.get("fitness", -1)) == 90
		and str(lu.get("role", "")) == "Batter" and str(lu.get("tactical", "")) == "balanced",
		"dev: legacy player gets safe default dev fields")
	_check(int(lu["batting"]) == 58,
		"dev: migration never rewrites base attributes")
	# --- 22. Legacy player dicts without dev keys are handled, not crashed.
	var legacy: Dictionary = {"id": "lx", "batting": 50}
	GCLDevelopment.ensure_player_dev(legacy)
	_check(str(legacy.get("role", "")) == "Batter" and float(legacy.get("form", -1.0)) == 0.5,
		"dev: bare legacy dict migrates without errors")
	_check(str(GCLDevelopment.injury_label(legacy)) == "",
		"dev: unmigrated players show no injury label")

	# --- 23. build_match_config: user gets effective stats; order persists.
	_setup_selection_team()
	CareerA.ensure_development_migrated()
	var cu: Dictionary = CareerA.user_player()
	cu["form"] = 0.9
	var cstage: Dictionary = CareerA.current_stage()
	var crng := GCLRng.new(555)
	var ccfg: Dictionary = GCLUI.build_match_config("1v1", "NORMAL", cstage, crng, {})
	var cfound := false
	for cp in ccfg["player_team"]:
		if cp is Dictionary and bool(cp.get("is_user", false)):
			cfound = true
			_check(int(cp["batting"]) > int(cu["batting"]),
				"dev: match config uses effective (form-boosted) stats for the user")
	_check(cfound, "dev: user player present in match config (user control retained)")
	_check((Save.data["lineup"] as Array).size() == (Save.data["team"] as Array).size(),
		"dev: role-based batting order persisted to the save")
	_check(ccfg.has("pitch") and ccfg.has("weather"),
		"dev: match config carries pitch and weather")
