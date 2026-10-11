extends Node
## Autoload: Career. Stages, unlocking, tournaments, random events.

const StagesData = preload("res://scripts/data/stages.gd")
const Selection = preload("res://scripts/career/selection.gd")
const TiersData = preload("res://scripts/data/tiers.gd")


func _ready() -> void:
	ensure_selection_migrated()
	ensure_development_migrated()
	ensure_events_migrated()


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


## Public read of the selection factors (for the comparison insight UI).
## Does NOT recompute or store the chance.
func selection_factors() -> Dictionary:
	return _selection_factors()


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
	return _selection_factors_v3_extra({"form": form, "ability": ability, "role_fit": role_fit, "tier_factor": tier_factor})


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
	advance_day()
	var s: Dictionary = SaveSystem.data["career"]["selection"]
	var score: float = Selection.performance_score(perf)
	_push_form(score)
	_sync_user_form()
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
	_post_match_injury()
	SaveSystem.save_game()
	return {
		"selected": selected, "status": str(s.get("status", "")),
		"chance": selection_chance(), "feedback": str(s.get("feedback", "")),
		"score": score,
	}


## Debut match finished. The debut is the milestone: the player joins the
## main XI (one match never decides retention — that is what form is for).
func record_debut_match(perf: Dictionary, won: bool) -> Dictionary:
	advance_day()
	var s: Dictionary = SaveSystem.data["career"]["selection"]
	var score: float = Selection.performance_score(perf)
	_push_form(score)
	_sync_user_form()
	s["debut"] = {
		"runs": int(perf.get("runs", 0)), "balls": int(perf.get("balls_faced", 0)),
		"wickets": int(perf.get("wickets", 0)), "score": score, "won": won,
	}
	s["status"] = "MAIN_XI"
	s["feedback"] = "Debut complete — you are in the main XI. Keep performing to stay there."
	_recompute_chance()
	_post_match_injury()
	SaveSystem.save_game()
	return {"status": "MAIN_XI", "score": score}


## Main-XI match finished (any normal match while status is MAIN_XI).
## Sustained poor form can cost the place; a single bad match never does.
func record_mainxi_match(perf: Dictionary) -> Dictionary:
	advance_day()
	var s: Dictionary = SaveSystem.data["career"]["selection"]
	_push_form(Selection.performance_score(perf))
	_sync_user_form()
	s["mainxi_matches"] = int(s.get("mainxi_matches", 0)) + 1
	_recompute_chance()
	var dropped: bool = false
	var form: Array = s.get("form", [])
	if form.size() >= 3 and Selection.recent_form(form) < 0.25:
		s["status"] = "DROPPED"
		s["feedback"] = "Dropped to the reserves after a run of poor form. Perform in reserve matches to earn your place back."
		dropped = true
	_post_match_injury()
	SaveSystem.save_game()
	return {"dropped": dropped, "status": str(s.get("status", ""))}


# ------------------------------------------------- v3.0 development ------

## Safe migration for pre-v3.0 saves: fills per-player development fields
## (form, fitness, injury, tactical, practice) with neutral defaults.
## _merge() cannot do this because team is an array. Runs once.
func ensure_development_migrated() -> void:
	var career: Dictionary = SaveSystem.data["career"]
	if bool(career.get("dev_migrated", false)):
		return
	for p in SaveSystem.data.get("team", []):
		if p is Dictionary:
			GCLDevelopment.ensure_player_dev(p)
	career["dev_migrated"] = true
	SaveSystem.save_game()


## Deterministic career clock. NEVER the device clock.
func career_day() -> int:
	return int(SaveSystem.data["career"].get("career_day", 1))


## Advance one career day: ticks injury recovery. Called after every match
## played and by rest_day(). Practice sessions reset via day-keying.
func advance_day() -> void:
	var c: Dictionary = SaveSystem.data["career"]
	c["career_day"] = int(c.get("career_day", 1)) + 1
	var u: Dictionary = user_player()
	if not u.is_empty():
		var inj: Dictionary = GCLDevelopment.injury_of(u)
		if not inj.is_empty():
			var res: Dictionary = GCLDevelopment.tick_injury(inj)
			u["injury"] = inj
			if bool(res.get("recovered", false)):
				_on_injury_recovered(u)


func _on_injury_recovered(u: Dictionary) -> void:
	var prev: String = str(GCLDevelopment.injury_of(u).get("_prev_status", ""))
	u["injury"] = {}
	u["fitness"] = maxi(int(u.get("fitness", 90)), 70)
	if prev != "" and prev in Selection.STATUSES:
		SaveSystem.data["career"]["selection"]["status"] = prev
	SaveSystem.data["career"]["selection"]["feedback"] = \
		"You have recovered and are available for selection again."


## Rest: advance a day without playing. Restores fitness. The honest way to
## recover from injury — no device-clock manipulation, no paid skips.
func rest_day() -> Dictionary:
	advance_day()
	var u: Dictionary = user_player()
	var gained: int = 0
	if not u.is_empty():
		var before: int = int(u.get("fitness", 90))
		u["fitness"] = mini(100, before + GCLDevelopment.FITNESS_REST_GAIN)
		gained = int(u["fitness"]) - before
	SaveSystem.save_game()
	# v4.0: resting is a career-appropriate moment for new events to surface.
	check_events()
	return {"day": career_day(), "fitness_gain": gained,
		"injury": GCLDevelopment.injury_label(user_player())}


## The user's player dict (live reference into the save — mutations persist).
func user_dict() -> Dictionary:
	return user_player()


func user_available() -> bool:
	var u: Dictionary = user_player()
	if u.is_empty():
		return false
	return GCLDevelopment.is_available(u)


func user_injury_label() -> String:
	return GCLDevelopment.injury_label(user_player())


## Practice budget for today. Keyed by career day — reopening the app never
## resets it, and only a new career day (match or Rest) refreshes it.
func practice_state() -> Dictionary:
	var c: Dictionary = SaveSystem.data["career"]
	var pr: Dictionary = c.get("practice", {"day": 0, "sessions": 0})
	if int(pr.get("day", 0)) != career_day():
		# New day: daily budget refreshes; the same-day legendary bonus
		# expires, but the legendary training history is kept.
		pr = {"day": career_day(), "sessions": 0, "bonus": 0,
			"legend_sessions": pr.get("legend_sessions", [])}
		c["practice"] = pr
	var done: int = int(pr.get("sessions", 0))
	var bonus: int = int(pr.get("bonus", 0))
	return {"sessions_left": maxi(0, GCLDevelopment.SESSIONS_PER_DAY - done) + bonus,
		"sessions_done": done, "sessions_total": GCLDevelopment.SESSIONS_PER_DAY,
		"bonus": bonus}


## Run one practice session. Applies role-weighted gains, form bump, fitness,
## history, and the daily budget. Returns {ok, message, ...}.
func do_practice(activity: String) -> Dictionary:
	var st: Dictionary = practice_state()
	if int(st["sessions_left"]) <= 0:
		return {"ok": false,
			"message": "No training sessions left today. Play a match or Rest to start a new day."}
	var u: Dictionary = user_player()
	if u.is_empty():
		return {"ok": false, "message": "No player found."}
	var res: Dictionary = GCLDevelopment.practice_result(activity, u)
	if str(res.get("blocked_reason", "")) != "":
		return {"ok": false, "message": str(res["blocked_reason"])}
	var gains: Dictionary = res.get("gains", {})
	var parts: Array[String] = []
	for sk in gains.keys():
		var s: String = str(sk)
		u[s] = mini(99, int(u.get(s, 50)) + int(gains[sk]))
		parts.append("+%d %s" % [int(gains[sk]), s.capitalize()])
	if int(res.get("fitness_gain", 0)) > 0:
		u["fitness"] = mini(100, int(u.get("fitness", 90)) + int(res["fitness_gain"]))
		parts.append("+%d Fitness" % int(res["fitness_gain"]))
	u["overall"] = GCLConfig.overall_of(u)
	u["form"] = clampf(float(u.get("form", 0.5)) + float(res.get("form_bump", 0.0)), 0.0, 1.0)
	_push_form(0.6)
	_sync_user_form()
	var hist: Array = u.get("practice", [])
	hist.push_front({"day": career_day(), "activity": activity, "gains": gains})
	while hist.size() > 10:
		hist.pop_back()
	u["practice"] = hist
	var c: Dictionary = SaveSystem.data["career"]
	var pr: Dictionary = c.get("practice", {"day": career_day(), "sessions": 0})
	# v4.0: legendary bonus sessions are consumed FIRST and never touch the
	# daily budget — the UI always labels which kind was used.
	var used_bonus: bool = int(pr.get("bonus", 0)) > 0
	if used_bonus:
		pr["bonus"] = int(pr["bonus"]) - 1
	else:
		pr["sessions"] = int(pr.get("sessions", 0)) + 1
	pr["day"] = career_day()
	c["practice"] = pr
	SaveSystem.save_game()
	var label: String = str(GCLDevelopment.PRACTICE_ACTIVITIES.get(activity, {}).get("label", activity))
	var msg: String = "%s complete: %s." % [label, ", ".join(parts)]
	if used_bonus:
		msg += " (⭐ bonus session — daily budget untouched)"
	return {"ok": true, "message": msg, "gains": gains, "used_bonus": used_bonus}


## Keep the player's form field in sync with the selection form history.
func _sync_user_form() -> void:
	var u: Dictionary = user_player()
	if u.is_empty():
		return
	u["form"] = Selection.recent_form(sel().get("form", []))


## Post-match injury roll + fitness cost. Formula documented in
## GCLDevelopment.roll_injury. Never while an injury is already active.
## Returns the new injury dict or {} (also when not injured).
func _post_match_injury() -> Dictionary:
	var u: Dictionary = user_player()
	if u.is_empty():
		return {}
	if GCLDevelopment.is_injured(u):
		return GCLDevelopment.injury_of(u)
	u["fitness"] = maxi(0, int(u.get("fitness", 90)) - GCLDevelopment.FITNESS_MATCH_COST)
	var n: int = int(SaveSystem.data["stats"].get("matches", 0))
	var rng := GCLRng.new(absi(hash(str(u.get("id", "")) + ":inj:" + str(n))))
	var inj: Dictionary = GCLDevelopment.roll_injury(
		int(u.get("fitness", 90)), rng.next(), rng.next(), rng.next())
	if inj.is_empty():
		return {}
	inj["_prev_status"] = str(sel().get("status", "RESERVE"))
	u["injury"] = inj
	var tier: Dictionary = GCLDevelopment.INJURY_TIERS[str(inj.get("severity", "minor"))]
	if not bool(tier.get("available", true)):
		SaveSystem.data["career"]["selection"]["status"] = "INJURED"
		SaveSystem.data["career"]["selection"]["feedback"] = \
			"%s — unavailable for %d days. Rest to recover." % [
				str(tier.get("label", "Injured")), int(inj.get("days_left", 0))]
	return inj


## v3.0: selection factors gain fitness + injury availability (read-only).
func _selection_factors_v3_extra(f: Dictionary) -> Dictionary:
	var u: Dictionary = user_player()
	f["fitness"] = clampf(float(u.get("fitness", 90)) / 100.0, 0.0, 1.0)
	f["injured"] = not GCLDevelopment.is_available(u)
	return f


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


## v3.0: reset a tournament for a fresh run (used by the tournament map's
## "New tournament" action on completed tournaments).
func reset_tournament(tid: String) -> void:
	SaveSystem.data["career"]["tournaments"][tid] = {"round": 0, "wins": 0}
	SaveSystem.save_game()


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


## ------------------------------------------------- v4.0 career events -------
## Six offline career events (rain, team challenge, rival team, target
## challenge, tournament invitation, legendary training) on a deterministic
## scheduler. At most ONE major event is pending at a time; every
## accept/decline/outcome is persisted; loading a save never rerolls.
## Replaces the v1.0 passive-buff event picker.

## Safe migration for pre-v4.0 saves: fills the events state, creates a
## stable per-save seed (persisted, never rerolled), and generates the
## persistent rival records deterministically from that seed.
func ensure_events_migrated() -> void:
	var career: Dictionary = SaveSystem.data["career"]
	if int(career.get("save_seed", 0)) == 0:
		career["save_seed"] = absi(hash(
			str(SaveSystem.data.get("player_name", "player")) + ":" + str(GCLRng.random_seed())))
	if not career.has("events") or not (career["events"] is Dictionary):
		career["events"] = {}
	var ev: Dictionary = career["events"]
	for k in GCLCareerEvents.default_events_state().keys():
		if not ev.has(k):
			ev[k] = GCLCareerEvents.default_events_state()[k]
	var rivals: Dictionary = ev.get("rivals", {})
	for rd in GCLCareerEvents.rival_defs():
		var rid: String = str(rd["id"])
		if not rivals.has(rid):
			rivals[rid] = {
				"name": str(rd["name"]), "color": str(rd["color"]),
				"base_lo": int(rd["base_lo"]), "base_hi": int(rd["base_hi"]),
				"wins": 0, "losses": 0, "encounters": 0, "announced": false,
			}
	ev["rivals"] = rivals
	# v4.0 practice bonus keys (bonus stacks ON TOP of the daily budget).
	var pr: Dictionary = career.get("practice", {"day": 0, "sessions": 0})
	if not pr.has("bonus"):
		pr["bonus"] = 0
	if not pr.has("legend_sessions"):
		pr["legend_sessions"] = []
	career["practice"] = pr
	# v4.0 added the Karachi stage (index 5). A save that had already reached
	# the old final index keeps pointing at the championship, now index 6.
	if "championship" in career.get("completed", []) \
			and int(career.get("stage_index", 0)) < 6:
		career["stage_index"] = 6
	SaveSystem.save_game()


func _event_ctx() -> Dictionary:
	return {
		"stage": current_stage(),
		"tier_index": TiersData.index_of(str(ladder_tier().get("id", "colony"))),
		"invite_tournaments": _invite_tournaments(),
		"state_history": (SaveSystem.data["career"]["events"] as Dictionary).get("history", []),
	}


## Tournaments the player can actually be invited to: unlocked stages whose
## trophy has not been won yet. Entry requirements are hard-enforced by
## construction (only unlocked stages appear).
func _invite_tournaments() -> Array:
	var out: Array = []
	var trophies: Array = SaveSystem.data["career"].get("trophies", [])
	for stage in stages():
		if not (stage is Dictionary):
			continue
		var sid: String = str(stage.get("id", ""))
		var t: Dictionary = stage.get("tournament", {})
		var tid: String = str(t.get("id", ""))
		if tid == "" or trophies.has(tid) or not is_unlocked(sid):
			continue
		var rounds: Array = t.get("rounds", [])
		out.append({
			"tid": tid,
			"name": str(t.get("name", "Tournament")),
			"venue": str(stage.get("name", "")),
			"difficulty": str(stage.get("difficulty", "NORMAL")),
			"requirements": "Reach %s (unlocked)" % str(stage.get("name", "")),
			"teams": int(pow(2, rounds.size())),
			"format": " · ".join(rounds) if not rounds.is_empty() else "Knockout",
			"prize": int(t.get("prize", 0)),
			"prize_xp": int(t.get("prize_xp", 0)),
		})
	return out


## Run the scheduler (at most once per career day). Returns the newly
## scheduled event or {}. Called on Career Hub entry, after matches, on Rest.
func check_events() -> Dictionary:
	ensure_events_migrated()
	var career: Dictionary = SaveSystem.data["career"]
	var ev: Dictionary = career["events"]
	var matches: int = int(SaveSystem.data.get("stats", {}).get("matches", 0))
	var new_ev: Dictionary = GCLCareerEvents.check(
		ev, career_day(), matches, int(career.get("save_seed", 1)), _event_ctx())
	if not new_ev.is_empty():
		SaveSystem.save_game()
	return new_ev


func pending_event() -> Dictionary:
	ensure_events_migrated()
	return SaveSystem.data["career"]["events"].get("pending", {})


func event_history() -> Array:
	ensure_events_migrated()
	return SaveSystem.data["career"]["events"].get("history", [])


func event_reputation() -> int:
	ensure_events_migrated()
	return int(SaveSystem.data["career"]["events"].get("reputation", 0))


func _archive_event(ev: Dictionary, outcome: String) -> void:
	var events: Dictionary = SaveSystem.data["career"]["events"]
	ev["state"] = outcome
	ev["resolved_day"] = career_day()
	var hist: Array = events.get("history", [])
	hist.push_front(ev)
	while hist.size() > GCLCareerEvents.MAX_HISTORY:
		hist.pop_back()
	events["history"] = hist
	events["pending"] = {}
	SaveSystem.save_game()


func decline_event(eid: String) -> bool:
	var ev: Dictionary = pending_event()
	if ev.is_empty() or str(ev.get("id", "")) != eid:
		return false
	_archive_event(ev, "declined")
	return true


## Accept a pending event. Match-type events stay "accepted" until the match
## is played (record_event_match resolves them); instant events (legend,
## invitation) resolve immediately.
func accept_event(eid: String) -> Dictionary:
	var ev: Dictionary = pending_event()
	if ev.is_empty() or str(ev.get("id", "")) != eid:
		return {}
	var etype: String = str(ev.get("type", ""))
	if etype == "legend":
		return grant_legend_bonus(eid)
	if etype == "invitation":
		return accept_invitation(eid)
	ev["state"] = "accepted"
	SaveSystem.save_game()
	return ev


## Idempotent reward grant: the same event can never pay out twice, even
## across save/load. Returns true only when the grant actually happened.
func grant_event_reward(eid: String, coins_r: int, xp_r: int) -> bool:
	var events: Dictionary = SaveSystem.data["career"]["events"]
	var ev: Dictionary = events.get("pending", {})
	if ev.is_empty() or str(ev.get("id", "")) != eid:
		for h in (events.get("history", []) as Array):
			if h is Dictionary and str((h as Dictionary).get("id", "")) == eid:
				ev = h
				break
	if ev.is_empty() or bool(ev.get("reward_claimed", false)):
		return false
	var claim_id: String = str(ev.get("id", ""))
	var claimed: Array = events.get("claimed", [])
	if claimed.has(claim_id):
		return false
	ev["reward_claimed"] = true
	claimed.append(claim_id)
	events["claimed"] = claimed
	if coins_r > 0:
		Economy.add_coins(coins_r, "event")
	if xp_r > 0:
		Economy.add_xp(xp_r)
	SaveSystem.save_game()
	return true


## Event match finished (team challenge / rival / target challenge) with the
## user's REAL per-player performance. Advances a day, moves form, rerolls
## nothing about selection status (side events never change selection), and
## resolves the pending event with its outcome + idempotent rewards.
func record_event_match(event_id: String, perf: Dictionary, won: bool, result: Dictionary) -> Dictionary:
	var out: Dictionary = {"event_id": event_id, "resolved": false}
	var ev: Dictionary = pending_event()
	if ev.is_empty() or str(ev.get("id", "")) != event_id:
		return out
	var etype: String = str(ev.get("type", ""))
	var data: Dictionary = ev.get("data", {})
	advance_day()
	var score: float = Selection.performance_score(perf)
	_push_form(score)
	_sync_user_form()
	_recompute_chance()
	_post_match_injury()
	var coins_r: int = 0
	var xp_r: int = 0
	var rep_gain: int = 0
	var success: bool = won
	var detail: String = ""
	var rematch: bool = false
	if etype == "target":
		var e: Dictionary = {
			"player_runs": int(result.get("player_runs", 0)),
			"player_wickets": int(result.get("player_wickets", 0)),
			"player_won": won,
			"sixes": int((result.get("perf", {}) as Dictionary).get("sixes", 0)),
			"fours": int((result.get("perf", {}) as Dictionary).get("fours", 0)),
			"wickets_taken": int((result.get("perf", {}) as Dictionary).get("wickets", 0)),
			"balls_bowled": int(perf.get("balls_bowled", 0)),
			"runs_conceded": int(perf.get("runs_conceded", 0)),
		}
		var er: Dictionary = GCLCareerEvents.evaluate_target(data, e)
		success = bool(er.get("success", false))
		detail = str(er.get("detail", ""))
		if success:
			coins_r = int(ev.get("reward_coins", 0))
			xp_r = int(ev.get("reward_xp", 0))
		else:
			xp_r = 10  # participation XP for the attempt
	elif etype == "challenge_team" or etype == "rival":
		var decisive: bool = bool(data.get("decisive", false))
		if won:
			coins_r = int(ev.get("reward_coins", 0))
			xp_r = int(ev.get("reward_xp", 0))
			rep_gain = 8 if decisive else (5 if etype == "rival" else 3)
			detail = "Decisive rivalry settled!" if decisive else "Challenge won!"
		else:
			coins_r = int(round(float(ev.get("reward_coins", 0)) * 0.25))
			xp_r = 20
			rep_gain = 1
			rematch = true
			detail = "Lost — but the challengers want a rematch."
		if etype == "rival":
			record_rival_result(str(data.get("rival_id", "")), won)
	if rep_gain > 0:
		var events: Dictionary = SaveSystem.data["career"]["events"]
		events["reputation"] = int(events.get("reputation", 0)) + rep_gain
	var granted: bool = false
	if coins_r > 0 or xp_r > 0:
		granted = grant_event_reward(event_id, coins_r, xp_r)
	_archive_event(ev, "completed")
	out["resolved"] = true
	out["success"] = success
	out["type"] = etype
	out["title"] = str(ev.get("title", "Event"))
	out["detail"] = detail
	out["coins"] = coins_r if granted else 0
	out["xp"] = xp_r if granted else 0
	out["reputation_gain"] = rep_gain
	out["rematch"] = rematch
	SaveSystem.save_game()
	return out


func rival_record(rival_id: String) -> Dictionary:
	ensure_events_migrated()
	return GCLCareerEvents.rival_record(SaveSystem.data["career"]["events"], rival_id)


func all_rival_records() -> Array:
	ensure_events_migrated()
	var out: Array = []
	var rivals: Dictionary = SaveSystem.data["career"]["events"].get("rivals", {})
	for rid in rivals.keys():
		var rec: Dictionary = (rivals[rid] as Dictionary).duplicate(true)
		rec["id"] = rid
		out.append(rec)
	return out


func record_rival_result(rival_id: String, won: bool) -> void:
	var events: Dictionary = SaveSystem.data["career"]["events"]
	var rivals: Dictionary = events.get("rivals", {})
	var rec: Dictionary = rivals.get(rival_id, {})
	if rec.is_empty():
		return
	rec["encounters"] = int(rec.get("encounters", 0)) + 1
	rec["announced"] = true
	if won:
		rec["wins"] = int(rec.get("wins", 0)) + 1
	else:
		rec["losses"] = int(rec.get("losses", 0)) + 1
	rivals[rival_id] = rec
	SaveSystem.save_game()


## Legendary training: grants ONE explicitly-labeled bonus practice session
## that stacks ON TOP of the 3/day budget, and records it in history.
func grant_legend_bonus(eid: String) -> Dictionary:
	var ev: Dictionary = pending_event()
	if ev.is_empty() or str(ev.get("id", "")) != eid:
		return {}
	var leg: Dictionary = GCLCareerEvents.legend_by_id(str(ev.get("data", {}).get("legend_id", "")))
	var career: Dictionary = SaveSystem.data["career"]
	var pr: Dictionary = career.get("practice", {"day": 0, "sessions": 0})
	if int(pr.get("day", 0)) != career_day():
		pr = {"day": career_day(), "sessions": 0, "bonus": 0, "legend_sessions": pr.get("legend_sessions", [])}
	pr["bonus"] = int(pr.get("bonus", 0)) + 1
	var lhist: Array = pr.get("legend_sessions", [])
	lhist.push_front({"day": career_day(), "legend": str(leg.get("name", "Legend")),
		"speciality": str(leg.get("speciality", ""))})
	while lhist.size() > 10:
		lhist.pop_back()
	pr["legend_sessions"] = lhist
	career["practice"] = pr
	grant_event_reward(eid, 0, int(ev.get("reward_xp", 0)))
	_archive_event(ev, "completed")
	return {"legend": leg, "event": ev}


## Tournament invitation: hard-enforces entry (the tournament must still be
## an unlocked, un-won stage tournament), then routes to the REAL tournament.
func accept_invitation(eid: String) -> Dictionary:
	var ev: Dictionary = pending_event()
	if ev.is_empty() or str(ev.get("id", "")) != eid:
		return {}
	var tid: String = str(ev.get("data", {}).get("tid", ""))
	var valid: bool = false
	for t in _invite_tournaments():
		if str(t["tid"]) == tid:
			valid = true
			break
	if not valid:
		_archive_event(ev, "expired")
		return {"expired": true}
	var events: Dictionary = SaveSystem.data["career"]["events"]
	var accepted: Array = events.get("invitations_accepted", [])
	if not accepted.has(tid):
		accepted.append(tid)
	events["invitations_accepted"] = accepted
	grant_event_reward(eid, 0, int(ev.get("reward_xp", 0)))
	_archive_event(ev, "completed")
	return {"tid": tid, "event": ev}


func invitations_accepted() -> Array:
	ensure_events_migrated()
	return SaveSystem.data["career"]["events"].get("invitations_accepted", [])


## After a lost challenge, the player can request a rematch: the scheduler
## cooldown is lifted so the next check may offer a new challenge.
func request_rematch() -> void:
	ensure_events_migrated()
	var events: Dictionary = SaveSystem.data["career"]["events"]
	events["last_day"] = career_day() - GCLCareerEvents.EVENT_COOLDOWN_DAYS
	SaveSystem.save_game()


## Rain-affected matches are logged to event history (no reward, just record).
func log_rain_match(overs: int) -> void:
	ensure_events_migrated()
	var events: Dictionary = SaveSystem.data["career"]["events"]
	var hist: Array = events.get("history", [])
	hist.push_front({
		"id": "rain_d%d" % career_day(), "type": "rain",
		"icon": "🌧", "title": "Rain-affected match",
		"desc": "Rain shortened the match to %d overs." % overs,
		"state": "completed", "created_day": career_day(),
		"resolved_day": career_day(), "reward_claimed": true,
	})
	while hist.size() > GCLCareerEvents.MAX_HISTORY:
		hist.pop_back()
	events["history"] = hist
	SaveSystem.save_game()


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
