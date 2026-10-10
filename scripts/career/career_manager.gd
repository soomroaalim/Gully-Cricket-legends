extends Node
## Autoload: Career. Stages, unlocking, tournaments, random events.

const StagesData = preload("res://scripts/data/stages.gd")
const EventsData = preload("res://scripts/data/events.gd")
const Selection = preload("res://scripts/career/selection.gd")
const TiersData = preload("res://scripts/data/tiers.gd")


func _ready() -> void:
	ensure_selection_migrated()


# ------------------------------------------------- v2.0 selection ---------

## Safe migration for pre-v2.0 saves: _merge() fills selection defaults, then
## this grandfathers established careers to MAIN_XI so no progress is lost.
## Brand-new saves (no team, no matches) start as RESERVE. Runs once.
func ensure_selection_migrated() -> void:
	var career: Dictionary = SaveSystem.data["career"]
	var sel: Dictionary = career.get("selection", {})
	if bool(sel.get("migrated", false)):
		return
	sel["migrated"] = true
	var had_progress: bool = int(SaveSystem.data["stats"].get("matches", 0)) > 0 \
		or not SaveSystem.data.get("team", []).is_empty()
	if had_progress:
		sel["status"] = "MAIN_XI"
		sel["selection_chance"] = 0.50
	else:
		sel["status"] = "RESERVE"
		sel["selection_chance"] = Selection.BASE_CHANCE
	career["selection"] = sel
	SaveSystem.save_game()


func sel() -> Dictionary:
	return SaveSystem.data["career"].get("selection", {})


func selection_status() -> String:
	return str(sel().get("status", "RESERVE"))


## READ-ONLY. The stored chance is recomputed only inside record_*_match().
## Screens must call this — never recompute on open.
func selection_chance() -> float:
	return clampf(float(sel().get("selection_chance", Selection.BASE_CHANCE)), 0.0, 1.0)


func user_player() -> Dictionary:
	for p in SaveSystem.data.get("team", []):
		if p is Dictionary and bool(p.get("is_user", false)):
			return p
	return {}


func _user_id() -> String:
	return str(user_player().get("id", ""))


## Factors for the selection model, from real data only.
func _selection_factors() -> Dictionary:
	var u: Dictionary = user_player()
	var form: float = Selection.recent_form(sel().get("form", []))
	var ability: float = clampf(float(u.get("overall", 50)) / 99.0, 0.0, 1.0)
	var xi_roles: Array = []
	for pid in SaveSystem.data.get("lineup", []):
		for p in SaveSystem.data.get("team", []):
			if p is Dictionary and str(p.get("id", "")) == str(pid):
				xi_roles.append(str(p.get("role", "")))
				break
	var role_fit: float = Selection.role_fit(str(u.get("role", "Batter")), xi_roles)
	var tier: Dictionary = TiersData.by_id(str(SaveSystem.data["career"].get("ladder", {}).get("tier", "colony")))
	var tier_factor: float = float(tier.get("tier_factor", 0.5))
	return {"form": form, "ability": ability, "role_fit": role_fit, "tier_factor": tier_factor}


## Recompute the stored chance. ONLY called from record_*_match() — never
## from UI code, so the chance can never be rerolled by opening a screen.
func _recompute_chance() -> float:
	var c: float = Selection.compute_chance(_selection_factors())
	SaveSystem.data["career"]["selection"]["selection_chance"] = c
	return c


## Seeded selection draw. The seed derives from the player's id and how many
## selection matches they have played, so the same inputs always decide the
## same way; the roll itself is the documented random element.
func _selection_draw() -> bool:
	var n: int = sel().get("reserve_matches", []).size() + sel().get("mainxi_matches", 0)
	var seed: int = absi(hash(_user_id() + ":sel:" + str(n)))
	var rng := GCLRng.new(seed)
	return Selection.draw_selection(selection_chance(), rng.next())


func _push_form(score: float) -> void:
	var form: Array = sel().get("form", [])
	form.append(score)
	while form.size() > 5:
		form.pop_front()
	SaveSystem.data["career"]["selection"]["form"] = form


## Reserve match finished (real playable match). Records the user's actual
## performance, updates form + chance, confers eligibility, and runs the
## manager's selection draw. Returns a summary for the result screen.
func record_reserve_match(perf: Dictionary, won: bool) -> Dictionary:
	var s: Dictionary = SaveSystem.data["career"]["selection"]
	var score: float = Selection.performance_score(perf)
	_push_form(score)
	var rec: Dictionary = {
		"runs": int(perf.get("runs", 0)), "balls": int(perf.get("balls_faced", 0)),
		"wickets": int(perf.get("wickets", 0)),
		"conceded": int(perf.get("runs_conceded", 0)),
		"score": score, "won": won,
	}
	var hist: Array = s.get("reserve_matches", [])
	hist.push_front(rec)
	while hist.size() > 10:
		hist.pop_back()
	s["reserve_matches"] = hist
	if str(s.get("status", "RESERVE")) == "RESERVE":
		s["status"] = "DEBUT_ELIGIBLE"
	_recompute_chance()
	var selected: bool = _selection_draw()
	var u: Dictionary = user_player()
	if selected:
		s["status"] = "SELECTED_FOR_DEBUT"
		s["debut_announced"] = false
	s["feedback"] = Selection.feedback_for(_selection_factors(), selected, str(u.get("name", "")))
	SaveSystem.save_game()
	return {
		"selected": selected, "status": str(s.get("status", "")),
		"chance": selection_chance(), "feedback": str(s.get("feedback", "")),
		"score": score,
	}


## Debut match finished. The debut is the milestone: the player joins the
## main XI (one match never decides retention — that is what form is for).
func record_debut_match(perf: Dictionary, won: bool) -> Dictionary:
	var s: Dictionary = SaveSystem.data["career"]["selection"]
	var score: float = Selection.performance_score(perf)
	_push_form(score)
	s["debut"] = {
		"runs": int(perf.get("runs", 0)), "balls": int(perf.get("balls_faced", 0)),
		"wickets": int(perf.get("wickets", 0)), "score": score, "won": won,
	}
	s["status"] = "MAIN_XI"
	s["feedback"] = "Debut complete — you are in the main XI. Keep performing to stay there."
	_recompute_chance()
	SaveSystem.save_game()
	return {"status": "MAIN_XI", "score": score}


## Main-XI match finished (any normal match while status is MAIN_XI).
## Sustained poor form can cost the place; a single bad match never does.
func record_mainxi_match(perf: Dictionary) -> Dictionary:
	var s: Dictionary = SaveSystem.data["career"]["selection"]
	_push_form(Selection.performance_score(perf))
	s["mainxi_matches"] = int(s.get("mainxi_matches", 0)) + 1
	_recompute_chance()
	var dropped: bool = false
	var form: Array = s.get("form", [])
	if form.size() >= 3 and Selection.recent_form(form) < 0.25:
		s["status"] = "DROPPED"
		s["feedback"] = "Dropped to the reserves after a run of poor form. Perform in reserve matches to earn your place back."
		dropped = true
	SaveSystem.save_game()
	return {"dropped": dropped, "status": str(s.get("status", ""))}


# ------------------------------------------------- v2.0 ladder -----------

func ladder_tier() -> Dictionary:
	var tid: String = str(SaveSystem.data["career"].get("ladder", {}).get("tier", "colony"))
	var t: Dictionary = TiersData.by_id(tid)
	return t if not t.is_empty() else TiersData.by_id("colony")


func promotion_checklist() -> Array:
	var tier: Dictionary = ladder_tier()
	var reqs: Array = tier.get("promotion", {}).get("requires", [])
	var s: Dictionary = sel()
	var out: Array = []
	for r in reqs:
		var rid: String = str(r.get("id", ""))
		var met: bool = false
		match rid:
			"mainxi":
				met = str(s.get("status", "")) == "MAIN_XI"
			"trophy":
				met = SaveSystem.data["career"].get("trophies", []).has("soomra_cup")
			"matches":
				met = int(s.get("mainxi_matches", 0)) >= 3
		out.append({"id": rid, "label": str(r.get("label", "")), "met": met})
	return out


func can_promote() -> bool:
	if ladder_tier().get("promotion", {}).get("next", "") == "":
		return false
	for c in promotion_checklist():
		if not bool(c.get("met", false)):
			return false
	return not promotion_checklist().is_empty()


func promote() -> bool:
	if not can_promote():
		return false
	var nxt: String = str(ladder_tier()["promotion"]["next"])
	var lad: Dictionary = SaveSystem.data["career"]["ladder"]
	lad["tier"] = nxt
	var done: Array = lad.get("promoted", [])
	done.append(nxt)
	lad["promoted"] = done
	SaveSystem.save_game()
	return true


## Cached deterministic colony teams (seeded — no save bloat).
var _colony_cache: Array = []

func colony_teams() -> Array:
	if _colony_cache.is_empty():
		_colony_cache = TiersData.generate_teams("colony", 20261010)
	return _colony_cache


func stages() -> Array:
	return StagesData.all()


func stage_by_id(sid: String) -> Dictionary:
	return StagesData.by_id(sid)


func current_stage() -> Dictionary:
	var idx: int = clampi(int(SaveSystem.data["career"].get("stage_index", 0)), 0, stages().size() - 1)
	return stages()[idx]


func is_unlocked(sid: String) -> bool:
	return SaveSystem.data["career"]["unlocked"].has(sid)


func is_completed(sid: String) -> bool:
	return SaveSystem.data["career"]["completed"].has(sid)


func tournament_state(tid: String) -> Dictionary:
	var t: Dictionary = SaveSystem.data["career"]["tournaments"].get(tid, {})
	if t.is_empty():
		return {"round": 0, "wins": 0}
	return t


func _stage_for_tournament(tid: String) -> Dictionary:
	for s in stages():
		if str(s["tournament"].get("id", "")) == tid:
			return s
	return {}


func record_tournament_match(tid: String, won: bool) -> Dictionary:
	var stage: Dictionary = _stage_for_tournament(tid)
	if stage.is_empty():
		return {"champion": false, "next_round_name": "", "eliminated": false}
	var rounds: Array = stage["tournament"]["rounds"]
	var ts: Dictionary = tournament_state(tid)
	var round_idx: int = int(ts.get("round", 0))
	if not won:
		# Losing never destroys progress: retry the same round.
		SaveSystem.save_game()
		return {"champion": false, "next_round_name": str(rounds[round_idx]), "eliminated": false}
	round_idx += 1
	var champion: bool = round_idx >= rounds.size()
	ts["round"] = round_idx
	ts["wins"] = int(ts.get("wins", 0)) + 1
	SaveSystem.data["career"]["tournaments"][tid] = ts
	SaveSystem.save_game()
	var next_name: String = "" if champion else str(rounds[round_idx])
	return {"champion": champion, "next_round_name": next_name, "eliminated": false}


func on_tournament_won(stage_id: String) -> Dictionary:
	var stage: Dictionary = stage_by_id(stage_id)
	var coins_r: int = 0
	var xp_r: int = 0
	if not stage.is_empty():
		coins_r = int(stage["tournament"].get("prize", 0))
		xp_r = int(stage["tournament"].get("prize_xp", 0))
		Economy.add_coins(coins_r, "tournament")
		Economy.add_xp(xp_r)
		var tid: String = str(stage["tournament"].get("id", ""))
		if tid != "" and not SaveSystem.data["career"]["trophies"].has(tid):
			SaveSystem.data["career"]["trophies"].append(tid)
		Economy.unlock_achievement("first_trophy")
		if stage_id == "championship":
			Economy.unlock_achievement("champion")
		complete_stage(stage_id)
	SaveSystem.save_game()
	return {"coins": coins_r, "xp": xp_r}


func complete_stage(sid: String) -> Dictionary:
	var career: Dictionary = SaveSystem.data["career"]
	var first_time: bool = not career["completed"].has(sid)
	if first_time:
		career["completed"].append(sid)
	var stage: Dictionary = stage_by_id(sid)
	var unlocked_next: bool = false
	var coins_r: int = 0
	if not stage.is_empty():
		var next_idx: int = int(stage.get("index", 0)) + 1
		if next_idx < stages().size():
			var next_id: String = str(stages()[next_idx].get("id", ""))
			if not career["unlocked"].has(next_id):
				career["unlocked"].append(next_id)
				unlocked_next = true
			career["stage_index"] = maxi(int(career.get("stage_index", 0)), next_idx)
		if first_time:
			coins_r = int(stage.get("unlock_reward", 0))
			if coins_r > 0:
				Economy.add_coins(coins_r, "stage_unlock")
	SaveSystem.save_game()
	return {"unlocked_next": unlocked_next, "coins": coins_r}


func maybe_event(rng: GCLRng) -> Dictionary:
	var events: Array = EventsData.all()
	if events.is_empty():
		return {}
	if rng.next() > 0.25:
		return {}
	var seen: Array = SaveSystem.data["career"]["events_seen"]
	var last: String = str(seen.back()) if not seen.is_empty() else ""
	var pick: Dictionary = events[rng.int_range(0, events.size() - 1)]
	if str(pick.get("id", "")) == last and events.size() > 1:
		pick = events[rng.int_range(0, events.size() - 1)]
	return pick


func add_active_effect(key: String) -> void:
	var eff: Array = SaveSystem.data["career"]["active_effects"]
	if not eff.has(key):
		eff.append(key)
	SaveSystem.save_game()


func active_effects() -> Array:
	return SaveSystem.data["career"]["active_effects"]


func clear_active_effect(key: String) -> void:
	var eff: Array = SaveSystem.data["career"]["active_effects"]
	eff.erase(key)
	SaveSystem.save_game()
