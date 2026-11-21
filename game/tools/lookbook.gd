extends Node2D
## Dev-only lookbook: the four zones side by side with their tints, to judge the asset mix.
## shortcut: lists res:// folders at runtime, so it only works when run from the editor, not in exports.

const ZONE_W := 160
const ZONE_H := 180
const W := "res://assets/world/"
const ZONES := [
	# Tints multiply, so they stay close to white: darker values crush the pixel art.
	{"name": "SETTLEMENT", "tint": Color("#fff0d8"), "ground": W + "zombie/Terrain_Variations/",
		"props": [W + "zombie/Windmill_with_Fan_Animation_Frames", W + "zombie/Different_Crops_Lengths",
			W + "zombie/Scarecrow", W + "zombie/Trees", W + "zombie/Modular_Fences", W + "zombie/Modular_Barns"]},
	{"name": "OUTER DUMP", "tint": Color("#c9bca6"), "ground": W + "lazystone/Tiles/Background_Bleak-Yellow_TileSet.png",
		"ground_region": Rect2(32, 32, 16, 16),
		"props": [W + "lazystone/Objects", W + "zombie/Broken_Cars_and_Tires", W + "zombie/Smoke_Animation_Frames"]},
	{"name": "SORTING CENTRE", "tint": Color("#d0dae2"), "ground": W + "lazystone/Tiles/Background_Bleak-Yellow_TileSet.png",
		"ground_region": Rect2(80, 144, 16, 16),
		"props": ["res://assets/generated", W + "factory"]},
	{"name": "RELAY TOWER", "tint": Color("#dde6ec"), "ground": W + "zombie/Modular_Terrain_Path/",
		"props": ["res://assets/generated/relay_broken.png", "res://assets/generated/relay_fixed.png",
			W + "terminal", W + "lazystone/Tiles/Iron-Fence_TileSet.png"]},
]


func _ready() -> void:
	for i in ZONES.size():
		_build_zone(ZONES[i], i * ZONE_W)
	var cam := Camera2D.new()
	cam.position = Vector2(ZONES.size() * ZONE_W / 2.0, ZONE_H / 2.0)
	cam.zoom = Vector2(2, 2)
	add_child(cam)


func _build_zone(zone: Dictionary, x0: int) -> void:
	var root := Node2D.new()
	root.position = Vector2(x0, 0)
	root.modulate = zone.tint
	add_child(root)

	var ground := Sprite2D.new()
	ground.texture = _ground_texture(zone)
	ground.centered = false
	ground.region_enabled = true
	ground.region_rect = Rect2(0, 0, ZONE_W, ZONE_H)
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	root.add_child(ground)

	var cursor := Vector2(4, 14)
	var row_h := 0.0
	for source in zone.props:
		for path in _pngs(source).slice(0, 8):
			var tex: Texture2D = load(path)
			if cursor.x + tex.get_width() > ZONE_W - 4:
				cursor = Vector2(4, cursor.y + row_h + 3)
				row_h = 0.0
			if cursor.y + tex.get_height() > ZONE_H - 24:
				break
			var prop := Sprite2D.new()
			prop.texture = tex
			prop.centered = false
			prop.position = cursor
			root.add_child(prop)
			cursor.x += tex.get_width() + 3
			row_h = max(row_h, tex.get_height())

	_add_player(root, Vector2(ZONE_W / 2.0, ZONE_H - 14))
	var label := Label.new()
	label.text = zone.name
	label.add_theme_font_size_override("font_size", 8)
	label.position = Vector2(4, 1)
	root.add_child(label)


func _ground_texture(zone: Dictionary) -> Texture2D:
	var path: String = zone.ground
	if path.ends_with("/"):
		path = _pngs(path)[0]
	var tex: Texture2D = load(path)
	if not zone.has("ground_region"):
		return tex
	# Repeat only works on a whole texture, so cut the tile out of the sheet first.
	return ImageTexture.create_from_image(tex.get_image().get_region(zone.ground_region))


func _add_player(root: Node2D, at: Vector2) -> void:
	var player := Sprite2D.new()
	var frame := AtlasTexture.new()
	frame.atlas = load("res://assets/characters/player/Character_down_idle_no-hands-Sheet6.png")
	frame.region = Rect2(0, 0, frame.atlas.get_width() / 6.0, frame.atlas.get_height())
	player.texture = frame
	player.position = at
	root.add_child(player)
	var fru := Sprite2D.new()
	fru.texture = load("res://assets/generated/fru01_a.png")
	fru.position = at + Vector2(12, -10)
	root.add_child(fru)


func _pngs(source: String) -> Array:
	if source.ends_with(".png"):
		return [source]
	var files := Array(DirAccess.get_files_at(source)).filter(func(f): return f.ends_with(".png"))
	files.sort()
	return files.map(func(f): return source.path_join(f))
