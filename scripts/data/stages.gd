class_name GCLStages
extends RefCounted
## Career stage definitions: Soomra Colony -> Sindh Gully Cricket Championship.

static func all() -> Array:
	return [
		{
			"id": "soomra_colony", "name": "Soomra Colony", "index": 0,
			"description": "Where it all begins. Narrow streets, tape-ball dreams, and your neighbourhood friends.",
			"difficulty": "EASY", "ai_overall": [45, 55],
			"team_names": ["Soomra Strikers", "Colony Kings", "Street Smashers", "Gully Gladiators", "Mohalla Mavericks"],
			"ground": {"sky": ["#87CEEB", "#E0F6FF"], "ground": "#7CB342", "accent": "#8D6E63",
				"label": "Narrow street", "features": "houses both sides, clotheslines, parked bicycles"},
			"tournament": {"id": "soomra_cup", "name": "Soomra Street Cup",
				"rounds": ["Semi Final", "Final"], "prize": 300, "prize_xp": 150},
			"unlock_reward": 200, "icon": "🏏",
		},
		{
			"id": "mithi", "name": "Mithi", "index": 1,
			"description": "More open grounds and better players. Word of your team is spreading.",
			"difficulty": "EASY", "ai_overall": [50, 60],
			"team_names": ["Mithi Thunders", "Desert Foxes", "Thar Titans", "Mithi Masters", "Sandstorm XI"],
			"ground": {"sky": ["#FFD54F", "#FFF3C4"], "ground": "#9CCC65", "accent": "#C19A6B",
				"label": "Open desert ground", "features": "sparse trees, sandy patches, distant dunes"},
			"tournament": {"id": "mithi_trophy", "name": "Mithi Gully Trophy",
				"rounds": ["Semi Final", "Final"], "prize": 500, "prize_xp": 250},
			"unlock_reward": 300, "icon": "🌵",
		},
		{
			"id": "badin", "name": "Badin", "index": 2,
			"description": "Competitive opponents on bigger grounds. Time to prove you belong.",
			"difficulty": "NORMAL", "ai_overall": [55, 65],
			"team_names": ["Badin Blasters", "Coastal Kings", "Badin Bulls", "Delta Dynamos", "Field Force XI"],
			"ground": {"sky": ["#90CAF9", "#E3F2FD"], "ground": "#66BB6A", "accent": "#5D4037",
				"label": "Large playing field", "features": "green fields, sugarcane edge, small pavilion"},
			"tournament": {"id": "badin_cup", "name": "Badin Super Cup",
				"rounds": ["Quarter Final", "Semi Final", "Final"], "prize": 800, "prize_xp": 400},
			"unlock_reward": 500, "icon": "🌾",
		},
		{
			"id": "larkana", "name": "Larkana", "index": 3,
			"description": "Serious local tournaments. Strong teams, real crowds.",
			"difficulty": "NORMAL", "ai_overall": [60, 70],
			"team_names": ["Larkana Lions", "Mohenjo Stars", "Larkana Legends", "Indus Warriors", "City Challengers"],
			"ground": {"sky": ["#A5D6A7", "#E8F5E9"], "ground": "#43A047", "accent": "#37474F",
				"label": "Tournament ground", "features": "stands with crowd, boundary ropes, sightscreen"},
			"tournament": {"id": "larkana_cup", "name": "Larkana Champions Cup",
				"rounds": ["Quarter Final", "Semi Final", "Final"], "prize": 1200, "prize_xp": 600},
			"unlock_reward": 700, "icon": "🏟️",
		},
		{
			"id": "hyderabad", "name": "Hyderabad", "index": 4,
			"description": "Elite street-cricket players. Difficult opponents, high-level tournaments.",
			"difficulty": "HARD", "ai_overall": [65, 75],
			"team_names": ["Hyderabad Hawks", "Kohsar Kings", "Hyderabad Hurricanes", "Pacca Qila XI", "City Elites"],
			"ground": {"sky": ["#7E57C2", "#D1C4E9"], "ground": "#388E3C", "accent": "#212121",
				"label": "City stadium ground", "features": "city skyline, floodlights, packed stands"},
			"tournament": {"id": "hyderabad_cup", "name": "Hyderabad Premier Cup",
				"rounds": ["Quarter Final", "Semi Final", "Final"], "prize": 1800, "prize_xp": 900},
			"unlock_reward": 1000, "icon": "🌆",
		},
		{
			"id": "championship", "name": "Sindh Gully Cricket Championship", "index": 5,
			"description": "The final stage. The best gully teams of Sindh. Become a legend.",
			"difficulty": "LEGEND", "ai_overall": [72, 85],
			"team_names": ["Sindh Stars", "Champion Challengers", "Gully Giants", "Sindh Sultans", "Legend Hunters"],
			"ground": {"sky": ["#0D47A1", "#42A5F5"], "ground": "#2E7D32", "accent": "#FFD23F",
				"label": "Championship stadium", "features": "grand stadium, fireworks, roaring crowd, trophy arch"},
			"tournament": {"id": "sindh_championship", "name": "Sindh Gully Cricket Championship",
				"rounds": ["Quarter Final", "Semi Final", "Final"], "prize": 3000, "prize_xp": 1500},
			"unlock_reward": 0, "icon": "🏆",
		},
	]


static func by_id(id: String) -> Dictionary:
	for s in all():
		if s["id"] == id:
			return s
	return {}
