class_name Controls
extends CanvasLayer
## Touch HUD: native joystick on the left half; one ACTION button (grab / drop / hold to use) and DASH on the right.
## Multi-touch safe (TouchScreenButton). Keyboard: WASD/arrows, Space or E = ACTION, Shift = DASH.

signal action_pressed
signal action_released
signal dash_pressed

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN], "action": [KEY_SPACE, KEY_E], "dash": [KEY_SHIFT],
}
const BIG := 150.0
const SMALL := 116.0

var _joystick := VirtualJoystick.new()
var _action: TouchScreenButton
var _dash: TouchScreenButton


func _ready() -> void:
	layer = 10
	register_actions()
	_joystick.action_left = &"move_left"
	_joystick.action_right = &"move_right"
	_joystick.action_up = &"move_forward"
	_joystick.action_down = &"move_back"
	_joystick.joystick_mode = VirtualJoystick.JOYSTICK_DYNAMIC
	_joystick.joystick_size = 150.0
	# The thumb zone hugs the bottom-left corner; the stick appears wherever the thumb lands inside it.
	_joystick.anchor_top = 1.0
	_joystick.anchor_bottom = 1.0
	_joystick.offset_top = -380.0
	_joystick.offset_right = 460.0
	add_child(_joystick)
	_action = _button("GRAB", "action", BIG * 1.15, Look.PRIMARY)
	_dash = _button("DASH", "dash", SMALL, Look.HUD_DARK)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("action"):
		action_pressed.emit()
	elif event.is_action_released("action"):
		action_released.emit()
	elif event.is_action_pressed("dash"):
		dash_pressed.emit()


## The ACTION button names what it will do now (GRAB, DROP, THROW, SHOO, FIX, OPEN).
func set_label(action: String) -> void:
	_action.get_child(0).text = action


## The shift is over: the touch controls step aside for the results.
func hide_buttons() -> void:
	for n: CanvasItem in [_action, _dash, _joystick]:
		n.visible = false


static func register_actions() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key in KEYS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action, e)


func _button(text: String, action: String, size: float, color: Color) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.texture_normal = _round(color, false)
	b.texture_pressed = _round(color, true)
	b.scale = Vector2.ONE * size / 128.0
	b.action = action  # the InputMap action drives _unhandled_input above for touch and keys alike
	var l := Look.label(text, 30, Look.INK if color.get_luminance() > 0.55 else Look.WHITE, true)  # in 128 px texture space
	l.add_theme_constant_override("outline_size", 0)
	l.size = Vector2(128, 116)
	add_child(b)
	b.add_child(l)
	return b


## A flat toy circle: colour fill, dark outline, hard shadow underneath (gone when pressed, the button sinks).
static func _round(color: Color, pressed: bool) -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var shadow := 0.0 if pressed else 7.0
	for y in 128:
		for x in 128:
			var top := Vector2(x - 63.5, y - 59.5 - (5.0 if pressed else 0.0)).length()
			var low := Vector2(x - 63.5, y - 59.5 - shadow).length()
			var c := Color(0, 0, 0, 0)
			if low < 58.0:
				c = Look.INK
			if top < 58.0:
				c = Look.INK if top > 53.0 else color
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	_action.position = view - Vector2(BIG * 1.15 + 36, BIG * 1.15 + 40)
	_dash.position = _action.position + Vector2(-SMALL - 28, BIG * 0.5)
