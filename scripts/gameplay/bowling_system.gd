class_name BowlingSystem
extends RefCounted
## Resolves a ball when someone bowls: the AI batter answers with timing and
## shot drawn from AIDirector, then BattingSystem resolves the contest.
## Delivery accuracy shapes everything — an accurate yorker brings dots and
## wickets, a loose ball gets punished to the boundary.

const DEFAULT_FIELDING_AVG: float = 55.0


## params = {delivery {line,length,type,accuracy 0..1}, batter, bowler,
##           rng: GCLRng, difficulty}.
## Returns the standard outcome {runs, wicket, timing, description,
## shot_quality, lofted, dismissal}; timing comes from the AI timing draw.
static func resolve(params: Dictionary) -> Dictionary:
	var delivery: Dictionary = params.get("delivery", {})
	var batter: Dictionary = params.get("batter", {})
	var bowler: Dictionary = params.get("bowler", {})
	var rng: GCLRng = params.get("rng") as GCLRng
	if rng == null:
		rng = GCLRng.new(0xB071)
	var difficulty: String = str(params.get("difficulty", "NORMAL"))
	var accuracy: float = clampf(float(delivery.get("accuracy", 0.6)), 0.0, 1.0)

	var offset: float = AIDirector.ai_batting_offset(difficulty, rng)
	var timing: String = BattingSystem.grade_timing(offset)
	var shot: String = AIDirector.ai_shot(difficulty, rng, delivery)

	var batting_params: Dictionary = {
		"batter": batter,
		"bowler": bowler,
		"delivery": delivery,
		"shot": shot,
		"timing": timing,
		"rng": rng,
		"fielding_avg": DEFAULT_FIELDING_AVG,
		"difficulty": difficulty,
		"accuracy": accuracy,
		"pitch": params.get("pitch", {}),
		"weather": params.get("weather", {}),
	}
	return BattingSystem.resolve(batting_params)
