class_name ThemeHelpers
extends RefCounted
## Shared UI builders for Gully Cricket Legends screens.
## Flat red-brand style, no external theme files. All buttons are >= 56px tall
## and all text is >= 18px so layouts hold at 960x540 on small phones.

const RED := Color("c62828")
const RED_DARK := Color("8e1b1b")
const RED_DEEP := Color("5d1010")
const PAPER := Color("f7f2e7")
const PAPER_DIM := Color("e9e0cb")
const INK := Color("1e2732")
const MUTED := Color("5d6b7a")
const GOLD := Color("f2b134")
const GREEN := Color("2e7d32")
const BLUE := Color("1565c0")
const ORANGE := Color("ef6c00")
const DISABLED := Color("9a9a9a")
const BAR_BG := Color("141b24")


static func panel_style(bg: Color = PAPER, radius: int = 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 20.0
	sb.border_color = Color(0, 0, 0, 0.18)
	sb.set_border_width_all(2)
	return sb


static func _btn_style(c: Color, radius: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb


## Primary red button. min_height defaults to 64 (>= 56px requirement).
static func make_button(text: String, min_height: float = 64.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_height)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	b.add_theme_stylebox_override("normal", _btn_style(RED))
	b.add_theme_stylebox_override("hover", _btn_style(RED_DARK))
	b.add_theme_stylebox_override("pressed", _btn_style(RED_DEEP))
	b.add_theme_stylebox_override("disabled", _btn_style(DISABLED))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


## Toggle button for option rows: gray when off, red when on.
static func make_toggle(text: String, on: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = on
	b.custom_minimum_size = Vector2(0, 60)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _btn_style(Color("4a5563")))
	b.add_theme_stylebox_override("hover", _btn_style(Color("3a434e")))
	b.add_theme_stylebox_override("pressed", _btn_style(RED))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


static func title_label(text: String, size: int = 32, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func body_label(text: String, size: int = 20, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func hud_label(text: String, size: int = 20, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func hud_bar_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BAR_BG
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


static func chip_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.12)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb


## Full-screen dim layer that blocks input behind a modal panel.
static func dim_layer() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0, 0, 0, 0.55)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	return d


## Wraps a panel in a centered full-rect container (with dim behind it).
static func centered(panel: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(panel)
	return cc


static func make_panel(min_size: Vector2 = Vector2(560, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.add_theme_stylebox_override("panel", panel_style())
	return p


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	return v


static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	return h


static func spacer(min_w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(min_w, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func make_check(text: String, on: bool) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.custom_minimum_size = Vector2(0, 56)
	c.add_theme_font_size_override("font_size", 20)
	c.add_theme_color_override("font_color", INK)
	c.add_theme_color_override("font_pressed_color", INK)
	c.add_theme_color_override("font_hover_color", INK)
	c.add_theme_color_override("font_hover_pressed_color", INK)
	c.add_theme_color_override("font_focus_color", INK)
	c.add_theme_color_override("font_disabled_color", MUTED)
	return c
