class_name MenuArt
extends RefCounted
## Main-menu art kit for Gully Cricket Legends (v1.1 redesign).
## Everything is drawn procedurally in _draw() — no binary assets, no emoji.
## Contains: DrawnIcon (vector game icons), StadiumVista (animated menu
## backdrop), AvatarMedallion (profile medallion with name initial),
## and factories for menu buttons, cards, chips and the logo lockup.
##
## Scope: main menu only. Gameplay screens are untouched.

const NAVY := Color("141b24")
const NAVY_SOFT := Color(0.10, 0.13, 0.19, 0.94)
const GOLD := Color("f2b134")
const GOLD_DEEP := Color("c98a1b")
const CREAM := Color(1, 1, 1, 0.92)
const CREAM_DIM := Color(1, 1, 1, 0.62)


## Vector game icon drawn in _draw(). Set `kind` and `ink` before adding.
class DrawnIcon:
	extends Control

	var kind: String = "play"
	var ink: Color = Color.WHITE

	func _init(p_kind: String = "play", p_ink: Color = Color.WHITE) -> void:
		kind = p_kind
		ink = p_ink
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		if r <= 0.0:
			return
		match kind:
			"play":
				_draw_poly(c, r, [Vector2(-0.30, -0.48), Vector2(-0.30, 0.48), Vector2(0.55, 0.0)])
			"trophy":
				_draw_rect_c(c, r, Rect2(-0.34, -0.52, 0.68, 0.55))
				draw_arc(c + Vector2(-0.34 * r, -0.24 * r), 0.20 * r, PI * 0.5, PI * 1.5, 12, ink, 0.13 * r)
				draw_arc(c + Vector2(0.34 * r, -0.24 * r), 0.20 * r, -PI * 0.5, PI * 0.5, 12, ink, 0.13 * r)
				_draw_rect_c(c, r, Rect2(-0.07, 0.03, 0.14, 0.26))
				_draw_rect_c(c, r, Rect2(-0.30, 0.29, 0.60, 0.16))
			"player":
				draw_circle(c + Vector2(0, -0.26 * r), 0.27 * r, ink)
				_draw_poly(c, r, [Vector2(-0.52, 0.55), Vector2(0.52, 0.55), Vector2(0.30, -0.02), Vector2(-0.30, -0.02)])
			"team":
				draw_circle(c + Vector2(-0.38 * r, -0.10 * r), 0.20 * r, ink)
				draw_circle(c + Vector2(0.38 * r, -0.10 * r), 0.20 * r, ink)
				draw_circle(c + Vector2(0, -0.34 * r), 0.24 * r, ink)
				_draw_poly(c, r, [Vector2(-0.62, 0.55), Vector2(0.62, 0.55), Vector2(0.42, 0.10), Vector2(-0.42, 0.10)])
			"cart":
				_draw_poly(c, r, [Vector2(-0.52, -0.28), Vector2(0.52, -0.28), Vector2(0.34, 0.30), Vector2(-0.34, 0.30)])
				draw_line(c + Vector2(0.52 * r, -0.44 * r), c + Vector2(0.72 * r, -0.60 * r), ink, 0.12 * r)
				draw_circle(c + Vector2(-0.28 * r, 0.50 * r), 0.13 * r, ink)
				draw_circle(c + Vector2(0.28 * r, 0.50 * r), 0.13 * r, ink)
			"gear":
				for i in 8:
					var a: float = TAU * float(i) / 8.0
					var d := Vector2(cos(a), sin(a))
					draw_line(c + d * 0.62 * r, c + d * 0.95 * r, ink, 0.20 * r)
				draw_arc(c, 0.62 * r, 0.0, TAU, 24, ink, 0.20 * r)
				draw_circle(c, 0.24 * r, ink)
			"coin":
				draw_circle(c, 0.85 * r, ink)
				draw_arc(c, 0.58 * r, 0.0, TAU, 24, Color(1, 1, 1, 0.85), 0.14 * r)
			"ball":
				draw_circle(c, 0.85 * r, ink)
				draw_arc(c, 0.55 * r, -0.9, 0.9, 16, Color(1, 1, 1, 0.9), 0.10 * r)
				draw_arc(c, 0.55 * r, PI - 0.9, PI + 0.9, 16, Color(1, 1, 1, 0.9), 0.10 * r)
			"bat":
				draw_set_transform(c, -0.55, Vector2.ONE)
				draw_rect(Rect2(-0.16 * r, -0.05 * r, 0.32 * r, 0.85 * r), ink)
				draw_rect(Rect2(-0.07 * r, -0.75 * r, 0.14 * r, 0.70 * r), ink)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"x":
				draw_line(c + Vector2(-0.45, -0.45) * r, c + Vector2(0.45, 0.45) * r, ink, 0.18 * r)
				draw_line(c + Vector2(0.45, -0.45) * r, c + Vector2(-0.45, 0.45) * r, ink, 0.18 * r)
			"star":
				var pts := PackedVector2Array()
				for i in 10:
					var a: float = -PI * 0.5 + PI * float(i) / 5.0
					var rr: float = 0.85 * r if i % 2 == 0 else 0.38 * r
					pts.append(c + Vector2(cos(a), sin(a)) * rr)
				draw_colored_polygon(pts, ink)
			_:
				draw_circle(c, 0.5 * r, ink)

	func _draw_poly(c: Vector2, r: float, fracs: Array) -> void:
		var pts := PackedVector2Array()
		for f in fracs:
			pts.append(c + (f as Vector2) * r)
		draw_colored_polygon(pts, ink)

	func _draw_rect_c(c: Vector2, r: float, fr: Rect2) -> void:
		draw_rect(Rect2(c + fr.position * r, fr.size * r), ink)


## Profile medallion: jersey-color disc, gold ring, player initial.
class AvatarMedallion:
	extends Control

	var jersey: Color = Color("c62828")
	var initial: String = "?"

	func _init(p_initial: String = "?", p_jersey: Color = Color("c62828")) -> void:
		initial = p_initial
		jersey = p_jersey
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(56, 56)
		var lab := Label.new()
		lab.text = initial
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 26)
		lab.add_theme_color_override("font_color", Color.WHITE)
		lab.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
		lab.add_theme_constant_override("shadow_offset_x", 2)
		lab.add_theme_constant_override("shadow_offset_y", 2)
		lab.set_anchors_preset(Control.PRESET_FULL_RECT)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lab)

	func _draw() -> void:
		var c := size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		if r <= 0.0:
			return
		draw_circle(c, r, Color(0, 0, 0, 0.35))
		draw_circle(c, r - 2.0, MenuArt.GOLD)
		draw_circle(c, r - 5.0, jersey)


## Animated cricket-stadium vista for the menu background.
## Dusk sky, floodlights, grandstand with crowd, striped outfield,
## boundary rope and a distant pitch — clearly a presentation vista,
## plus scrims so UI text stays readable.
class StadiumVista:
	extends Control

	var _clouds: Array = []
	var _crowd: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r := RandomNumberGenerator.new()
		r.seed = 20261010
		for i in 6:
			_clouds.append({
				"x": r.randf_range(-240.0, 1200.0),
				"y": r.randf_range(14.0, 120.0),
				"s": r.randf_range(0.7, 1.5),
				"speed": r.randf_range(6.0, 20.0),
			})
		var palette: Array[Color] = [
			Color("d9c8a9"), Color("b08968"), Color("7f5539"), Color("9c6644"),
			Color("e0e0e0"), Color("606060"), Color("c14953"),
		]
		for i in 420:
			_crowd.append({
				"p": Vector2(r.randf(), r.randf()),
				"c": palette[r.randi_range(0, palette.size() - 1)],
			})

	func _process(delta: float) -> void:
		for cl in _clouds:
			cl["x"] = float(cl["x"]) + float(cl["speed"]) * delta
			if float(cl["x"]) > 1240.0:
				cl["x"] = -300.0
		queue_redraw()

	## Vertical gradient painted as strips (no texture dependency).
	func _vgrad(rect: Rect2, top: Color, bottom: Color, strips: int = 48) -> void:
		for i in strips:
			var t0: float = float(i) / float(strips)
			var c: Color = top.lerp(bottom, t0)
			var y0: float = rect.position.y + rect.size.y * t0
			var y1: float = rect.position.y + rect.size.y * float(i + 1) / float(strips)
			draw_rect(Rect2(rect.position.x, y0, rect.size.x, y1 - y0 + 1.0), c)

	## Horizontal alpha fade painted as strips.
	func _hfade(rect: Rect2, alpha: float, strips: int = 16) -> void:
		for i in strips:
			var t0: float = float(i) / float(strips)
			var a: float = alpha * (1.0 - t0)
			var x0: float = rect.position.x + rect.size.x * t0
			var x1: float = rect.position.x + rect.size.x * float(i + 1) / float(strips)
			draw_rect(Rect2(x0, rect.position.y, x1 - x0 + 1.0, rect.size.y), Color(0, 0, 0, a))

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if w <= 0.0 or h <= 0.0:
			return
		var horizon: float = h * 0.56
		# Dusk sky.
		_vgrad(Rect2(0, 0, w, horizon), Color("1b2a52"), Color("c96a2e"))
		# Floodlight towers (near the edges, out of the UI's way).
		for fx in [0.06, 0.94]:
			var top := Vector2(w * fx, horizon * 0.18)
			var base := Vector2(w * fx, horizon * 0.98)
			draw_line(base, top, Color("0e1220"), 7.0)
			draw_circle(top, 66.0, Color(1.0, 0.9, 0.55, 0.10))
			draw_circle(top, 30.0, Color(1.0, 0.9, 0.55, 0.16))
			for lx in [-14.0, 0.0, 14.0]:
				draw_circle(top + Vector2(lx, -6.0), 7.0, Color(1.0, 0.95, 0.75, 0.95))
		# Clouds.
		for cl in _clouds:
			var p := Vector2(float(cl["x"]), float(cl["y"]))
			var s: float = float(cl["s"])
			var cc := Color(1, 1, 1, 0.13)
			draw_circle(p, 36.0 * s, cc)
			draw_circle(p + Vector2(32.0 * s, 7.0 * s), 27.0 * s, cc)
			draw_circle(p + Vector2(-32.0 * s, 9.0 * s), 25.0 * s, cc)
		# Grandstand silhouette + crowd.
		var stand := Rect2(0, horizon - 132.0, w, 132.0)
		draw_rect(stand, Color("1d2230"))
		draw_rect(Rect2(0, horizon - 132.0, w, 10.0), Color("2c3448"))
		for d in _crowd:
			var fp: Vector2 = d["p"]
			draw_circle(stand.position + Vector2(fp.x * stand.size.x, 14.0 + fp.y * (stand.size.y - 20.0)), 2.1, d["c"])
		# Outfield with mow stripes.
		var field_top: float = horizon
		var stripes: int = 6
		for i in stripes:
			var y0: float = field_top + (h - field_top) * float(i) / float(stripes)
			var y1: float = field_top + (h - field_top) * float(i + 1) / float(stripes)
			var g := Color("2f8f3e") if i % 2 == 0 else Color("2b8438")
			draw_rect(Rect2(0, y0, w, y1 - y0), g)
		# Boundary rope (dashed white).
		var rope_y: float = horizon + 44.0
		var x: float = 0.0
		while x < w:
			draw_line(Vector2(x, rope_y), Vector2(x + 26.0, rope_y), Color(1, 1, 1, 0.75), 3.0)
			x += 44.0
		# Distant pitch (small, clearly a vista element).
		var pw: float = 84.0
		var px: float = (w - pw) * 0.5
		var py: float = horizon + 96.0
		draw_rect(Rect2(px, py, pw, 110.0), Color("c9a86a"))
		draw_rect(Rect2(px, py, pw, 110.0), Color(0, 0, 0, 0.15), false, 2.0)
		draw_line(Vector2(px + 10.0, py + 24.0), Vector2(px + pw - 10.0, py + 24.0), Color(1, 1, 1, 0.7), 2.0)
		draw_line(Vector2(px + 10.0, py + 86.0), Vector2(px + pw - 10.0, py + 86.0), Color(1, 1, 1, 0.7), 2.0)
		# Scrims for UI readability: left column + top bar.
		_hfade(Rect2(0, 0, w * 0.62, h), 0.62)
		draw_rect(Rect2(0, 0, w, 84.0), Color(0, 0, 0, 0.38))


## Big sports button: drawn icon + label, red with a deep bottom edge.
static func menu_button(text: String, icon_kind: String, min_size: Vector2, font_size: int = 24) -> Button:
	var b := Button.new()
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", _sports_btn(ThemeHelpers.RED, ThemeHelpers.RED_DEEP))
	b.add_theme_stylebox_override("hover", _sports_btn(ThemeHelpers.RED_DARK, ThemeHelpers.RED_DEEP))
	b.add_theme_stylebox_override("pressed", _sports_btn(ThemeHelpers.RED_DEEP, ThemeHelpers.RED_DEEP))
	b.add_theme_stylebox_override("disabled", _sports_btn(ThemeHelpers.DISABLED, Color("6e6e6e")))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := DrawnIcon.new(icon_kind, Color.WHITE)
	ic.custom_minimum_size = Vector2(font_size + 14, font_size + 14)
	row.add_child(ic)
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", font_size)
	lab.add_theme_color_override("font_color", Color.WHITE)
	lab.add_theme_color_override("font_hover_color", Color.WHITE)
	lab.add_theme_color_override("font_pressed_color", Color.WHITE)
	lab.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lab)
	b.add_child(row)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	return b


static func _sports_btn(top: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = top
	sb.set_corner_radius_all(16)
	sb.border_color = edge
	sb.border_width_bottom = 5
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb


## Feature card: dark navy panel, gold top accent, icon + title + subtitle.
static func card_button(icon_kind: String, title: String, subtitle: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", _card_style(NAVY_SOFT))
	b.add_theme_stylebox_override("hover", _card_style(Color(0.14, 0.18, 0.26, 0.96)))
	b.add_theme_stylebox_override("pressed", _card_style(Color(0.07, 0.09, 0.14, 0.97)))
	b.add_theme_stylebox_override("disabled", _card_style(Color(0.3, 0.3, 0.3, 0.6)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Gold top accent strip (StyleBoxFlat has one border color, so the
	# accent is a drawn strip pinned to the card's top edge).
	var accent := ColorRect.new()
	accent.color = GOLD
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent.set_anchors_preset(Control.PRESET_TOP_WIDE)
	accent.custom_minimum_size = Vector2(0, 4)
	accent.offset_bottom = 4
	# Rounded top corners on the strip are approximated by insetting it.
	accent.offset_left = 14
	accent.offset_right = -14
	b.add_child(accent)
	var ic := DrawnIcon.new(icon_kind, GOLD)
	ic.custom_minimum_size = Vector2(44, 44)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ic)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", CREAM)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	var s := Label.new()
	s.text = subtitle
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 14)
	s.add_theme_color_override("font_color", CREAM_DIM)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(s)
	b.add_child(col)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	return b


static func _card_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(14)
	sb.border_color = Color(0, 0, 0, 0.35)
	sb.set_border_width_all(1)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 10.0
	return sb


## Dark info chip with a drawn icon (coins, trophies, ...).
static func chip(icon_kind: String, text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := DrawnIcon.new(icon_kind, GOLD)
	ic.custom_minimum_size = Vector2(22, 22)
	row.add_child(ic)
	var l := ThemeHelpers.hud_label(text, 18)
	row.add_child(l)
	p.add_child(row)
	return p


## Square icon button (e.g. settings gear).
static func icon_button(icon_kind: String, px: float = 56.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(px, px)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", _sports_btn(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.7)))
	b.add_theme_stylebox_override("hover", _sports_btn(Color(0.1, 0.1, 0.12, 0.75), Color(0, 0, 0, 0.7)))
	b.add_theme_stylebox_override("pressed", _sports_btn(Color(0, 0, 0, 0.8), Color(0, 0, 0, 0.85)))
	b.add_theme_stylebox_override("disabled", _sports_btn(ThemeHelpers.DISABLED, Color("6e6e6e")))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := DrawnIcon.new(icon_kind, Color.WHITE)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	return b


## Game logo lockup: drawn cricket ball + two-line wordmark.
static func logo_lockup() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ball := DrawnIcon.new("ball", ThemeHelpers.RED)
	ball.custom_minimum_size = Vector2(72, 72)
	row.add_child(ball)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for line in ["GULLY CRICKET", "LEGENDS"]:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 40)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
		l.add_theme_constant_override("shadow_offset_x", 3)
		l.add_theme_constant_override("shadow_offset_y", 3)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)
	row.add_child(col)
	return row


## Thousands separator for coin counts ("2000" -> "2,000").
static func fmt_coins(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out
