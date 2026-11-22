class_name Tutorial
extends PanelContainer
## Guided first shift, shown to BOTH players with the steps of their own side (Rules.TUTORIAL[side]): the left worker
## learns catch → belt → hazard bins, the right worker belt → machine → orders. Steps advance on what really happens.
## The session draws the arrow: where this player's item goes, else `target()`.

signal finished

var _shift: Shift
var _area: Dictionary  ## this player's walkable side
var _steps: Array
var _my_id := -1
var _step := 0
var _wait := 0.0
var _count: Label
var _text: Label


func setup(shift: Shift, my_id: int, side: int, area: Dictionary) -> void:
	_shift = shift
	_my_id = my_id
	_steps = Rules.TUTORIAL[side]
	_area = area


func _ready() -> void:
	theme = Look.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)  # under the score: the bottom corners belong to the thumbs
	offset_left = 14
	offset_top = 168
	custom_minimum_size = Vector2(196, 0)  # narrow: it sits over the left wall, never over the floor
	add_theme_stylebox_override("panel", Look.chunky(Color(Look.HUD_DARK, 0.94), 16))
	var box := VBoxContainer.new()
	add_child(box)
	_count = Look.label("", 18, Look.YELLOW, true)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_count)
	_text = Look.label("", 15, Look.WHITE)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(176, 0)
	box.add_child(_text)
	var skip := Button.new()
	skip.text = "SKIP"
	skip.add_theme_font_size_override("font_size", 16)
	skip.custom_minimum_size = Vector2(90, 38)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.pressed.connect(_finish)
	box.add_child(skip)
	_show()


func _process(delta: float) -> void:
	var step: Dictionary = _steps[_step]
	if step.get("held", false) and _shift.held(_my_id) >= 0:
		_advance()
	elif step.has("seconds"):
		_wait += delta
		if _wait >= step.seconds:
			_finish()


func on_cue(e: Dictionary) -> void:
	if e.e in _steps[_step].get("done_on", []):
		_advance()


## Where the arrow points while this player's hands are empty.
func target() -> Variant:
	var at: String = _steps[_step].at
	match at:
		"item":  # the nearest loose waste on my side
			for id in _shift.items:
				var it: Dictionary = _shift.items[id]
				if it.at != null and _area.has(it.at):
					return it.at
			return null
		"belt_in":
			return Guide.incoming_belt(_shift, _area)
	for tile in _shift.room.tiles:
		if _shift.room.tiles[tile] == at and Guide.touches(_area, tile):
			return tile
	return null


func _advance() -> void:
	_step += 1
	_wait = 0.0
	if _step >= _steps.size():
		_finish()
		return
	_show()


func _show() -> void:
	_count.text = "TUTORIAL %d/%d" % [_step + 1, _steps.size()]
	_text.text = _steps[_step].text


func _finish() -> void:
	Profile.finish_tutorial()
	finished.emit()
	queue_free()
