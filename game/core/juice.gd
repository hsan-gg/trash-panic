extends Node
## Autoload "Juice": the shared feedback kit (MINIGAMES.md §3). Every minigame calls these, never its own effects.
## Routine hits get particles, sound and haptics; only perfect, mistake and tier-up shake the screen.

const MAX_SHAKE_PX := 28.0
const TRAUMA_DECAY := 1.6
const SHOCKWAVE := preload("res://core/shaders/shockwave.gdshader")
const SPEED_LINES := preload("res://core/shaders/speed_lines.gdshader")

var reduce_shake := false
var haptics := true

var _target: Control
var _origin := Vector2.ZERO
var _trauma := 0.0
var _frozen := false
var _circle: ImageTexture
var _star: Texture2D
var _screen := CanvasLayer.new()
var _ring: ImageTexture


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_circle = _make_texture(func(r: float, _a: float) -> bool: return r < 1.0)
	_star = load(Look.UI % "star")
	_screen.layer = 50
	add_child(_screen)
	_ring = _make_texture(func(r: float, _a: float) -> bool: return r < 1.0 and r > 0.82)


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	if _trauma <= 0.0:
		_target.position = _origin
		return
	_trauma = maxf(0.0, _trauma - delta * TRAUMA_DECAY)
	var strength := 0.0 if reduce_shake else MAX_SHAKE_PX * _trauma * _trauma
	_target.position = _origin + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength


## The node that shakes. Must be a plain Control (not inside a container).
func set_shake_target(target: Control) -> void:
	_target = target
	_origin = target.position
	_trauma = 0.0


func shake(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func hit_stop(ms: int) -> void:
	if _frozen:
		return
	_frozen = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(ms / 1000.0, true, false, true).timeout
	Engine.time_scale = 1.0
	_frozen = false


func haptic(ms: int) -> void:
	if haptics and not OS.has_feature("web_ios"):  # iPhone browsers have no vibration API
		Input.vibrate_handheld(ms)


## Target squash 1.0 → 0.9 → 1.15 → 1.0 in 140 ms.
func squash(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector2.ONE * 0.9, 0.04)
	t.tween_property(node, "scale", Vector2.ONE * 1.15, 0.05)
	t.tween_property(node, "scale", Vector2.ONE, 0.05)


## 3D pop-in: 0.6 → 1.15 → 1.0 when an item appears or changes state.
func squash3d(node: Node3D) -> void:
	var base := node.scale
	node.scale = base * 0.6
	var t := node.create_tween()
	t.tween_property(node, "scale", base * 1.15, 0.08)
	t.tween_property(node, "scale", base, 0.08)


func burst(parent: Node, at: Vector2, color: Color, count := 12) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.texture = _star if randf() < 0.5 else _circle
	p.amount = count
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.7
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 460.0
	p.gravity = Vector2(0, 900)
	var star := p.texture == _star
	p.scale_amount_min = 0.15 if star else 0.3
	p.scale_amount_max = 0.35 if star else 0.7
	p.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	parent.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


## Number or word that rises 40 px and fades in 600 ms.
func popup(parent: Node, at: Vector2, text: String, color := Look.YELLOW) -> void:
	var l := Look.label(text, 56, color, true)
	l.position = at - Vector2(100, 40)
	l.size = Vector2(200, 80)
	parent.add_child(l)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 40.0, 0.6)
	t.tween_property(l, "modulate:a", 0.0, 0.6)
	t.chain().tween_callback(l.queue_free)


## Full-area colour flash (red vignette on mistakes, white on perfects).
func flash(parent: Control, color: Color, seconds: float) -> void:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(r)
	var t := r.create_tween()
	t.tween_property(r, "modulate:a", 0.0, seconds)
	t.tween_callback(r.queue_free)


func ring(parent: Node, at: Vector2, color: Color) -> void:
	var r := TextureRect.new()
	r.texture = _ring
	r.modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(64, 64)
	r.pivot_offset = r.size / 2.0
	r.position = at - r.size / 2.0
	parent.add_child(r)
	var t := r.create_tween().set_parallel()
	t.tween_property(r, "scale", Vector2.ONE * 6.0, 0.4)
	t.tween_property(r, "modulate:a", 0.0, 0.4)
	t.chain().tween_callback(r.queue_free)


## Banner that slams in (scale 2.0 → 1.0 in 180 ms), holds, then fades.
func slam(parent: Control, text: String, color := Look.WHITE, hold := 0.6, size := 140) -> void:
	var l := Look.label(text, size, color, true)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.pivot_offset = parent.size / 2.0
	l.scale = Vector2.ONE * 2.0
	l.modulate.a = 0.0
	parent.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 1.0, 0.06)
	t.tween_interval(hold)
	t.tween_property(l, "modulate:a", 0.0, 0.2)
	t.tween_callback(l.queue_free)


## Screen-space ripple from `at` (viewport pixels), for perfects and big moments.
func shockwave(at: Vector2) -> void:
	var m := _screen_effect(SHOCKWAVE, 0.45)
	m.set_shader_parameter("origin_uv", at / get_viewport().get_visible_rect().size)
	m.set_shader_parameter("strength", 0.03)
	var t := create_tween()
	t.tween_method(func(r: float) -> void: m.set_shader_parameter("radius", r), 0.0, 0.7, 0.45)


## Anime speed lines for tier-ups and the showdown.
func speed_lines(seconds: float) -> void:
	var m := _screen_effect(SPEED_LINES, seconds)
	var t := create_tween()
	t.tween_method(func(a: float) -> void: m.set_shader_parameter("strength", a), 0.6, 0.0, seconds)


func _screen_effect(shader: Shader, seconds: float) -> ShaderMaterial:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = shader
	r.material = m
	_screen.add_child(r)
	get_tree().create_timer(seconds, true, false, true).timeout.connect(r.queue_free)
	return m


func _make_texture(inside: Callable) -> ImageTexture:
	const SIZE := 32
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var v := Vector2(x + 0.5 - SIZE / 2.0, y + 0.5 - SIZE / 2.0) / (SIZE / 2.0)
			img.set_pixel(x, y, Color.WHITE if inside.call(v.length(), v.angle()) else Color(1, 1, 1, 0))
	return ImageTexture.create_from_image(img)
