class_name Quests
extends RefCounted
## The shift's three QUESTS (GAME_PLAN.md §4): picked from the map's pool with the seed, counted from the Shift's
## cues on the host, sent to the guest in the globals. Each one done pays Rules.QUEST_COINS and, after a moment,
## makes way for a new random quest that asks a little more: they never run out.

## kind -> {text (%d = need), need, cue: the event that counts, m: only loads of this material count}
const POOL := {
	"sort": {"text": "Sort %d items right", "need": 20, "cue": "load", "icon": "recycle"},
	"orders": {"text": "Fill %d orders", "need": 4, "cue": "ship", "icon": "factory"},
	"hazards": {"text": "Make %d hazards safe", "need": 3, "cue": "safe", "icon": "bomb"},
	"catch": {"text": "Catch %d intruders", "need": 2, "cue": "rescued", "icon": "raccoon"},
	"combo": {"text": "Reach a %d combo", "need": 6, "cue": "", "icon": "light"},
	"fix": {"text": "Fix %d jams or breakers", "need": 2, "cue": "repaired", "icon": "repair"},
	"compost": {"text": "Compost %d food scraps", "need": 6, "cue": "load", "m": "compost", "icon": "compost"},
}
const BY_MAP := [
	["sort", "orders", "hazards", "catch", "combo", "fix"],
	["sort", "orders", "catch", "combo", "compost"],
	["sort", "orders", "hazards", "combo", "fix"],
]

var list: Array = []  ## [{k, need, got}] in display order
var done := 0  ## quests finished this shift
var _swap := {}  ## index of a finished quest -> seconds until it is replaced (host)


## Three different quests for this shift (a seeded pick, so both phones would agree even before a sync).
func pick(seed: int, map: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7 + 3
	var pool: Array = BY_MAP[map].duplicate()
	list.clear()
	done = 0
	_swap.clear()
	for i in 3:
		var k: String = pool.pop_at(rng.randi() % pool.size())
		list.append({"k": k, "need": POOL[k].need, "got": 0})


## Host: finished quests are replaced by a different random kind than the ones on screen, each harder than the last.
func tick(dt: float, rng: RandomNumberGenerator, map: int) -> void:
	for i in _swap.keys():
		_swap[i] -= dt
		if _swap[i] > 0.0:
			continue
		_swap.erase(i)
		var shown := list.map(func(q: Dictionary) -> String: return q.k)
		var pool: Array = BY_MAP[map].filter(func(k: String) -> bool: return k not in shown)
		var k: String = pool[rng.randi() % pool.size()]
		var need: int = POOL[k].need + done / 2 if k == "combo" else ceili(POOL[k].need * (1.0 + 0.25 * done))
		list[i] = {"k": k, "need": need, "got": 0}


## Count a Shift cue; returns the indices of the quests it just finished.
func on_cue(e: Dictionary, combo: int) -> Array:
	var finished := []
	for i in list.size():
		var q: Dictionary = list[i]
		if q.got >= q.need:
			continue
		var spec: Dictionary = POOL[q.k]
		if q.k == "combo":
			q.got = maxi(q.got, mini(combo, q.need))
		elif spec.cue != "" and e.e == spec.cue and (not spec.has("m") or e.get("m", "") == spec.m) and (e.e != "rescued" or e.get("k", "") != ""):
			q.got += 1
		elif q.k == "catch" and e.e == "robot_down":
			q.got += 1
		if q.got >= q.need:
			finished.append(i)
			done += 1
			_swap[i] = Rules.QUEST_SWAP_S
	return finished


func done_count() -> int:
	return done


static func text(q: Dictionary) -> String:
	return POOL[q.k].text % q.need


## [[k, need, got] x3, done]
func pack() -> Array:
	return list.map(func(q: Dictionary) -> Array: return [q.k, q.need, q.got]) + [done]


func unpack(rows: Array) -> void:
	list.clear()
	for r in rows.slice(0, 3):
		if r is Array and r.size() == 3 and POOL.has(str(r[0])):
			list.append({"k": str(r[0]), "need": int(r[1]), "got": int(r[2])})
	done = int(rows[-1]) if not rows.is_empty() and (rows[-1] is float or rows[-1] is int) else 0
