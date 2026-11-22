class_name WorkerPreview
extends SubViewportContainer
## A small turning 3D character on the title screen: your worker (skin button) or your partner.

var _holder := Node3D.new()
var _avatar: Avatar


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.size = Vector2i(320, 420)
	add_child(vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 5.6)  # framed for the tallest worker (the punks)
	cam.fov = 36.0
	vp.add_child(cam)
	cam.look_at(Vector3(0, 1.25, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.9, 1.0)
	env.environment.ambient_light_energy = 0.8
	vp.add_child(env)
	vp.add_child(_holder)


func show_worker(skin: int) -> void:
	if _avatar != null:
		_avatar.queue_free()
	_avatar = Avatar.new()
	_holder.add_child(_avatar)
	_avatar.setup(skin)
	_avatar.play(Avatar.anim("idle"))
	Juice.squash3d(_avatar)


func _process(delta: float) -> void:
	_holder.rotation.y = sin(Time.get_ticks_msec() / 1200.0) * 0.5
