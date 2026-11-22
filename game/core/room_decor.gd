class_name RoomDecor
extends Node3D
## Everything around the play area, in the Trash-is-Fun look (design/refs): a tiled platform on harbour water, low
## steel walls with a red trim, dockside clutter, and THE DROPPER, a battered machine that slides along a gantry
## over the back wall and spits waste into the room.

const FLOOR := preload("res://core/shaders/floor.gdshader")
const WATER := preload("res://core/shaders/water.gdshader")
const STEEL := Color("2F3540")
const TRIM := Color("C8323A")
const CHARCOAL := Color("3A3F48")
const HAZARD := Color("FFC21A")
const WALL_H := 0.75
const DROPPER_Y := 4.3

var rush := false  ## RUSH HOUR: the beacons spin faster and turn red

var _env: Environment
var _lights: Array[Light3D] = []  ## dimmed in a BLACKOUT
var _beacons: Array[Node3D] = []
var _beacon_lights: Array[OmniLight3D] = []
var _floaters: Array[Node3D] = []  ## crates bobbing on the water
var _dropper: Node3D
var _dropper_eyes: Array[MeshInstance3D] = []
var _dropper_z := 0.0
var _half := Vector2.ZERO  ## half extents of the room (walls included), metres


func build(room: RoomMap) -> void:
	_half = Vector2(room.width, room.height) * RoomMap.TILE / 2.0
	_lighting()
	_platform()
	_water()
	_walls(room)
	_dock_clutter()
	_gantry()
	for x in [-_half.x + 0.6, _half.x - 0.6]:
		_beacon(Vector3(x, WALL_H, _half.y - 0.6))
	Bake.children(self)
	var look: Dictionary = Rules.MAPS[Rules.map].look.light
	if look.get("ambience", false):  # added after the bake: lights and particles stay live
		var mood := MapAmbience.new()
		add_child(mood)
		mood.build(room, _half, look)
		_lights.append_array(mood.lights)  # walls, frames, gantry, sandbags: one draw call


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for b in _beacons:
		b.rotation.y += delta * (10.0 if rush else 4.0)
	for l in _beacon_lights:
		l.light_color = Color("FF3030") if rush else Color("FF9A2A")
	for i in _floaters.size():
		var f := _floaters[i]
		f.position.y = -0.35 + sin(t * 1.3 + i) * 0.08
		f.rotation.z = sin(t * 0.9 + i * 2.0) * 0.12
	if _dropper != null:
		var blink := 0.5 + 0.5 * sin(t * (14.0 if rush else 4.0))
		for e in _dropper_eyes:
			(e.material_override as StandardMaterial3D).emission_energy_multiplier = 0.6 + blink * 2.4


## BLACKOUT: nearly all light goes out; emissive lamps and beacons keep glowing.
func dark(on: bool) -> void:
	var t := create_tween().set_parallel()
	t.tween_property(_env, "ambient_light_energy", 0.06 if on else float(Rules.MAPS[Rules.map].look.light.amb_e), 0.4)
	t.tween_property(_env, "adjustment_brightness", 0.3 if on else float(Rules.MAPS[Rules.map].look.light.get("brightness", 1.0)), 0.4)  # also darkens the unshaded water
	for l in _lights:
		if not l.has_meta("base"):
			l.set_meta("base", l.light_energy)
		t.tween_property(l, "light_energy", float(l.get_meta("base")) * (0.05 if on else 1.0), 0.4)


## Where waste leaves the Dropper when it aims at `target` (the Dropper slides there first).
func mouth_for(target: Vector3) -> Vector3:
	if _dropper == null:
		return target + Vector3(0, 4, 0)
	var x := clampf(target.x, -_half.x + 1.5, _half.x - 1.5)
	var t := _dropper.create_tween()
	t.tween_property(_dropper, "position:x", x, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return Vector3(x, DROPPER_Y - 1.2, _dropper_z + 0.7)


## The Dropper coughs each time it lets something fall.
func burp() -> void:
	var t := _dropper.create_tween()
	t.tween_property(_dropper, "scale", Vector3(1.08, 0.88, 1.08), 0.07)
	t.tween_property(_dropper, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## It rattles and swings before it drops something worse.
func rattle() -> void:
	var t := _dropper.create_tween()
	for i in 8:
		t.tween_property(_dropper, "rotation:z", 0.12 if i % 2 == 0 else -0.12, 0.06)
	t.tween_property(_dropper, "rotation:z", 0.0, 0.08)


# ── light and ground ─────────────────────────────────────────────────────────

func _lighting() -> void:
	var look: Dictionary = Rules.MAPS[Rules.map].look.light
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(look.bg)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(look.amb)
	_env.ambient_light_energy = look.amb_e
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = look.exposure
	_env.adjustment_enabled = true
	_env.adjustment_saturation = look.sat
	_env.adjustment_contrast = look.get("contrast", 1.0)
	_env.adjustment_brightness = look.get("brightness", 1.0)
	_env.glow_enabled = true
	_env.glow_intensity = look.glow
	_env.glow_hdr_threshold = 1.2 if look.glow < 1.0 else 0.9  # the neon map lets more of its lamps bloom
	var world := WorldEnvironment.new()
	world.environment = _env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(look.sun_rot[0], look.sun_rot[1], 0)
	sun.light_color = Color(look.sun)
	sun.light_energy = look.sun_e
	sun.shadow_enabled = not (OS.has_feature("web_android") or OS.has_feature("web_ios"))  # the app can afford them, mobile browsers not
	if OS.has_feature("mobile"):
		RenderingServer.directional_shadow_atlas_set_size(2048, true)
	sun.shadow_opacity = 0.7
	sun.directional_shadow_max_distance = 26.0 if OS.has_feature("mobile") else 40.0
	add_child(sun)
	_lights.append(sun)
	var fill := DirectionalLight3D.new()  # complementary bounce from the other side keeps shadows coloured, not black
	fill.rotation_degrees = Vector3(-40, look.sun_rot[1] + 180, 0)
	fill.light_color = Color(look.fill)
	fill.light_energy = look.fill_e
	add_child(fill)
	_lights.append(fill)


func _platform() -> void:
	var size := Vector3(_half.x * 2.0 + 1.2, 0.8, _half.y * 2.0 + 1.2)
	var top := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	top.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = FLOOR
	mat.set_shader_parameter("lane", Vector2(_half.x - RoomMap.TILE, _half.y - RoomMap.TILE))
	_map_colors(mat, "floor")
	top.material_override = mat
	top.position.y = -0.4
	add_child(top)
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position.y = -0.4
	ground.add_child(cs)
	add_child(ground)
	_box(Vector3(0, -0.55, 0), Vector3(size.x + 0.3, 0.5, size.z + 0.3), Color("5D6B78"))  # concrete lip at the waterline


## This map's colours for the floor or water shader (Rules.MAPS look); the Sorting Floor keeps the defaults.
func _map_colors(mat: ShaderMaterial, part: String) -> void:
	var colors: Dictionary = Rules.MAPS[Rules.map].look.get(part, {})
	for param in colors:
		mat.set_shader_parameter(param, Color(colors[param]))


func _water() -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 70)
	mi.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = WATER
	mat.set_shader_parameter("platform", _half + Vector2(0.75, 0.75))
	_map_colors(mat, "water")
	mi.material_override = mat
	mi.position.y = -0.6
	add_child(mi)


## Low steel walls with a red trim line, gaps for the exit doors.
func _walls(room: RoomMap) -> void:
	var t := RoomMap.TILE
	for at in room.tiles:
		var type: String = room.tiles[at]
		if type != "wall" and type != "exit":
			continue
		if at.x != 0 and at.x != room.width - 1 and at.y != 0 and at.y != room.height - 1:
			continue
		var p := room.world(at)
		if type == "exit":
			_door_frame(p)
			continue
		var back: bool = at.y == 0
		var h := WALL_H * (1.6 if back else 1.0)
		_box(p + Vector3(0, h / 2.0, 0), Vector3(t - 0.02, h, t - 0.02), STEEL)
		var inward := Vector3(-signf(p.x) if at.x == 0 or at.x == room.width - 1 else 0.0, 0, -signf(p.z) if at.y == 0 or at.y == room.height - 1 else 0.0)
		var trim := Vector3(0.14 if inward.x != 0.0 else t, 0.08, 0.14 if inward.z != 0.0 else t)
		_box(p + inward * (t / 2.0 - 0.07) + Vector3(0, h + 0.03, 0), trim, TRIM)
		if at.x % 3 == 0:
			_box(p + Vector3(0, h + 0.1, 0), Vector3(0.18, 0.2, 0.18), Color("596273"))  # rail posts


func _door_frame(p: Vector3) -> void:
	for dz in [-0.62, 0.62]:
		_box(p + Vector3(0, 1.0, dz), Vector3(0.5, 2.0, 0.16), HAZARD)
	_box(p + Vector3(0, 2.05, 0), Vector3(0.6, 0.22, 1.4), CHARCOAL)


## Harbour clutter around the platform: cones, sandbags, barrels, crates, a tool cart and bobbing crates.
func _dock_clutter() -> void:
	var w := _half.x
	var h := _half.y
	for c in [Vector3(-w - 0.2, 0, -h + 0.4), Vector3(w + 0.1, 0, h - 0.3)]:  # cone clusters at two corners
		for i in 4:
			Kit.prop(self, "vehicles", "cone", c + Vector3((i % 2) * 0.45 - 0.2, 0, (i / 2) * 0.45 - 0.2), i * 40.0, 1.6, "none")
	for i in 5:  # sandbag wall along the left dock edge
		var bag := _box(Vector3(-w - 0.35, 0.12 + (i % 2) * 0.2, -1.8 + i * 0.5 + (i % 2) * 0.25), Vector3(0.45, 0.2, 0.3), Color("CFC6A8"))
		bag.rotation_degrees.y = 8.0 * (i % 3)
	for p in [Vector3(w + 0.35, 0, -1.6), Vector3(w + 0.35, 0, -2.3), Vector3(-w - 0.3, 0, 2.6)]:
		Kit.prop(self, "survival", "barrel", p, randf() * 90.0, 1.9, "none")
	Kit.prop(self, "factory", "box-large", Vector3(-w - 0.2, 0, 1.6), 20, 1.1, "none")
	Kit.prop(self, "urban", "pallet", Vector3(w + 0.3, 0, 2.0), 90, 1.1, "none")
	Kit.prop(self, "factory", "box-small", Vector3(w + 0.3, 0.2, 2.0), 30, 1.0, "none")
	var cart := Node3D.new()  # red tool cart like the refs
	cart.position = Vector3(w - 0.2, 0, -h - 0.25)
	add_child(cart)
	_box(Vector3(0, 0.45, 0), Vector3(1.4, 0.5, 0.6), TRIM, cart)
	_box(Vector3(0, 0.72, 0), Vector3(1.3, 0.08, 0.5), Color("D9DDE3"), cart)
	Bake.children(cart)
	for spot in [Vector3(-w - 4.0, 0, -h + 1.0), Vector3(w + 3.5, 0, 1.0), Vector3(-w - 2.5, 0, h + 2.5), Vector3(w + 2.0, 0, -h - 3.0)]:
		var crate := Kit.model("factory", "box-small")
		crate.position = spot
		crate.scale = Vector3.ONE * 1.6
		add_child(crate)
		_floaters.append(crate)
	_boat(Vector3(-w - 4.2, -0.45, 3.0))


## A little moored barge loaded with junk, rocking on the water.
func _boat(at: Vector3) -> void:
	var boat := Node3D.new()
	boat.position = at
	boat.rotation_degrees.y = -12
	add_child(boat)
	_box(Vector3(0, 0.15, 0), Vector3(2.2, 0.6, 4.6), Color("B5764A"), boat)
	_box(Vector3(0, 0.47, 0), Vector3(2.4, 0.08, 4.8), Color("7A4A2C"), boat)
	_box(Vector3(0, 0.62, -1.4), Vector3(1.2, 0.3, 0.9), Color("8FB9E0"), boat)
	Bake.children(boat)
	Kit.prop(boat, "food", "soda-bottle", Vector3(0.4, 0.5, 0.9), 40, 2.4, "none")
	Kit.prop(boat, "factory", "box-small", Vector3(-0.4, 0.5, 0.4), 15, 1.0, "none")
	_floaters.append(boat)


# ── THE DROPPER ──────────────────────────────────────────────────────────────

## A yellow gantry over the back wall; the Dropper hangs from it: a dented charcoal hopper overflowing with junk,
## a yellow-rimmed spout, hazard stripes and two red lamp eyes that blink faster in RUSH HOUR.
func _gantry() -> void:
	_dropper_z = -_half.y + 0.3
	for x in [-_half.x + 0.3, _half.x - 0.3]:
		_box(Vector3(x, (DROPPER_Y + 1.2) / 2.0, _dropper_z - 0.4), Vector3(0.35, DROPPER_Y + 1.2, 0.35), HAZARD)
	_box(Vector3(0, DROPPER_Y + 1.25, _dropper_z - 0.4), Vector3(_half.x * 2.0, 0.3, 0.35), HAZARD)
	_dropper = Node3D.new()
	_dropper.position = Vector3(0, DROPPER_Y, _dropper_z)
	add_child(_dropper)
	_box(Vector3(0, 0.95, -0.4), Vector3(0.7, 0.3, 0.4), CHARCOAL, _dropper)  # trolley on the beam
	_box(Vector3(0, 0.1, 0), Vector3(2.0, 1.3, 1.5), CHARCOAL, _dropper)
	_box(Vector3(0, -0.25, 0), Vector3(2.06, 0.22, 1.56), HAZARD, _dropper)
	for i in 5:  # hazard stripes on the yellow band
		var s := _box(Vector3(-0.8 + i * 0.4, -0.25, 0.79), Vector3(0.14, 0.24, 0.02), Color("1E2026"), _dropper)
		s.rotation_degrees.z = 35
	var spout := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.6
	cone.bottom_radius = 0.38
	cone.height = 0.6
	spout.mesh = cone
	spout.material_override = Kit.material(Color("596273"))
	spout.position = Vector3(0, -0.8, 0.3)
	_dropper.add_child(spout)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.34
	ring.outer_radius = 0.46
	rim.mesh = ring
	rim.material_override = Kit.material(HAZARD)
	rim.position = Vector3(0, -1.1, 0.3)
	_dropper.add_child(rim)
	for x in [-0.5, 0.5]:
		var eye := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.2
		ball.height = 0.4
		eye.mesh = ball
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color("FF2A2A")
		glow.emission_enabled = true
		glow.emission = Color("FF3B2F")
		eye.material_override = glow
		eye.position = Vector3(x, 0.35, 0.76)
		_dropper.add_child(eye)
		_dropper_eyes.append(eye)
	for junk in [["soda-can", Vector3(-0.5, 0.8, 0.1)], ["soda-bottle", Vector3(0.2, 0.8, -0.1)], ["pizza-box", Vector3(0.4, 0.78, 0.3)], ["bag", Vector3(-0.1, 0.8, 0.35)]]:
		Kit.prop(_dropper, "food", junk[0], junk[1], randf() * 360.0, 1.6, "none")
	var plate := Label3D.new()
	plate.text = "DROPPER"
	plate.font = load(Look.FONT_DISPLAY)
	plate.font_size = 48
	plate.pixel_size = 0.008
	plate.outline_size = 10
	plate.modulate = Color("FFF4D6")
	plate.position = Vector3(0, 0.0, 0.77)
	_dropper.add_child(plate)


func _beacon(at: Vector3) -> void:
	var head := Node3D.new()
	head.position = at + Vector3(0, 0.15, 0)
	add_child(head)
	var lamp := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.12
	mesh.bottom_radius = 0.15
	mesh.height = 0.24
	lamp.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("FF8A1A")
	mat.emission_enabled = true
	mat.emission = Color("FF7A10")
	mat.emission_energy_multiplier = 3.0
	lamp.material_override = mat
	head.add_child(lamp)
	var light := OmniLight3D.new()
	light.position = Vector3(0.5, 0, 0)
	light.light_energy = 1.0
	light.omni_range = 3.0
	head.add_child(light)
	_beacons.append(head)
	_beacon_lights.append(light)


func _box(center: Vector3, size: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = Kit.material(color)
	mi.position = center
	parent.add_child(mi)
	return mi
