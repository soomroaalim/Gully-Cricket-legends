class_name GCLRng
extends RefCounted
## Seeded deterministic RNG (mulberry32). All match simulation draws from this
## so matches are reproducible and AI cannot cheat — outcomes derive from
## stats + player input + the seeded stream only.

var _s: int = 0x9E3779B9


func _init(seed_value: int = 0) -> void:
	_s = seed_value if seed_value != 0 else 0x9E3779B9


## Float in [0, 1).
func next() -> float:
	_s = (_s + 0x6D2B79F5) & 0xFFFFFFFF
	var t: int = _s
	t = (t ^ (t >> 15)) & 0xFFFFFFFF
	t = (t * (t | 1)) & 0xFFFFFFFF
	t = (t ^ (t + (((t ^ (t >> 7)) & 0xFFFFFFFF) * (t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0


## Int in [min_v, max_v] inclusive.
func int_range(min_v: int, max_v: int) -> int:
	return min_v + int(next() * float(max_v - min_v + 1))


func pick(arr: Array):
	return arr[int(next() * arr.size())]


func weighted(items: Array, weights: Array) -> Variant:
	var total: float = 0.0
	for w in weights:
		total += maxf(0.0, float(w))
	var r: float = next() * total
	for i in items.size():
		r -= maxf(0.0, float(weights[i]))
		if r <= 0.0:
			return items[i]
	return items[items.size() - 1]


## Roughly normal in [-1, 1].
func normal() -> float:
	return (next() + next() + next() - 1.5) / 1.5


static func random_seed() -> int:
	return int(Time.get_unix_time_from_system() * 1000) & 0x7FFFFFFF
