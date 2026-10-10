class_name GCLShop
extends RefCounted
## Shop catalogue: {id, category, name, price, description, bonus: Dictionary, tier 1..4, icon}.
## Bonuses apply to the five core stats via Economy.effective_stats().


static func items() -> Array:
	return [
		{
			"id": "street_bat", "category": "bat", "name": "Street Bat",
			"price": 0, "tier": 1, "icon": "🏏",
			"description": "A trusty old bat, tape on the handle. Every legend starts somewhere.",
			"bonus": {},
		},
		{
			"id": "improved_bat", "category": "bat", "name": "Improved Bat",
			"price": 400, "tier": 2, "icon": "🏏",
			"description": "Heavier willow with a clean middle. +3 batting.",
			"bonus": {"batting": 3},
		},
		{
			"id": "pro_bat", "category": "bat", "name": "Pro Bat",
			"price": 1200, "tier": 3, "icon": "🏏",
			"description": "Grade-1 willow, pro knock-in. +6 batting.",
			"bonus": {"batting": 6},
		},
		{
			"id": "legend_bat", "category": "bat", "name": "Legend Bat",
			"price": 2500, "tier": 4, "icon": "🏏",
			"description": "The bat the street whispers about. +9 batting.",
			"bonus": {"batting": 9},
		},
		{
			"id": "tennis_ball", "category": "ball", "name": "Tennis Ball",
			"price": 0, "tier": 1, "icon": "🎾",
			"description": "Classic gully tennis ball. Bounces big, swings late.",
			"bonus": {},
		},
		{
			"id": "season_ball", "category": "ball", "name": "Season Ball",
			"price": 400, "tier": 2, "icon": "🔴",
			"description": "A real leather season ball with a proud seam. +3 bowling.",
			"bonus": {"bowling": 3},
		},
		{
			"id": "pro_season_ball", "category": "ball", "name": "Pro Season Ball",
			"price": 1200, "tier": 3, "icon": "🔴",
			"description": "Match-grade leather, swings both ways. +6 bowling.",
			"bonus": {"bowling": 6},
		},
		{
			"id": "club_jersey", "category": "jersey", "name": "Club Jersey",
			"price": 250, "tier": 1, "icon": "🎽",
			"description": "Your mohalla colours. +2 fielding.",
			"bonus": {"fielding": 2},
		},
		{
			"id": "pro_jersey", "category": "jersey", "name": "Pro Jersey",
			"price": 900, "tier": 3, "icon": "🎽",
			"description": "Breathable pro kit, built for long days in the field. +4 fielding, +2 stamina.",
			"bonus": {"fielding": 4, "stamina": 2},
		},
		{
			"id": "street_shoes", "category": "shoes", "name": "Street Shoes",
			"price": 250, "tier": 1, "icon": "👟",
			"description": "Light canvas shoes for quick singles. +2 speed.",
			"bonus": {"speed": 2},
		},
		{
			"id": "spikes", "category": "shoes", "name": "Spikes",
			"price": 800, "tier": 3, "icon": "👟",
			"description": "Real cricket spikes. Grip the turf, fly between wickets. +4 speed, +2 stamina.",
			"bonus": {"speed": 4, "stamina": 2},
		},
		{
			"id": "cap", "category": "cap", "name": "Street Cap",
			"price": 200, "tier": 1, "icon": "🧢",
			"description": "Keeps the sun out of your eyes. +1 fielding, +1 stamina.",
			"bonus": {"fielding": 1, "stamina": 1},
		},
		{
			"id": "lucky_cap", "category": "cap", "name": "Lucky Cap",
			"price": 700, "tier": 2, "icon": "🧢",
			"description": "The cap you wore when you hit your first six. +3 fielding.",
			"bonus": {"fielding": 3},
		},
		{
			"id": "batting_gloves", "category": "gloves", "name": "Batting Gloves",
			"price": 600, "tier": 2, "icon": "🧤",
			"description": "Padded gloves for fearless strokeplay. +2 batting, +1 fielding.",
			"bonus": {"batting": 2, "fielding": 1},
		},
		{
			"id": "keeper_gloves", "category": "gloves", "name": "Keeper Gloves",
			"price": 1000, "tier": 3, "icon": "🥊",
			"description": "Pro keeping gloves that swallow edges. +3 fielding, +1 stamina.",
			"bonus": {"fielding": 3, "stamina": 1},
		},
	]


static func by_id(item_id: String) -> Dictionary:
	for item in items():
		if String(item.get("id", "")) == item_id:
			return item
	return {}
