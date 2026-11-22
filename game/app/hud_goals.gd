class_name HudGoals
extends Control
## The shift's goals on the HUD (GAME_PLAN.md §4, §6): three QUEST cards under the stars (icon, text, progress bar,
## a stamp when done), the flaming COMBO pill under the orders, and the LEVEL badge under the timer.

const ROW := Vector2(296, 48)
const TOP := 168.0

var _rows: Array = []  ## [{panel, icon, text, count, fill, done}]
var _combo: Control
var _combo_label: Label
var _level: Label
var _level_n := 0
var _combo_n := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		_rows.append(_quest_row(Vector2(14, TOP + i * (ROW.y + 8))))
	_build_combo()
	_build_level()


func refresh(shift: Shift) -> void:
	var list: Array = shift.quests.list
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		row.panel.visible = i < list.size()
		if i >= list.size():
			continue
		var q: Dictionary = list[i]
		row.icon.texture = Look.glyph("check" if q.got >= q.need else Quests.POOL[q.k].icon)
		row.text.text = Quests.text(q)
		row.count.text = "%d/%d" % [mini(q.got, q.need), q.need]
		row.fill.size.x = lerpf(row.fill.size.x, (ROW.x - 72) * clampf(float(q.got) / q.need, 0.0, 1.0), 0.25)
		if q.got >= q.need and not row.done:
			_stamp(row)
		elif q.got < q.need and row.done:
			_unstamp(row)
	_set_combo(shift.combo)
	var level := Rules.level(shift.elapsed)
	if level != _level_n:
		_level_n = level
		_level.text = "LEVEL %d" % level
		Juice.squash(_level)


func on_cue(e: Dictionary) -> void:
	match e.e:
		"combo_lost":
			Juice.squash(_combo)


## One quest card: a rounded dark panel, the quest's icon in a coloured disc, its text, a count and a progress bar.
func _quest_row(at: Vector2) -> Dictionary:
	var panel := Panel.new()
	var style := Look.pill(Color(Look.HUD_DARK, 0.92), 14)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.85)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = at
	panel.size = ROW
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var disc := Panel.new()
	var ds := Look.pill(Look.SKY, 20)
	ds.shadow_size = 0
	disc.add_theme_stylebox_override("panel", ds)
	disc.position = Vector2(6, 6)
	disc.size = Vector2(38, 38)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(disc)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.position = Vector2(7, 7)
	icon.size = Vector2(24, 24)
	icon.modulate = Look.INK
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(icon)
	var text := Look.label("", 16, Look.WHITE)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.position = Vector2(52, 2)
	text.size = Vector2(ROW.x - 120, 30)
	panel.add_child(text)
	var count := Look.label("", 17, Look.YELLOW, true)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.position = Vector2(ROW.x - 74, 2)
	count.size = Vector2(64, 30)
	panel.add_child(count)
	var track := ColorRect.new()
	track.color = Color(0, 0, 0, 0.45)
	track.position = Vector2(52, 34)
	track.size = Vector2(ROW.x - 72, 8)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(track)
	var fill := ColorRect.new()
	fill.color = Look.MINT
	fill.size = Vector2(0, 8)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	return {"panel": panel, "disc": ds, "icon": icon, "text": text, "count": count, "fill": fill, "style": style, "done": false,
			"base": [style.bg_color, style.border_color, ds.bg_color]}


## A quest just got done: the card turns mint with a check, pops, and throws confetti.
func _stamp(row: Dictionary) -> void:
	row.done = true
	row.style.bg_color = Color("1F6E4E")
	row.style.border_color = Look.MINT
	row.disc.bg_color = Look.MINT
	var panel: Panel = row.panel
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(1.25, 1.25)
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for color in [Look.YELLOW, Look.MINT, Look.PINK, Look.SKY]:
		Juice.burst(get_parent(), panel.global_position + panel.size / 2.0, color, 8)


## A new quest took the card: back to its normal colours, and it slides in.
func _unstamp(row: Dictionary) -> void:
	row.done = false
	row.style.bg_color = row.base[0]
	row.style.border_color = row.base[1]
	row.disc.bg_color = row.base[2]
	row.fill.size.x = 0.0
	var panel: Panel = row.panel
	var x := panel.position.x
	panel.position.x = x - 340.0
	panel.create_tween().tween_property(panel, "position:x", x, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_combo() -> void:
	_combo = PanelContainer.new()
	var style := Look.pill(Look.ORANGE, 30)
	style.set_border_width_all(4)
	style.border_color = Color.WHITE
	style.content_margin_left = 14
	style.content_margin_right = 18
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_combo.add_theme_stylebox_override("panel", style)
	_combo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_combo.offset_left = -250
	_combo.offset_right = -14
	_combo.offset_top = 142
	_combo.offset_bottom = 196
	_combo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo.visible = false
	add_child(_combo)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo.add_child(row)
	var flame := TextureRect.new()
	flame.texture = Look.emoji("fire")
	flame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flame.custom_minimum_size = Vector2(40, 40)
	flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(flame)
	_combo_label = Look.label("", 30, Look.WHITE, true)
	row.add_child(_combo_label)


## The pill shows from a 3-chain; it pops at each new multiplier step.
func _set_combo(n: int) -> void:
	_combo.visible = n >= 3
	if n == _combo_n:
		return
	var stepped := Rules.combo_mult(n) > Rules.combo_mult(_combo_n)
	_combo_n = n
	_combo_label.text = "COMBO %d  x%s" % [n, str(Rules.combo_mult(n)).trim_suffix(".0")]
	if n >= 3:
		Juice.squash(_combo)
	if stepped:
		Juice.burst(get_parent(), _combo.global_position + _combo.size / 2.0, Look.ORANGE, 16)
		Juice.ring(get_parent(), _combo.global_position + _combo.size / 2.0, Look.YELLOW)


func _build_level() -> void:
	_level = Look.label("LEVEL 1", 22, Look.WHITE, true)
	var bg := Look.pill(Color("7A3DF0"), 18)
	bg.set_border_width_all(3)
	bg.border_color = Color.WHITE
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	_level.add_theme_stylebox_override("normal", bg)
	_level.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_level.offset_left = -70
	_level.offset_right = 70
	_level.offset_top = 124
	_level.offset_bottom = 156
	_level.pivot_offset = Vector2(70, 16)
	add_child(_level)
