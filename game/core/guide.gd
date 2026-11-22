class_name Guide
extends RefCounted
## Where should this go? Used for the arrow over the right station whenever a worker carries something (always on,
## not only in the tutorial): its own bin or machine input if this worker can reach it, else the belt that carries
## things to the partner's side.


## The tile to bring item `kind` to, for a worker whose walkable side is `area`; null when nowhere fits.
static func target(shift: Shift, area: Dictionary, kind: String) -> Variant:
	var room := shift.room
	var dest := Rules.dest(kind)
	for at in room.tiles:
		var t: String = room.tiles[at]
		if ((t == "bunker" and room.bunker_material(at) == dest) or t == dest) and touches(area, at):
			return at
	return outgoing_belt(shift, area)


## The free belt tile next to this side whose belt carries things away from it (respects REVERSE WORLD).
static func outgoing_belt(shift: Shift, area: Dictionary) -> Variant:
	var room := shift.room
	var flip := -1 if shift.mayhem.chaos == "reverse" else 1
	var best: Variant = null
	for at: Vector2i in room.belts:
		var next: Vector2i = at + Vector2i(room.belts[at] * flip, 0)
		if not room.belts.has(next) or not touches(area, at) or touches(area, _end(room, at, room.belts[at] * flip)):
			continue
		if shift.items_at(at).is_empty() and (best == null or shift.items_at(best).size() > 0):
			best = at
	return best


## The last tile of the belt through `at`, following direction `dir`.
static func _end(room: RoomMap, at: Vector2i, dir: int) -> Vector2i:
	var end := at
	while room.belts.has(end + Vector2i(dir, 0)):
		end += Vector2i(dir, 0)
	return end


## The belt end that brings things to this side (where the partner's deliveries arrive).
static func incoming_belt(shift: Shift, area: Dictionary) -> Variant:
	var flip := -1 if shift.mayhem.chaos == "reverse" else 1
	for at: Vector2i in shift.room.belts:
		var dir: int = shift.room.belts[at] * flip
		if not shift.room.belts.has(at + Vector2i(dir, 0)) and touches(area, at):
			return at
	return null


static func touches(area: Dictionary, at: Vector2i) -> bool:
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if area.has(at + d):
			return true
	return false


## The icon of a destination, for the carry arrow (same icons as the bins' signs).
static func glyph(shift: Shift, at: Vector2i) -> String:
	match shift.room.type_at(at):
		"bunker":
			return StationArt.MATERIAL_GLYPHS[shift.room.bunker_material(at)]
		"chute":
			return "bomb"
		"container":
			return "nuke"
		"batterybin":
			return "battery"
	return "reverse"  # the belt over to the partner
