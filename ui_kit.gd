extends RefCounted

# The shared look of the menus and the in-game panels: dark glass cards, chunky buttons with
# a darker lower edge, neon accents. Everything is drawn from StyleBoxFlat and code, so there
# are no extra image files. Use it through preload:
#   const UiKit := preload("res://ui_kit.gd")
#   UiKit.style_button(button, "primary")

const CYAN := Color("00e5ff")
const PINK := Color("ff2e93")
const GOLD := Color("ffd23f")
const GREEN := Color("39d65c")
const ORANGE := Color("ff8a1f")
const BLUE := Color("2b7bff")
const PURPLE := Color("8a3ffc")
const RED := Color("ff5a4d")
const TEXT_DIM := Color(0.72, 0.84, 0.9)
const CARD_BG := Color(0.03, 0.07, 0.13, 0.9)
const CARD_BORDER := Color(0.0, 0.9, 1.0, 0.55)

# Button colours by kind. Anything else (including "dark") is the outlined glass button.
const KINDS := {"primary": BLUE, "warn": ORANGE, "blue": BLUE, "purple": PURPLE, "yellow": GOLD}


static func box(bg: Color, border: Color, radius := 24, border_width := 3, bottom := -1,
		pad_x := 12.0, pad_y := 6.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	if bottom >= 0:
		style.border_width_bottom = bottom
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y
	style.content_margin_bottom = pad_y
	return style


static func style_button(button: Button, kind := "dark") -> void:
	var normal: StyleBoxFlat
	var hover: StyleBoxFlat
	var pressed: StyleBoxFlat
	if KINDS.has(kind):
		var base: Color = KINDS[kind]
		var edge := base.darkened(0.5)
		normal = box(base, edge, 22, 4, 10)
		hover = box(base.lightened(0.15), edge, 22, 4, 10)
		pressed = box(base.darkened(0.15), edge, 22, 4, 4)
		button.add_theme_color_override("font_outline_color", Color(0.0, 0.05, 0.1, 0.8))
		button.add_theme_constant_override("outline_size", 6)
	elif kind == "danger":
		normal = box(Color(RED, 0.1), Color(RED, 0.8), 22, 3)
		hover = box(Color(RED, 0.2), RED, 22, 3)
		pressed = box(Color(RED, 0.4), Color.WHITE, 22, 3)
	else:
		normal = box(Color(0.04, 0.12, 0.18, 0.92), Color(CYAN, 0.55), 22, 3)
		hover = box(Color(0.06, 0.2, 0.28, 0.95), Color(CYAN, 0.9), 22, 3)
		pressed = box(Color(CYAN, 0.35), Color.WHITE, 22, 3)
	var disabled := box(Color(0.06, 0.09, 0.12, 0.85), Color(0.3, 0.4, 0.45, 0.45), 22, 3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var text_color := Color(0.92, 1.0, 1.0)
	var text_hover := Color.WHITE
	if kind == "yellow":
		text_color = Color(0.16, 0.1, 0.0)
		text_hover = text_color
		button.add_theme_constant_override("outline_size", 0)
	elif kind == "danger":
		text_color = Color("ff8a80")
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_hover)
	button.add_theme_color_override("font_pressed_color", text_hover)
	button.add_theme_color_override("font_hover_pressed_color", text_hover)
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.6, 0.64))


# A glass button that turns green while it is on (toggle buttons and option groups).
static func style_toggle(button: Button) -> void:
	style_button(button, "dark")
	var on := box(Color(GREEN, 0.35), GREEN, 22, 3)
	button.add_theme_stylebox_override("pressed", on)
	button.add_theme_stylebox_override("hover_pressed", on)


static func style_field(field: LineEdit) -> void:
	field.add_theme_stylebox_override("normal", box(Color(0.02, 0.08, 0.12, 0.92), Color(CYAN, 0.45), 18, 3, -1, 20.0, 10.0))
	field.add_theme_stylebox_override("focus", box(Color(0.03, 0.12, 0.18, 0.95), CYAN, 18, 3, -1, 20.0, 10.0))
	field.add_theme_color_override("font_placeholder_color", Color(0.5, 0.62, 0.68))


static func card(bg := CARD_BG, border := CARD_BORDER, radius := 28, pad_x := 36.0, pad_y := 32.0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(bg, border, radius, 3, -1, pad_x, pad_y))
	return panel


# Headline text with a dark outline and a soft glow.
static func title(text: String, font_size: int, color := CYAN) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.03, 0.08, 0.95))
	label.add_theme_constant_override("outline_size", maxi(6, int(font_size / 8.0)))
	label.add_theme_color_override("font_shadow_color", Color(color, 0.35))
	label.add_theme_constant_override("shadow_offset_y", maxi(3, int(font_size / 20.0)))
	return label


# A small rounded badge: an optional icon, then text.
static func pill(text: String, color: Color, icon: Control = null) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(Color(0.0, 0.0, 0.0, 0.5), Color(color, 0.8), 32, 3, -1, 20.0, 8.0))
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	if icon != null:
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	row.add_child(label)
	return panel


static func progress(value: float, max_value: float, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 20.0)
	bar.add_theme_stylebox_override("background", box(Color(0.0, 0.0, 0.0, 0.55), Color(1.0, 1.0, 1.0, 0.15), 10, 2))
	bar.add_theme_stylebox_override("fill", box(color, color.darkened(0.3), 10, 0))
	return bar


# Lets taps fall through decorations to the button they sit on.
static func ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ignore_mouse(child)


# A padlock drawn from shapes (no font glyph needed).
class LockIcon extends Control:
	var color := Color(0.75, 0.84, 0.9)

	func _init(size_px := 40.0) -> void:
		custom_minimum_size = Vector2(size_px, size_px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		draw_arc(Vector2(w * 0.5, w * 0.45), w * 0.2, PI, TAU, 16, color, w * 0.09)
		draw_rect(Rect2(w * 0.2, w * 0.45, w * 0.6, w * 0.45), color)


# Row of dots for a paged list: the current page is the big bright one.
class PageDots extends Control:
	var count := 1
	var current := 0
	var color := Color.WHITE

	func _init(page_count: int, page: int, accent: Color) -> void:
		count = page_count
		current = page
		color = accent
		custom_minimum_size = Vector2(count * 34.0, 40.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in count:
			var centre := Vector2(size.x / 2.0 + (i - (count - 1) / 2.0) * 34.0, size.y / 2.0)
			if i == current:
				draw_circle(centre, 9.0, color)
			else:
				draw_circle(centre, 6.0, Color(1.0, 1.0, 1.0, 0.3))


# A picture in a rounded frame with a dark fade from the left, so text on top stays readable.
# Filled by UV-mapping a rounded polygon, so it needs no clipping support from the renderer.
class RoundedImage extends Control:
	var texture: Texture2D
	var tint := Color.WHITE
	var border := Color.WHITE
	var radius := 28.0
	var shade_left := 0.88
	var shade_right := 0.15

	func _init(image: Texture2D, tint_color: Color, border_color: Color) -> void:
		texture = image
		tint = tint_color
		border = border_color
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := minf(radius, minf(size.x, size.y) / 2.0)
		var points := PackedVector2Array()
		var corners := [
			[Vector2(size.x - r, r), -PI / 2.0],
			[Vector2(size.x - r, size.y - r), 0.0],
			[Vector2(r, size.y - r), PI / 2.0],
			[Vector2(r, r), PI],
		]
		for corner in corners:
			var centre: Vector2 = corner[0]
			for i in 7:
				var angle: float = corner[1] + (PI / 2.0) * float(i) / 6.0
				points.append(centre + Vector2(cos(angle), sin(angle)) * r)

		if texture != null:
			var tex_size := texture.get_size()
			# Scale the picture until it covers the frame, centred.
			var fit := maxf(size.x / tex_size.x, size.y / tex_size.y)
			var uvs := PackedVector2Array()
			for p in points:
				uvs.append(Vector2(
					0.5 + (p.x - size.x / 2.0) / (tex_size.x * fit),
					0.5 + (p.y - size.y / 2.0) / (tex_size.y * fit)))
			draw_colored_polygon(points, tint, uvs, texture)
		else:
			draw_colored_polygon(points, tint)

		var shade := PackedColorArray()
		for p in points:
			shade.append(Color(0.0, 0.02, 0.05, lerpf(shade_left, shade_right, p.x / size.x)))
		draw_polygon(points, shade)

		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, border, 4.0, true)


# A segmented-control option: dark glass that fills blue while selected.
static func style_segment(button: Button) -> void:
	style_button(button, "dark")
	var on := box(BLUE, BLUE.lightened(0.3), 14, 2)
	button.add_theme_stylebox_override("normal", box(Color(0.04, 0.09, 0.15, 0.9), Color(CYAN, 0.25), 14, 2))
	button.add_theme_stylebox_override("pressed", on)
	button.add_theme_stylebox_override("hover_pressed", on)


# Puts a drawn icon at the left edge of a button, vertically centred.
static func add_button_icon(button: Button, kind: String, size_px := 44.0, color := Color.WHITE) -> void:
	var icon := Icon.new(kind, size_px, color)
	icon.anchor_left = 0.0
	icon.anchor_right = 0.0
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = 30.0
	icon.offset_right = 30.0 + size_px
	icon.offset_top = -size_px / 2.0
	icon.offset_bottom = size_px / 2.0
	button.add_child(icon)


# A round filled dot, used as the slider handle.
static func dot_texture(radius: int, color: Color) -> ImageTexture:
	var side := radius * 2
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	for y in side:
		for x in side:
			var d := Vector2(x + 0.5 - radius, y + 0.5 - radius).length()
			if d <= radius - 1.0:
				image.set_pixel(x, y, color)
			elif d <= radius:
				image.set_pixel(x, y, Color(color, 0.5))
	return ImageTexture.create_from_image(image)


static func style_slider(slider: HSlider) -> void:
	slider.add_theme_stylebox_override("slider", box(Color(1, 1, 1, 0.14), Color(0, 0, 0, 0), 8, 0))
	slider.add_theme_stylebox_override("grabber_area", box(BLUE, Color(0, 0, 0, 0), 8, 0))
	slider.add_theme_stylebox_override("grabber_area_highlight", box(BLUE.lightened(0.15), Color(0, 0, 0, 0), 8, 0))
	var handle := dot_texture(22, Color("5aa2ff"))
	slider.add_theme_icon_override("grabber", handle)
	slider.add_theme_icon_override("grabber_highlight", handle)


# Simple line icons drawn from shapes, so no image files or font glyphs are needed.
# kinds: back, play, restart, home, person, gear, trophy, shield, lock, unlock, eye, check,
# crown, google
class Icon extends Control:
	var kind := ""
	var color := Color.WHITE

	func _init(icon_kind: String, size_px := 40.0, icon_color := Color.WHITE) -> void:
		kind = icon_kind
		color = icon_color
		custom_minimum_size = Vector2(size_px, size_px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _p(x: float, y: float) -> Vector2:
		var s := minf(size.x, size.y)
		return (size - Vector2(s, s)) / 2.0 + Vector2(x, y) * s

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var w := s * 0.1
		match kind:
			"back":
				draw_polyline(PackedVector2Array([_p(0.62, 0.2), _p(0.3, 0.5), _p(0.62, 0.8)]), color, w, true)
			"play":
				draw_colored_polygon(PackedVector2Array([_p(0.28, 0.15), _p(0.85, 0.5), _p(0.28, 0.85)]), color)
			"restart":
				draw_arc(_p(0.5, 0.5), s * 0.3, -PI * 0.35, PI * 1.5, 24, color, w, true)
				draw_colored_polygon(PackedVector2Array([_p(0.6, 0.02), _p(0.88, 0.3), _p(0.56, 0.34)]), color)
			"home":
				draw_colored_polygon(PackedVector2Array([_p(0.08, 0.5), _p(0.5, 0.12), _p(0.92, 0.5)]), color)
				draw_rect(Rect2(_p(0.2, 0.48), Vector2(0.6, 0.4) * s), color)
			"person":
				draw_circle(_p(0.5, 0.32), s * 0.17, color)
				var body := PackedVector2Array()
				for i in 13:
					var a := PI + PI * i / 12.0
					body.append(_p(0.5 + cos(a) * 0.34, 0.92 + sin(a) * 0.4))
				draw_colored_polygon(body, color)
			"gear":
				draw_arc(_p(0.5, 0.5), s * 0.22, 0.0, TAU, 24, color, w * 1.4, true)
				for i in 8:
					var a := TAU * i / 8.0
					draw_line(_p(0.5 + cos(a) * 0.3, 0.5 + sin(a) * 0.3), _p(0.5 + cos(a) * 0.42, 0.5 + sin(a) * 0.42), color, w * 1.3)
			"trophy":
				draw_colored_polygon(PackedVector2Array([_p(0.28, 0.12), _p(0.72, 0.12), _p(0.66, 0.52), _p(0.34, 0.52)]), color)
				draw_rect(Rect2(_p(0.44, 0.5), Vector2(0.12, 0.22) * s), color)
				draw_rect(Rect2(_p(0.3, 0.72), Vector2(0.4, 0.1) * s), color)
				draw_arc(_p(0.24, 0.3), s * 0.1, PI * 0.5, PI * 1.5, 8, color, w * 0.7)
				draw_arc(_p(0.76, 0.3), s * 0.1, -PI * 0.5, PI * 0.5, 8, color, w * 0.7)
			"shield":
				draw_colored_polygon(PackedVector2Array([_p(0.5, 0.08), _p(0.86, 0.22), _p(0.8, 0.56), _p(0.5, 0.92), _p(0.2, 0.56), _p(0.14, 0.22)]), color)
			"lock", "unlock":
				var shackle_x := 0.5 if kind == "lock" else 0.7
				draw_arc(_p(shackle_x, 0.42), s * 0.18, PI, TAU, 14, color, w, true)
				draw_rect(Rect2(_p(0.2, 0.44), Vector2(0.6, 0.46) * s), color)
			"eye":
				var lens := PackedVector2Array()
				for i in 11:
					var t := i / 10.0
					lens.append(_p(0.08 + 0.84 * t, 0.5 - 0.24 * sin(PI * t)))
				for i in 11:
					var t := 1.0 - i / 10.0
					lens.append(_p(0.08 + 0.84 * t, 0.5 + 0.24 * sin(PI * t)))
				lens.append(lens[0])
				draw_polyline(lens, color, w * 0.7, true)
				draw_circle(_p(0.5, 0.5), s * 0.12, color)
			"check":
				draw_polyline(PackedVector2Array([_p(0.2, 0.52), _p(0.42, 0.74), _p(0.8, 0.28)]), color, w * 1.3, true)
			"crown":
				draw_colored_polygon(PackedVector2Array([_p(0.1, 0.78), _p(0.1, 0.28), _p(0.32, 0.52), _p(0.5, 0.18), _p(0.68, 0.52), _p(0.9, 0.28), _p(0.9, 0.78)]), color)
			"coin":
				draw_circle(_p(0.5, 0.5), s * 0.46, color.darkened(0.45))
				draw_circle(_p(0.5, 0.5), s * 0.38, color)
				draw_arc(_p(0.5, 0.5), s * 0.24, 0.0, TAU, 20, color.darkened(0.45), w * 0.7, true)
			"google":
				draw_circle(_p(0.5, 0.5), s * 0.5, Color.WHITE)
				draw_string(ThemeDB.fallback_font, _p(0.24, 0.76), "G", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.72), Color("4285f4"))


# A round avatar: the player's initial on a colour picked from their name.
class Avatar extends Control:
	var letter := "?"
	var tint := Color.WHITE

	func _init(player_name: String, size_px := 56.0) -> void:
		var shown := player_name.strip_edges()
		letter = shown.substr(0, 1).to_upper() if not shown.is_empty() else "?"
		tint = Color.from_hsv(float(absi(shown.hash()) % 360) / 360.0, 0.55, 0.85)
		custom_minimum_size = Vector2(size_px, size_px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var centre := size / 2.0
		draw_circle(centre, s / 2.0, tint.darkened(0.45))
		draw_arc(centre, s / 2.0 - 1.5, 0.0, TAU, 32, tint.lightened(0.2), 3.0, true)
		var font := ThemeDB.fallback_font
		var font_size := int(s * 0.5)
		var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, Vector2(centre.x - text_size.x / 2.0, centre.y + text_size.y * 0.3), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


# An on/off switch: a pill track with a round knob, green while on.
class Switch extends Button:
	func _init(initial := false) -> void:
		toggle_mode = true
		button_pressed = initial
		custom_minimum_size = Vector2(110.0, 58.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		toggled.connect(func(_on: bool): queue_redraw())

	func _draw() -> void:
		var track := Color("39d65c") if button_pressed else Color(0.3, 0.38, 0.45)
		var style := StyleBoxFlat.new()
		style.bg_color = track
		style.set_corner_radius_all(int(size.y / 2.0))
		draw_style_box(style, Rect2(Vector2.ZERO, size))
		var knob_x := size.x - size.y / 2.0 if button_pressed else size.y / 2.0
		draw_circle(Vector2(knob_x, size.y / 2.0), size.y / 2.0 - 6.0, Color.WHITE)
