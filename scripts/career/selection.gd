class_name GCLSelection
extends RefCounted
## Reserve -> debut -> main-XI selection model (v2.0). Pure logic.
##
## A persisted per-player `selection_chance` starts at BASE_CHANCE (20%) for a
## newly eligible reserve. It is recomputed ONLY after a match involving the
## player (reserve, debut, or main-XI) — never when a screen opens. The actual
## selection decision is a single seeded RNG draw against the stored chance,
## so identical inputs always give identical decisions (the seed is derived
## from the player's id and how many selection matches they have played).

const BASE_CHANCE: float = 0.20
const MIN_CHANCE: float = 0.05
const MAX_CHANCE: float = 0.95

const W_FORM: float = 0.35
const W_ABILITY: float = 0.30
const W_ROLE: float = 0.25
const W_TIER: float = 0.10

const STATUSES: Array = ["RESERVE", "DEBUT_ELIGIBLE", "SELECTED_FOR_DEBUT", "MAIN_XI", "DROPPED", "INJURED"]

const STATUS_LABELS: Dictionary = {
	"RESERVE": "Reserve",
	"DEBUT_ELIGIBLE": "Debut eligible",
	"SELECTED_FOR_DEBUT": "Selected for debut",
	"MAIN_XI": "Main XI",
	"DROPPED": "Dropped to reserves",
	"INJURED": "Injured",
}


static func status_label(status: String) -> String:
	return str(STATUS_LABELS.get(status, status))


static func is_selectable_status(status: String) -> bool:
	return status in ["RESERVE", "DEBUT_ELIGIBLE", "DROPPED"]


## factors: {form: 0..1, ability: 0..1, role_fit: 0..1, tier_factor: 0..1}.
## Each factor is centred on 0.5 (neutral); deviations move the chance away
## from BASE_CHANCE. Result is clamped to [MIN_CHANCE, MAX_CHANCE].
static func compute_chance(factors: Dictionary) -> float:
	var c: float = BASE_CHANCE
	c += W_FORM * (float(factors.get("form", 0.5)) - 0.5)
	c += W_ABILITY * (float(factors.get("ability", 0.5)) - 0.5)
	c += W_ROLE * (float(factors.get("role_fit", 0.5)) - 0.5)
	c += W_TIER * (float(factors.get("tier_factor", 0.5)) - 0.5)
	return clampf(c, MIN_CHANCE, MAX_CHANCE)


## Real match performance -> 0..1 score. Uses only stats the match engine
## actually records per player (runs/balls/fours/sixes, wickets/runs conceded).
## No balls faced and no wickets: neutral 0.5 (e.g. did-not-bat edge cases).
static func performance_score(perf: Dictionary) -> float:
	var balls: int = int(perf.get("balls_faced", 0))
	var runs: int = int(perf.get("runs", 0))
	var wkts: int = int(perf.get("wickets", 0))
	var conceded: int = int(perf.get("runs_conceded", 0))
	var has_bat: bool = balls > 0
	var has_bowl: bool = wkts > 0 or int(perf.get("balls_bowled", 0)) > 0
	if not has_bat and not has_bowl:
		return 0.5
	var parts: Array[float] = []
	if has_bat:
		# Par is ~1 run per ball; 2+ runs per ball is outstanding.
		parts.append(clampf(0.15 + 0.45 * (float(runs) / float(maxi(balls, 1))), 0.0, 1.0))
	if has_bowl:
		# Each wicket is worth a lot; conceding runs drags it down.
		parts.append(clampf(0.30 + 0.25 * float(wkts) - 0.015 * float(conceded), 0.0, 1.0))
	var total: float = 0.0
	for p in parts:
		total += p
	return clampf(total / float(parts.size()), 0.0, 1.0)


## Average of the last (up to) 5 performance scores; 0.5 when no history.
static func recent_form(form: Array) -> float:
	if form.is_empty():
		return 0.5
	var n: int = mini(form.size(), 5)
	var total: float = 0.0
	for i in range(form.size() - n, form.size()):
		total += float(form[i])
	return clampf(total / float(n), 0.0, 1.0)


## 1.0 if the XI needs the player's role, 0.5 if adequately stocked,
## 0.2 if the role is oversubscribed. xi_roles: roles currently in the XI.
static func role_fit(player_role: String, xi_roles: Array) -> float:
	var want: Dictionary = {"Batter": 2, "Bowler": 2, "AllRounder": 1, "Wicketkeeper": 1}
	var have: Dictionary = {}
	for r in xi_roles:
		var k: String = str(r)
		have[k] = int(have.get(k, 0)) + 1
	var need_n: int = int(want.get(player_role, 1))
	var have_n: int = int(have.get(player_role, 0))
	if have_n < need_n:
		return 1.0
	if have_n < need_n + 2:
		return 0.5
	return 0.2


## Seeded draw: roll must come from a seeded RNG (documented by the caller).
static func draw_selection(chance: float, roll: float) -> bool:
	return roll < clampf(chance, 0.0, 1.0)


## Human-readable feedback based on the actual weakest factor.
## factors also carries player_name/role for personalisation.
## v3.0: fitness joins the comparison (neutral 0.5 when absent).
static func feedback_for(factors: Dictionary, selected: bool, player_name: String = "") -> String:
	if selected:
		return "The manager has selected you for a debut opportunity. Make it count!"
	if bool(factors.get("injured", false)):
		return "You are injured and unavailable for selection. Rest and recover first."
	var form: float = float(factors.get("form", 0.5))
	var ability: float = float(factors.get("ability", 0.5))
	var role: float = float(factors.get("role_fit", 0.5))
	var fitness: float = float(factors.get("fitness", 0.5))
	var weakest: String = "form"
	var weakest_v: float = form
	if ability < weakest_v:
		weakest = "ability"
		weakest_v = ability
	if role < weakest_v:
		weakest = "role"
		weakest_v = role
	if fitness < weakest_v:
		weakest = "fitness"
	var who: String = (" " + player_name) if player_name != "" else ""
	match weakest:
		"form":
			return "Not selected%s: your recent match form needs improvement. Score runs or take wickets in reserve matches." % who
		"ability":
			return "Not selected%s: your overall ability is below what the manager wants. Practice and upgrade your player to improve." % who
		"fitness":
			return "Not selected%s: your fitness is low. Rest or do fitness training to recover." % who
		_:
			return "Not selected%s: the team is well stocked in your role right now. Keep performing — openings come up." % who


## Short explainer of what a status means and how to progress.
static func status_help(status: String) -> String:
	match status:
		"RESERVE":
			return "You are a reserve. Play reserve matches, perform well, and the manager will consider you for a debut."
		"DEBUT_ELIGIBLE":
			return "You are eligible for selection. Strong reserve performances raise your selection chance."
		"SELECTED_FOR_DEBUT":
			return "You have been selected! Play your debut match for the main team."
		"MAIN_XI":
			return "You are in the main XI. Keep your form up — sustained poor form can cost your place."
		"DROPPED":
			return "You lost your main-XI place. Perform in reserve matches to earn your way back."
		"INJURED":
			return "You are injured and unavailable. Rest to recover — your place is held."
	return ""
