class_name FieldingAI
extends RefCounted
## Resolves the fielding phase of a ball after the batting outcome is rolled:
## catches on lofted balls (with drops per difficulty mistake_rate),
## run-outs on quick singles, misfields and overthrows.
## Returns {runs, wicket, dismissal, fielding_note}.


static func resolve_outcome(base_runs: int, wicket_chance: float, fielding_avg: float, difficulty: String, rng: GCLRng, lofted: bool) -> Dictionary:
	var run_rng: GCLRng = rng
	var runs: int = base_runs
	var wicket: bool = false
	var dismissal: String = ""
	var note: String = ""
	var params: Dictionary = AIDirector.params_for(difficulty)
	var mistake: float = float(params.get("mistake_rate", 0.2))
	var skill: float = clampf(fielding_avg / 70.0, 0.4, 1.3)

	# Dismissal attempt first.
	if wicket_chance > 0.0 and run_rng.next() < wicket_chance:
		if lofted:
			# Catch attempt — gully fielders can shell them, easier sides drop more.
			if run_rng.next() < mistake:
				wicket = false
				runs = maxi(base_runs, 2)
				note = "dropped"
			else:
				wicket = true
				dismissal = "caught"
		else:
			# Beaten through the gate: bowled / stumps shattered.
			wicket = true
			dismissal = "bowled"
	elif base_runs >= 1 and base_runs <= 3:
		# Run-out chance on quick runs; sharper fielding = more run-outs.
		var ro_chance: float = (0.02 + 0.03 * float(base_runs)) * skill * (1.0 - mistake)
		if run_rng.next() < ro_chance:
			wicket = true
			runs = maxi(0, base_runs - 1)
			dismissal = "run out"
		elif run_rng.next() < mistake * 0.6:
			runs = mini(6, base_runs + 1)
			note = "misfield"
	elif base_runs == 0 and run_rng.next() < mistake * 0.15:
		runs = 1
		note = "overthrow"

	return {"runs": runs, "wicket": wicket, "dismissal": dismissal, "fielding_note": note}
