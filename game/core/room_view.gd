class_name RoomView
extends Node3D
## Draws a room from its RoomMap (Kenney Factory Kit look) and mirrors a Shift every frame: items, station
## progress, bunker lamps, fires. `holder_point` maps a player id to where carried items sit.

signal cue(e: Dictionary)

var room: RoomMap
var shift: Shift
var decor := RoomDecor.new()
var art := StationArt.new()
var creatures := CreatureView.new()
var shark := SharkView.new()
var solo := false
var holder_point: Callable  ## func(pid: int) -> Vector3, or Vector3.INF if unknown

var _items := {}  ## id -> {node, key}
var _bars := {}  ## Vector2i -> [background, fill, centre]
var _marker: Node3D  ## the bobbing arrow: where to go next
var _marker_tween: Tween
var _marker_at: Variant = null
var _jams := {}  ## rail Vector2i -> warning sign
var _highlight := MeshInstance3D.new()
var _gate_body: Node  ## the gate's collision, removed when play goes solo
var _belt_scroll := 0.0
var _white: ImageTexture


func build(p_room: RoomMap, p_shift: Shift, p_solo: bool) -> void:
	room = p_room
	shift = p_shift
	solo = p_solo
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(img)
	decor.build(room)
	add_child(decor)
	creatures.setup(room, shift)
	add_child(creatures)
	shark.setup(room)
	add_child(shark)
	art.build(self, room, solo)
	_solids()
	var hl := BoxMesh.new()
	hl.size = Vector3(RoomMap.TILE * 0.98, 0.04, RoomMap.TILE * 0.98)
	_highlight.mesh = hl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(Look.MINT, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight.material_override = mat
	_highlight.visible = false
	add_child(_highlight)


## Outline the tile the local worker faces, so GRAB is never ambiguous.
func highlight(at: Variant) -> void:
	_highlight.visible = at != null and room.type_at(at) != "wall" and (room.type_at(at) != "floor" or not shift.items_at(at).is_empty())
	if _highlight.visible:
		_highlight.position = room.world(at) + Vector3(0, _top(at) + 0.03, 0)


func _process(_delta: float) -> void:
	if shift == null:
		return
	_sync_items()
	_sync_stations()
	for e in shift.cues:
		_play(e)
		cue.emit(e)
	shift.cues.clear()


# ── static geometry ──────────────────────────────────────────────────────────

## The partner left: the gate counter disappears so one worker can reach both sides.
func open_gate() -> void:
	solo = true
	for n in art.gate_nodes:
		n.queue_free()
	art.gate_nodes.clear()
	if _gate_body != null:
		_gate_body.queue_free()
		_gate_body = null


## Collision for everything you can't walk on, as a few big boxes (RoomMap.solid_rects): one box per tile left
## seams that workers snagged on along walls and belts. The gate keeps its own box (it opens when play goes solo).
func _solids() -> void:
	for r: Rect2i in room.solid_rects(solo):
		var body := _box_body(r.position, r.size)
		if room.type_at(r.position) == "gate":
			_gate_body = body


func _box_body(at: Vector2i, size: Vector2i) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x * RoomMap.TILE, 2.0, size.y * RoomMap.TILE)
	cs.shape = shape
	body.add_child(cs)
	body.position = (room.world(at) + room.world(at + size - Vector2i.ONE)) / 2.0 + Vector3(0, 0.6, 0)
	add_child(body)
	return body


func _top(at: Vector2i) -> float:
	return 0.0 if room.walkable(at, solo) else StationArt.top(room.type_at(at))


# ── dynamic state ────────────────────────────────────────────────────────────

## Items follow an anchor (a tile slot or a worker's hands). A new anchor is reached with a hop, or a
## higher arc for long moves (throws); a changed look (crushed, rinsed) keeps the item where it was.
func _sync_items() -> void:
	for id in _items.keys():
		if not shift.items.has(id):
			_items[id].node.queue_free()
			_items.erase(id)
	for id in shift.items:
		var it: Dictionary = shift.items[id]
		var key := "%s:%s" % [it.k, it.s]
		var anchor := ("h%d" % it.by) if it.by >= 0 else ("t%s" % str(it.at))
		if not _items.has(id) or _items[id].key != key:
			var node := ItemArt.make(it.k, it.s)
			add_child(node)
			if _items.has(id):
				node.global_position = _items[id].node.global_position
				_items[id].node.queue_free()
			elif it.at != null:
				node.global_position = decor.mouth_for(_slot(id, it.at))  # spat out by the Dropper
			Juice.squash3d(node)
			_items[id] = {"node": node, "key": key, "anchor": "", "arc": {}}
		var entry: Dictionary = _items[id]
		var node: Node3D = entry.node
		node.get_node("carry").visible = it.by >= 0  # carried: a ring in its bin's colour
		if it.by >= 0:
			var hold: Vector3 = holder_point.call(it.by) if holder_point.is_valid() else Vector3.INF
			if hold != Vector3.INF:
				node.global_position = node.global_position.lerp(hold, 0.6)
			entry.anchor = anchor
		elif it.at != null:
			var target := _slot(id, it.at)
			if entry.anchor != anchor:
				var riding: bool = entry.anchor.begins_with("t") and room.type_at(it.at) in ["belt", "floor"] and node.global_position.distance_to(target) < RoomMap.TILE * 1.2
				entry.anchor = anchor
				var dist := node.global_position.distance_to(target)
				if riding:  # carried along by a belt (or rolling, or pulled by the magnet): slide, no hop
					entry.arc = {"from": node.global_position, "t": 0.0, "d": Rules.belt_step(shift.elapsed), "h": 0.0, "slide": true}
				else:
					entry.arc = {"from": node.global_position, "t": 0.0, "d": clampf(0.14 + dist * 0.05, 0.14, 0.55), "h": 0.2 + dist * 0.18}
			node.global_position = _arc_step(entry, target)


func _arc_step(entry: Dictionary, target: Vector3) -> Vector3:
	var arc: Dictionary = entry.arc
	if arc.is_empty():
		return target
	arc.t += get_process_delta_time()
	var k := clampf(arc.t / arc.d, 0.0, 1.0)
	if k >= 1.0:
		if not arc.get("slide", false):
			Juice.squash3d(entry.node)
		entry.arc = {}
		return target
	return arc.from.lerp(target, k) + Vector3(0, sin(k * PI) * arc.h, 0)


func _slot(id: int, at: Vector2i) -> Vector3:
	var p := room.world(at) + Vector3(0, _top(at), 0)
	var here := shift.items_at(at)
	if here.size() > 1:
		var i := here.find(id)
		p.x += (i - (here.size() - 1) / 2.0) * 0.38
	return p


func _sync_stations() -> void:
	for at in shift.stations:
		var st: Dictionary = shift.stations[at]
		var need: float = Rules.USE_TIME.repair if st.jam else Rules.USE_TIME.door
		_bar(at, clampf(st.p / need, 0.0, 1.0) if st.p > 0.0 else -1.0)
		_set_jam(at, st.jam)
		if art.doors.has(at):
			var open: bool = st.t > 0.0
			var door: MeshInstance3D = art.doors[at]
			door.position.y = lerpf(door.position.y, 2.2 if open else 0.9, 0.2)
			var shade := Kit.material(Color("2FBF5A") if open else Color("D8343C"))
			if door.material_override != shade:
				door.material_override = shade
	_sync_belts()
	for at in art.lamps:  # a lamp lights for each item the machine still wants of that material
		var material := room.bunker_material(at)
		var wanted := 0
		for o in shift.orders:
			if o.m == material:
				wanted += o.need - o.got
		var lamps: Array = art.lamps[at]
		for i in 3:
			var lit := Kit.material(Look.YELLOW if i < wanted else Color("20242E"))
			if lamps[i].material_override != lit:
				lamps[i].material_override = lit


## Belts scroll at the simulation's speed (backwards in REVERSE WORLD) and flash red while a tile is jammed.
func _sync_belts() -> void:
	var flip := -1.0 if shift.mayhem.chaos == "reverse" else 1.0
	var running := shift.elapsed > 0.0 and not shift.finished()
	_belt_scroll += get_process_delta_time() * flip / Rules.belt_step(shift.elapsed) * (1.0 if running else 0.0)
	for b in art.belts:
		var jammed: bool = b.tiles.any(func(t: Vector2i) -> bool: return shift.stations.has(t) and shift.stations[t].jam)
		b.mat.set_shader_parameter("offset", _belt_scroll * (0.0 if jammed else 1.0))
		b.mat.set_shader_parameter("jam", 1.0 if jammed else 0.0)


func _set_jam(at: Vector2i, on: bool) -> void:
	if on and not _jams.has(at):
		_jams[at] = _icon(room.world(at) + Vector3(0, _top(at) + 0.9, 0), "warning", 0.004)
	elif not on and _jams.has(at):
		_jams[at].queue_free()
		_jams.erase(at)


func _bar(at: Vector2i, value: float) -> void:
	if not _bars.has(at):
		if value < 0.0:
			return
		var base := room.world(at) + Vector3(0, _top(at) + 1.15, 0)
		var bg := _sprite(Color("14102E"), Vector2(0.9, 0.16))
		bg.position = base
		var fill := _sprite(Look.MINT, Vector2(0.86, 0.11))
		fill.render_priority = 1
		add_child(bg)
		add_child(fill)
		_bars[at] = [bg, fill, base]
	var bar: Array = _bars[at]
	bar[0].visible = value >= 0.0
	bar[1].visible = value >= 0.0
	if value >= 0.0:
		bar[1].scale.x = maxf(0.01, 0.86 * value)
		bar[1].position = bar[2] + Vector3(-0.43 * (1.0 - value), 0, 0.02)


## Bobbing arrow above where to go next: the destination's icon on a disc of its colour over a triangle; null hides it.
func mark(at: Variant, glyph := "", color := Look.YELLOW) -> void:
	if at == null:
		if _marker != null:
			_marker.visible = false
		return
	if _marker == null:
		_marker = Node3D.new()
		add_child(_marker)
		var tip := Sprite3D.new()  # an icon, not a font character: the game fonts have no arrow glyphs
		tip.name = "tip"
		tip.texture = Look.glyph("down")
		tip.pixel_size = 0.5 / 256.0
		tip.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tip.no_depth_test = true
		tip.render_priority = 3
		tip.shaded = false
		_marker.add_child(tip)
		var badge := StationArt.sign_node("recycle", Color.WHITE, 0.7, Vector3(0, 0.62, 0))
		badge.name = "badge"
		_marker.add_child(badge)
	var badge: Sprite3D = _marker.get_node("badge")
	badge.visible = glyph != ""
	if glyph != "":
		badge.modulate = color
		(badge.get_node("icon") as Sprite3D).texture = Look.glyph(glyph)
	(_marker.get_node("tip") as Sprite3D).modulate = color
	_marker.visible = true
	var base: Vector3 = room.world(at) + Vector3(0, _top(at) + 0.5, 0)
	if _marker_at == at:
		return
	_marker_at = at
	_marker.position = base
	if _marker_tween != null:
		_marker_tween.kill()
	_marker_tween = _marker.create_tween().set_loops()
	_marker_tween.tween_property(_marker, "position:y", base.y + 0.35, 0.45).from(base.y).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play(e: Dictionary) -> void:
	var at: Variant = e.get("at")
	var p: Vector3 = room.world(at) + Vector3(0, _top(at) + 0.3, 0) if at != null else Vector3.ZERO
	if e.has("pts") and at != null:
		_score_popup(p + Vector3(0, 0.4, 0), int(e.pts))
	match e.e:
		"load":
			Fx.burst(self, p, ItemArt.MATERIAL_COLORS.get(str(e.get("m", "")), Look.MINT), 12)
			_wobble(art.hoppers.get(at))
		"ship":
			Fx.burst(self, p, Look.YELLOW, 30)
			for h in art.hoppers.values():
				_wobble(h, 0.25)
		"safe":
			Fx.burst(self, p, Look.MINT, 24)
		"wrong", "reject":
			Fx.burst(self, p, Look.PINK, 14)
		"fall":
			Fx.puff(self, p)
			decor.burp()
		"jam":
			Fx.burst(self, p, Look.ORANGE, 24)
		"repaired", "door_open":
			Fx.puff(self, p)
		"drop_alert":
			creatures.telegraph(at, str(e.k))
			decor.rattle()
		"drop":
			Fx.puff(self, p)
			Fx.burst(self, p, Look.YELLOW, 14)
		"boom":
			Fx.burst(self, p, Look.ORANGE, 40)
			Fx.burst(self, p, Color.WHITE, 16)
			Fx.puff(self, p)
			_blast_flash(p)
		"leak":
			Fx.burst(self, p, Color("3DFF5A"), 30)
		"robot_down", "rescued":
			Fx.burst(self, p, Look.MINT, 30)
		"steal", "raccoon_gone":
			Fx.puff(self, p)
		"shark_alert":
			shark.alert(at)
			creatures.telegraph(at, "shark")
			_danger_zone(at)
		"shark":
			shark.bite(at)
		"rush":
			decor.rush = true
		"rush_end":
			decor.rush = false


## "+5" / "-10" rising from where it happened, so every point has a visible cause.
func _score_popup(at: Vector3, points: int) -> void:
	var l := Label3D.new()
	l.text = ("+%d" if points > 0 else "%d") % points
	l.font = load(Look.FONT_DISPLAY)
	l.font_size = 64 if absi(points) >= 20 else 44
	l.pixel_size = 0.006
	l.outline_size = 14
	l.modulate = Look.MINT if points > 0 else Look.PINK
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at
	add_child(l)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", at.y + 1.3, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.5)
	t.chain().tween_callback(l.queue_free)


## The shark's bite zone: flashing red squares on exactly the tiles it will hit. Step out and you're safe.
func _danger_zone(at: Vector2i) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.12, 0.08, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var zone := Node3D.new()
	add_child(zone)
	for d in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not room.walkable(at + d, solo):
			continue
		var tile := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(RoomMap.TILE * 0.92, 0.03, RoomMap.TILE * 0.92)
		tile.mesh = box
		tile.material_override = mat
		tile.position = room.world(at + d) + Vector3(0, 0.02, 0)
		zone.add_child(tile)
	var t := zone.create_tween().set_loops(int(Rules.SHARK_WARN_S / 0.3))
	t.tween_property(mat, "albedo_color:a", 0.35, 0.15)
	t.tween_property(mat, "albedo_color:a", 0.85, 0.15)
	get_tree().create_timer(Rules.SHARK_WARN_S + 0.2).timeout.connect(zone.queue_free)


## A comic shout over a worker or a spot: pops up big, wobbles, floats away ("HOT HOT HOT!", "OUCH!!").
func shout(at: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = load(Look.FONT_DISPLAY)
	l.font_size = 64
	l.pixel_size = 0.006
	l.outline_size = 18
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 3
	l.position = at + Vector3(0, 2.3, 0)
	l.scale = Vector3.ONE * 0.2
	l.rotation_degrees.z = randf_range(-8.0, 8.0)
	add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.6)
	t.set_parallel()
	t.tween_property(l, "position:y", l.position.y + 0.8, 0.4)
	t.tween_property(l, "modulate:a", 0.0, 0.4)
	t.chain().tween_callback(l.queue_free)


## A cartoon explosion puff that blooms and fades where the bomb went off.
func _blast_flash(at: Vector3) -> void:
	var s := Sprite3D.new()
	s.texture = Look.emoji("collision")
	s.pixel_size = 0.004
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	s.position = at + Vector3(0, 0.8, 0)
	s.scale = Vector3.ONE * 0.3
	add_child(s)
	var t := s.create_tween().set_parallel()
	t.tween_property(s, "scale", Vector3.ONE * 1.6, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, 0.3).set_delay(0.35)
	t.chain().tween_callback(s.queue_free)


func _wobble(node: Node3D, amount := 0.15) -> void:
	if node == null:
		return
	var base := Vector3.ONE
	var t := node.create_tween()
	t.tween_property(node, "scale", base * Vector3(1.0 + amount, 1.0 - amount, 1.0 + amount), 0.07)
	t.tween_property(node, "scale", base * Vector3(1.0 - amount * 0.5, 1.0 + amount * 0.5, 1.0 - amount * 0.5), 0.09)
	t.tween_property(node, "scale", base, 0.12)


func _box(parent: Node3D, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = Kit.material(color)
	mi.position = center
	parent.add_child(mi)
	return mi


func _icon(at: Vector3, emoji: String, size: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = Look.emoji(emoji)
	s.pixel_size = size
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.position = at
	add_child(s)
	return s


func _sprite(color: Color, size: Vector2) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = _white
	s.modulate = color
	s.pixel_size = 1.0 / 4.0
	s.scale = Vector3(size.x, size.y, 1)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	return s
