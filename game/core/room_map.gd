class_name RoomMap
extends RefCounted
## A room parsed from ASCII (rooms/*.txt). One char per tile; `#` lines starting a file are comments.
## Legend: # wall · . floor · = counter · | divider rail · g gate (rail in co-op, floor in solo)
## M machine input · K emergency chute · R shielded container · B battery bin · e exit door · 1 / 2 player spawns
## > < conveyor belt carrying items right / left.

const TILE := 1.2
const STATIONS := {
	"=": "counter", "|": "divider", "g": "gate", "M": "bunker", "K": "chute", "R": "container", "B": "batterybin", "e": "exit",
	">": "belt", "<": "belt",
}

var width := 0
var height := 0
var tiles := {}  ## Vector2i -> station type, "floor" or "wall"
var spawns := {}  ## 1/2 -> Vector2i
var bunkers: Array[Vector2i] = []  ## the machine inputs, left to right: metal, plastic, paper, wood, glass
var belts := {}  ## Vector2i -> +1 (carries right) or -1 (carries left)


static func parse(text: String) -> RoomMap:
	var m := RoomMap.new()
	var rows := Array(text.split("\n")).filter(func(l: String) -> bool: return l.strip_edges() != "" and not l.begins_with("# "))
	m.height = rows.size()
	for z in rows.size():
		var row: String = rows[z]
		m.width = maxi(m.width, row.length())
		for x in row.length():
			var c := row[x]
			var at := Vector2i(x, z)
			if c == "1" or c == "2":
				m.spawns[int(c)] = at
				m.tiles[at] = "floor"
			elif c == ".":
				m.tiles[at] = "floor"
			elif STATIONS.has(c):
				m.tiles[at] = STATIONS[c]
				if c == "M":
					m.bunkers.append(at)
				elif m.tiles[at] == "belt":
					m.belts[at] = 1 if c == ">" else -1
			else:
				m.tiles[at] = "wall"
	return m


static func load_room(room_name: String) -> RoomMap:
	return parse(FileAccess.get_file_as_string("res://rooms/%s.txt" % room_name))


func type_at(at: Vector2i) -> String:
	return tiles.get(at, "wall")


func walkable(at: Vector2i, solo: bool) -> bool:
	var t := type_at(at)
	return t == "floor" or (solo and t == "gate")


func world(at: Vector2i) -> Vector3:
	return Vector3((at.x - (width - 1) / 2.0) * TILE, 0.0, (at.y - (height - 1) / 2.0) * TILE)


## The same as world() for a creature walking between tiles.
func world_f(x: float, y: float) -> Vector3:
	return Vector3((x - (width - 1) / 2.0) * TILE, 0.0, (y - (height - 1) / 2.0) * TILE)


func tile_of(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / TILE + (width - 1) / 2.0), roundi(pos.z / TILE + (height - 1) / 2.0))


func bunker_material(at: Vector2i) -> String:
	var i := bunkers.find(at)
	return Rules.MATERIALS[i] if i >= 0 and i < Rules.MATERIALS.size() else ""


## Floor tiles reachable from `from` (4-neighbour flood fill).
func reachable(from: Vector2i, solo: bool) -> Dictionary:
	var seen := {from: true}
	var todo := [from]
	while not todo.is_empty():
		var at: Vector2i = todo.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = at + d
			if not seen.has(n) and walkable(n, solo):
				seen[n] = true
				todo.append(n)
	return seen


## Station types a player standing in `area` can touch (adjacent, 4 directions).
func stations_touching(area: Dictionary) -> Dictionary:
	var out := {}
	for at in area:
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var t := type_at(at + d)
			if t != "floor" and t != "wall":
				out[t] = true
	return out


## Every tile you can't walk on, merged greedily into rectangles (rows first, then grown down) so collision has no
## seams between neighbouring tiles. The gate always gets a rectangle of its own.
func solid_rects(solo: bool) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var used := {}
	var blocks := func(at: Vector2i) -> bool:
		return tiles.has(at) and not walkable(at, solo) and not used.has(at) and type_at(at) != "gate"
	for y in height:
		for x in width:
			var at := Vector2i(x, y)
			if used.has(at) or not tiles.has(at) or walkable(at, solo):
				continue
			if type_at(at) == "gate":
				used[at] = true
				out.append(Rect2i(at, Vector2i.ONE))
				continue
			var w := 1
			while blocks.call(at + Vector2i(w, 0)):
				w += 1
			var h := 1
			while range(w).all(func(i: int) -> bool: return blocks.call(at + Vector2i(i, h))):
				h += 1
			for dy in h:
				for dx in w:
					used[at + Vector2i(dx, dy)] = true
			out.append(Rect2i(at, Vector2i(w, h)))
	return out


## Problems that make the room unplayable; empty when it's fine (PLAN.md).
func problems() -> Array:
	var out := []
	if not spawns.has(1) or not spawns.has(2):
		return ["needs spawns 1 and 2"]
	if bunkers.size() != Rules.MATERIALS.size():
		out.append("needs %d machine inputs" % Rules.MATERIALS.size())
	var left := reachable(spawns[1], false)
	var right := reachable(spawns[2], false)
	if left.has(spawns[2]):
		out.append("co-op: the divider must separate the players")
	var team := stations_touching(left)
	team.merge(stations_touching(right))
	for kind in Rules.WASTE_WEIGHTS.keys() + Rules.HAZARDS:  # what this chapter's Dropper can send
		var dest := Rules.dest(kind)
		var need := "bunker" if dest in Rules.MATERIALS else dest
		if not team.has(need):
			out.append("%s has no route: missing %s" % [kind, need])
	if not stations_touching(left).has("exit") or not stations_touching(right).has("exit"):
		out.append("both sides need an exit door for the elephant")
	if not stations_touching(left).has("divider") or not stations_touching(right).has("divider"):
		out.append("both sides must reach the divider to hand items over")
	for at in belts:
		if belts.has(at - Vector2i(belts[at], 0)):
			continue  # only check each belt once, from its first tile
		var run := [at]
		while belts.has(run[-1] + Vector2i(belts[at], 0)):
			run.append(run[-1] + Vector2i(belts[at], 0))
		var from_left := run.any(func(b: Vector2i) -> bool: return _touches(left, b))
		var from_right := run.any(func(b: Vector2i) -> bool: return _touches(right, b))
		if not from_left or not from_right:
			out.append("the belt at %s must connect both sides" % at)
	if not reachable(spawns[1], true).has(spawns[2]):
		out.append("solo: the gate must join both sides")
	return out


func _touches(area: Dictionary, at: Vector2i) -> bool:
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if area.has(at + d):
			return true
	return false
