class_name MapAmbience
extends Node3D
## Extra mood for a map whose look asks for it (Rules.MAPS look.light.ambience): warm lamp pools over the machine and
## the bins (dimmed with the rest in a BLACKOUT), sun sparkles drifting over the floor, and a soft screen vignette.

const SPARKLE := preload("res://core/assets/particles/star_01.png")
const VIGNETTE := preload("res://core/shaders/vignette.gdshader")

var lights: Array[Light3D] = []


func build(room: RoomMap, half: Vector2, look: Dictionary) -> void:
	var lamp := Color(look.get("lamp", "FFD08A"))
	var spots := [_centre(room, room.bunkers), _centre(room, _tiles(room, ["chute", "container", "batterybin"]))]
	for at: Vector3 in spots:
		if at != Vector3.INF:
			_lamp(at + Vector3(0, 2.4, 0.4), lamp)
	_sparkles(half, Color(look.get("sparkle", "FFF2C0")))
	_vignette(float(look.get("vignette", 0.35)))


func _lamp(at: Vector3, color: Color) -> void:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = color
	l.light_energy = 2.6
	l.omni_range = 4.5
	l.omni_attenuation = 1.6
	add_child(l)
	lights.append(l)


## Dust in the sunbeams: a few soft glints rise and fade all over the room.
func _sparkles(half: Vector2, color: Color) -> void:
	var p := CPUParticles3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * 0.22
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = SPARKLE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	p.mesh = mesh
	p.amount = 36
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(half.x - 0.8, 1.0, half.y - 0.8)
	p.position.y = 1.4
	p.direction = Vector3.UP
	p.spread = 30.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	p.angle_max = 360.0
	var fade := Gradient.new()  # in and out, never popping
	fade.set_color(0, Color(color, 0.0))
	fade.set_color(1, Color(color, 0.0))
	fade.add_point(0.5, Color(color, 0.8))
	p.color_ramp = fade
	add_child(p)


func _vignette(strength: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1  # over the 3D view, under the HUD and the touch controls
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = VIGNETTE
	mat.set_shader_parameter("strength", strength)
	rect.material = mat
	layer.add_child(rect)
	add_child(layer)


static func _tiles(room: RoomMap, types: Array) -> Array:
	return room.tiles.keys().filter(func(at: Vector2i) -> bool: return room.tiles[at] in types)


## Middle of some tiles, in world space (INF when there are none).
static func _centre(room: RoomMap, tiles: Array) -> Vector3:
	if tiles.is_empty():
		return Vector3.INF
	var sum := Vector3.ZERO
	for at: Vector2i in tiles:
		sum += room.world(at)
	return sum / tiles.size()
