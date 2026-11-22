class_name RemotePlayer
extends Node3D
## Another player (or a bot) as seen on this phone: rendered 150 ms in the past, interpolated between
## the two snapshots around that moment, with a name tag.

const DELAY_MS := 150  # 1.5 snapshots at 10 Hz
const MAX_SNAPSHOTS := 8

var id := -1
var carrying := -1
var avatar := Avatar.new()
var _snaps: Array[Dictionary] = []  ## {t: local ms, p: Vector3, y: float}
var _tag: Label3D


func setup(info: Dictionary, at: Vector3) -> void:
	id = info.id
	add_child(avatar)
	avatar.setup(info.skin)
	position = at
	_tag = Label3D.new()
	_tag.text = info.name
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.font = load(Look.FONT_DISPLAY)
	_tag.font_size = 48
	_tag.pixel_size = 0.005
	_tag.outline_size = 12
	_tag.modulate = Look.SKY
	_tag.position.y = 1.7
	_tag.no_depth_test = true
	add_child(_tag)


func push(s: Dictionary) -> void:
	var p: Array = s.p
	_snaps.append({"t": Time.get_ticks_msec(), "p": Vector3(p[0], p[1], p[2]), "y": float(s.y)})
	if _snaps.size() > MAX_SNAPSHOTS:
		_snaps.pop_front()
	avatar.play(int(s.a))
	carrying = int(s.get("h", -1))


func hold_point() -> Vector3:
	var f := Vector3(sin(avatar.rotation.y), 0, cos(avatar.rotation.y))
	return global_position + f * Player.HOLD.z + Vector3(0, Player.HOLD.y, 0)


func _process(_delta: float) -> void:
	if _snaps.is_empty():
		return
	var pose := sample(_snaps, Time.get_ticks_msec() - DELAY_MS)
	position = pose.p
	avatar.rotation.y = pose.y


## Pose at local time `t` from timestamped snapshots: interpolate between neighbours, hold the ends.
static func sample(snaps: Array, t: int) -> Dictionary:
	if t <= snaps[0].t:
		return snaps[0]
	for i in range(1, snaps.size()):
		if snaps[i].t >= t:
			var a: Dictionary = snaps[i - 1]
			var b: Dictionary = snaps[i]
			var k := float(t - a.t) / maxf(1.0, b.t - a.t)
			return {"t": t, "p": a.p.lerp(b.p, k), "y": lerp_angle(a.y, b.y, k)}
	return snaps[-1]
