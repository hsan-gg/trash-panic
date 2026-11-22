class_name Fx
extends RefCounted
## 3D particle effects made in code with Kenney particle sprites: sparkle bursts and smoke puffs.

const STAR := preload("res://core/assets/particles/star_01.png")
const SMOKE := preload("res://core/assets/particles/smoke_01.png")


static func burst(parent: Node3D, at: Vector3, color: Color, count := 24) -> void:
	_emit(parent, at, color, count, 0.9, Vector3(0, -9.8, 0), 3.0, 6.0, 0.3, STAR)


static func puff(parent: Node3D, at: Vector3) -> void:
	_emit(parent, at, Color(0.85, 0.8, 0.7, 0.8), 10, 0.5, Vector3.ZERO, 0.8, 1.6, 0.5, SMOKE)


static func _emit(parent: Node3D, at: Vector3, color: Color, count: int, life: float, gravity: Vector3, v_min: float, v_max: float, size: float, tex: Texture2D) -> void:
	var p := _particles(color, count, life, gravity, v_min, v_max, size, tex)
	p.position = at
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


static func _particles(color: Color, count: int, life: float, gravity: Vector3, v_min: float, v_max: float, size: float, tex: Texture2D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * size
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	p.mesh = mesh
	p.amount = count
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.gravity = gravity
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.angle_max = 360.0
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	return p
