class_name GCLCareerEvents
extends RefCounted
## v4.0: the six offline career events — rain, team challenge, rival team,
## target challenge, tournament invitation, legendary training.
##
## Deterministic scheduler: the event for a career day is seeded from
## (save_seed, career_day, per-type counters). At most ONE major event is
## pending at a time, per-type cooldowns apply, types never repeat back to
## back, and loading a save NEVER rerolls or duplicates an event: the
## scheduler runs at most once per career day (guarded by last_check_day).
##
## Pure logic — callers pass the events state dict, the day, and career
## context. Nothing here touches autoloads, so it is fully unit-testable.
## Persistence (accept/decline/grant/archive) lives in Career.

## Rain probability lives in GCLDevelopment.RAIN_CHANCE (used by
## pick_conditions); this file only schedules the five card-based events —
## rain itself is a per-match condition, logged to history when it hits.
const EVENT_COOLDOWN_DAYS := 2
const MAX_HISTORY := 20

const TYPES: Array[String] = ["challenge_team", "rival", "target", "invitation", "legend"]

const DIFF_MULT: Dictionary = {"EASY": 1.0, "NORMAL": 1.25, "HARD": 1.5, "LEGEND": 2.0}

const TYPE_META: Dictionary = {
	"challenge_team": {"icon": "⚔️", "name": "Team Challenge"},
	"rival": {"icon": "🔥", "name": "Rival Team"},
	"target": {"icon": "🎯", "name": "Target Challenge"},
	"invitation": {"icon": "✉️", "name": "Tournament Invitation"},
	"legend": {"icon": "🌟", "name": "Legendary Training"},
	"rain": {"icon": "🌧", "name": "Rain-Affected Match"},
}

## Fictional challenger teams (never real club names).
const CHALLENGER_NAMES: Array[String] = [
	"Tape-Ball Tigers", "Night Hawks XI", "Street Sultan XI", "Mohalla Kings",
	"Gully Gladiators", "Boundary Bashers", "Slumdog Strikers", "Alley-Oop XI",
]

const CHALLENGER_MODES: Array[String] = ["2v2", "gully6"]


## ---------------------------------------------------------------- state ---

static func default_events_state() -> Dictionary:
	return {
		"pending": {},
		"history": [],
		"counters": {},
		"claimed": [],
		"last_type": "",
		"last_day": 0,
		"last_check_day": 0,
		"rivals": {},
		"reputation": 0,
		"invitations_accepted": [],
	}


## ---------------------------------------------------------------- scheduler ---

static func _seed_for(save_seed: int, day: int) -> int:
	return absi(hash("%d:evt:%d" % [save_seed, day]))


## Runs the scheduler. Mutates `state` (pending, counters, last_*). Returns
## the newly scheduled event, or {} when nothing was scheduled. `ctx` carries
## "stage" (current stage dict), "tier_index" (int) and "invite_tournaments"
## (Array of playable-tournament dicts).
static func check(state: Dictionary, day: int, matches_played: int, save_seed: int, ctx: Dictionary) -> Dictionary:
	if not (state.get("pending", {}) as Dictionary).is_empty():
		return {}
	if int(state.get("last_check_day", 0)) >= day:
		return {}
	state["last_check_day"] = day
	# Cooldown only applies once an event has actually been scheduled
	# (last_day == 0 means "never", not "day zero").
	if int(state.get("last_day", 0)) > 0 \
			and day - int(state.get("last_day", 0)) < EVENT_COOLDOWN_DAYS:
		return {}
	var rng := GCLRng.new(_seed_for(save_seed, day))
	var pool: Array = _eligible_types(state, matches_played, ctx)
	if pool.is_empty():
		return {}
	var etype: String = _weighted_pick(rng, pool)
	var ev: Dictionary = _build(etype, rng, state, ctx, day)
	if ev.is_empty():
		return {}
	state["pending"] = ev
	state["last_day"] = day
	state["last_type"] = etype
	var counters: Dictionary = state.get("counters", {})
	counters[etype] = int(counters.get(etype, 0)) + 1
	state["counters"] = counters
	return ev


static func _eligible_types(state: Dictionary, matches_played: int, ctx: Dictionary) -> Array:
	var last: String = str(state.get("last_type", ""))
	var invites: Array = ctx.get("invite_tournaments", [])
	var defs: Array = [
		{"type": "challenge_team", "weight": 2, "ok": matches_played >= 2},
		{"type": "rival", "weight": 2, "ok": matches_played >= 4},
		{"type": "target", "weight": 3, "ok": matches_played >= 1},
		{"type": "invitation", "weight": 1, "ok": matches_played >= 5 and not invites.is_empty()},
		{"type": "legend", "weight": 2, "ok": matches_played >= 1},
	]
	var pool: Array = []
	for d in defs:
		if bool(d["ok"]) and str(d["type"]) != last:
			pool.append(d)
	if pool.is_empty():
		# Only the last type is eligible — allow it rather than stalling.
		for d in defs:
			if bool(d["ok"]):
				pool.append(d)
	return pool


static func _weighted_pick(rng: GCLRng, pool: Array) -> String:
	var total: int = 0
	for d in pool:
		total += int(d["weight"])
	var roll: int = rng.int_range(0, maxi(total - 1, 0))
	for d in pool:
		roll -= int(d["weight"])
		if roll < 0:
			return str(d["type"])
	return str(pool[0]["type"])


static func _build(etype: String, rng: GCLRng, state: Dictionary, ctx: Dictionary, day: int) -> Dictionary:
	var meta: Dictionary = TYPE_META.get(etype, {})
	var n: int = int((state.get("counters", {}) as Dictionary).get(etype, 0))
	var ev: Dictionary = {
		"id": "evt_%s_d%d_n%d" % [etype, day, n],
		"type": etype,
		"icon": str(meta.get("icon", "🎲")),
		"title": str(meta.get("name", etype)),
		"state": "pending",
		"created_day": day,
		"reward_claimed": false,
		"data": {},
	}
	match etype:
		"challenge_team":
			_fill_challenge_team(ev, rng, ctx)
		"rival":
			_fill_rival(ev, rng, state, ctx)
		"target":
			_fill_target(ev, rng, ctx)
		"invitation":
			_fill_invitation(ev, rng, ctx)
		"legend":
			_fill_legend(ev, rng, state)
		_:
			return {}
	if str(ev.get("desc", "")) == "":
		return {}
	return ev


static func _reward(base_coins: int, base_xp: int, difficulty: String) -> Dictionary:
	var m: float = float(DIFF_MULT.get(difficulty, 1.0))
	return {"coins": int(round(base_coins * m)), "xp": int(round(base_xp * m))}


## ------------------------------------------------------- team challenge ---

static func _fill_challenge_team(ev: Dictionary, rng: GCLRng, ctx: Dictionary) -> void:
	var stage: Dictionary = ctx.get("stage", {})
	var tier: int = int(ctx.get("tier_index", 0))
	var ai_ovr: Array = stage.get("ai_overall", [50, 60])
	var lo: int = int(ai_ovr[0]) + tier
	var hi: int = int(ai_ovr[1]) + tier
	var team_name: String = rng.pick(CHALLENGER_NAMES)
	var mode: String = rng.pick(CHALLENGER_MODES)
	var difficulty: String = str(stage.get("difficulty", "NORMAL"))
	var rw: Dictionary = _reward(200, 90, difficulty)
	ev["title"] = "⚔️ Team Challenge: %s" % team_name
	ev["difficulty"] = difficulty
	ev["reward_coins"] = int(rw["coins"])
	ev["reward_xp"] = int(rw["xp"])
	ev["desc"] = "%s (team rating %d–%d) have challenged you to a %s match. " % [
		team_name, lo, hi, mode] + \
		"Win for a big payout and reputation; lose and you still earn a consolation — plus a rematch offer."
	ev["data"] = {
		"team_name": team_name, "overall_lo": lo, "overall_hi": hi,
		"mode": mode, "difficulty": difficulty,
	}


## ---------------------------------------------------------------- rivals ---

static func rival_defs() -> Array:
	return [
		{"id": "rival_kings", "name": "Gully Kings", "color": "#e53935",
			"base_lo": 52, "base_hi": 60, "taunt": "They say the Kings own every street they play on."},
		{"id": "rival_hawks", "name": "Night Hawks", "color": "#1e88e5",
			"base_lo": 55, "base_hi": 63, "taunt": "The Hawks hunt under floodlights — and they remember every loss."},
		{"id": "rival_titans", "name": "Tape-Ball Titans", "color": "#43a047",
			"base_lo": 58, "base_hi": 66, "taunt": "The Titans have never lost a rivalry series. Yet."},
	]


static func rival_record(state: Dictionary, rival_id: String) -> Dictionary:
	return (state.get("rivals", {}) as Dictionary).get(rival_id, {})


static func rival_effective_range(rec: Dictionary, tier_index: int) -> Array:
	# Rivals scale with the career tier so they stay competitive.
	var bump: int = tier_index * 4
	return [int(rec.get("base_lo", 50)) + bump, int(rec.get("base_hi", 58)) + bump]


static func _fill_rival(ev: Dictionary, rng: GCLRng, state: Dictionary, ctx: Dictionary) -> void:
	var rivals: Dictionary = state.get("rivals", {})
	if rivals.is_empty():
		return
	# Prefer unannounced rivals, then the least-played ones.
	var cands: Array = []
	for rid in rivals.keys():
		var rec: Dictionary = rivals[rid]
		if not bool(rec.get("announced", false)):
			cands.append(rid)
	if cands.is_empty():
		var best: int = 1 << 30
		for rid in rivals.keys():
			var e: int = int((rivals[rid] as Dictionary).get("encounters", 0))
			if e < best:
				best = e
				cands = [rid]
			elif e == best:
				cands.append(rid)
	var rid: String = str(rng.pick(cands))
	var rec: Dictionary = rivals[rid]
	var enc: int = int(rec.get("encounters", 0))
	var decisive: bool = enc >= 2
	var tier: int = int(ctx.get("tier_index", 0))
	var stage: Dictionary = ctx.get("stage", {})
	var difficulty: String = str(stage.get("difficulty", "NORMAL"))
	var rw: Dictionary = _reward(350 if decisive else 250, 140 if decisive else 110, difficulty)
	ev["title"] = "🔥 %s: %s" % ["DECISIVE RIVALRY MATCH" if decisive else "Rivalry Match", str(rec.get("name", "Rivals"))]
	ev["difficulty"] = difficulty
	ev["reward_coins"] = int(rw["coins"])
	ev["reward_xp"] = int(rw["xp"])
	var rng_range: Array = rival_effective_range(rec, tier)
	var record_line: String = "First meeting." if enc == 0 else "Rivalry record: %dW–%dL." % [
		int(rec.get("wins", 0)), int(rec.get("losses", 0))]
	if decisive:
		record_line += " This one settles the rivalry — bigger stakes!"
	ev["desc"] = "%s %s (rating %d–%d) want a match. %s" % [
		str(rec.get("name", "Rivals")), _rival_taunt(rid), int(rng_range[0]), int(rng_range[1]), record_line]
	ev["data"] = {
		"rival_id": rid, "rival_name": str(rec.get("name", "Rivals")),
		"mode": "gully6", "difficulty": difficulty,
		"decisive": decisive, "overall_lo": int(rng_range[0]), "overall_hi": int(rng_range[1]),
	}


static func _rival_taunt(rid: String) -> String:
	for d in rival_defs():
		if str(d["id"]) == rid:
			return str(d["taunt"])
	return ""


## ------------------------------------------------------ target challenges ---

## The six target-challenge types. `target` scales with tier via _scale_target.
static func target_specs() -> Array:
	return [
		{"kind": "chase", "icon": "🏃", "name": "Target Chase",
			"rule": "Score {target}+ runs in the match", "target": 24, "balls": 12,
			"mode": "1v1", "coins": 250, "xp": 100},
		{"kind": "defend", "icon": "🛡️", "name": "Defend the Total",
			"rule": "Win the match — defend your total", "target": 0, "balls": 12,
			"mode": "1v1", "coins": 300, "xp": 120},
		{"kind": "boundaries", "icon": "💥", "name": "Boundary Blitz",
			"rule": "Hit {target}+ boundaries (4s & 6s)", "target": 4, "balls": 12,
			"mode": "1v1", "coins": 300, "xp": 120},
		{"kind": "wickets", "icon": "🎯", "name": "Wicket Blitz",
			"rule": "Take {target}+ wickets while bowling", "target": 3, "balls": 18,
			"mode": "2v2", "coins": 300, "xp": 120},
		{"kind": "wicketless", "icon": "🧱", "name": "Rock Solid",
			"rule": "Win scoring {target}+ runs without losing a wicket", "target": 20, "balls": 12,
			"mode": "1v1", "coins": 350, "xp": 140},
		{"kind": "economy", "icon": "🧊", "name": "Ice Veins",
			"rule": "Bowl at least {min_balls} balls, concede at most {target} runs",
			"target": 12, "balls": 18, "min_balls": 6,
			"mode": "2v2", "coins": 350, "xp": 140},
	]


static func _fill_target(ev: Dictionary, rng: GCLRng, ctx: Dictionary) -> void:
	var specs: Array = target_specs()
	# Avoid repeating the last target kind when there is history.
	var hist: Array = []
	for h in (ctx.get("state_history", []) as Array):
		if h is Dictionary and str((h as Dictionary).get("type", "")) == "target":
			hist.append(str((h as Dictionary).get("data", {}).get("kind", "")))
	var cands: Array = []
	for s in specs:
		if not hist.is_empty() and str(s["kind"]) == str(hist[0]):
			continue
		cands.append(s)
	if cands.is_empty():
		cands = specs
	var spec: Dictionary = (rng.pick(cands) as Dictionary).duplicate(true)
	var tier: int = int(ctx.get("tier_index", 0))
	var stage: Dictionary = ctx.get("stage", {})
	var difficulty: String = str(stage.get("difficulty", "NORMAL"))
	_scale_target(spec, tier)
	var rw: Dictionary = _reward(int(spec["coins"]), int(spec["xp"]), difficulty)
	ev["title"] = "%s %s" % [str(spec["icon"]), str(spec["name"])]
	ev["difficulty"] = difficulty
	ev["reward_coins"] = int(rw["coins"])
	ev["reward_xp"] = int(rw["xp"])
	ev["desc"] = "Special rules: %s (%d balls, %s). Succeed for the full reward; " % [
		_format_rule(spec), int(spec["balls"]), str(spec["mode"])] + \
		"fail and you still earn a little XP for the effort."
	spec["difficulty"] = difficulty
	spec["reward_coins"] = int(rw["coins"])
	spec["reward_xp"] = int(rw["xp"])
	ev["data"] = spec


static func _scale_target(spec: Dictionary, tier: int) -> void:
	match str(spec.get("kind", "")):
		"chase":
			spec["target"] = int(spec["target"]) + tier * 4
		"boundaries":
			spec["target"] = int(spec["target"]) + mini(tier, 2)
		"wickets":
			spec["target"] = int(spec["target"]) + mini(tier, 2)
		"wicketless":
			spec["target"] = int(spec["target"]) + tier * 3
		"economy":
			spec["target"] = maxi(6, int(spec["target"]) - tier * 2)


static func _format_rule(spec: Dictionary) -> String:
	var r: String = str(spec.get("rule", ""))
	r = r.replace("{target}", str(spec.get("target", 0)))
	r = r.replace("{min_balls}", str(spec.get("min_balls", 0)))
	return r


## Evaluate a target challenge. `e` is a plain dict:
## player_runs, player_wickets, player_won, sixes, fours, wickets_taken,
## balls_bowled, runs_conceded.
static func evaluate_target(spec: Dictionary, e: Dictionary) -> Dictionary:
	var kind: String = str(spec.get("kind", ""))
	var target: int = int(spec.get("target", 0))
	var ok: bool = false
	var detail: String = ""
	match kind:
		"chase":
			ok = int(e.get("player_runs", 0)) >= target
			detail = "Scored %d, needed %d." % [int(e.get("player_runs", 0)), target]
		"defend":
			ok = bool(e.get("player_won", false))
			detail = "Defended the total." if ok else "The total was chased down."
		"boundaries":
			var b: int = int(e.get("sixes", 0)) + int(e.get("fours", 0))
			ok = b >= target
			detail = "Hit %d boundaries, needed %d." % [b, target]
		"wickets":
			ok = int(e.get("wickets_taken", 0)) >= target
			detail = "Took %d wickets, needed %d." % [int(e.get("wickets_taken", 0)), target]
		"wicketless":
			ok = bool(e.get("player_won", false)) and int(e.get("player_wickets", 99)) == 0 \
				and int(e.get("player_runs", 0)) >= target
			detail = "Scored %d/%d — %s." % [int(e.get("player_runs", 0)),
				int(e.get("player_wickets", 0)),
				"wicketless, target met" if ok else "wickets lost or target missed"]
		"economy":
			var bb: int = int(e.get("balls_bowled", 0))
			var rc: int = int(e.get("runs_conceded", 0))
			var need: int = int(spec.get("min_balls", 6))
			ok = bb >= need and rc <= target
			detail = "Bowled %d balls, conceded %d (limit %d)." % [bb, rc, target]
	return {"success": ok, "detail": detail}


## ------------------------------------------------- tournament invitation ---

static func _fill_invitation(ev: Dictionary, rng: GCLRng, ctx: Dictionary) -> void:
	var invites: Array = ctx.get("invite_tournaments", [])
	if invites.is_empty():
		return
	var t: Dictionary = rng.pick(invites)
	var prize: int = int(t.get("prize", 0))
	ev["title"] = "✉️ Invitation: %s" % str(t.get("name", "Tournament"))
	ev["difficulty"] = str(t.get("difficulty", "NORMAL"))
	ev["reward_coins"] = 0
	ev["reward_xp"] = 60
	ev["desc"] = "You are invited to the %s at %s! " % [
		str(t.get("name", "")), str(t.get("venue", ""))] + \
		"Format: %s · Teams: %d · Prize: 🪙%d + ✨%d XP. " % [
			str(t.get("format", "")), int(t.get("teams", 0)), prize, int(t.get("prize_xp", 0))] + \
		"Requirement: %s. Accept to enter the real tournament — win it to lift the trophy." % str(
			t.get("requirements", ""))
	ev["data"] = {
		"tid": str(t.get("tid", "")), "name": str(t.get("name", "")),
		"venue": str(t.get("venue", "")), "prize": prize,
	}


## --------------------------------------------------- legendary training ---

static func legends() -> Array:
	return [
		{"id": "ustad_rahim", "name": "Ustad Rahim", "speciality": "Batting timing",
			"personality": "Patient mentor who speaks in proverbs.",
			"intro": "“Beta, timing beats power. I will teach your hands to be late — late is perfect.”"},
		{"id": "chacha_express", "name": "Chacha Express", "speciality": "Swing bowling",
			"personality": "Loud, laughing, full of street wisdom.",
			"intro": "“Ha! The ball talks in the air, boy. I will teach you its language.”"},
		{"id": "sixer_salman", "name": "Sixer Salman", "speciality": "Power hitting",
			"personality": "Quiet confidence, lets the bat do the talking.",
			"intro": "“Sixes are not hit. They are decided — three balls before.”"},
		{"id": "safehands_sana", "name": "Safe-Hands Sana", "speciality": "Fielding",
			"personality": "Sharp-eyed perfectionist, kind but demanding.",
			"intro": "“Catches win matches. I dropped two in twenty years — you will drop none today.”"},
		{"id": "yorker_yasir", "name": "Yorker Yasir", "speciality": "Bowling accuracy",
			"personality": "Calm tactician, talks in chess metaphors.",
			"intro": "“The yorker is checkmate, but only if the setup is honest. Watch.”"},
		{"id": "dashing_danish", "name": "Dashing Danish", "speciality": "Fitness & running",
			"personality": "Relentless energy, trains at dawn every day.",
			"intro": "“Legs win matches the bat cannot. Run with me — no shortcuts!”"},
	]


static func legend_by_id(lid: String) -> Dictionary:
	for l in legends():
		if str(l["id"]) == lid:
			return l
	return {}


static func _fill_legend(ev: Dictionary, rng: GCLRng, state: Dictionary) -> void:
	# Avoid the most recently featured legend when possible.
	var last_lid: String = ""
	for h in (state.get("history", []) as Array):
		if h is Dictionary and str((h as Dictionary).get("type", "")) == "legend":
			last_lid = str((h as Dictionary).get("data", {}).get("legend_id", ""))
			break
	var cands: Array = []
	for l in legends():
		if str(l["id"]) != last_lid:
			cands.append(l)
	if cands.is_empty():
		cands = legends()
	var leg: Dictionary = rng.pick(cands)
	ev["title"] = "🌟 Legendary Training: %s" % str(leg["name"])
	ev["difficulty"] = "NORMAL"
	ev["reward_coins"] = 0
	ev["reward_xp"] = 80
	ev["desc"] = "%s — %s (%s). %s Accept for ONE explicitly-labeled bonus " % [
		str(leg["name"]), str(leg["speciality"]), str(leg["personality"]), str(leg["intro"])] + \
		"practice session today: it stacks ON TOP of your 3 daily sessions and is recorded in your training history."
	ev["data"] = {"legend_id": str(leg["id"])}


## ----------------------------------------------------------------- rain ---

static func rain_weather() -> Dictionary:
	return {
		"id": "rain", "name": "Rain",
		"desc": "Wet ball, slow skiddy outfield — extra swing for seamers, fewer boundaries.",
		"swing_mod": 1.15, "fielding_mod": 0.94, "boundary_mod": 0.85, "rain": true,
	}


static func rain_overs(overs: int) -> int:
	return maxi(1, overs - 1)


static func rain_warning_text(overs: int) -> String:
	return "🌧 RAIN WARNING — overs reduced to %d, outfield slow (fewer boundaries), extra swing for seamers." % overs


## -------------------------------------------------------------- helpers ---

static func reward_line(ev: Dictionary) -> String:
	var etype: String = str(ev.get("type", ""))
	if etype == "legend":
		return "Reward: ⭐ +1 bonus practice session  ·  ✨+%d XP" % int(ev.get("reward_xp", 0))
	if etype == "invitation":
		var d: Dictionary = ev.get("data", {})
		return "Prize: 🪙%d tournament prize  ·  ✨+%d XP appearance" % [
			int(d.get("prize", 0)), int(ev.get("reward_xp", 0))]
	return "Reward: 🪙%d  ·  ✨%d XP%s" % [int(ev.get("reward_coins", 0)),
		int(ev.get("reward_xp", 0)), "  ·  📈 reputation" if etype != "target" else ""]
