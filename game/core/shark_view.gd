class_name SharkView
extends Node3D
## The shark in the harbour: its fin circles the platform; on "shark_alert" it rushes to the wall by the target tile,
## on "shark" it leaps over the wall, jaws open, bites, and splashes back. Pure view, driven by Mayhem's cues.

const WATER_Y := -0.6
const SWIM_Y := -1.05  ## only the fin cuts the surface
const SPEED := 0.22  ## radians per second around the platform

var room: RoomMap
var _shark := Node3D.new()
var _angle := 0.0
var _busy := false  ## rushing or leaping: not circling
var _radius := Vector2.ZERO


func setup(p_room: RoomMap) -> void:
	room = p_room
	_radius = Vector2(room.width, room.height) * RoomMap.TILE / 2.0 + Vector2(2.2, 2.0)
	_build()
	_shark.scale = Vector3.ONE * 1.5  # big enough to make the edge feel dangerous
	add_child(_shark)
	_shark.position = Vector3(_radius.x, SWIM_Y, 0)


func _process(delta: float) -> void:
	if _busy:
		return
	_angle += delta * SPEED
	var next := Vector3(cos(_angle) * _radius.x, SWIM_Y, sin(_angle) * _radius.y)
	if not next.is_equal_approx(_shark.position):
		_shark.look_at(next, Vector3.UP)
	_shark.position = next


## Rush to the water just outside the wall nearest to `at`.
func alert(at: Vector2i) -> void:
	_busy = true
	var spot := _sea_spot(at)
	_shark.look_at(Vector3(spot.x, SWIM_Y, spot.z), Vector3.UP)
	var t := _shark.create_tween()
	t.tween_property(_shark, "position", Vector3(spot.x, SWIM_Y, spot.z), Rules.SHARK_WARN_S * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## The leap: out of the water, over the wall onto `at`, and back with a splash.
func bite(at: Vector2i) -> void:
	_busy = true
	var sea := _sea_spot(at)
	var land := room.world(at)
	_shark.position = Vector3(sea.x, SWIM_Y, sea.z)
	_shark.look_at(Vector3(land.x, SWIM_Y, land.z), Vector3.UP)
	var t := _shark.create_tween()
	t.tween_method(func(k: float) -> void:
		var flat := Vector3(sea.x, 0, sea.z).lerp(Vector3(land.x, 0, land.z), k)
		_shark.position = Vector3(flat.x, lerpf(SWIM_Y, 0.4, k) + sin(k * PI) * 2.2, flat.z)
		_shark.rotation.x = lerpf(-0.6, 0.5, k), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void:
		Fx.burst(get_parent(), land + Vector3(0, 0.5, 0), Color("CFEFFF"), 26)
		Fx.puff(get_parent(), land + Vector3(0, 0.3, 0)))
	t.tween_interval(0.25)
	t.tween_method(func(k: float) -> void:
		var flat := Vector3(land.x, 0, land.z).lerp(Vector3(sea.x, 0, sea.z), k)
		_shark.position = Vector3(flat.x, lerpf(0.4, SWIM_Y - 0.6, k) + sin(k * PI) * 1.6, flat.z), 0.0, 1.0, 0.5)
	t.tween_callback(func() -> void:
		Fx.burst(get_parent(), Vector3(sea.x, WATER_Y + 0.1, sea.z), Color.WHITE, 30)
		_shark.rotation.x = 0.0
		_angle = atan2(sea.z / _radius.y, sea.x / _radius.x)
		_busy = false)


## Water just outside the outer wall, in line with `at`.
func _sea_spot(at: Vector2i) -> Vector3:
	var p := room.world(at)
	var half := Vector2(room.width, room.height) * RoomMap.TILE / 2.0
	var gaps := {"left": at.x, "right": room.width - 1 - at.x, "top": at.y, "bottom": room.height - 1 - at.y}
	var side: String = gaps.keys().reduce(func(a: String, b: String) -> String: return a if gaps[a] <= gaps[b] else b)
	match side:
		"left":
			return Vector3(-half.x - 1.6, 0, p.z)
		"right":
			return Vector3(half.x + 1.6, 0, p.z)
		"top":
			return Vector3(p.x, 0, -half.y - 1.6)
	return Vector3(p.x, 0, half.y + 1.6)


## A chunky cartoon shark facing -Z (Godot's forward): slate-blue back, white belly, big fin, teeth.
func _build() -> void:
	var blue := Color("5D7C99")
	_part(SphereMesh.new(), blue, Vector3(0, 0, 0), Vector3(0.75, 0.6, 1.7))
	_part(SphereMesh.new(), Color("E8EEF2"), Vector3(0, -0.12, -0.05), Vector3(0.62, 0.42, 1.5))
	var fin := _part(PrismMesh.new(), blue.darkened(0.1), Vector3(0, 0.55, 0.1), Vector3(0.12, 0.7, 0.6))
	fin.rotation_degrees.x = -12
	var tail := _part(PrismMesh.new(), blue.darkened(0.1), Vector3(0, 0.1, 0.95), Vector3(0.1, 0.7, 0.45))
	tail.rotation_degrees.x = 90
	for x in [-0.22, 0.22]:
		_part(SphereMesh.new(), Color("14161A"), Vector3(x, 0.12, -0.62), Vector3(0.09, 0.09, 0.09))
		var side_fin := _part(PrismMesh.new(), blue, Vector3(x * 1.9, -0.18, -0.1), Vector3(0.05, 0.3, 0.35))
		side_fin.rotation_degrees.z = 70 * signf(x)
	_part(BoxMesh.new(), Color("3A1F2E"), Vector3(0, -0.12, -0.78), Vector3(0.4, 0.14, 0.12))
	for i in 5:
		var tooth := _part(PrismMesh.new(), Color.WHITE, Vector3(-0.16 + i * 0.08, -0.08, -0.84), Vector3(0.06, 0.08, 0.04))
		tooth.rotation_degrees.z = 180
	Bake.children(_shark)


func _part(mesh: PrimitiveMesh, color: Color, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Kit.material(color)
	mi.position = pos
	mi.scale = scl
	_shark.add_child(mi)
	return mi
