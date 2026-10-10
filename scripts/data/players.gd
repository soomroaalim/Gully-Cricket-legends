class_name GCLPlayers
extends RefCounted
## Player generation: starter team, opponents, recruitables.

static var _counter: int = 0

const FIRST_NAMES: Array = ["Ahmed", "Bilal", "Usman", "Danish", "Fahad", "Hassan",
	"Imran", "Junaid", "Kamran", "Noman", "Rashid", "Salman", "Tariq", "Waqas",
	"Yasir", "Zubair", "Adeel", "Farhan", "Sajid", "Naveed"]
const AVATAR_COUNT: int = 8


static func _next_id() -> String:
	_counter += 1
	return "p_%d_%d" % [GCLRng.random_seed() % 100000, _counter]


static func _build(name: String, role: String, stats: Dictionary, avatar: int, is_user: bool = false) -> Dictionary:
	var p: Dictionary = {
		"id": _next_id(), "name": name, "role": role,
		"batting": stats.get("batting", 50), "bowling": stats.get("bowling", 50),
		"fielding": stats.get("fielding", 50), "speed": stats.get("speed", 50),
		"stamina": stats.get("stamina", 50),
		"level": 1, "xp": 0, "avatar": avatar % AVATAR_COUNT, "is_user": is_user,
		"jersey": 0, "cap": 0, "shoes": 0, "bat_skin": 0,
	}
	p["overall"] = GCLConfig.overall_of(p)
	# v3.0: every newly created player carries development fields, so fresh
	# careers and post-reset teams never need a separate migration pass.
	GCLDevelopment.ensure_player_dev(p)
	return p


static func make_starter_team(user_name: String, avatar: int) -> Array:
	var nm: String = user_name.strip_edges()
	if nm.is_empty():
		nm = "Haroon"
	var team: Array = [
		_build(nm, "Batter",
			{"batting": 58, "bowling": 45, "fielding": 50, "speed": 52, "stamina": 50},
			avatar, true),
		_build("Ahmed", "Batter",
			{"batting": 55, "bowling": 40, "fielding": 48, "speed": 55, "stamina": 48}, 1),
		_build("Bilal", "Bowler",
			{"batting": 42, "bowling": 56, "fielding": 50, "speed": 52, "stamina": 55}, 2),
		_build("Usman", "AllRounder",
			{"batting": 52, "bowling": 50, "fielding": 52, "speed": 50, "stamina": 52}, 3),
		_build("Danish", "Wicketkeeper",
			{"batting": 48, "bowling": 35, "fielding": 58, "speed": 54, "stamina": 50}, 4),
	]
	return team


static func generate_opponent_team(stage: Dictionary, rng: GCLRng) -> Array:
	var lo: int = int(stage["ai_overall"][0])
	var hi: int = int(stage["ai_overall"][1])
	var roles: Array = ["Batter", "Bowler", "AllRounder", "Wicketkeeper", "Batter"]
	var team_names: Array = stage.get("team_names", ["Gully XI"])
	var team: Array = []
	var used: Dictionary = {}
	for i in 5:
		var target: int = rng.int_range(lo, hi)
		# Retry until overall lands in range.
		var p: Dictionary = {}
		for _t in 40:
			var stats: Dictionary = {
				"batting": rng.int_range(35, 90), "bowling": rng.int_range(35, 90),
				"fielding": rng.int_range(35, 90), "speed": rng.int_range(35, 90),
				"stamina": rng.int_range(35, 90),
			}
			var ov: int = GCLConfig.overall_of(stats)
			if ov >= lo and ov <= hi:
				var fname: String = str(rng.pick(FIRST_NAMES))
				while used.has(fname):
					fname = str(rng.pick(FIRST_NAMES))
				used[fname] = true
				p = _build(fname, roles[i % roles.size()], stats, rng.int_range(0, AVATAR_COUNT - 1))
				p["overall"] = ov
				break
		if p.is_empty():
			p = _build("Player%d" % (i + 1), roles[i % roles.size()],
				{"batting": target, "bowling": target, "fielding": target,
					"speed": target, "stamina": target}, i)
		team.append(p)
	return team


static func recruits() -> Array:
	var defs: Array = [
		{"id": "rec_local_1", "name": "Aslam", "role": "Batter", "overall": 50,
			"price": 200, "min_stage_index": 0, "avatar": 5},
		{"id": "rec_local_2", "name": "Kashif", "role": "Bowler", "overall": 51,
			"price": 200, "min_stage_index": 0, "avatar": 6},
		{"id": "rec_good_1", "name": "Shahid", "role": "AllRounder", "overall": 60,
			"price": 600, "min_stage_index": 1, "avatar": 2},
		{"id": "rec_good_2", "name": "Rafiq", "role": "Wicketkeeper", "overall": 61,
			"price": 600, "min_stage_index": 1, "avatar": 7},
		{"id": "rec_strong_1", "name": "Majid", "role": "Batter", "overall": 70,
			"price": 1500, "min_stage_index": 2, "avatar": 1},
		{"id": "rec_strong_2", "name": "Tanveer", "role": "Bowler", "overall": 71,
			"price": 1500, "min_stage_index": 2, "avatar": 3},
		{"id": "rec_elite_1", "name": "Javed Miandad Jr.", "role": "Batter", "overall": 82,
			"price": 3500, "min_stage_index": 3, "avatar": 0},
		{"id": "rec_elite_2", "name": "Wasim Junior", "role": "Bowler", "overall": 83,
			"price": 3500, "min_stage_index": 3, "avatar": 4},
	]
	return defs


static func build_recruit(def: Dictionary) -> Dictionary:
	var ov: int = int(def["overall"])
	var spread: Dictionary = {"Batter": "batting", "Bowler": "bowling",
		"Wicketkeeper": "fielding", "AllRounder": "batting"}
	var stats: Dictionary = {"batting": ov - 4, "bowling": ov - 4, "fielding": ov - 4,
		"speed": ov - 4, "stamina": ov - 4}
	stats[spread.get(str(def["role"]), "batting")] = ov + 4
	var p: Dictionary = _build(str(def["name"]), str(def["role"]), stats,
		int(def.get("avatar", 0)))
	p["overall"] = GCLConfig.overall_of(stats)
	return p
