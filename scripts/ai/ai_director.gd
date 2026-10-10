class_name AIDirector
extends RefCounted
## Drives all AI behavior through per-difficulty behavior parameters.
## The AI NEVER manipulates results — it only plays through these knobs
## (timing error, shot choice, delivery choice, fielding mistakes).
## Every parameter improves strictly monotonically from EASY to LEGEND.

const PARAMS: Dictionary = {
	"EASY": {
		"timing_error_ms": 230.0, "shot_skill": 0.40, "bowling_accuracy": 0.45,
		"fielding_error": 0.32, "mistake_rate": 0.32, "aggression": 0.45,
		"ai_batting_boost": 0.85, "ai_bowling_boost": 0.85,
	},
	"NORMAL": {
		"timing_error_ms": 160.0, "shot_skill": 0.58, "bowling_accuracy": 0.60,
		"fielding_error": 0.22, "mistake_rate": 0.22, "aggression": 0.58,
		"ai_batting_boost": 1.00, "ai_bowling_boost": 1.00,
	},
	"HARD": {
		"timing_error_ms": 110.0, "shot_skill": 0.72, "bowling_accuracy": 0.74,
		"fielding_error": 0.13, "mistake_rate": 0.12, "aggression": 0.70,
		"ai_batting_boost": 1.10, "ai_bowling_boost": 1.10,
	},
	"LEGEND": {
		"timing_error_ms": 70.0, "shot_skill": 0.88, "bowling_accuracy": 0.88,
		"fielding_error": 0.06, "mistake_rate": 0.05, "aggression": 0.82,
		"ai_batting_boost": 1.22, "ai_bowling_boost": 1.22,
	},
}

const LINES: Array = ["Off", "Middle", "Leg"]
const LENGTHS: Array = ["Yorker", "Full", "Good", "Short"]
const TYPES: Array = ["Fast", "Swing", "Spin", "Slower"]


static func params_for(difficulty: String) -> Dictionary:
	return PARAMS.get(difficulty, PARAMS["NORMAL"])


## Picks a delivery for an AI bowler. Skilled bowlers hunt the yorker more often.
static func choose_delivery(difficulty: String, rng: GCLRng, bowler: Dictionary) -> Dictionary:
	var skill: float = clampf(float(bowler.get("bowling", 50)) / 70.0, 0.4, 1.3)
	var length_weights: Array = [0.4 + 0.9 * skill, 1.0, 1.7, 0.9]
	var type_weights: Array = [1.2, 1.0, 0.9, 0.7]
	var line_weights: Array = [1.2, 1.4, 1.0]
	return {
		"line": str(rng.weighted(LINES, line_weights)),
		"length": str(rng.weighted(LENGTHS, length_weights)),
		"type": str(rng.weighted(TYPES, type_weights)),
	}


## Draws the AI batter's timing error in milliseconds (signed).
## Smaller timing_error_ms at higher difficulties -> tighter timing.
static func ai_batting_offset(difficulty: String, rng: GCLRng) -> float:
	var p: Dictionary = params_for(difficulty)
	return clampf(float(p["timing_error_ms"]) * rng.normal() * 1.6, -450.0, 450.0)


## Picks the AI batter's shot. shot_skill = chance of picking the matchup-correct
## shot; aggression = extra love for the lofted swipeUp on short balls.
static func ai_shot(difficulty: String, rng: GCLRng, delivery: Dictionary) -> String:
	var p: Dictionary = params_for(difficulty)
	var skill: float = float(p["shot_skill"])
	var aggr: float = float(p["aggression"])
	var length: String = str(delivery.get("length", "Good"))
	var best: String = "swipeLeft"
	match length:
		"Yorker":
			best = "tap"
		"Short":
			best = "swipeUp"
		"Full":
			best = "swipeRight"
		_:
			best = "swipeLeft"
	var shot: String
	if rng.next() < skill:
		shot = best
	else:
		shot = str(rng.pick(["tap", "swipeLeft", "swipeRight", "swipeUp"]))
	if length == "Short" and rng.next() < aggr * 0.4:
		shot = "swipeUp"
	elif length == "Yorker" and rng.next() < skill * 0.5:
		shot = "tap"
	return shot
