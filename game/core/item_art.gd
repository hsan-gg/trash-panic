class_name ItemArt
extends RefCounted
## Chunky procedural props in the Trash-is-Fun style: one strong colour per material so every item reads from the
## overhead camera at phone size. The bomb follows design/refs/bomb_prop.jpg (purple-black, green LCD, coloured wires).

const MATERIAL_COLORS := {"metal": Color("C9CED8"), "plastic": Color("FFD93D"), "paper": Color("4CC9F0"), "wood": Color("C8874A"), "glass": Color("3DDC97"),
	"compost": Color("A0703A"), "circuit": Color("4C8DF0"), "copper": Color("E2725B")}  ## the last three: chapters 2 and 3
const SCALE := 1.45
## The hazard bins' colours; with MATERIAL_COLORS every destination has its own, used by the bin, its sign, the
## ring around a carried item and the arrow to where it goes.
const BIN_COLORS := {"chute": Color("E0393E"), "container": Color("9B5CF0"), "batterybin": Color("FF8C1A")}

static var _baked := {}  ## kind -> ArrayMesh of its flat-coloured parts


static func make(kind: String, state: String) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "body"
	root.add_child(body)
	match kind:
		"can": _can(body)
		"bottle": _bottle(body)
		"box": _cardboard(body)
		"paper": _newspaper(body)
		"plank": _planks(body)
		"jar": _jar(body)
		"bomb": _bomb(body, state)
		"nuke": _barrel(body)
		"battery": _battery(body)
		"apple": _apple(body)
		"peel": _peel(body)
		"rot": _rot(body)
		"board": _board(body)
		"cable": _cable(body)
	_bake(body, kind)
	_blob(root, 0.3 if kind not in ["plank", "nuke"] else 0.38)
	_carry_ring(root, kind)
	body.scale = Vector3.ONE * SCALE
	return root


static func _can(r: Node3D) -> void:
	_cyl(r, 0.15, 0.34, Color("D5DAE2"), Vector3(0, 0.17, 0))  # a tin can: metal grey like the METAL input
	_cyl(r, 0.152, 0.12, Color("8D96A3"), Vector3(0, 0.19, 0))
	_cyl(r, 0.13, 0.03, Color("C9CED8"), Vector3(0, 0.355, 0))
	_box(r, Vector3(0.08, 0.015, 0.03), Color("8D96A3"), Vector3(0.03, 0.375, 0))  # ring pull


static func _bottle(r: Node3D) -> void:
	_cyl(r, 0.14, 0.32, Color("CFEFFF"), Vector3(0, 0.16, 0))  # clear plastic, yellow label: the PLASTIC input's colour
	_cyl(r, 0.145, 0.12, Color("FFD93D"), Vector3(0, 0.17, 0))  # label
	var neck := _cyl(r, 0.06, 0.12, Color("CFEFFF"), Vector3(0, 0.38, 0))
	(neck.mesh as CylinderMesh).bottom_radius = 0.14
	_cyl(r, 0.065, 0.06, Color("FFD93D"), Vector3(0, 0.46, 0))


static func _cardboard(r: Node3D) -> void:
	_box(r, Vector3(0.5, 0.36, 0.42), Color("C98B4E"), Vector3(0, 0.18, 0))
	_box(r, Vector3(0.12, 0.005, 0.43), Color("4CC9F0"), Vector3(0, 0.362, 0))  # blue tape: it's PAPER, not wood
	_box(r, Vector3(0.5, 0.006, 0.02), Color("9C6533"), Vector3(0, 0.362, 0))  # flap seam


static func _newspaper(r: Node3D) -> void:
	for i in 3:
		var sheet := _box(r, Vector3(0.48, 0.05, 0.36), Color("F2F2EC") if i % 2 == 0 else Color("DADBD5"), Vector3(0, 0.03 + i * 0.05, 0))
		sheet.rotation_degrees.y = (i - 1) * 6.0
	_box(r, Vector3(0.36, 0.012, 0.06), Color("4CC9F0"), Vector3(0, 0.161, 0.08))  # headline
	_box(r, Vector3(0.03, 0.02, 0.37), Color("A06A3A"), Vector3(0, 0.16, 0))  # string


static func _planks(r: Node3D) -> void:
	for i in 2:
		var p := _box(r, Vector3(0.72, 0.09, 0.17), Color("C8874A") if i == 0 else Color("B0723A"), Vector3(0, 0.05 + i * 0.09, (i - 0.5) * 0.12))
		p.rotation_degrees.y = 12.0 * (1 - i * 2)
		_box(p, Vector3(0.7, 0.005, 0.02), Color("8C5A2B"), Vector3(0, 0.046, 0.03))  # grain


static func _jar(r: Node3D) -> void:
	_cyl(r, 0.15, 0.3, Color("3DDC97"), Vector3(0, 0.15, 0))
	_cyl(r, 0.1, 0.18, Color("A8F5D5"), Vector3(0.06, 0.16, 0.06))  # glint
	_cyl(r, 0.13, 0.06, Color("D9A441"), Vector3(0, 0.33, 0))  # lid


static func _apple(r: Node3D) -> void:  # an apple core: red ends, a pale bitten middle
	_ball(r, 0.17, Color("E8453C"), Vector3(0, 0.17, 0))
	_cyl(r, 0.12, 0.16, Color("F6E7B0"), Vector3(0, 0.17, 0))
	_box(r, Vector3(0.03, 0.12, 0.03), Color("6B4226"), Vector3(0, 0.38, 0))
	_box(r, Vector3(0.12, 0.02, 0.07), Color("4CAF50"), Vector3(0.07, 0.4, 0))  # leaf


static func _peel(r: Node3D) -> void:  # a banana peel: a yellow middle and three floppy strips
	_ball(r, 0.1, Color("FFE14D"), Vector3(0, 0.12, 0))
	for i in 3:
		var strip := _box(r, Vector3(0.09, 0.03, 0.34), Color("FFD23A") if i % 2 == 0 else Color("F2C230"), Vector3(0, 0.04, 0))
		strip.rotation_degrees.y = i * 120.0
		strip.position += strip.transform.basis.z * 0.14
	_box(r, Vector3(0.04, 0.1, 0.04), Color("6B4E1E"), Vector3(0, 0.24, 0))


static func _rot(r: Node3D) -> void:  # rotten mush with flies: brown-green, it stinks
	_ball(r, 0.2, Color("6E5A2E"), Vector3(0, 0.08, 0)).scale = Vector3(1.2, 0.5, 1.0)
	_ball(r, 0.1, Color("7FA33A"), Vector3(0.08, 0.15, 0.04))
	for i in 3:
		_ball(r, 0.035, Color("1E1E1E"), Vector3(cos(i * 2.1) * 0.18, 0.36 + i * 0.05, sin(i * 2.1) * 0.18))


static func _board(r: Node3D) -> void:  # a circuit board: green PCB, black chips, gold pins
	_box(r, Vector3(0.52, 0.04, 0.36), Color("2E8B57"), Vector3(0, 0.04, 0))
	_box(r, Vector3(0.16, 0.06, 0.14), Color("1E2228"), Vector3(-0.1, 0.09, 0.04))
	_box(r, Vector3(0.1, 0.05, 0.1), Color("1E2228"), Vector3(0.14, 0.085, -0.06))
	_box(r, Vector3(0.44, 0.012, 0.03), Color("E8C25A"), Vector3(0, 0.066, -0.14))
	_box(r, Vector3(0.06, 0.06, 0.06), Color("4C8DF0"), Vector3(0.16, 0.09, 0.1))  # a blue cap: CIRCUITS input colour


static func _cable(r: Node3D) -> void:  # a coil of copper cable with a plug
	for i in 3:
		var loop := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.13
		torus.outer_radius = 0.19
		loop.mesh = torus
		loop.material_override = Kit.material(Color("D4572F") if i != 1 else Color("A8432A"))
		loop.position = Vector3(0, 0.04 + i * 0.05, 0)
		r.add_child(loop)
	_box(r, Vector3(0.12, 0.08, 0.1), Color("2A2D33"), Vector3(0.26, 0.05, 0))
	_box(r, Vector3(0.06, 0.02, 0.02), Color("E8C25A"), Vector3(0.35, 0.05, 0.025))


## The bomb: round purple-black body, orange twisted fuse, coloured wires and a green LCD with the countdown.
static func _bomb(r: Node3D, fuse: String) -> void:
	_ball(r, 0.27, Color("3A2D55"), Vector3(0, 0.27, 0))
	var neck := _cyl(r, 0.08, 0.1, Color("2A2140"), Vector3(0, 0.55, 0))
	(neck.mesh as CylinderMesh).top_radius = 0.11
	var wick := _cyl(r, 0.035, 0.18, Color("F0A030"), Vector3(0.04, 0.66, 0))
	wick.rotation_degrees.z = -25
	for w in [[Color("E23B3B"), 0.0], [Color("2F6FE0"), 60.0], [Color("F0C030"), -60.0]]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.26
		torus.outer_radius = 0.3
		ring.mesh = torus
		ring.material_override = Kit.material(w[0])
		ring.position.y = 0.27
		ring.rotation_degrees = Vector3(90, w[1], 0)
		r.add_child(ring)
	_box(r, Vector3(0.36, 0.2, 0.06), Color("2B2D33"), Vector3(0, 0.3, 0.25))
	var screen := _box(r, Vector3(0.3, 0.14, 0.02), Color("4ADE3A"), Vector3(0, 0.3, 0.285))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("4ADE3A")
	glow.emission_enabled = true
	glow.emission = Color("4ADE3A") if fuse.to_int() > 2 else Color("FF3B2F")
	glow.emission_energy_multiplier = 1.4
	screen.material_override = glow
	var digits := Label3D.new()
	digits.text = "00:0%s" % fuse
	digits.font_size = 64
	digits.pixel_size = 0.0035
	digits.modulate = Color("EFFFEF")
	digits.position = Vector3(0, 0.3, 0.3)
	r.add_child(digits)
	var big := Label3D.new()  # the countdown everyone can read from across the room
	big.text = fuse
	big.font = load(Look.FONT_DISPLAY)
	big.font_size = 120
	big.pixel_size = 0.005
	big.outline_size = 24
	big.modulate = Look.YELLOW if fuse.to_int() > 2 else Look.PINK
	big.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	big.no_depth_test = true
	big.position.y = 1.05
	r.add_child(big)


## Nuclear waste: a rusty yellow barrel with black bands, a glowing green lid and a trefoil.
static func _barrel(r: Node3D) -> void:
	_cyl(r, 0.24, 0.52, Color("F2C230"), Vector3(0, 0.26, 0))
	for y in [0.1, 0.42]:
		_cyl(r, 0.245, 0.05, Color("2B2D33"), Vector3(0, y, 0))
	_box(r, Vector3(0.12, 0.08, 0.02), Color("B8742A"), Vector3(-0.12, 0.2, 0.235))  # rust
	var lid := _cyl(r, 0.2, 0.03, Color("7CFF5A"), Vector3(0, 0.53, 0))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("7CFF5A")
	glow.emission_enabled = true
	glow.emission = Color("5CFF3A")
	glow.emission_energy_multiplier = 2.2
	lid.material_override = glow
	var sign := Sprite3D.new()
	sign.texture = Look.glyph("nuke")
	sign.pixel_size = 0.26 / 256.0
	sign.modulate = Color("1E1E22")
	sign.position = Vector3(0, 0.27, 0.245)
	r.add_child(sign)
	var light := OmniLight3D.new()
	light.light_color = Color("5CFF3A")
	light.light_energy = 1.4
	light.omni_range = 2.0
	light.position.y = 0.7
	r.add_child(light)


## A leaking battery: chunky green cell, black base, copper nub and a fizzing yellow spark.
static func _battery(r: Node3D) -> void:
	_cyl(r, 0.14, 0.4, Color("2FBF5A"), Vector3(0, 0.2, 0))
	_cyl(r, 0.142, 0.1, Color("1E1E22"), Vector3(0, 0.05, 0))
	_cyl(r, 0.05, 0.06, Color("D9A441"), Vector3(0, 0.43, 0))
	_box(r, Vector3(0.1, 0.025, 0.02), Color.WHITE, Vector3(0, 0.3, 0.14))  # "+"
	_box(r, Vector3(0.025, 0.1, 0.02), Color.WHITE, Vector3(0, 0.3, 0.14))
	var spark := Sprite3D.new()
	spark.texture = Look.glyph("power")
	spark.pixel_size = 0.3 / 256.0
	spark.modulate = Color("FFE14D")
	spark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spark.shaded = false
	spark.position = Vector3(0.18, 0.5, 0)
	r.add_child(spark)
	var t := spark.create_tween().set_loops()
	t.tween_property(spark, "modulate:a", 0.15, 0.12)
	t.tween_property(spark, "modulate:a", 1.0, 0.1)


## Swap the item's plain-coloured parts for one cached merged mesh (labels, glows and sprites stay as they are).
static func _bake(body: Node3D, kind: String) -> void:
	var parts: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if Bake.mergeable(mi):
			parts.append(mi)
	if not _baked.has(kind):
		_baked[kind] = Bake.mesh_of(parts, body)
	parts.reverse()  # children before their parents: a part can sit under another (plank grain)
	for mi in parts:
		mi.free()
	var merged := MeshInstance3D.new()
	merged.mesh = _baked[kind]
	merged.material_override = Bake.material()
	body.add_child(merged)


static func dest_color(kind: String) -> Color:
	var dest := Rules.dest(kind)
	return MATERIAL_COLORS.get(dest, BIN_COLORS.get(dest, Color.WHITE))


## A glowing ring in the colour of the item's bin, shown only while someone carries it (RoomView toggles it).
static func _carry_ring(root: Node3D, kind: String) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "carry"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.48
	torus.outer_radius = 0.7
	torus.rings = 24
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = dest_color(kind)
	mat.emission_enabled = true
	mat.emission = dest_color(kind)
	mat.emission_energy_multiplier = 1.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	ring.scale = Vector3(1, 0.45, 1)
	ring.position.y = 0.2
	ring.visible = false
	root.add_child(ring)
	var pulse := ring.create_tween().set_loops()
	pulse.tween_property(ring, "scale", Vector3(1.15, 0.45, 1.15), 0.35).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(ring, "scale", Vector3(1, 0.45, 1), 0.35).set_trans(Tween.TRANS_SINE)


## A soft dark disc under the item: keeps it grounded where real-time shadows are off (phones).
static func _blob(r: Node3D, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.005
	mi.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.1, 0.15, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position.y = 0.006
	r.add_child(mi)


static func _box(parent: Node3D, size: Vector3, color: Color, at := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = Kit.material(color)
	mi.position = at
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, radius: float, height: float, color: Color, at := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = Kit.material(color)
	mi.position = at
	parent.add_child(mi)
	return mi


static func _ball(parent: Node3D, radius: float, color: Color, at := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mi.mesh = mesh
	mi.material_override = Kit.material(color)
	mi.position = at
	parent.add_child(mi)
	return mi
