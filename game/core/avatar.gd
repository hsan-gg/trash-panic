class_name Avatar
extends Node3D
## A cute animal worker (Quaternius, CC0) with its animations. The anim index is what goes over the network.

## Playable workers (all CC0): a panda and two bunnies (Quaternius) and a monkey (Kenney Cube Pets).
const SKINS := [
	{"name": "PANDA", "model": "animals/panda", "scale": 0.7},
	{"name": "BUNNY", "model": "animals/rabbit", "scale": 0.7},
	{"name": "PUNK BUNNY", "model": "animals/rabbit_cyan", "scale": 0.7},
	{"name": "MONKEY", "model": "animals/monkey", "scale": 1.15},
	{"name": "TRASH CAT", "model": "animals/cat", "scale": 1.15},
	{"name": "DUMPSTER DOG", "model": "animals/dog", "scale": 1.15},
	{"name": "TIGER", "model": "animals/tiger", "scale": 1.15},
	{"name": "LION", "model": "animals/lion", "scale": 1.15},
]  ## at most 8: the server takes skins 0-7
const TEAM := [Color("FF8A1A"), Color("2F8CFF")]  ## ring colours: host, guest
## Logical animations (the index goes over the network) and the clip names that play them in each model.
const ANIMS := ["idle", "walk", "run", "carry", "carry_walk", "work", "yes", "no"]
const CLIPS := {
	"idle": ["Idle", "static"], "walk": ["Walk", "walk"], "run": ["Run", "run"],  # lowercase: the cube-pet monkey
	"carry": ["Idle_Holding", "Idle_Gun_Pointing", "static"], "carry_walk": ["Walk_Holding", "Walk", "walk"], "work": ["Assembly_Loop", "Interact", "static"],
	"yes": ["Yes", "Wave"], "no": ["No", "HitRecieve"],
}

var anim_id := -1
var _player: AnimationPlayer
var _clips := {}  ## logical name -> clip name in this model


func setup(skin: int) -> void:
	var spec: Dictionary = SKINS[posmod(skin, SKINS.size())]
	var model: Node3D = load("res://core/assets/3d/%s.glb" % spec.model).instantiate()
	model.scale = Vector3.ONE * spec.scale
	add_child(model)
	_player = model.find_child("AnimationPlayer", true, false)
	var by_tail := {}
	for clip in _player.get_animation_list():
		by_tail[clip.get_slice("|", clip.get_slice_count("|") - 1)] = clip
	for logical in CLIPS:
		for tail in CLIPS[logical]:
			if by_tail.has(tail):
				_clips[logical] = by_tail[tail]
				if logical not in ["yes", "no"]:
					_player.get_animation(by_tail[tail]).loop_mode = Animation.LOOP_LINEAR
				break
	play(0)


func play(id: int, blend := 0.15) -> void:
	if id == anim_id and _player.is_playing():
		return
	anim_id = id
	var logical: String = ANIMS[clampi(id, 0, ANIMS.size() - 1)]
	_player.play(_clips.get(logical, _clips.get("idle", "")), blend)


## The coloured ring a worker stands on, so each player finds themself at a glance (the refs' player rings).
func ring(color: Color) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.56
	torus.rings = 24
	mi.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.scale = Vector3(1, 0.1, 1)
	mi.position.y = 0.02
	add_child(mi)


static func anim(anim_name: String) -> int:
	return ANIMS.find(anim_name)
