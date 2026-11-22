class_name Look
extends RefCounted
## Chunky Pop look: palette, fonts, rounded panels and outlined labels (ASSETS.md §1).

const BG := Color("14102E")
const PANEL := Color("2A1F5C")
const PINK := Color("FF3D81")
const YELLOW := Color("FFD93D")
const MINT := Color("3DFFB5")
const SKY := Color("4CC9F0")
const ORANGE := Color("FF8C42")
const WHITE := Color.WHITE
const OUTLINE := Color("14102E")
const HUD_DARK := Color("2B2F38")  ## the refs' charcoal HUD panels
const INK := Color("1E2026")  ## outlines and text on light buttons
const PRIMARY := Color("FFC21A")  ## the one call-to-action colour (PLAY, AGAIN)
const DANGER := Color("E0393E")

const FONT_BODY := "res://core/assets/fonts/Fredoka-Bold.ttf"
const FONT_DISPLAY := "res://core/assets/fonts/LilitaOne-Regular.ttf"

const UI := "res://core/assets/ui/%s.png"

static var _theme: Theme
static var _disc: ImageTexture


static func emoji(id: String) -> Texture2D:
	return load("res://core/assets/emoji/%s.png" % id)


## A white monochrome icon (Fluent high-contrast set) for floor badges and the HUD; tint it with modulate.
static func glyph(id: String) -> Texture2D:
	return load("res://core/assets/glyphs/%s.svg" % id)


## A white disc with a dark rim (tint it with modulate): sign and marker backgrounds.
static func disc() -> ImageTexture:
	if _disc == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length()
				var edge := clampf(31.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, edge) if d < 26.0 else Color(0.12, 0.13, 0.15, edge))
		_disc = ImageTexture.create_from_image(img)
	return _disc


static func pill(color: Color, radius := 40) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 6)
	s.content_margin_left = 32
	s.content_margin_right = 32
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	return s


## The refs' HUD panels: a solid fill with a thick white outline and a drop shadow.
static func chunky(color: Color, radius := 16) -> StyleBoxFlat:
	var s := pill(color, radius)
	s.set_border_width_all(5)
	s.border_color = Color.WHITE
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 4)
	s.set_content_margin_all(10)
	return s


## The game's button: a chunky toy. Bright fill, dark outline, and a thick lip underneath in its own darker colour
## (then a soft shadow) so it looks 3D; pressed, it sinks onto the lip. style_button() adds a glossy highlight.
static func toy(color: Color, pressed := false, radius := 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(4)
	s.border_width_bottom = 4 if pressed else 10
	s.border_color = color.darkened(0.55)  # the lip and outline in the button's own colour, darker
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 2 if pressed else 6)
	s.expand_margin_top = -4.0 if pressed else 0.0  # sinks
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 10 + (5 if pressed else 0)
	s.content_margin_bottom = 12 - (5 if pressed else 0)
	return s


## Style any Button as a toy button; dark text on light colours, white on dark ones.
static func style_button(b: Button, color: Color, font_size := 0) -> Button:
	b.add_theme_stylebox_override("normal", toy(color))
	b.add_theme_stylebox_override("hover", toy(color.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", toy(color.darkened(0.06), true))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var text := INK if color.get_luminance() > 0.55 else Color.WHITE
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, text)
	b.add_theme_constant_override("outline_size", 0)
	if font_size > 0:
		b.add_theme_font_size_override("font_size", font_size)
	if not b.has_node("Gloss"):
		b.add_child(gloss())
	return b


## A soft white highlight over the top of a button or card (the glossy mobile-game look); ignores the mouse.
static func gloss(radius := 14) -> Panel:
	var g := Panel.new()
	g.name = "Gloss"
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.16)
	s.set_corner_radius_all(radius)
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	g.add_theme_stylebox_override("panel", s)
	g.anchor_right = 1.0
	g.anchor_bottom = 0.42
	g.offset_left = 8
	g.offset_top = 6
	g.offset_right = -8
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


static func button(text: String, color: Color, font_size := 32) -> Button:
	var b := Button.new()
	b.text = text
	return style_button(b, color, font_size)


static func label(text: String, size: int, color := WHITE, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load(FONT_DISPLAY if display else FONT_BODY))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(4, size / 8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Theme applied once at the root; every Button below becomes a big pill.
static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font = load(FONT_BODY)
	_theme.default_font_size = 40
	_theme.set_font("font", "Button", load(FONT_DISPLAY))
	_theme.set_font_size("font_size", "Button", 56)
	_theme.set_color("font_color", "Button", WHITE)
	_theme.set_color("font_pressed_color", "Button", WHITE)
	_theme.set_color("font_hover_color", "Button", WHITE)
	_theme.set_color("font_outline_color", "Button", OUTLINE)
	_theme.set_constant("outline_size", "Button", 8)
	_theme.set_stylebox("normal", "Button", toy(HUD_DARK))
	_theme.set_stylebox("hover", "Button", toy(HUD_DARK.lightened(0.08)))
	_theme.set_stylebox("pressed", "Button", toy(HUD_DARK, true))
	_theme.set_constant("outline_size", "Button", 0)
	var field := toy(Color("1E2026"))
	field.shadow_offset = Vector2.ZERO
	field.border_color = Color.WHITE
	field.content_margin_left = 10
	field.content_margin_right = 10
	_theme.set_stylebox("normal", "LineEdit", field)
	_theme.set_stylebox("focus", "LineEdit", field)
	_theme.set_color("font_color", "LineEdit", Color.WHITE)
	_theme.set_font("font", "LineEdit", load(FONT_DISPLAY))
	_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	return _theme
