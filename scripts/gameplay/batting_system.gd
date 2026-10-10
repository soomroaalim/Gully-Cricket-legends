class_name BattingSystem
extends RefCounted
## Resolves a batting ball: timing grade + shot + delivery + batter/bowler stats
## produce a weighted outcome. HARD RULE: timing dominates — PERFECT/GOOD
## statistically crush MISS/EARLY/LATE in both runs and wicket rate.

const BASE_WEIGHTS: Dictionary = {
	"PERFECT": {"0": 7.0, "1": 22.0, "2": 13.0, "3": 4.0, "4": 22.0, "6": 16.0, "W": 1.0},
	"GOOD": {"0": 12.0, "1": 24.0, "2": 11.0, "3": 3.0, "4": 13.0, "6": 7.0, "W": 2.5},
	"EARLY": {"0": 22.0, "1": 18.0, "2": 8.0, "3": 3.0, "4": 7.0, "6": 2.5, "W": 7.0},
	"LATE": {"0": 22.0, "1": 18.0, "2": 8.0, "3": 3.0, "4": 7.0, "6": 2.5, "W": 7.0},
	"MISS": {"0": 60.0, "1": 5.0, "2": 2.5, "3": 1.0, "4": 1.5, "6": 0.3, "W": 22.0},
}

const TYPE_DIFFICULTY: Dictionary = {"Fast": 1.15, "Bouncer": 1.3, "Swing": 1.05, "Spin": 1.05, "Slower": 0.8}
const LENGTH_DIFFICULTY: Dictionary = {"Yorker": 1.35, "Full": 0.95, "Good": 1.0, "Short": 1.1}


static func grade_timing(offset_ms: Variant) -> String:
	if offset_ms == null:
		return "MISS"
	var off: float = float(offset_ms)
	var mag: float = absf(off)
	if mag <= GCLConfig.TIMING_PERFECT_MS:
		return "PERFECT"
	if mag <= GCLConfig.TIMING_GOOD_MS:
		return "GOOD"
	if mag <= GCLConfig.TIMING_OK_MS:
		return "EARLY" if off < 0.0 else "LATE"
	return "MISS"


## params = {batter, bowler, delivery {line,length,type}, shot, timing,
##           rng: GCLRng, fielding_avg, difficulty, accuracy (-1 = n/a)}.
## Returns {runs, wicket, timing, description, shot_quality, lofted, dismissal}.
static func resolve(params: Dictionary) -> Dictionary:
	var batter: Dictionary = params.get("batter", {})
	var bowler: Dictionary = params.get("bowler", {})
	var delivery: Dictionary = params.get("delivery", {})
	var shot: String = str(params.get("shot", "tap"))
	var timing: String = str(params.get("timing", "MISS"))
	var rng: GCLRng = params.get("rng") as GCLRng
	if rng == null:
		rng = GCLRng.new(0xB471)
	var fielding_avg: float = float(params.get("fielding_avg", 55.0))
	var difficulty: String = str(params.get("difficulty", "NORMAL"))
	var accuracy: float = float(params.get("accuracy", -1.0))

	if not BASE_WEIGHTS.has(timing):
		timing = "MISS"

	# Batter-vs-bowler edge, clamped to a sane band.
	var edge: float = clampf(
		float(batter.get("batting", 50)) / maxf(1.0, float(bowler.get("bowling", 50))),
		0.6, 1.6)
	var dtype: String = str(delivery.get("type", "Fast"))
	var dlength: String = str(delivery.get("length", "Good"))
	var dline: String = str(delivery.get("line", "Middle"))
	var diff_f: float = float(TYPE_DIFFICULTY.get(dtype, 1.0)) * float(LENGTH_DIFFICULTY.get(dlength, 1.0))

	var w: Dictionary = (BASE_WEIGHTS[timing] as Dictionary).duplicate()

	# Better batters find boundaries and leak fewer wickets; tough deliveries invert that.
	w["4"] = float(w["4"]) * edge / sqrt(diff_f)
	w["6"] = float(w["6"]) * edge / sqrt(diff_f)
	w["W"] = float(w["W"]) * diff_f * (2.0 - edge)

	# Shot-vs-delivery matchup.
	match shot:
		"swipeUp":
			if dlength == "Yorker":
				# Trying to launch a yorker: huge wicket risk.
				w["W"] = float(w["W"]) * 2.4
				w["4"] = float(w["4"]) * 0.5
				w["6"] = float(w["6"]) * 0.4
			elif dlength == "Short":
				# Sitting up nicely: six bonus.
				w["6"] = float(w["6"]) * 1.9
				w["4"] = float(w["4"]) * 1.3
				w["W"] = float(w["W"]) * 0.9
			else:
				w["6"] = float(w["6"]) * 1.4
				w["W"] = float(w["W"]) * 1.3
		"tap":
			# Safe nudge: few boundaries, few wickets, lots of ones and twos.
			w["4"] = float(w["4"]) * 0.5
			w["6"] = float(w["6"]) * 0.15
			w["W"] = float(w["W"]) * 0.6
			w["1"] = float(w["1"]) * 1.25
			w["2"] = float(w["2"]) * 1.2
		"swipeLeft", "swipeRight":
			var on_side: bool = (shot == "swipeLeft" and dline != "Leg") or (shot == "swipeRight" and dline != "Off")
			if on_side:
				w["4"] = float(w["4"]) * 1.25
			else:
				w["W"] = float(w["W"]) * 1.2

	# Bowling accuracy shaping (driven by BowlingSystem): accurate balls go for
	# dots/wickets, loose balls get punished to the boundary.
	if accuracy >= 0.0:
		var acc: float = clampf(accuracy, 0.0, 1.0)
		w["0"] = float(w["0"]) * (0.7 + 0.8 * acc)
		var yorker_bonus: float = 1.0 + 0.5 * acc if dlength == "Yorker" else 1.0
		w["W"] = float(w["W"]) * (0.45 + 1.25 * acc) * yorker_bonus
		w["4"] = float(w["4"]) * (1.5 - 1.0 * acc)
		w["6"] = float(w["6"]) * (1.6 - 1.2 * acc)

	var keys: Array = ["0", "1", "2", "3", "4", "6", "W"]
	var weights: Array = [w["0"], w["1"], w["2"], w["3"], w["4"], w["6"], w["W"]]
	var key: String = str(rng.weighted(keys, weights))

	var lofted: bool = shot == "swipeUp" or (key in ["4", "6"] and shot != "tap" and rng.next() < 0.45)

	var fr: Dictionary
	if key == "W":
		fr = FieldingAI.resolve_outcome(0, 1.0, fielding_avg, difficulty, rng, lofted)
	else:
		fr = FieldingAI.resolve_outcome(int(key), 0.0, fielding_avg, difficulty, rng, lofted)
	var runs: int = int(fr.get("runs", 0))
	var wicket: bool = bool(fr.get("wicket", false))
	var dismissal: String = str(fr.get("dismissal", ""))
	var fnote: String = str(fr.get("fielding_note", ""))

	var quality: float = _shot_quality(timing, edge, rng)
	var desc: String = _describe(timing, shot, key, wicket, dismissal, fnote, dtype, dlength, rng)

	return {
		"runs": runs,
		"wicket": wicket,
		"timing": timing,
		"description": desc,
		"shot_quality": quality,
		"lofted": lofted,
		"dismissal": dismissal,
	}


static func _shot_quality(timing: String, edge: float, rng: GCLRng) -> float:
	var base: float = 0.1
	match timing:
		"PERFECT":
			base = 0.9
		"GOOD":
			base = 0.7
		"EARLY", "LATE":
			base = 0.4
		"MISS":
			base = 0.1
	return clampf(base + rng.normal() * 0.08 + (edge - 1.0) * 0.15, 0.0, 1.0)


static func _describe(timing: String, shot: String, key: String, wicket: bool, dismissal: String, fnote: String, dtype: String, dlength: String, rng: GCLRng) -> String:
	var text: String
	if wicket:
		match dismissal:
			"caught":
				text = str(rng.pick([
					"Skied it... and TAKEN! The fielder barely had to move. OUT!",
					"Straight up in the air — pouched! That's a soft dismissal. OUT!",
					"Huge top edge... gobbled up! Back to the gully. OUT!",
				]))
			"run out":
				text = str(rng.pick([
					"Direct hit! Miles short of the crease — RUN OUT!",
					"Terrible mix-up... the throw beats the dive. RUN OUT!",
				]))
			_:
				text = str(rng.pick([
					"TIMBER! The stumps are shattered. BOWLED HIM!",
					"Beaten for pace — crashing into the stumps! OUT!",
					"That kept low and smashed middle stump! BOWLED!",
				]))
	elif fnote == "dropped":
		text = "DROPPED! The fielder shells a sitter — they scamper through for extra runs!"
	elif key == "6":
		if timing == "PERFECT":
			text = str(rng.pick([
				"ABSOLUTELY LAUNCHED! That ball has left the gully — SIX!",
				"Right out of the screws! Miles over the wall — SIX!",
			]))
		elif dlength == "Short":
			text = "Picked the length early — deposited over the wall! SIX!"
		else:
			text = str(rng.pick([
				"Goes big... and goes all the way! SIX!",
				"Launched high over long-on! That's a maximum — SIX!",
			]))
	elif key == "4":
		if timing == "PERFECT":
			text = "Crashed through the gap — pure timing! FOUR!"
		elif shot == "tap":
			text = "Placed wide of the fielder and it races away! FOUR!"
		else:
			text = str(rng.pick([
				"Smacked through the covers! FOUR!",
				"Threaded the gap — no chance for the fielders! FOUR!",
			]))
	elif key == "3":
		text = "Great chase... they come back for three!"
	elif key == "2":
		text = str(rng.pick([
			"Worked into the gap — quick legs, they come back for two.",
			"Pushed wide of long-on, easy two.",
		]))
	elif key == "1":
		text = str(rng.pick([
			"Nudged into the gap for a quick single.",
			"Pushed to the fielder and they scamper through for one.",
		]))
	else:
		if timing == "MISS":
			text = str(rng.pick([
				"Swing and a miss! Beaten all ends up.",
				"Wild hack — nowhere near it. Dot ball.",
			]))
		elif timing == "PERFECT":
			text = "Solid block, dead-batted. No run."
		else:
			text = str(rng.pick([
				"Mistimed... straight to the fielder. Dot ball.",
				"Beaten just outside off. No run.",
			]))
	if fnote == "misfield":
		text += " A misfield lets an extra run through!"
	elif fnote == "overthrow":
		text += " Overthrow — a gifted run!"
	return text
