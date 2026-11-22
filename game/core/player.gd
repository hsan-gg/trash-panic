class_name Player
extends CharacterBody3D
## The local worker: snappy top-down movement relative to the fixed camera (stick up = into the room),
## a short DASH, and the tile it faces for GRAB / USE.

const SPEED := 4.4
const ACCEL := 40.0
const DASH_SPEED := 11.0
const DASH_S := 0.18
const DASH_COOLDOWN_S := 0.9
const REACH := 0.95  ## how far ahead the faced tile is sampled
const HOLD := Vector3(0, 1.05, 0.5)  ## carried item: in front of the chest

var avatar := Avatar.new()
var carrying := false  ## set by the session from the shift each frame
var using := false
var frozen := true
var floaty := false  ## CHAOS: LOW GRAVITY, the worker bounces like on the moon
var wind := Vector3.ZERO  ## CHAOS: hurricane push (m/s)
var speed_mult := 1.0  ## carrying nuclear waste slows you down

var _dash_t := 0.0
var _dash_cd := 0.0
var _fling_v := Vector3.ZERO  ## flung by a blast or a bite: slides out over a moment, even while frozen


func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.2
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.6
	add_child(cs)
	add_child(avatar)


func forward() -> Vector3:
	return Vector3(sin(avatar.rotation.y), 0, cos(avatar.rotation.y))


## Cardinal direction the worker faces (for throws).
func facing_dir() -> Vector2i:
	var f := forward()
	return Vector2i(signi(roundi(f.x)), 0) if absf(f.x) > absf(f.z) else Vector2i(0, signi(roundi(f.z)))


func facing_tile(room: RoomMap) -> Vector2i:
	return room.tile_of(global_position + forward() * REACH)


func hold_point() -> Vector3:
	return global_position + forward() * HOLD.z + Vector3(0, HOLD.y, 0)


func dash() -> void:
	if frozen or _dash_cd > 0.0:
		return
	_dash_t = DASH_S
	_dash_cd = DASH_COOLDOWN_S


## Launched through the air with a spin (blasts, shark bites, bumping the elephant).
func fling(dir: Vector3) -> void:
	_fling_v = dir * 7.0
	var t := avatar.create_tween().set_parallel()
	t.tween_property(avatar, "rotation:y", avatar.rotation.y + TAU * 2.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(avatar, "position:y", 1.4, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(avatar, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	_dash_t = maxf(0.0, _dash_t - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	var stick := Vector2.ZERO if frozen else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := Vector3(stick.x, 0, stick.y).limit_length(1.0)
	var target := wish * SPEED * speed_mult + wind
	if _dash_t > 0.0:
		target = forward() * DASH_SPEED
	var horizontal := Vector3(velocity.x, 0, velocity.z).move_toward(target, (ACCEL * 3.0 if _dash_t > 0.0 else ACCEL) * delta)
	if _fling_v.length() > 0.1:
		horizontal = _fling_v
		_fling_v = _fling_v.move_toward(Vector3.ZERO, 14.0 * delta)
	velocity = Vector3(horizontal.x, -2.0, horizontal.z)
	move_and_slide()
	if _dash_t <= 0.0 and _fling_v.length() <= 0.1:
		_corner_assist(target, delta)
	if wish.length() > 0.15:
		avatar.rotation.y = lerp_angle(avatar.rotation.y, atan2(wish.x, wish.z), 16.0 * delta)
	_animate(wish)
	var hop := absf(sin(Time.get_ticks_msec() / 260.0)) * 0.9 if floaty else 0.0
	avatar.position.y = lerpf(avatar.position.y, hop, 10.0 * delta)


## Walking into a tile corner that sticks out a little would stop you dead: slip sideways around it into the gap.
func _corner_assist(target: Vector3, delta: float) -> void:
	var flat := Vector3(target.x, 0, target.z)
	var real := get_real_velocity()
	if flat.length() < 1.0 or Vector3(real.x, 0, real.z).dot(flat.normalized()) > flat.length() * 0.5:  # still making headway
		return
	var lifted := global_transform.translated(Vector3.UP * 0.05)  # off the floor so only walls count
	var ahead := flat.normalized() * 0.2
	if not test_move(lifted, ahead):
		return  # nothing in the way, just speeding up
	var side := Vector3(-ahead.z, 0, ahead.x).normalized()
	for dist in [0.15, 0.3, 0.45, 0.6]:  # up to half a tile
		for s: Vector3 in [side, -side]:
			if not test_move(lifted, s * dist) and not test_move(lifted.translated(s * dist), ahead):
				move_and_collide(s * minf(dist, flat.length() * delta))
				return


func _animate(wish: Vector3) -> void:
	var moving := wish.length() > 0.1
	var a := "idle"
	if using:
		a = "work"
	elif carrying:
		a = "carry_walk" if moving else "carry"
	elif _dash_t > 0.0:
		a = "run"
	elif moving:
		a = "walk"
	avatar.play(Avatar.anim(a))
