extends Node
## Autoload: Economy. Fictional coins + XP. No real money, no network.

const ShopData = preload("res://scripts/data/shop_items.gd")
const AchData = preload("res://scripts/data/achievements.gd")
const PlayersData = preload("res://scripts/data/players.gd")
const ChallengesData = preload("res://scripts/data/challenges.gd")
const Config = preload("res://scripts/core/config.gd")

const DIFF_MULT: Dictionary = {"EASY": 1.0, "NORMAL": 1.25, "HARD": 1.5, "LEGEND": 2.0}
const MODE_BASE: Dictionary = {"1v1": 40, "2v2": 60, "5v5": 100, "gully6": 100}


func coins() -> int:
	return int(SaveSystem.data.get("coins", 0))


func add_coins(n: int, _reason: String = "") -> void:
	SaveSystem.data["coins"] = coins() + n
	var stats: Dictionary = SaveSystem.data["stats"]
	stats["coins_earned"] = int(stats.get("coins_earned", 0)) + maxi(n, 0)


func spend(n: int) -> bool:
	if coins() < n:
		return false
	SaveSystem.data["coins"] = coins() - n
	SaveSystem.save_game()
	return true


func add_xp(n: int) -> int:
	var d: Dictionary = SaveSystem.data
	d["xp"] = int(d.get("xp", 0)) + n
	var levels: int = 0
	while int(d["xp"]) >= Config.xp_for_level(int(d.get("level", 1))):
		d["xp"] = int(d["xp"]) - Config.xp_for_level(int(d.get("level", 1)))
		d["level"] = int(d.get("level", 1)) + 1
		levels += 1
		_level_up_bonus()
	SaveSystem.save_game()
	return levels


func _level_up_bonus() -> void:
	for p in SaveSystem.data["team"]:
		if bool(p.get("is_user", false)):
			p["batting"] = mini(99, int(p.get("batting", 50)) + 1)
			p["bowling"] = mini(99, int(p.get("bowling", 50)) + 1)
			p["overall"] = Config.overall_of(p)


func _find_player(pid: String) -> Dictionary:
	for p in SaveSystem.data["team"]:
		if str(p.get("id", "")) == pid:
			return p
	return {}


func upgrade_cost(player: Dictionary) -> int:
	return 150 * maxi(int(player.get("level", 1)), 1)


func upgrade_player(pid: String) -> bool:
	var p: Dictionary = _find_player(pid)
	if p.is_empty():
		return false
	var cost: int = upgrade_cost(p)
	if not spend(cost):
		return false
	p["level"] = int(p.get("level", 1)) + 1
	var primary: String = "batting"
	match str(p.get("role", "Batter")):
		"Bowler":
			primary = "bowling"
		"Wicketkeeper":
			primary = "fielding"
		"AllRounder":
			p["batting"] = mini(99, int(p.get("batting", 50)) + 1)
			p["bowling"] = mini(99, int(p.get("bowling", 50)) + 1)
	if str(p.get("role", "")) != "AllRounder":
		p[primary] = mini(99, int(p.get(primary, 50)) + 2)
	var secondary: String = "fielding" if primary != "fielding" else "stamina"
	p[secondary] = mini(99, int(p.get(secondary, 50)) + 1)
	p["overall"] = Config.overall_of(p)
	SaveSystem.save_game()
	return true


func purchase(item_id: String) -> bool:
	var item: Dictionary = ShopData.by_id(item_id)
	if item.is_empty():
		return false
	var owned: Array = SaveSystem.data["equipment_owned"]
	if owned.has(item_id):
		return false
	if not spend(int(item.get("price", 0))):
		return false
	owned.append(item_id)
	var cat: String = str(item.get("category", ""))
	var equipped: Dictionary = SaveSystem.data["equipped"]
	if str(equipped.get(cat, "")) == "":
		equipped[cat] = item_id
	SaveSystem.save_game()
	return true


func equip(item_id: String) -> void:
	var item: Dictionary = ShopData.by_id(item_id)
	if item.is_empty():
		return
	if not SaveSystem.data["equipment_owned"].has(item_id):
		return
	SaveSystem.data["equipped"][str(item.get("category", ""))] = item_id
	SaveSystem.save_game()


func recruit_player(def_id: String) -> bool:
	var def: Dictionary = {}
	for r in PlayersData.recruits():
		if str(r.get("id", "")) == def_id:
			def = r
			break
	if def.is_empty():
		return false
	if int(SaveSystem.data["career"]["stage_index"]) < int(def.get("min_stage_index", 0)):
		return false
	if SaveSystem.data["team"].size() >= 11:
		return false
	if not spend(int(def.get("price", 0))):
		return false
	var p: Dictionary = PlayersData.build_recruit(def)
	SaveSystem.data["team"].append(p)
	SaveSystem.save_game()
	return true


func effective_stats(p: Dictionary) -> Dictionary:
	var bonus: Dictionary = {"batting": 0, "bowling": 0, "fielding": 0, "speed": 0, "stamina": 0}
	for slot in SaveSystem.data["equipped"].values():
		var item: Dictionary = ShopData.by_id(str(slot))
		for k in bonus.keys():
			bonus[k] = int(bonus[k]) + int(item.get("bonus", {}).get(k, 0))
	var lvl_bonus: int = maxi(int(p.get("level", 1)) - 1, 0)
	var out: Dictionary = {}
	for k in bonus.keys():
		out[k] = mini(99, int(p.get(k, 50)) + int(bonus[k]) + lvl_bonus)
	return out


func apply_effective(p: Dictionary) -> Dictionary:
	var c: Dictionary = p.duplicate(true)
	var eff: Dictionary = effective_stats(p)
	for k in eff.keys():
		c[k] = eff[k]
	return c


func rewards_for_match(result: Dictionary, mode: String, difficulty: String) -> Dictionary:
	var base: int = int(MODE_BASE.get(mode, 100))
	var mult: float = 1.0
	if bool(result.get("player_won", false)):
		mult = 2.0
	elif bool(result.get("tied", false)):
		mult = 1.2
	else:
		mult = 0.5
	var coins_r: int = int(round(base * mult * float(DIFF_MULT.get(difficulty, 1.0))))
	var perf: Dictionary = result.get("perf", {})
	coins_r += int(perf.get("sixes", 0)) * 5 + int(perf.get("wickets", 0)) * 10
	var xp_r: int = int(round((30 + (20 if bool(result.get("player_won", false)) else 0)
		+ int(perf.get("sixes", 0)) * 2 + int(perf.get("wickets", 0)) * 3)
		* float(DIFF_MULT.get(difficulty, 1.0))))
	return {"coins": coins_r, "xp": xp_r}


func finalize_match(result: Dictionary, mode: String, difficulty: String) -> Dictionary:
	var rw: Dictionary = rewards_for_match(result, mode, difficulty)
	var coins_r: int = int(rw["coins"])
	var effects: Array = Career.active_effects() if has_node("/root/Career") else []
	if effects.has("bonus_match") and bool(result.get("player_won", false)):
		coins_r = int(round(coins_r * 1.5))
		Career.clear_active_effect("bonus_match")
	if effects.has("target_bonus") and int(result.get("player_runs", 0)) >= 20:
		coins_r += 100
		Career.clear_active_effect("target_bonus")
	result["coins"] = coins_r
	result["xp"] = int(rw["xp"])
	add_coins(coins_r, "match")
	add_xp(int(rw["xp"]))
	# Stats.
	var st: Dictionary = SaveSystem.data["stats"]
	st["matches"] = int(st.get("matches", 0)) + 1
	if bool(result.get("player_won", false)):
		st["wins"] = int(st.get("wins", 0)) + 1
	elif bool(result.get("tied", false)):
		st["ties"] = int(st.get("ties", 0)) + 1
	else:
		st["losses"] = int(st.get("losses", 0)) + 1
	var perf: Dictionary = result.get("perf", {})
	st["runs"] = int(st.get("runs", 0)) + int(result.get("player_runs", 0))
	st["sixes"] = int(st.get("sixes", 0)) + int(perf.get("sixes", 0))
	st["fours"] = int(st.get("fours", 0)) + int(perf.get("fours", 0))
	st["wickets"] = int(st.get("wickets", 0)) + int(perf.get("wickets", 0))
	st["best"] = maxi(int(st.get("best", 0)), int(result.get("player_runs", 0)))
	# Achievements.
	result["achievements_unlocked"] = []
	_check_and_unlock(result, "first_match", true)
	_check_and_unlock(result, "first_win", bool(result.get("player_won", false)))
	_check_and_unlock(result, "first_six", int(perf.get("sixes", 0)) > 0)
	_check_and_unlock(result, "big_earner", int(st.get("coins_earned", 0)) >= 5000)
	# Challenge completion.
	_check_challenge(result)
	SaveSystem.save_game()
	return result


func _check_and_unlock(result: Dictionary, aid: String, cond: bool) -> void:
	if cond and unlock_achievement(aid):
		result["achievements_unlocked"].append(aid)


func _check_challenge(result: Dictionary) -> void:
	var cid: String = str(GameState.match_config.get("challenge_id", ""))
	if cid == "":
		return
	if SaveSystem.data["challenges_done"].has(cid):
		return
	var ch: Dictionary = ChallengesData.by_id(cid)
	if ch.is_empty():
		return
	var perf: Dictionary = result.get("perf", {})
	var done: bool = false
	match str(ch.get("kind", "")):
		"score_runs":
			done = int(result.get("player_runs", 0)) >= int(ch.get("target", 999))
		"hit_sixes":
			done = int(perf.get("sixes", 0)) >= int(ch.get("target", 999))
		"take_wickets":
			done = int(perf.get("wickets", 0)) >= int(ch.get("target", 999))
		"defend_target":
			done = bool(result.get("player_won", false))
		"no_wicket_chase":
			done = bool(result.get("player_won", false)) and int(result.get("player_wickets", 99)) == 0
	if done:
		SaveSystem.data["challenges_done"].append(cid)
		add_coins(int(ch.get("coins", 0)), "challenge")
		add_xp(int(ch.get("xp", 0)))
		result["new_unlocks"].append("challenge:" + cid)
		SaveSystem.save_game()


func unlock_achievement(aid: String) -> bool:
	if SaveSystem.data["achievements"].has(aid):
		return false
	var a: Dictionary = AchData.by_id(aid)
	if a.is_empty():
		return false
	SaveSystem.data["achievements"].append(aid)
	add_coins(int(a.get("coins", 0)), "achievement")
	add_xp(int(a.get("xp", 0)))
	SaveSystem.save_game()
	return true
