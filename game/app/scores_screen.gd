class_name ScoresScreen
extends Panel
## The menu's HALL OF FAME: the best shift on each map, then the latest shifts on this device.

signal back_pressed

const SIZE := Vector2(1000, 640)


func _ready() -> void:
	add_theme_stylebox_override("panel", Look.chunky(Color(Look.HUD_DARK, 0.96), 22))
	var title := Look.label("HALL OF FAME", 52, Look.PRIMARY, true)
	title.position = Vector2(0, 14)
	title.size = Vector2(SIZE.x, 64)
	add_child(title)
	var bests := HBoxContainer.new()
	bests.position = Vector2(30, 90)
	bests.size = Vector2(SIZE.x - 60, 150)
	bests.add_theme_constant_override("separation", 16)
	add_child(bests)
	for m in Rules.MAPS.size():
		bests.add_child(_best_card(m))
	var head := Look.label("LATEST SHIFTS", 24, Look.WHITE.darkened(0.2), true)
	head.position = Vector2(0, 252)
	head.size = Vector2(SIZE.x, 32)
	add_child(head)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 290)
	scroll.size = Vector2(SIZE.x - 60, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var recent := Records.recent()
	if recent.is_empty():
		list.add_child(Look.label("No shifts yet. Go make a mess!", 26, Look.SKY, true))
	for e: Dictionary in recent:
		list.add_child(_recent_row(e))
	var back := Look.button("BACK", Look.PRIMARY, 32)
	back.position = Vector2(SIZE.x / 2.0 - 120, 556)
	back.size = Vector2(240, 70)
	back.pressed.connect(back_pressed.emit)
	add_child(back)


## One map's record: its name in the map's colour, the best coins and stars.
func _best_card(m: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tint := Color(Rules.MAPS[m].look.get("floor", {}).get("teal", "4CC9F0"))
	var style := Look.pill(tint.darkened(0.55), 18)
	style.set_border_width_all(4)
	style.border_color = tint
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	card.add_child(box)
	box.add_child(Look.label(Rules.MAPS[m].name, 20, Look.WHITE, true))
	var best := Records.best(m)
	if best.is_empty():
		box.add_child(Look.label("not played yet", 22, Look.WHITE.darkened(0.35)))
		return card
	box.add_child(Look.label("%d" % int(best.coins), 48, Look.PRIMARY, true))
	box.add_child(_stars(int(best.stars), 26))
	return card


func _recent_row(e: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := Look.pill(Color("3A3F4A"), 14)
	style.content_margin_left = 16
	style.content_margin_right = 16
	panel.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	panel.add_child(line)
	var map: int = clampi(int(e.get("map", 0)), 0, Rules.MAPS.size() - 1)
	var when := Time.get_datetime_dict_from_unix_time(int(e.get("t", 0)) + int(Time.get_time_zone_from_system().bias) * 60)
	var info := Look.label("%02d:%02d  %s" % [when.hour, when.minute, Rules.MAPS[map].name], 20, Look.SKY, true)
	info.custom_minimum_size.x = 330
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	line.add_child(info)
	line.add_child(_stars(int(e.get("stars", 0)), 22))
	var who := Look.label("%s  ·  you %d  ·  %s %d" % [str(e.get("title", "")), int(e.get("mine", 0)),
		str(e.get("partner", "?")), int(e.get("partner_pts", 0))], 18, Look.MINT)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	line.add_child(who)
	line.add_child(Look.label("%d" % int(e.get("coins", 0)), 30, Look.WHITE, true))
	return panel


static func _stars(n: int, px: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	for i in 3:
		var s := TextureRect.new()
		s.texture = load("res://core/assets/ui/star.png")
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		s.custom_minimum_size = Vector2(px, px)
		s.modulate = Color.WHITE if i < n else Color(0.3, 0.3, 0.38, 0.9)
		row.add_child(s)
	return row
