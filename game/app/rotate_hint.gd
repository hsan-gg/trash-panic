class_name RotateHint
extends CanvasLayer
## Phones held upright get a "turn your phone" card: the game is landscape only, and browsers (iPhone Safari above
## all) cannot lock the orientation. Desktop windows are never covered.

var _card: Control


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_card = ColorRect.new()
	(_card as ColorRect).color = Color("14213D")
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	var label := Look.label("Turn your phone sideways\nto play TRASH PANIC!", 44, Look.YELLOW, true)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(label)
	get_viewport().size_changed.connect(_check)
	_check()


static func is_phone() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _check() -> void:
	var size := get_viewport().get_visible_rect().size
	_card.visible = is_phone() and size.y > size.x
