class_name GCLAchievements
extends RefCounted
## Lightweight achievements.

static func all() -> Array:
	return [
		{"id": "first_match", "name": "First Match", "description": "Play your first match",
			"icon": "🏏", "coins": 50, "xp": 20},
		{"id": "first_win", "name": "First Victory", "description": "Win your first match",
			"icon": "🥇", "coins": 100, "xp": 40},
		{"id": "first_six", "name": "First Six", "description": "Hit your first six",
			"icon": "🔥", "coins": 80, "xp": 30},
		{"id": "first_trophy", "name": "First Trophy", "description": "Win your first tournament",
			"icon": "🏆", "coins": 300, "xp": 150},
		{"id": "big_earner", "name": "Big Earner", "description": "Earn 5,000 total coins",
			"icon": "💰", "coins": 200, "xp": 100},
		{"id": "champion", "name": "Sindh Champion",
			"description": "Win the Sindh Gully Cricket Championship",
			"icon": "👑", "coins": 1000, "xp": 500},
	]


static func by_id(id: String) -> Dictionary:
	for a in all():
		if a["id"] == id:
			return a
	return {}
