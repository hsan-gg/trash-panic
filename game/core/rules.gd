class_name Rules
extends RefCounted
## SORT STORM's rules as data and pure functions (PLAN.md), shared by the host simulation and the tests.
## A giant Dropper machine rains waste into the room. Two workers carry it to the Recycling Machine's inputs to fill
## its orders, and deal with bombs, nuclear waste, leaking batteries and intruders before the pollution explodes.

const SHIFT_S := 180.0
const COUNTDOWN_S := 3.5
const STARS := [80, 200, 340]  ## v5: with the combo and the quests a decent team gets all three

## kind -> where it goes: a machine input (a material) or a special bin.
const ITEMS := {
	"can": {"dest": "metal"},
	"bottle": {"dest": "plastic"},
	"box": {"dest": "paper"},
	"paper": {"dest": "paper"},
	"plank": {"dest": "wood"},
	"jar": {"dest": "glass"},
	"apple": {"dest": "compost"},
	"peel": {"dest": "compost"},
	"rot": {"dest": "compost"},
	"board": {"dest": "circuit"},
	"cable": {"dest": "copper"},
	"bomb": {"dest": "chute"},
	"nuke": {"dest": "container"},
	"battery": {"dest": "batterybin"},
}
const BINS := ["chute", "container", "batterybin"]  ## emergency chute, shielded container, battery bin
const HAZARDS := ["bomb", "nuke", "battery"]

## THE MAPS (GAME_PLAN.md §2): one game, three maps. Each has its own room, look, machine inputs, waste, Dropper bag
## (animals and hazards), chaos and music, plus its own trouble run by Shift._tick_map(): ROT & ROLL rots food and
## tilts the floor, CIRCUIT BREAKERS trips the machine inputs. look: floor/water shader colours and the light: one
## dominant colour per map, a warm or cool key light against a complementary fill (sunny noon, golden hour, neon night).
const MAPS := [
	{"name": "THE SORTING FLOOR", "tag": "Sort the Dropper's mess before the factory blows!", "room": "sorting_room", "music": "match",
		"materials": ["metal", "plastic", "paper", "wood", "glass"],
		"waste": {"can": 3, "bottle": 3, "box": 2, "paper": 2, "plank": 2, "jar": 2},
		"drops": {"bomb": 3, "nuke": 2, "battery": 2, "raccoon": 2, "elephant": 1, "chicken": 2, "pig": 2},
		"chaos": ["blackout", "reverse", "hurricane", "lowgrav"],
		"look": {"light": {"bg": "16345E", "sun": "FFF1D6", "sun_e": 0.75, "sun_rot": [-62, 28], "fill": "8EC5FF", "fill_e": 0.35,
			"amb": "C8DCF5", "amb_e": 0.3, "exposure": 0.72, "sat": 1.2, "glow": 0.35,
			"contrast": 1.06, "brightness": 0.86, "ambience": true, "lamp": "FFC46A", "sparkle": "FFF2C0", "vignette": 0.7},
			"floor": {"white": "B9C6CC", "teal": "4E9FAA", "deep": "377F8C", "grout": "93A6AD"}}},
	{"name": "ROT & ROLL", "tag": "Food rots on the floor, and the floor keeps tilting!", "room": "rot_room", "music": "stage_1",
		"materials": ["metal", "plastic", "paper", "compost", "glass"],
		"waste": {"apple": 3, "peel": 3, "can": 2, "bottle": 2, "paper": 1, "jar": 1},
		"drops": {"bomb": 2, "nuke": 1, "battery": 1, "raccoon": 3, "pig": 3, "chicken": 3},
		"chaos": ["blackout", "reverse", "hurricane", "lowgrav"],
		"look": {"floor": {"white": "EADFB4", "teal": "8CC46A", "deep": "5E9440", "grout": "A8BE88"}, "water": {"deep": "1F3A22", "shallow": "3F6E36"},
			"light": {"bg": "2B2414", "sun": "FFB46B", "sun_e": 1.3, "sun_rot": [-34, 62], "fill": "B48CFF", "fill_e": 0.45,
				"amb": "FFE0B5", "amb_e": 0.5, "exposure": 0.92, "sat": 1.28, "glow": 0.6}}},
	{"name": "CIRCUIT BREAKERS", "tag": "E-waste! Inputs trip: hold ACTION to reset them!", "room": "circuit_room", "music": "stage_2",
		"materials": ["metal", "plastic", "circuit", "copper", "glass"],
		"waste": {"board": 3, "cable": 3, "can": 2, "bottle": 2, "jar": 1},
		"drops": {"bomb": 2, "nuke": 2, "battery": 4, "robot": 4, "raccoon": 2, "elephant": 1},
		"chaos": ["blackout", "reverse", "robots", "magnet"],
		"look": {"floor": {"white": "A9A6D6", "teal": "6F64D8", "deep": "4B3FB8", "grout": "8580C4"}, "water": {"deep": "0C1430", "shallow": "1F2E66"},
			"light": {"bg": "070B1F", "sun": "AFC0FF", "sun_e": 0.8, "sun_rot": [-72, -24], "fill": "FF4FD8", "fill_e": 0.6,
				"amb": "7080FF", "amb_e": 0.45, "exposure": 1.0, "sat": 1.32, "glow": 1.1}}},
]
## The map being played (set by set_map() before a shift; both phones play the host's pick).
static var map := 0
static var MATERIALS: Array = MAPS[0].materials  ## the machine's inputs, left to right
static var WASTE_WEIGHTS: Dictionary = MAPS[0].waste  ## what the Dropper rains down all shift long
static var DROP_WEIGHTS: Dictionary = MAPS[0].drops
static var CHAOS_MODS: Array = MAPS[0].chaos
## ROT & ROLL: food left lying this long rots (pollutes); every TILT_S the floor tips the other way and loose round
## waste rolls a tile downhill every ROLL_STEP_S (off the edge it's the shark's).
const FOOD := ["apple", "peel"]
const ROT_S := 12.0
const ROT_POLLUTION := 4
const ROUND := ["apple", "can", "bottle", "jar"]
const TILT_FIRST_S := 6.0
const TILT_S := 8.0  ## v5: the floor rolls often (user, 22 Nov)
const ROLL_STEP_S := 1.6
## CIRCUIT BREAKERS: now and then a machine input trips and takes nothing until someone holds USE on it.
const BREAKER_FIRST_S := 10.0
const BREAKER_GAP_S := 14.0
const BREAKER_GAP_RUSH_S := 9.0
const MAX_TRIPPED := 2
const THROW_TILES := 4
const BELT_STEP_S := 0.55  ## seconds for a belt to carry an item one tile
const BELT_STEP_RUSH_S := 0.35

## COMBO (GAME_PLAN.md §4): right deliveries less than COMBO_WINDOW_S apart chain; the chain multiplies their points.
const COMBO_WINDOW_S := 6.0
const COMBO_STEPS := [[10, 3.0], [6, 2.0], [3, 1.5]]  ## [chain length, multiplier], longest first
const QUEST_COINS := 40
const QUEST_SWAP_S := 2.5  ## a finished quest shows its stamp this long before a new one takes its place

const SORT_POINTS := 5
const WRONG_POINTS := 5
const HAZARD_POINTS := {"bomb": 10, "nuke": 15, "battery": 5}
const USE_TIME := {"repair": 2.5, "door": 1.2}
const DOOR_OPEN_S := 10.0
const JAM_RADIUS := 3.0  ## tiles: a blast this close jams the rail

## THE MACHINE'S ORDERS: deliver `need` items of a material before the card runs out.
const MAX_ORDERS := 3
const ORDER_BASE := 15
const ORDER_PER_ITEM := 8
const TIP_MAX := 15
const LATE_PENALTY := 10
const FINAL_CONTRACT_AT := 150.0  ## the last big order of the shift
const FINAL_NEED := 8
const FINAL_S := 10.0  ## the closing countdown moment
const FINAL_CONTRACT_S := 28.0
const FINAL_MULTIPLIER := 2

## DIFFICULTY (GAME_PLAN.md §3): the shift climbs a level every LEVEL_S, from calm to frantic. Index = level - 1.
const LEVEL_S := 36.0
const MAX_LEVEL := 5
const WASTE_GAPS := [4.4, 3.8, 3.2, 2.7, 2.2]  ## seconds between two pieces of waste
const DROP_GAPS := [20.0, 17.0, 14.0, 12.0, 10.0]  ## seconds between two specials
const HAZARD_CAPS := [1, 2, 2, 3, 3]  ## specials alive at once
const ORDER_GAPS := [14.0, 12.0, 10.0, 9.0, 8.0]
const BELT_STEPS := [0.6, 0.55, 0.5, 0.45, 0.4]
const WORKER_SPEEDS := [1.0, 1.08, 1.16, 1.24, 1.32]  ## workers speed up with the game
const RUSH_SPEED := 1.4

## RUSH HOUR: a 25 s window. Waste, orders and the Dropper speed up, and every point counts double.
const RUSH_FROM_S := 110.0
const RUSH_END_S := 135.0
const RUSH_MULTIPLIER := 2

## THE DROPPER: a worn-out machine over the room. Waste rains down all the time; now and then comes something worse,
## announced by a shadow and an alarm 1.8 s before it lands.
const LOOSE_MAX := 20  ## more loose waste than this on the floor pollutes the factory
const CLUTTER_POLLUTION := 0.35  ## meter per second for each item above LOOSE_MAX
const DROP_FIRST_S := 25.0
const DROP_TRAINING_FIRST_S := 70.0  ## the tutorial shift starts calm
const DROP_GAP_RUSH_S := 10.0
const DROP_WARN_S := 1.8
const BOMB_FUSE_S := 12
const LEAK_S := {"nuke": 35.0, "battery": 40.0}  ## left alone this long, they leak
const NUKE_SLOW := 0.55  ## speed while carrying nuclear waste
const BOMB_FREEZE_S := 2.5
const BOMB_RADIUS := 2.5  ## tiles: who freezes when it blows
const BLAST_PENALTY := 10
const LEAK_PENALTY := 10
const RESCUE_COINS := 30
const ROBOT_COINS := 20
const RACCOON_COINS := 10
## Catching the other intruders: the chicken knocks things off belts, the pig eats paper.
const CATCH_COINS := {"chicken": 5, "pig": 10}
const EAT_LOSS := 3  ## each piece of paper or cardboard the pig eats
const PIG_CHEW_S := 1.2
const RACCOON_LOSS := 3
const RACCOON_NIBBLE_S := 1.8  ## it stops to nibble the loot before running
## Seconds of USE it takes to deal with a creature (robot: switch it off, raccoon: catch it). The elephant is scared off instead.
const STUN_S := 1.5  ## DASH into an intruder: it stands dizzy this long (easy to catch)
const SHOO_S := {"robot": 2.0, "raccoon": 1.0, "elephant": 0.3, "chicken": 0.6, "pig": 1.0}
const ELEPHANT_SCARE_S := 2.5  ## how long one USE keeps it running for the exit
const CREATURE_SPEED := {"robot": 2.0, "raccoon": 3.0, "elephant": 1.1, "chicken": 3.4, "pig": 1.5}
const ELEPHANT_RUN := 2.6
## THE SHARK: it circles the platform; now and then it leaps over the outer wall at a tile along the edge (warned
## SHARK_WARN_S ahead) and drags waste there into the sea, biting any worker in reach (frozen, drops what they hold).
const SHARK_FIRST_S := 45.0
const SHARK_GAP_S := 28.0
const SHARK_GAP_RUSH_S := 16.0
const SHARK_WARN_S := 3.5  ## long enough to see the red squares and step out
const SHARK_LOSS := 3  ## per piece of waste lost to the sea
const SHARK_FREEZE_S := 1.4

## POLLUTION / CHAOS STATE: mistakes, disasters and clutter fill the meter; at 80 % the factory goes wild for 20 s.
const CHAOS_AT := 80.0
const CHAOS_S := 20.0
const CHAOS_FORCE_AT := 75.0  ## no chaos yet by now? one starts anyway: it is the mid-game twist
const CHAOS_END_GAP := 8.0  ## chaos always ends this long before the whistle
const LOWGRAV_THROW := 2  ## extra tiles a throw flies in LOW GRAVITY
const MAGNET_STEP_S := 0.6  ## MAGNETIC MADNESS pulls every loose can one tile toward the Dropper's magnet this often
const CHAOS_NAMES := {"blackout": "BLACKOUT", "reverse": "REVERSE WORLD", "hurricane": "HURRICANE", "robots": "ROBOT INVASION", "lowgrav": "LOW GRAVITY", "magnet": "MAGNETIC MADNESS"}
const CHAOS_AFTER := 30.0  ## meter left after a chaos state
const METER_DECAY := 1.8
const METER_PER_POINT := 1.1  ## every point lost fills the meter

## First-shift tutorial, one list per side (1 = left catcher, 2 = right machine worker). at: where the arrow points
## (a station type, "item" = waste on my side, "belt_in" = where the partner's belt arrives). done_on: cues that finish
## the step; "held": this player picked something up; seconds: shown for that long.
const TUTORIAL := {
	1: [
		{"text": "Waste rains from the DROPPER! Walk to it and press GRAB.", "at": "item", "held": true},
		{"text": "The machine is on your partner's side. Follow the arrow: drop it on the BELT.", "at": "item", "done_on": ["belt", "catch"]},
		{"text": "Your partner sends you bombs, barrels and batteries: their bins are on YOUR side. Follow the arrow!", "at": "chute", "seconds": 9.0},
	],
	2: [
		{"text": "Your partner sends waste on the BELT. Grab it where the belt ends.", "at": "belt_in", "held": true},
		{"text": "Follow the arrow: each material has its own machine input.", "at": "bunker", "done_on": ["load"]},
		{"text": "Fill the ORDERS (top right) for big points! Bombs and barrels fall on YOUR side: put them on the lower belt.", "at": "bunker", "seconds": 10.0},
	],
}


static func set_map(n: int) -> void:
	map = clampi(n, 0, MAPS.size() - 1)
	MATERIALS = MAPS[map].materials
	WASTE_WEIGHTS = MAPS[map].waste
	DROP_WEIGHTS = MAPS[map].drops
	CHAOS_MODS = MAPS[map].chaos


static func breaker_gap(elapsed: float) -> float:
	return BREAKER_GAP_RUSH_S if is_rush(elapsed) else BREAKER_GAP_S


static func dest(kind: String) -> String:
	return ITEMS.get(kind, {}).get("dest", "")


## Loading a machine input of `material`: right only when the item belongs there.
static func clean_load(kind: String, material: String) -> bool:
	return dest(kind) == material


static func bin_ok(kind: String, bin: String) -> bool:
	return dest(kind) == bin


static func tip(time_left: float, duration: float) -> int:
	return int(round(TIP_MAX * clampf(time_left / duration, 0.0, 1.0)))


## What a finished order pays: a base, a bonus per item, and a tip for speed.
static func order_coins(need: int, time_left: float, duration: float) -> int:
	return ORDER_BASE + need * ORDER_PER_ITEM + tip(time_left, duration)


static func combo_mult(chain: int) -> float:
	for step in COMBO_STEPS:
		if chain >= step[0]:
			return step[1]
	return 1.0


## Points for a right delivery: the base, doubled in RUSH HOUR, times the combo multiplier.
static func award(base: int, elapsed: float, chain: int) -> int:
	return roundi(base * rush_mult(elapsed) * combo_mult(chain))


static func is_rush(elapsed: float) -> bool:
	return elapsed >= RUSH_FROM_S and elapsed < RUSH_END_S


## Points for correct recycling double during RUSH HOUR.
static func rush_mult(elapsed: float) -> int:
	return RUSH_MULTIPLIER if is_rush(elapsed) else 1


static func stars(coins: int) -> int:
	var n := 0
	for threshold in STARS:
		if coins >= threshold:
			n += 1
	return n


## Seconds between two drops of ordinary waste.
static func level(elapsed: float) -> int:
	return mini(MAX_LEVEL, 1 + int(elapsed / LEVEL_S))


static func worker_speed(elapsed: float) -> float:
	return RUSH_SPEED if is_rush(elapsed) else WORKER_SPEEDS[level(elapsed) - 1]


static func waste_gap(elapsed: float) -> float:
	return 1.8 if is_rush(elapsed) else WASTE_GAPS[level(elapsed) - 1]


static func belt_step(elapsed: float) -> float:
	return BELT_STEP_RUSH_S if is_rush(elapsed) else BELT_STEPS[level(elapsed) - 1]


## Seconds between the machine's new orders.
static func order_interval(elapsed: float) -> float:
	return 7.0 if is_rush(elapsed) else ORDER_GAPS[level(elapsed) - 1]


static func drop_gap(elapsed: float) -> float:
	return DROP_GAP_RUSH_S if is_rush(elapsed) else DROP_GAPS[level(elapsed) - 1]


static func max_hazards(elapsed: float) -> int:
	return HAZARD_CAPS[level(elapsed) - 1]


static func order_material(rng: RandomNumberGenerator) -> String:
	return MATERIALS[rng.randi() % MATERIALS.size()]


static func waste(rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in WASTE_WEIGHTS:
		total += WASTE_WEIGHTS[k]
	var roll := rng.randi() % total
	for k in WASTE_WEIGHTS:
		roll -= WASTE_WEIGHTS[k]
		if roll < 0:
			return k
	return "can"
