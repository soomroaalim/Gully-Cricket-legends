class_name GCLChallenges
extends RefCounted
## Short special challenges.

static func all() -> Array:
	return [
		{"id": "quick_fire", "name": "Quick Fire", "description": "Score 10 runs in 6 balls",
			"icon": "⚡", "coins": 150, "xp": 60, "kind": "score_runs",
			"target": 10, "balls": 6, "difficulty": "NORMAL"},
		{"id": "six_machine", "name": "Six Machine", "description": "Hit 2 sixes in 12 balls",
			"icon": "🚀", "coins": 250, "xp": 100, "kind": "hit_sixes",
			"target": 2, "balls": 12, "difficulty": "NORMAL"},
		{"id": "wicket_taker", "name": "Wicket Taker", "description": "Take 2 wickets in 12 balls",
			"icon": "🎯", "coins": 250, "xp": 100, "kind": "take_wickets",
			"target": 2, "balls": 12, "difficulty": "NORMAL"},
		{"id": "defend_total", "name": "Defend the Total", "description": "Defend 24 runs in 2 overs",
			"icon": "🛡️", "coins": 350, "xp": 140, "kind": "defend_target",
			"target": 24, "balls": 12, "difficulty": "NORMAL"},
		{"id": "clean_chase", "name": "Clean Chase", "description": "Chase 18 in 12 balls without losing a wicket",
			"icon": "🧹", "coins": 300, "xp": 120, "kind": "no_wicket_chase",
			"target": 18, "balls": 12, "difficulty": "NORMAL"},
	]


static func by_id(id: String) -> Dictionary:
	for c in all():
		if c["id"] == id:
			return c
	return {}
