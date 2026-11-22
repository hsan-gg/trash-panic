extends Node
## Autoload "Sfx": one-shot sounds with a player pool, and a single looping music track.

const SFX := [
	"pop_1", "pop_2", "pop_3", "coin", "pickup_coin", "gem_gather", "ui_click", "ui_confirmation",
	"ui_back", "ui_tick", "ui_error", "ui_bong", "ui_maximize", "ui_pluck", "ui_drop", "ui_scratch",
	"sfx_crunch", "sfx_horn", "sfx_alarm", "sfx_splash", "sfx_whoosh", "sfx_thunk", "mx_slam", "mx_clank", "mx_fall",
]
const MUSIC := ["title", "lobby", "match", "stage_1", "stage_2", "boss", "happy_clappy", "result_win", "result_lose"]
const LOOPS := ["title", "lobby", "match", "stage_1", "stage_2", "boss", "happy_clappy"]  ## the rest are jingles
const SEMITONE := 1.0594631
const MAX_COMBO_STEPS := 12
const POOL := 10

var sfx_on := true
var music_on := true

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music := AudioStreamPlayer.new()
var _music_name := ""


func _ready() -> void:
	for n in SFX:
		_streams[n] = load("res://core/assets/sfx/%s.ogg" % n)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music.volume_db = -8.0
	add_child(_music)


func set_music(on: bool) -> void:
	music_on = on
	var track := _music_name
	_music_name = ""
	music(track)  # stops it, and restarts it only when on


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not sfx_on:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## The player "plays a scale": every combo step raises the pop by a semitone, up to an octave.
func pop(combo: int) -> void:
	play("pop_1", pow(SEMITONE, mini(maxi(combo - 1, 0), MAX_COMBO_STEPS)))


func music(track: String) -> void:
	if track == _music_name:
		return
	_music_name = track
	_music.stop()
	if track == "" or not music_on:
		return
	var stream: AudioStreamOggVorbis = load("res://core/assets/music/%s.ogg" % track)
	stream.loop = track in LOOPS
	_music.stream = stream
	_music.pitch_scale = 1.0
	_music.play()


func music_pitch(pitch: float) -> void:
	_music.pitch_scale = pitch
