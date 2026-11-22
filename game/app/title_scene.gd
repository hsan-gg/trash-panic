class_name TitleScene
extends Node3D
## Behind the menus: the picked map (its harbour, belts, machines and colours) with a camera drifting slowly over
## it, so the first screen already shows the game.

const PROPS := [["can", "bottle", "box", "jar", "plank", "paper", "nuke"], ["apple", "peel", "can", "bottle", "jar"], ["board", "cable", "battery", "can", "jar"]]

var map := 0  ## set before adding it to the tree
var _cam := Camera3D.new()
var _belts: StationArt


func _ready() -> void:
	Rules.set_map(map)
	var room := RoomMap.load_room(Rules.MAPS[map].room)
	var decor := RoomDecor.new()
	add_child(decor)
	decor.build(room)
	_belts = StationArt.new()
	_belts.build(self, room, false)
	for kind in PROPS[map]:  # a little of this map's waste lying about
		var item := ItemArt.make(kind, "5")
		item.position = room.world(Vector2i(randi_range(1, 13), randi_range(3, 5)))
		item.rotation.y = randf() * TAU
		add_child(item)
	_cam.fov = 42.0
	add_child(_cam)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_cam.position = Vector3(2.5 + sin(t * 0.12) * 3.0, 9.0, 8.5)
	_cam.look_at(Vector3(1.5 + sin(t * 0.12) * 2.5, 0.0, 0.0))
	for b in _belts.belts:
		b.mat.set_shader_parameter("offset", t * 1.6)
