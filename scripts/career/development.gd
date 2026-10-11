class_name GCLDevelopment
extends RefCounted
## Player development systems (v3.0): roles, form vs base ratings, fitness,
## injuries, practice, career-day, pitch/weather effects, effective ratings,
## role-based batting order. Pure logic — no SaveSystem/UI references.
##
## CORE RULE (never violated): base attributes (batting/bowling/fielding/
## speed/stamina on the player dict) are NEVER overwritten by form, fitness,
## injury, or tactical style. All temporary effects are computed on the fly
## by effective_stats() and applied to a COPY of the player dict.

# ------------------------------------------------------------------ roles --

const ROLES: Array[String] = ["Batter", "Bowler", "AllRounder", "Wicketkeeper"]
const TACTICAL_STYLES: Array[String] = ["balanced", "batting", "bowling"]

const ROLE_LABELS: Dictionary = {
	"Batter": "Batsman", "Bowler": "Bowler",
	"AllRounder": "All-rounder", "Wicketkeeper": "Wicketkeeper",
}

const TACTICAL_LABELS: Dictionary = {
	"balanced": "Balanced", "batting": "Batting-focused", "bowling": "Bowling-focused",
}


static func role_label(role: String) -> String:
	return str(ROLE_LABELS.get(role, role))


static func tactical_label(t: String) -> String:
	return str(TACTICAL_LABELS.get(t, t))


## Tactical style modifiers for All-rounders. These adjust EFFECTIVE stats
## only (used inside effective_stats) — base attributes are never changed.
## Returns {batting: int, bowling: int} deltas.
static func tactical_mods(role: String, tactical: String) -> Dictionary:
	if role != "AllRounder":
		return {"batting": 0, "bowling": 0}
	match tactical:
		"batting_focused":
			return {"batting": 3, "bowling": -2}
		"bowling_focused":
			return {"batting": -2, "bowling": 3}
	return {"batting": 0, "bowling": 0}


# ------------------------------------------------- form / fitness / injury --

## form: 0.0..1.0 persisted per player (0.5 = neutral). Effective delta in
## rating points: (form - 0.5) * FORM_POINTS. Good form helps, poor form
## hurts, but base ratings are untouched.
const FORM_POINTS: float = 10.0

## fitness: 0..100. Below LOW_FITNESS_THRESHOLD the player is drained.
const LOW_FITNESS_THRESHOLD: int = 40
const LOW_FITNESS_PENALTY: int = -3
const FITNESS_MATCH_COST: int = 5
const FITNESS_REST_GAIN: int = 12
const FITNESS_PRACTICE_GAIN: int = 8

## Injury severity tiers. All durations in career days. Documented constants.
const INJURY_TIERS: Dictionary = {
	"minor": {"days_min": 2, "days_max": 4, "available": true, "penalty": -5,
		"label": "Minor injury", "training": "no_fitness"},
	"moderate": {"days_min": 10, "days_max": 20, "available": false, "penalty": 0,
		"label": "Moderate injury", "training": "none"},
	"serious": {"days_min": 40, "days_max": 90, "available": false, "penalty": 0,
		"label": "Serious injury", "training": "none"},
}
const INJURY_BASE_CHANCE: float = 0.03
const INJURY_FITNESS_FACTOR: float = 0.001
const INJURY_SEVERITY_WEIGHTS: Dictionary = {"minor": 0.6, "moderate": 0.3, "serious": 0.1}


static func default_player_dev() -> Dictionary:
	return {
		"role": "Batter", "form": 0.5, "fitness": 90, "injury": {},
		"tactical": "balanced", "practice": [],
	}


## Fill any missing development fields on a player dict with safe defaults.
## Returns the same dict (mutated) for convenience.
static func ensure_player_dev(p: Dictionary) -> Dictionary:
	var d: Dictionary = default_player_dev()
	for k in d.keys():
		if not p.has(k):
			p[k] = d[k] if not (d[k] is Array or d[k] is Dictionary) else (d[k] as Variant).duplicate(true)
	if not TACTICAL_STYLES.has(str(p.get("tactical", "balanced"))):
		p["tactical"] = "balanced"
	p["form"] = clampf(float(p.get("form", 0.5)), 0.0, 1.0)
	p["fitness"] = clampi(int(p.get("fitness", 90)), 0, 100)
	return p


static func form_delta(form: float) -> float:
	return (clampf(form, 0.0, 1.0) - 0.5) * FORM_POINTS


static func injury_of(p: Dictionary) -> Dictionary:
	var inj: Variant = p.get("injury", {})
	return inj if inj is Dictionary else {}


static func is_injured(p: Dictionary) -> bool:
	return not injury_of(p).is_empty()


## Unavailable = moderate/serious. Minor injuries stay available with a penalty.
static func is_available(p: Dictionary) -> bool:
	var inj: Dictionary = injury_of(p)
	if inj.is_empty():
		return true
	var tier: Dictionary = INJURY_TIERS.get(str(inj.get("severity", "minor")), {})
	return bool(tier.get("available", true))


static func injury_penalty(p: Dictionary) -> int:
	var inj: Dictionary = injury_of(p)
	if inj.is_empty():
		return 0
	var tier: Dictionary = INJURY_TIERS.get(str(inj.get("severity", "minor")), {})
	return int(tier.get("penalty", 0))


## Read-only word for form display.
static func form_word(f: float) -> String:
	if f >= 0.7:
		return "Excellent"
	if f >= 0.58:
		return "Good"
	if f >= 0.42:
		return "Neutral"
	if f >= 0.3:
		return "Poor"
	return "Very poor"


static func injury_label(p: Dictionary) -> String:
	var inj: Dictionary = injury_of(p)
	if inj.is_empty():
		return ""
	var tier: Dictionary = INJURY_TIERS.get(str(inj.get("severity", "minor")), {})
	return "%s — returns in %d day(s)" % [str(tier.get("label", "Injured")), int(inj.get("days_left", 0))]


## Effective stats for match use: base + form delta + injury penalty +
## low-fitness penalty + tactical modifiers, clamped 1..99. Returns a COPY;
## the input player dict (and its base ratings) are never modified.
## Also sets "effective_overall" and keeps "overall" as the base rating.
static func effective_stats(p: Dictionary) -> Dictionary:
	var c: Dictionary = p.duplicate()
	var fd: float = form_delta(float(p.get("form", 0.5)))
	var ipen: int = injury_penalty(p)
	var fpen: int = LOW_FITNESS_PENALTY if int(p.get("fitness", 90)) < LOW_FITNESS_THRESHOLD else 0
	var tmod: Dictionary = tactical_mods(str(p.get("role", "")), str(p.get("tactical", "balanced")))
	for stat in ["batting", "bowling", "fielding"]:
		var v: float = float(p.get(stat, 50)) + fd + float(ipen) + float(fpen)
		if stat == "batting":
			v += float(tmod.get("batting", 0))
		elif stat == "bowling":
			v += float(tmod.get("bowling", 0))
		c[stat] = clampf(v, 1.0, 99.0)
	c["effective_overall"] = GCLConfig.overall_of(c)
	return c


## Post-match injury roll. Pure/testable: takes explicit rolls instead of RNG.
## Returns {} (no injury) or {severity, days_left, total_days}.
## Formula: chance = BASE + (100 - fitness) * FACTOR  (3% at 100 fit .. 13% at 0).
static func roll_injury(fitness: int, chance_roll: float, severity_roll: float, days_roll: float) -> Dictionary:
	var chance: float = INJURY_BASE_CHANCE + float(100 - clampi(fitness, 0, 100)) * INJURY_FITNESS_FACTOR
	if chance_roll >= chance:
		return {}
	var sev: String = "minor"
	var acc: float = 0.0
	for k in ["minor", "moderate", "serious"]:
		acc += float(INJURY_SEVERITY_WEIGHTS[k])
		if severity_roll < acc:
			sev = k
			break
	var tier: Dictionary = INJURY_TIERS[sev]
	var span: int = int(tier["days_max"]) - int(tier["days_min"]) + 1
	var days: int = int(tier["days_min"]) + int(days_roll * float(span)) % span
	return {"severity": sev, "days_left": days, "total_days": days}


## Advance an injury by one career day. Returns {"recovered": bool}.
static func tick_injury(injury: Dictionary) -> Dictionary:
	if injury.is_empty():
		return {"recovered": false}
	injury["days_left"] = maxi(0, int(injury.get("days_left", 0)) - 1)
	return {"recovered": int(injury.get("days_left", 0)) <= 0}


## Training restriction for an injury: "ok" | "no_fitness" | "none".
static func training_restriction(p: Dictionary) -> String:
	var inj: Dictionary = injury_of(p)
	if inj.is_empty():
		return "ok"
	var tier: Dictionary = INJURY_TIERS.get(str(inj.get("severity", "minor")), {})
	return str(tier.get("training", "ok"))


# ---------------------------------------------------------------- practice --

const SESSIONS_PER_DAY: int = 3

## activity -> {label, skill(s) trained, description}.
const PRACTICE_ACTIVITIES: Dictionary = {
	"batting": {"label": "Batting Practice", "skills": ["batting"],
		"desc": "Throwdowns and net sessions. Sharpens timing and shot selection."},
	"bowling": {"label": "Bowling Practice", "skills": ["bowling"],
		"desc": "Run-up, release and line/length drills at the nets."},
	"fielding": {"label": "Fielding Practice", "skills": ["fielding"],
		"desc": "Catching, ground fielding and throwing drills."},
	"allround": {"label": "All-rounder Training", "skills": ["batting", "bowling"],
		"desc": "Split session: batting then bowling. Balanced development."},
	"fitness": {"label": "Fitness & Recovery", "skills": ["fitness"],
		"desc": "Sprints, stamina work and stretching. Restores fitness."},
}

## Role x activity weight. Primary skills train at full weight; off-role
## skills train slower. Documented and tested.
const PRACTICE_WEIGHTS: Dictionary = {
	"Batter": {"batting": 1.0, "bowling": 0.4, "fielding": 0.7, "fitness": 1.0},
	"Bowler": {"batting": 0.4, "bowling": 1.0, "fielding": 0.7, "fitness": 1.0},
	"AllRounder": {"batting": 0.8, "bowling": 0.8, "fielding": 0.7, "fitness": 1.0},
	"Wicketkeeper": {"batting": 0.7, "bowling": 0.3, "fielding": 1.0, "fitness": 1.0},
}
const PRACTICE_BASE_GAIN: int = 2


## Diminishing returns: +2 below 60, +1 from 60-84, +0 at 85+ (documented cap).
## Returns the integer gain for one session on one skill.
static func _gain_for(attr_value: int, weight: float) -> int:
	if attr_value >= 85:
		return 0
	var base: int = 2 if attr_value < 60 else 1
	return maxi(0, int(round(float(base) * weight)))


## Compute the result of one practice session. Pure/testable.
## Returns {gains: {skill: points}, fitness_gain: int, form_bump: float,
##           blocked_reason: String} — blocked_reason != "" means no session.
static func practice_result(activity: String, player: Dictionary) -> Dictionary:
	var out: Dictionary = {"gains": {}, "fitness_gain": 0, "form_bump": 0.0, "blocked_reason": ""}
	if not PRACTICE_ACTIVITIES.has(activity):
		out["blocked_reason"] = "Unknown activity."
		return out
	var restr: String = training_restriction(player)
	if restr == "none":
		out["blocked_reason"] = "Injured — rest until recovered. Training is not available."
		return out
	if restr == "no_fitness" and activity == "fitness":
		out["blocked_reason"] = "Minor injury — skip fitness work until it heals."
		return out
	var role: String = str(player.get("role", "Batter"))
	var weights: Dictionary = PRACTICE_WEIGHTS.get(role, PRACTICE_WEIGHTS["Batter"])
	var skills: Array = PRACTICE_ACTIVITIES[activity]["skills"]
	var gains: Dictionary = {}
	for sk in skills:
		var sks: String = str(sk)
		if sks == "fitness":
			out["fitness_gain"] = FITNESS_PRACTICE_GAIN
		else:
			var g: int = _gain_for(int(player.get(sks, 50)), float(weights.get(sks, 0.5)))
			if g > 0:
				gains[sks] = g
	if gains.is_empty() and int(out["fitness_gain"]) == 0:
		out["blocked_reason"] = "No further gains available at this level — play matches to develop."
		return out
	out["gains"] = gains
	out["form_bump"] = 0.03
	return out


# ------------------------------------------------------------ batting order --

## Role-based default batting order, sorted by actual batting attribute
## within role bands. Openers: best 2 batters (Batter/Wicketkeeper);
## then remaining Batters; then AllRounders by batting; then Bowlers.
## The user's player is placed in their correct band slot (never forced
## first except in reserve matches — see user_first flag).
static func batting_order(team: Array, user_id: String = "", user_first: bool = false) -> Array:
	var openers: Array = []
	var batters: Array = []
	var allround: Array = []
	var bowlers: Array = []
	for p in team:
		if not (p is Dictionary):
			continue
		var pd: Dictionary = p
		match str(pd.get("role", "Batter")):
			"Batter", "Wicketkeeper":
				openers.append(pd)
			"AllRounder":
				allround.append(pd)
			_:
				bowlers.append(pd)
	var by_bat: Callable = func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("batting", 50)) > float(b.get("batting", 50))
	openers.sort_custom(by_bat)
	# First two openers open; the rest of the Batter/WK band bats at 3-4.
	var top: Array = openers.slice(0, 2)
	var rest_bat: Array = openers.slice(2)
	batters = rest_bat
	allround.sort_custom(by_bat)
	bowlers.sort_custom(by_bat)
	var order: Array = top + batters + allround + bowlers
	if user_first and user_id != "":
		var ui: int = -1
		for i in order.size():
			if str((order[i] as Dictionary).get("id", "")) == user_id:
				ui = i
				break
		if ui > 0:
			var up: Dictionary = order[ui]
			order.remove_at(ui)
			order.push_front(up)
	return order


# ------------------------------------------------------- pitch and weather --

## Pitch: pace/spin/boundary modifiers + honest description of the effect.
const PITCHES: Array = [
	{"id": "green", "name": "Green Top",
		"desc": "Lively seam movement — pace bowling is more dangerous.",
		"pace_mod": 1.15, "spin_mod": 1.0, "boundary_mod": 1.0},
	{"id": "dry", "name": "Dry Surface",
		"desc": "Turns a little — spin bowling gets extra bite.",
		"pace_mod": 1.0, "spin_mod": 1.15, "boundary_mod": 1.0},
	{"id": "cracked", "name": "Cracked Pitch",
		"desc": "Cracks opening up — spinners are a real threat.",
		"pace_mod": 1.0, "spin_mod": 1.25, "boundary_mod": 1.0},
	{"id": "slow", "name": "Slow Outfield",
		"desc": "Heavy outfield — boundaries are harder to find.",
		"pace_mod": 1.0, "spin_mod": 1.05, "boundary_mod": 0.85},
	{"id": "flat", "name": "Flat Track",
		"desc": "True bounce, fast outfield — a batter's paradise.",
		"pace_mod": 1.0, "spin_mod": 1.0, "boundary_mod": 1.05},
]

## v4.0: probability that a match is rain-affected (rolled separately from
## the weather table, so rain can never appear in every match).
const RAIN_CHANCE := 0.18

const WEATHERS: Array = [
	{"id": "sunny", "name": "Sunny",
		"desc": "Clear skies — no assistance for the bowlers.",
		"swing_mod": 1.0},
	{"id": "overcast", "name": "Overcast",
		"desc": "Cloud cover — the ball swings more.",
		"swing_mod": 1.15},
	{"id": "humid", "name": "Hot & Humid",
		"desc": "Sweaty palms — fielders spill a few more.",
		"swing_mod": 1.0, "fielding_mod": 0.94},
	# v4.0: rain — rolled separately (RAIN_CHANCE below), never every match.
	# Real effects: shortened overs (match config), slower outfield
	# (boundary reduction), extra swing, sloppy fielding.
	{"id": "rain", "name": "Rain",
		"desc": "Wet ball, slow skiddy outfield — extra swing for seamers, fewer boundaries.",
		"swing_mod": 1.15, "fielding_mod": 0.94, "boundary_mod": 0.85, "rain": true},
]


static func pitch_by_id(pid: String) -> Dictionary:
	for p in PITCHES:
		if str(p.get("id", "")) == pid:
			return p
	return PITCHES[4]


static func weather_by_id(wid: String) -> Dictionary:
	for w in WEATHERS:
		if str(w.get("id", "")) == wid:
			return w
	return WEATHERS[0]


## Pick pitch + weather from a seeded RNG. Pure/testable via injected rolls.
## v4.0: rain is NOT part of the normal weather table — it is rolled
## separately via rain_roll (< RAIN_CHANCE means rain), so it can never
## appear in every match.
static func pick_conditions(pitch_roll: float, weather_roll: float, rain_roll: float = -1.0) -> Dictionary:
	var pi: int = clampi(int(pitch_roll * PITCHES.size()), 0, PITCHES.size() - 1)
	var dry: Array = []
	for w in WEATHERS:
		if not bool(w.get("rain", false)):
			dry.append(w)
	var wi: int = clampi(int(weather_roll * dry.size()), 0, dry.size() - 1)
	var weather: Dictionary = dry[wi]
	if rain_roll >= 0.0 and rain_roll < RAIN_CHANCE:
		weather = weather_by_id("rain")
	return {"pitch": PITCHES[pi], "weather": weather}


## Delivery difficulty multipliers from conditions. Only the effects listed
## here are implemented — the UI must describe exactly these.
static func condition_mods(pitch: Dictionary, weather: Dictionary, delivery_type: String) -> Dictionary:
	var wicket_mult: float = 1.0
	# v4.0: weather may override the boundary modifier (rain slows the
	# outfield); otherwise the pitch decides.
	var boundary_mult: float = float(weather.get("boundary_mod", pitch.get("boundary_mod", 1.0)))
	match delivery_type:
		"Fast", "Bouncer":
			# Swing is a pace phenomenon: overcast helps seam/swing bowling.
			wicket_mult *= float(pitch.get("pace_mod", 1.0)) * float(weather.get("swing_mod", 1.0))
		"Spin":
			wicket_mult *= float(pitch.get("spin_mod", 1.0))
	return {"wicket_mult": wicket_mult, "boundary_mult": boundary_mult}


static func fielding_mod(weather: Dictionary) -> float:
	return float(weather.get("fielding_mod", 1.0))
