class_name StationArt
extends RefCounted
## Builds the stations of a room in the Trash-is-Fun look: chunky charcoal machines with coloured panels, chevron
## belts through a machine housing, hazard pads, round icon badges on the floor and curved yellow floor arrows.
## Returns the handles RoomView animates.

const BELT := preload("res://core/shaders/belt.gdshader")
const CHARCOAL := Color("3A3F48")
const DARK := Color("23262D")
const STEEL := Color("C9D1DA")
const HAZARD := Color("FFC21A")
const ARROW := Color("FFD23A")
const BELT_H := 0.62
## Where items sit on top of each station type (metres).
const TOPS := {"bunker": 1.2, "chute": 0.95, "container": 0.95, "batterybin": 0.95, "divider": 0.9, "gate": 0.9, "counter": 0.9, "belt": BELT_H + 0.05}
const BIN_LOOK := {
	"chute": {"color": ItemArt.BIN_COLORS.chute, "glyph": "bomb"},
	"container": {"color": ItemArt.BIN_COLORS.container, "glyph": "nuke"},
	"batterybin": {"color": ItemArt.BIN_COLORS.batterybin, "glyph": "battery"},
}
const MATERIAL_GLYPHS := {"metal": "metal", "plastic": "plastic", "paper": "paper", "wood": "wood", "glass": "glass",
	"compost": "compost", "circuit": "circuit", "copper": "copper"}

var lamps := {}  ## bunker Vector2i -> [3 lamp meshes]
var doors := {}  ## exit Vector2i -> roller door panel
var hoppers := {}  ## bunker Vector2i -> Node3D that wobbles when fed
var belts := []  ## [{tiles: Array[Vector2i], mat: ShaderMaterial, dir: int}]
var gate_nodes: Array[Node] = []

var _root: Node3D
var _room: RoomMap


func build(root: Node3D, room: RoomMap, solo: bool) -> void:
	_root = root
	_room = room
	for at in room.tiles:
		match room.tiles[at]:
			"divider":
				_handoff(at)
			"gate":
				if not solo:
					_handoff(at, true)
			"counter":
				_block(room.world(at), Vector3(1.16, 0.9, 1.16), CHARCOAL, STEEL)
			"bunker":
				_input(at)
			"chute", "container", "batterybin":
				_bin(at, room.tiles[at])
			"exit":
				_door(at)
			"wall":
				if at.x > 0 and at.x < room.width - 1 and at.y > 0 and at.y < room.height - 1:
					_block(room.world(at), Vector3(1.2, 1.6, 1.2), CHARCOAL, Color("4A505B"))
	_machine_body()
	_belts()
	for at in hoppers:
		Bake.children(hoppers[at], lamps[at])
	Bake.children(_root, doors.values() + gate_nodes)  # every static station part in one draw call


static func top(type: String) -> float:
	return TOPS.get(type, 0.0)


# ── machines ─────────────────────────────────────────────────────────────────

## The RECYCLING MACHINE: one long charcoal body against the back wall; each input is a hopper mouth with its
## material's colour panel, three demand lamps and a badge on the floor.
func _machine_body() -> void:
	if _room.bunkers.is_empty():
		return
	var a := _room.world(_room.bunkers[0])
	var b := _room.world(_room.bunkers[-1])
	var c := (a + b) / 2.0
	var span := b.x - a.x + 1.3
	_block(c + Vector3(0, 0, -0.75), Vector3(span, 2.3, 0.6), CHARCOAL, Color("4A505B"))
	for i in 3:  # exhaust stacks
		var stack := _cyl(c + Vector3((i - 1) * span / 3.0, 2.6, -0.8), 0.18, 0.7, Color("596273"))
		stack.name = "stack"
	_sign(c + Vector3(0, 2.25, -0.6), "recycle", Color("4ADE3A"), 0.9)


func _input(at: Vector2i) -> void:
	var p := _room.world(at)
	var material := _room.bunker_material(at)
	var color: Color = ItemArt.MATERIAL_COLORS[material]
	var hop := Node3D.new()
	hop.position = p
	_root.add_child(hop)
	hoppers[at] = hop
	_block(Vector3.ZERO, Vector3(1.12, 1.1, 1.0), CHARCOAL, Color("4A505B"), hop)
	_box(Vector3(0, 1.12, 0), Vector3(0.8, 0.06, 0.7), DARK, hop)  # the mouth
	_box(Vector3(0, 0.6, 0.51), Vector3(0.9, 0.5, 0.04), color, hop)  # colour panel
	_glyph(Vector3(0, 0.6, 0.54), MATERIAL_GLYPHS[material], 0.36, Color.WHITE, false, hop)
	var row := []
	for i in 3:
		row.append(_box(Vector3((i - 1) * 0.26, 0.2, 0.52), Vector3(0.18, 0.1, 0.04), DARK, hop))
	lamps[at] = row
	_sign(p + Vector3(0, 1.55, 0.3), MATERIAL_GLYPHS[material], color)
	_badge(_front(at), MATERIAL_GLYPHS[material], color)


func _bin(at: Vector2i, type: String) -> void:
	var p := _room.world(at)
	var look: Dictionary = BIN_LOOK[type]
	_block(p, Vector3(1.05, 0.9, 1.05), look.color, Color(look.color).lightened(0.25))
	_box(p + Vector3(0, 0.92, 0), Vector3(0.8, 0.04, 0.8), DARK)
	for i in 4:  # hazard chevrons on the front
		var s := _box(p + Vector3(-0.36 + i * 0.24, 0.3, 0.53), Vector3(0.1, 0.22, 0.02), DARK if i % 2 == 0 else HAZARD)
		s.rotation_degrees.z = 30
	_glyph(p + Vector3(0, 0.62, 0.54), look.glyph, 0.42, Color.WHITE, false)
	_sign(p + Vector3(0, 1.3, 0.3), look.glyph, look.color)
	_badge(_front(at), look.glyph, look.color)


## The hand-off rail on the divider: a steel counter with hazard-striped edges.
func _handoff(at: Vector2i, gate := false) -> void:
	var p := _room.world(at)
	var nodes := _block(p, Vector3(1.0, 0.9, 1.16), CHARCOAL, STEEL)
	for dx in [-0.5, 0.5]:
		nodes.append(_box(p + Vector3(dx, 0.88, 0), Vector3(0.06, 0.04, 1.16), HAZARD))
	if gate:
		gate_nodes.append_array(nodes)


## An exit door: a red roller door in a yellow frame; it rolls up (and turns green) while open.
func _door(at: Vector2i) -> void:
	var p := _room.world(at)
	doors[at] = _box(p + Vector3(0, 0.9, 0), Vector3(0.18, 1.8, 1.08), Color("D8343C"))
	_badge(_front(at), "elephant", Color("8C9BAD"))


# ── belts ────────────────────────────────────────────────────────────────────

func _belts() -> void:
	for at in _room.belts:
		var dir: int = _room.belts[at]
		if _room.belts.has(at - Vector2i(dir, 0)):
			continue
		var run: Array[Vector2i] = [at]
		while _room.belts.has(run[-1] + Vector2i(dir, 0)):
			run.append(run[-1] + Vector2i(dir, 0))
		_belt(run, dir)


func _belt(run: Array[Vector2i], dir: int) -> void:
	var a := _room.world(run[0])
	var b := _room.world(run[-1])
	var c := (a + b) / 2.0
	var length := absf(b.x - a.x) + RoomMap.TILE
	_box(c + Vector3(0, BELT_H / 2.0 - 0.05, 0), Vector3(length, BELT_H - 0.1, 1.0), DARK)
	var surface := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(length, 0.9)
	surface.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = BELT
	mat.set_shader_parameter("dir", float(dir))
	mat.set_shader_parameter("tiles", float(run.size()))
	surface.material_override = mat
	surface.position = c + Vector3(0, BELT_H, 0)
	_root.add_child(surface)
	for end: Vector3 in [a, b]:  # yellow/black hazard caps at both ends
		var x := end.x + signf(end.x - c.x) * (RoomMap.TILE / 2.0 + 0.08)
		_box(Vector3(x, BELT_H / 2.0, c.z), Vector3(0.16, BELT_H, 1.04), HAZARD)
		for i in 3:
			_box(Vector3(x + signf(end.x - c.x) * 0.081, BELT_H / 2.0, c.z - 0.34 + i * 0.34), Vector3(0.01, BELT_H * 0.8, 0.12), DARK)
	for at in run:  # a machine housing where the belt crosses the divider
		if _room.type_at(at + Vector2i.UP) == "divider" or _room.type_at(at + Vector2i.DOWN) == "divider":
			var p := _room.world(at)
			_box(p + Vector3(0, 1.25, 0), Vector3(1.1, 0.7, 1.15), CHARCOAL)
			for dx in [-0.5, 0.5]:
				_box(p + Vector3(dx, 0.95, 0), Vector3(0.14, 0.7, 1.15), CHARCOAL)
			_box(p + Vector3(0, 1.3, 0.58), Vector3(0.5, 0.3, 0.03), Color("2FBF5A") if dir > 0 else Color("4C7CF0"))
	belts.append({"tiles": run, "mat": mat, "dir": dir})
	var upstream := a - Vector3(dir * RoomMap.TILE * 1.6, 0, 0)
	var downstream := b + Vector3(dir * RoomMap.TILE * 1.4, 0, 0)
	var toward := -1.0 if c.z < 0.0 else 1.0  # curve toward the wall the belt runs along
	_arrow(upstream + Vector3(0, 0, -toward * 1.1), upstream + Vector3(dir * 0.3, 0, 0), a - Vector3(dir * 0.75, 0, 0))
	_arrow(b + Vector3(dir * 0.75, 0, 0.0), downstream, downstream + Vector3(dir * 0.2, 0, toward * 1.0))


# ── floor paint ──────────────────────────────────────────────────────────────

## A round floor badge: dark disc, coloured ring, white glyph (the refs' station markers).
func _badge(at: Vector3, glyph: String, ring: Color) -> void:
	_cyl(at + Vector3(0, 0.012, 0), 0.36, 0.02, DARK)
	var r := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.33
	torus.outer_radius = 0.4
	r.mesh = torus
	r.material_override = Kit.material(ring)
	r.position = at + Vector3(0, 0.02, 0)
	r.scale = Vector3(1, 0.12, 1)
	_root.add_child(r)
	_glyph(at + Vector3(0, 0.03, 0), glyph, 0.42, Color.WHITE, true)


## A curved painted arrow on the floor through three points (quadratic Bézier) with an arrowhead.
func _arrow(from: Vector3, ctrl: Vector3, to: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 14
	var width := 0.11
	var pts: Array[Vector3] = []
	for i in steps + 1:
		var t := float(i) / steps * 0.82
		pts.append(from.lerp(ctrl, t).lerp(ctrl.lerp(to, t), t))
	for i in steps:
		var d := (pts[i + 1] - pts[i]).normalized()
		var n := Vector3(-d.z, 0, d.x) * width
		_quad(st, pts[i] - n, pts[i] + n, pts[i + 1] + n, pts[i + 1] - n)
	var tip_dir := (to - pts[-1]).normalized()
	var side := Vector3(-tip_dir.z, 0, tip_dir.x) * width * 2.6
	st.add_vertex(pts[-1] - side)
	st.add_vertex(to)
	st.add_vertex(pts[-1] + side)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ARROW
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.6
	mi.material_override = mat
	mi.position.y = 0.015
	_root.add_child(mi)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


## The floor point just in front of a station (the first walkable neighbour), for its badge.
func _front(at: Vector2i) -> Vector3:
	for d in [Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT]:
		if _room.walkable(at + d, false):
			return _room.world(at) + Vector3(d.x, 0, d.y) * RoomMap.TILE * 0.62
	return _room.world(at)


# ── primitives ───────────────────────────────────────────────────────────────

## A chunky block: dark plinth, body, lighter top cap (fakes a bevel from above). Returns its meshes.
func _block(at: Vector3, size: Vector3, body: Color, cap: Color, parent: Node3D = null) -> Array:
	var host := parent if parent else _root
	var base_y := at.y if parent == null else 0.0
	var origin := Vector3(at.x, base_y, at.z) if parent == null else Vector3.ZERO
	return [
		_box(origin + Vector3(0, 0.06, 0), Vector3(size.x + 0.04, 0.12, size.z + 0.04), DARK, host),
		_box(origin + Vector3(0, size.y / 2.0, 0), size - Vector3(0, 0.02, 0), body, host),
		_box(origin + Vector3(0, size.y - 0.02, 0), Vector3(size.x - 0.1, 0.06, size.z - 0.1), cap, host),
	]


func _box(center: Vector3, size: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = Kit.material(color)
	mi.position = center
	(parent if parent else _root).add_child(mi)
	return mi


func _cyl(center: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mi.mesh = mesh
	mi.material_override = Kit.material(color)
	mi.position = center
	_root.add_child(mi)
	return mi


func _glyph(at: Vector3, id: String, size: float, color: Color, flat: bool, parent: Node3D = null) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = Look.glyph(id)
	s.pixel_size = size / 256.0
	s.modulate = color
	s.shaded = false
	s.position = at
	if flat:
		s.rotation_degrees.x = -90
	(parent if parent else _root).add_child(s)
	return s


## A sign over a bin: just its icon on a disc of its colour (no words: icons read faster mid-panic).
func _sign(at: Vector3, glyph: String, color: Color, size := 0.6) -> void:
	_root.add_child(sign_node(glyph, color, size, at))


## The icon-on-a-disc sign used over bins and on the carry arrow.
static func sign_node(glyph: String, color: Color, size: float, at := Vector3.ZERO) -> Sprite3D:
	var disc := Sprite3D.new()
	disc.texture = Look.disc()
	disc.pixel_size = size / 64.0
	disc.modulate = color
	disc.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	disc.shaded = false
	disc.no_depth_test = true
	disc.render_priority = 1
	disc.position = at
	var icon := Sprite3D.new()
	icon.name = "icon"
	icon.texture = Look.glyph(glyph)
	icon.pixel_size = size * 0.67 / 256.0
	icon.modulate = Look.INK
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.shaded = false
	icon.no_depth_test = true
	icon.render_priority = 2
	disc.add_child(icon)
	return disc
