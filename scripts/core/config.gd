class_name GCLConfig
extends RefCounted
## Global constants for Gully Cricket Legends.

const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://gcl_save_v1.json"

const VIEW_W: int = 960
const VIEW_H: int = 540

# Timing windows in milliseconds (offset of input vs ball arrival at hitting zone).
const TIMING_PERFECT_MS: float = 60.0
const TIMING_GOOD_MS: float = 120.0
const TIMING_OK_MS: float = 250.0

const MODE_CONFIG: Dictionary = {
	"1v1": {"overs": 2, "max_wickets": 3, "players": 1, "label": "1v1 · 2 overs"},
	"2v2": {"overs": 3, "max_wickets": 5, "players": 2, "label": "2v2 · 3 overs"},
	"5v5": {"overs": 6, "max_wickets": 5, "players": 5, "label": "5v5 · 6 overs"},
	"gully6": {"overs": 6, "max_wickets": 5, "players": 5, "label": "6-Over Gully Match"},
}

const DIFFICULTIES: Array[String] = ["EASY", "NORMAL", "HARD", "LEGEND"]

const SHOT_TAP: String = "tap"
const SHOT_LEFT: String = "swipeLeft"
const SHOT_RIGHT: String = "swipeRight"
const SHOT_UP: String = "swipeUp"


static func xp_for_level(level: int) -> int:
	return 100 + (level - 1) * 150


static func overall_of(stats: Dictionary) -> int:
	var w: float = float(stats.get("batting", 50)) * 0.35 \
		+ float(stats.get("bowling", 50)) * 0.30 \
		+ float(stats.get("fielding", 50)) * 0.20 \
		+ float(stats.get("speed", 50)) * 0.075 \
		+ float(stats.get("stamina", 50)) * 0.075
	return clampi(int(round(w)), 1, 99)
