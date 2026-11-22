class_name Scoreboard
extends RefCounted
## Who did what this shift, from the Shift's cues (both phones see the same cues): points, sorts, catches,
## fixes and oopsies per worker. At the end it ranks the workers and hands each a silly title.

const MISTAKES := ["wrong"]
## stat -> title for the worker who leads it (first free one wins, so two workers never share a title)
const TITLES := [
	["load", "SULTAN OF SORTING"], ["ship", "ORDER OVERLORD"], ["catch", "ANIMAL WHISPERER"],
	["safe", "BOMB HUGGER"], ["fix", "DUCT TAPE WIZARD"], ["oops", "CAPTAIN BUTTERFINGERS"],
]
const FALLBACK := ["PROFESSIONAL NAPPER", "EMOTIONAL SUPPORT"]

var _rows := {}  ## player id -> {pts, load, ship, catch, safe, fix, oops}


func track(e: Dictionary) -> void:
	var who: int = e.get("who", -1)
	if who < 0:
		return
	var r: Dictionary = _rows.get(who, {"pts": 0, "load": 0, "ship": 0, "catch": 0, "safe": 0, "fix": 0, "oops": 0})
	r.pts += int(e.get("pts", 0))
	match str(e.e):
		"load", "ship", "safe":
			r[e.e] += 1
		"rescued", "robot_down":
			r.catch += 1
		"repaired":
			r.fix += 1
		"wrong":
			r.oops += 1
	_rows[who] = r


func row(id: int) -> Dictionary:
	return _rows.get(id, {"pts": 0, "load": 0, "ship": 0, "catch": 0, "safe": 0, "fix": 0, "oops": 0})


## Player ids, best score first.
func ranking(ids: Array) -> Array:
	var out := ids.duplicate()
	out.sort_custom(func(a: int, b: int) -> bool: return row(a).pts > row(b).pts)
	return out


## One title per worker: the stat they lead (and actually did), else a consolation prize.
func titles(ids: Array) -> Dictionary:
	var out := {}
	var taken := {}
	for pair in TITLES:
		var best := -1
		for id in ids:
			if out.has(id) or row(id)[pair[0]] <= 0:
				continue
			if best < 0 or row(id)[pair[0]] > row(best)[pair[0]]:
				best = id
		if best >= 0 and not taken.has(pair[1]):
			out[best] = pair[1]
			taken[pair[1]] = true
	var spare := 0
	for id in ids:
		if not out.has(id):
			out[id] = FALLBACK[spare % FALLBACK.size()]
			spare += 1
	return out


## This worker's line for the HALL OF FAME: their points, rank and title, and the partner's name and points.
func summary(players: Dictionary, my_id: int) -> Dictionary:
	var ids := ranking(players.keys())
	var partner: int = ids.filter(func(id: int) -> bool: return id != my_id).front() if ids.size() > 1 else -1
	return {"mine": row(my_id).pts, "rank": ids.find(my_id) + 1, "title": titles(ids).get(my_id, ""),
		"partner": str(players[partner].name) if partner >= 0 else "", "partner_pts": row(partner).pts if partner >= 0 else 0}


## The results table: a row per worker with medal, name, title, points and what they did.
func build(players: Dictionary, my_id: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var ids := ranking(players.keys())
	var names := titles(ids)
	for rank in ids.size():
		var id: int = ids[rank]
		var r := row(id)
		var panel := PanelContainer.new()
		var style := Look.pill(Color("3A3F4A") if id != my_id else Color("4A4230"), 16)
		style.set_border_width_all(3)
		style.border_color = Look.YELLOW if rank == 0 else Color(1, 1, 1, 0.5)
		style.content_margin_left = 14
		style.content_margin_right = 14
		panel.add_theme_stylebox_override("panel", style)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		panel.add_child(line)
		line.add_child(Look.label(["1ST", "2ND", "3RD", "4TH"][mini(rank, 3)], 30, Look.YELLOW if rank == 0 else Look.WHITE, true))
		var who := VBoxContainer.new()
		who.add_theme_constant_override("separation", -4)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.add_child(Look.label(str(players[id].name).to_upper(), 26, Look.ORANGE if rank == 0 else Look.SKY, true))
		var detail := "%s  ·  %d sorted  %d caught  %d fixed  %d oops" % [names[id], r.load, r.catch, r.fix, r.oops]
		var sub := Look.label(detail, 16, Look.MINT)
		who.add_child(sub)
		for l: Label in [who.get_child(0), sub]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.add_child(who)
		line.add_child(Look.label("%d" % r.pts, 38, Look.WHITE, true))
		box.add_child(panel)
	return box
