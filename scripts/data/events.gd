class_name GCLEvents
extends RefCounted
## Offline random events (local RNG). The UI shows the event and calls
## Career.add_active_effect(event["apply"]) to arm its effect.

static func all() -> Array:
	return [
		{"id": "rain", "title": "🌧️ Rain!",
			"text": "Rain has started! The ball will skid and the AI looks sharper today.",
			"icon": "🌧️", "effect": "AI gets a small boost in your next match",
			"apply": "rain"},
		{"id": "team_challenge", "title": "🏏 Team Challenge!",
			"text": "A rival team wants to challenge you! Extra coins if you win your next match.",
			"icon": "🏏", "effect": "+50% coins for your next win",
			"apply": "bonus_match"},
		{"id": "rival_team", "title": "💥 Rival Team!",
			"text": "A strong neighbourhood team has appeared. Your next match will be tougher.",
			"icon": "💥", "effect": "Next match is one difficulty harder",
			"apply": "rival"},
		{"id": "target_challenge", "title": "🎯 Target Challenge!",
			"text": "Score 20+ runs in your next match for a bonus reward.",
			"icon": "🎯", "effect": "+100 coins if you score 20+ runs next match",
			"apply": "target_bonus"},
		{"id": "tournament_invite", "title": "🏆 Tournament Invitation!",
			"text": "You have been invited to a bigger tournament! Sponsors send a gift.",
			"icon": "🏆", "effect": "+250 coins right now",
			"apply": "tournament"},
		{"id": "legend_training", "title": "👴 Legendary Player!",
			"text": "A legendary local player offers you a training session. Your team learns a lot!",
			"icon": "👴", "effect": "+80 XP right now",
			"apply": "training"},
	]


static func by_id(id: String) -> Dictionary:
	for e in all():
		if e["id"] == id:
			return e
	return {}
