class_name CreatureView
extends Node3D
## Draws the Dropper's creatures as animated 3D animals (Kenney Cube Pets, Quaternius; CC0) walking between tiles,
## their progress bars, and the warning shadow that tells you where something is about to land.

## kind -> [model in assets/3d/animals, scale, bar height]
const MODELS := {
	"robot": ["robot", 0.42, 1.6], "raccoon": ["raccoon", 0.5, 1.2], "elephant": ["elephant", 1.15, 2.2],
	"chicken": ["chick", 0.6, 1.0], "pig": ["pig", 0.7, 1.1],
}
const WALK := ["walk", "Walk", "Robot_Walking"]
const RUN := ["run", "Run", "Robot_Running"]
const IDLE := ["static", "Idle", "Idle_Eating", "Robot_Idle"]
const WARN_ICONS := {"bomb": "bomb", "nuke": "radioactive", "battery": "battery", "robot": "robot", "raccoon": "raccoon", "elephant": "elephant", "chicken": "chicken", "pig": "pig", "shark": "shark"}

var room: RoomMap
var shift: Shift

var _nodes := {}  ## creature id -> {root, model, player, clips, fill}
var _white: Texture2D


func setup(p_room: RoomMap, p_shift: Shift) -> void:
	room = p_room
	shift = p_shift
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	var live: Dictionary = shift.mayhem.creatures
	for id in _nodes.keys():
		if not live.has(id):
			_leave(id)
	var now := Time.get_ticks_msec() / 1000.0
	for id in live:
		var c: Dictionary = live[id]
		if _nodes.has(id) and _nodes[id].k != c.k:  # a hatchling got tangled (or freed): swap its model in place
			_nodes[id].root.queue_free()
			_nodes.erase(id)
		if not _nodes.has(id):
			_arrive(id, c)
		var n: Dictionary = _nodes[id]
		var root: Node3D = n.root
		var target := room.world_f(c.x, c.y)
		var step := target - root.position
		root.position = root.position.lerp(target, clampf(delta * 14.0, 0.0, 1.0))
		var model: Node3D = n.model
		var walking := step.length() > 0.004
		if walking:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(step.x, step.z), clampf(delta * 10.0, 0.0, 1.0))
		var fast: bool = c.k == "elephant" and c.p > 0.0
		_animate(n, RUN if fast else (WALK if walking else IDLE))
		model.position.y = absf(sin(now * 12.0)) * 0.08 if walking and n.player == null else 0.0
		var fill: Sprite3D = n.fill
		var p: float = clampf(c.p / Rules.SHOO_S[c.k], 0.0, 1.0)
		fill.get_parent().visible = p > 0.0
		fill.scale.x = maxf(0.01, 0.86 * p)
		fill.position.x = -0.43 * (1.0 - p)


func _arrive(id: int, c: Dictionary) -> void:
	var spec: Array = MODELS[c.k]
	var root := Node3D.new()
	root.position = room.world_f(c.x, c.y)
	add_child(root)
	var shadow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.45 if c.k != "elephant" else 1.1
	disc.bottom_radius = disc.top_radius
	disc.height = 0.02
	disc.material = _flat(Color(0, 0, 0, 0.35))
	shadow.mesh = disc
	shadow.position.y = 0.03
	root.add_child(shadow)
	var model: Node3D = load("res://core/assets/3d/animals/%s.glb" % spec[0]).instantiate()
	model.scale = Vector3.ONE * spec[1]
	root.add_child(model)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var clips := {}
	if player != null:
		for clip in player.get_animation_list():
			clips[clip.get_slice("|", clip.get_slice_count("|") - 1)] = clip
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var base: float = spec[2] / 2.0
	var bar := Node3D.new()
	bar.position = Vector3(0, base * 2.0 + 0.3, 0)
	bar.visible = false
	root.add_child(bar)
	var back := _bar_piece(Color("14102E"), Vector2(1.0, 0.2))
	bar.add_child(back)
	var fill := _bar_piece(Look.MINT, Vector2(0.86, 0.14))
	fill.render_priority = 1
	bar.add_child(fill)
	_nodes[id] = {"root": root, "model": model, "player": player, "clips": clips, "fill": fill, "playing": "", "k": c.k}
	root.scale = Vector3.ZERO
	root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Play the first clip this model has from `names` (cube pets: walk/run/static; Quaternius: Walk/Run/Idle).
func _animate(n: Dictionary, names: Array) -> void:
	if n.player == null:
		return
	for name in names:
		if n.clips.has(name):
			if n.playing != name:
				n.playing = name
				n.player.play(n.clips[name], 0.15)
			return


func _leave(id: int) -> void:
	var root: Node3D = _nodes[id].root
	_nodes.erase(id)
	Fx.puff(self, root.position + Vector3(0, 0.5, 0))
	var t := root.create_tween()
	t.tween_property(root, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(root.queue_free)


func _bar_piece(color: Color, size: Vector2) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = _white
	s.modulate = color
	s.pixel_size = 0.5
	s.scale = Vector3(size.x, size.y, 1)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	return s


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## A growing dark shadow with a blinking icon of what is about to fall there.
func telegraph(at: Vector2i, kind: String) -> void:
	var root := Node3D.new()
	root.position = room.world(at)
	add_child(root)
	var shadow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.02
	disc.material = _flat(Color(0.05, 0.0, 0.0, 0.55))
	shadow.mesh = disc
	shadow.position.y = 0.04
	shadow.scale = Vector3(0.2, 1, 0.2)
	root.add_child(shadow)
	var icon := Sprite3D.new()
	icon.texture = Look.emoji(WARN_ICONS.get(kind, "warning"))
	icon.pixel_size = 0.0022
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.shaded = false
	icon.no_depth_test = true
	icon.position.y = 1.9
	root.add_child(icon)
	var t := root.create_tween().set_parallel()
	t.tween_property(shadow, "scale", Vector3.ONE, Rules.DROP_WARN_S).set_trans(Tween.TRANS_QUAD)
	var blink := icon.create_tween().set_loops(int(Rules.DROP_WARN_S / 0.3))
	blink.tween_property(icon, "modulate:a", 0.15, 0.15)
	blink.tween_property(icon, "modulate:a", 1.0, 0.15)
	t.chain().tween_callback(root.queue_free)
