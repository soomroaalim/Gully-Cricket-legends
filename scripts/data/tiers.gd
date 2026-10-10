class_name GCLTiers
extends RefCounted
## Competition ladder (v2.0). Data-driven: one definition per tier, one
## generator for teams. Colony tier is fully playable (20 generated teams);
## higher tiers are scaffolded with honest "not yet playable" states.
##
## Naming rule: a LOCATION is not a team. Team names always carry a suffix
## ("XI", "Strikers", ...) and are never the bare location name.

const SUFFIXES: Array = ["XI", "Strikers", "Kings", "Gladiators", "Titans",
	"Mavericks", "Warriors", "Blasters", "Legends", "Challengers"]


static func all() -> Array:
	return [
		{
			"id": "colony", "name": "Colony Cricket", "team_count": 20,
			"playable": true, "ai_overall": [45, 58], "tier_factor": 0.6,
			"blurb": "Street cricket in the neighbourhoods. Every legend starts here.",
			"promotion": {
				"next": "city", "label": "Earn promotion to City Cricket",
				"requires": [
					{"id": "mainxi", "label": "Secure a place in the main XI"},
					{"id": "trophy", "label": "Win the Soomra Street Cup"},
					{"id": "matches", "label": "Play 3 main-XI matches"},
				],
			},
		},
		{
			"id": "city", "name": "City Cricket", "team_count": 20,
			"playable": false, "ai_overall": [55, 65], "tier_factor": 0.5,
			"blurb": "The city's best street teams. Faster, sharper, less forgiving.",
			"promotion": {"next": "district", "label": "Earn promotion to District Cricket", "requires": []},
		},
		{
			"id": "district", "name": "District Cricket", "team_count": 20,
			"playable": false, "ai_overall": [62, 72], "tier_factor": 0.45,
			"blurb": "District-level competition. Semi-professional setups.",
			"promotion": {"next": "provincial", "label": "Earn promotion to Provincial Cricket", "requires": []},
		},
		{
			"id": "provincial", "name": "Provincial Cricket", "team_count": 5,
			"playable": false, "ai_overall": [70, 80], "tier_factor": 0.4,
			"blurb": "Five provincial sides. The step before the big leagues.",
			"promotion": {"next": "national", "label": "Earn promotion to National Cricket", "requires": []},
		},
		{
			"id": "national", "name": "National Cricket", "team_count": 20,
			"playable": false, "ai_overall": [75, 88], "tier_factor": 0.35,
			"blurb": "Franchise-style national competition. Original fictional teams.",
			"promotion": {"next": "international", "label": "Earn an international call-up", "requires": []},
		},
		{
			"id": "international", "name": "International Cricket", "team_count": 0,
			"playable": false, "ai_overall": [82, 95], "tier_factor": 0.3,
			"blurb": "Separate men's and women's pathways. The ultimate stage.",
			"pathways": ["men", "women"],
			"promotion": {"next": "", "label": "", "requires": []},
		},
	]


static func by_id(tid: String) -> Dictionary:
	for t in all():
		if str(t.get("id", "")) == tid:
			return t
	return {}


static func index_of(tid: String) -> int:
	var tiers: Array = all()
	for i in tiers.size():
		if str(tiers[i].get("id", "")) == tid:
			return i
	return -1


## Fictional Sindh neighbourhood / town names used as team locations.
static func colony_locations() -> Array:
	return ["Soomra Colony", "Gulshan-e-Ravi", "Model Town", "Shah Faisal Colony",
		"North Nazimabad", "Latifabad", "Qasimabad", "Saddar Town", "Clifton Block",
		"Malir Halt", "Landhi Town", "Korangi Crossing", "New Karachi", "Orangi Town",
		"FB Area", "Gulberg Town", "Scheme 33", "Bahria Enclave", "DHA Phase 6",
		"Johar Town"]


## Deterministic team generation for a tier (seeded — same input, same teams).
## Each team: {id, name, location, overall_lo/hi, roster (5 players)}.
## Only the colony tier generates full rosters; others get names + ratings.
static func generate_teams(tier_id: String, seed: int = 0) -> Array:
	var tier: Dictionary = by_id(tier_id)
	if tier.is_empty():
		return []
	var rng := GCLRng.new(seed if seed != 0 else absi(hash(tier_id)))
	var count: int = int(tier.get("team_count", 0))
	var lo: int = int(tier.get("ai_overall", [50, 60])[0])
	var hi: int = int(tier.get("ai_overall", [50, 60])[1])
	var locs: Array = colony_locations() if tier_id == "colony" else []
	var teams: Array = []
	for i in count:
		var loc: String = str(locs[i % locs.size()]) if not locs.is_empty() else ("Side %d" % (i + 1))
		# Location is never the team name: always a suffix.
		var suffix: String = str(SUFFIXES[(i + int(rng.next() * 7)) % SUFFIXES.size()])
		var tname: String = "%s %s" % [loc, suffix]
		var team: Dictionary = {
			"id": "%s_%d" % [tier_id, i],
			"name": tname, "location": loc,
			"overall_lo": lo, "overall_hi": hi,
			"roster": [],
		}
		if bool(tier.get("playable", false)):
			team["roster"] = _gen_roster(lo, hi, rng)
		teams.append(team)
	return teams


static func _gen_roster(lo: int, hi: int, rng: GCLRng) -> Array:
	var roles: Array = ["Batter", "Bowler", "AllRounder", "Wicketkeeper", "Batter"]
	var names: Array = GCLPlayers.FIRST_NAMES.duplicate()
	# Fisher-Yates with our seeded RNG (Array.shuffle() is not seeded).
	for i in range(names.size() - 1, 0, -1):
		var j: int = rng.int_range(0, i)
		var tmp: Variant = names[i]
		names[i] = names[j]
		names[j] = tmp
	var roster: Array = []
	for i in 5:
		var target: int = rng.int_range(lo, hi)
		var stats: Dictionary = {
			"batting": rng.int_range(35, 90), "bowling": rng.int_range(35, 90),
			"fielding": rng.int_range(35, 90), "speed": rng.int_range(35, 90),
			"stamina": rng.int_range(35, 90),
		}
		# Nudge the primary stat toward the tier target.
		var role: String = str(roles[i % roles.size()])
		var prim: String = {"Batter": "batting", "Bowler": "bowling",
			"Wicketkeeper": "fielding", "AllRounder": "batting"}.get(role, "batting")
		stats[prim] = clampi(target + rng.int_range(-6, 6), 30, 99)
		var p: Dictionary = GCLPlayers._build(str(names[i % names.size()]), role, stats,
			rng.int_range(0, GCLPlayers.AVATAR_COUNT - 1))
		roster.append(p)
	return roster
