class_name GardenTheme
extends RefCounted

## Shared palette, fonts and style helpers for the whole game.
## Everything is drawn/constructed in code so the project needs no art assets.

const BG := Color("f6f0ff")
const BG2 := Color("fff7fb")
const SURFACE := Color("fffaf3")
const CARD := Color("ffffff")
const LAVENDER := Color("b39ddb")
const LAVENDER_DEEP := Color("8e7cc3")
const LAVENDER_SOFT := Color("ece4fb")
const PINK := Color("f7bfd0")
const PINK_DEEP := Color("e38aa8")
const PINK_SOFT := Color("ffe9f0")
const YELLOW := Color("ffe082")
const YELLOW_DEEP := Color("e3b34c")
const YELLOW_SOFT := Color("fff4cc")
const MINT := Color("bfe8d1")
const MINT_DEEP := Color("5fae84")
const INK := Color("3d3550")
const MUTED := Color("837a96")
const LINE := Color("e9e2f2")
const LOCKED := Color("ece8f3")
const LOCKED_INK := Color("a79fba")
const DANGER := Color("d96c7c")
const WHITE := Color("ffffff")
const SHADOW := Color(0.35, 0.25, 0.5, 0.13)

static var _regular: Font
static var _bold: Font
static var _theme: Theme


static func regular_font() -> Font:
	if _regular == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "Roboto", "Arial", "DejaVu Sans"])
		f.font_weight = 400
		f.allow_system_fallback = true
		_regular = f
	return _regular


static func bold_font() -> Font:
	if _bold == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI Semibold", "Segoe UI", "Noto Sans", "Roboto", "Arial", "DejaVu Sans"])
		f.font_weight = 700
		f.allow_system_fallback = true
		_bold = f
	return _bold


static func panel_style(color: Color = CARD, radius: int = 24, shadow: bool = true,
		border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	if shadow:
		sb.shadow_color = SHADOW
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 5)
	if border_width > 0:
		sb.border_color = border
		sb.border_width_left = border_width
		sb.border_width_right = border_width
		sb.border_width_top = border_width
		sb.border_width_bottom = border_width
	return sb


static func button_style(color: Color, radius: int = 20, shadow: bool = true) -> StyleBoxFlat:
	var sb := panel_style(color, radius, shadow)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


static func build_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = regular_font()
	t.default_font_size = 17

	t.set_color("font_color", "Label", INK)
	t.set_font_size("font_size", "Label", 17)

	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())

	t.set_stylebox("normal", "Button", button_style(LAVENDER))
	t.set_stylebox("hover", "Button", button_style(LAVENDER.lightened(0.08)))
	t.set_stylebox("pressed", "Button", button_style(LAVENDER_DEEP))
	t.set_stylebox("focus", "Button", button_style(LAVENDER, 20, false))
	t.set_stylebox("disabled", "Button", button_style(LOCKED, 20, false))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", WHITE)
	t.set_color("font_disabled_color", "Button", LOCKED_INK)
	t.set_font("font", "Button", bold_font())
	t.set_font_size("font_size", "Button", 17)

	t.set_stylebox("normal", "LineEdit", _input_style(CARD))
	t.set_stylebox("focus", "LineEdit", _input_style(CARD, LAVENDER, 2))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", LOCKED_INK)
	t.set_color("caret_color", "LineEdit", LAVENDER_DEEP)
	t.set_font_size("font_size", "LineEdit", 17)

	t.set_stylebox("background", "ProgressBar", panel_style(LINE, 8, false))
	t.set_stylebox("fill", "ProgressBar", panel_style(LAVENDER, 8, false))
	t.set_color("font_color", "ProgressBar", INK)

	t.set_stylebox("panel", "PopupMenu", panel_style(CARD, 18, true))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_stylebox("panel", "TooltipPanel", panel_style(INK, 12, true))

	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	_theme = t
	return t


static func _input_style(bg: Color, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var sb := panel_style(bg, 16, false, border, width)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func kind_color(kind: String) -> Color:
	match kind:
		"primary":
			return LAVENDER
		"pink":
			return PINK
		"yellow":
			return YELLOW
		"mint":
			return MINT
		"ghost":
			return LAVENDER_SOFT
		"danger":
			return DANGER
		_:
			return CARD


static func kind_ink(kind: String) -> Color:
	match kind:
		"primary":
			return Color("2f2650")
		"pink":
			return Color("5a2a3a")
		"yellow":
			return Color("4d3b12")
		"mint":
			return Color("1e4a36")
		"danger":
			return WHITE
		_:
			return INK
