class_name UIKit
extends RefCounted
## Helpers estáticos para montar a interface em código (mobile-first).

const COLOR_BG := Color("#1b1f2a")
const COLOR_PANEL := Color("#262b38")
const COLOR_PANEL_LIGHT := Color("#313747")
const COLOR_TEXT := Color("#eef0f5")
const COLOR_MUTED := Color("#9aa3b5")
const COLOR_ACCENT := Color("#f3a712")
const COLOR_GREEN := Color("#48c88c")
const COLOR_RED := Color("#e4572e")
const COLOR_BLUE := Color("#669bbc")
const COLOR_PURPLE := Color("#a97bd6")

const ATTR_SHORT := {
	"creativity": "Cri", "strategy": "Est", "performance": "Per",
	"communication": "Com", "management": "Ges", "technology": "Tec",
}


static var _theme: Theme = null


## Tema único compartilhado (Controls dentro de CanvasLayer não herdam o tema do pai).
static func theme() -> Theme:
	if _theme == null:
		_theme = build_theme()
	return _theme


static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18

	var panel := StyleBoxFlat.new()
	panel.bg_color = COLOR_PANEL
	panel.corner_radius_top_left = 8
	panel.corner_radius_top_right = 8
	panel.corner_radius_bottom_left = 8
	panel.corner_radius_bottom_right = 8
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 10
	panel.content_margin_bottom = 10
	theme.set_stylebox("panel", "PanelContainer", panel)

	var btn := StyleBoxFlat.new()
	btn.bg_color = COLOR_PANEL_LIGHT
	btn.corner_radius_top_left = 6
	btn.corner_radius_top_right = 6
	btn.corner_radius_bottom_left = 6
	btn.corner_radius_bottom_right = 6
	btn.content_margin_left = 14
	btn.content_margin_right = 14
	btn.content_margin_top = 8
	btn.content_margin_bottom = 8
	theme.set_stylebox("normal", "Button", btn)
	var btn_hover := btn.duplicate()
	btn_hover.bg_color = COLOR_PANEL_LIGHT.lightened(0.1)
	theme.set_stylebox("hover", "Button", btn_hover)
	var btn_pressed := btn.duplicate()
	btn_pressed.bg_color = COLOR_ACCENT.darkened(0.2)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	var btn_disabled := btn.duplicate()
	btn_disabled.bg_color = COLOR_PANEL_LIGHT.darkened(0.25)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_disabled_color", "Button", COLOR_MUTED)
	theme.set_color("font_color", "Label", COLOR_TEXT)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = COLOR_BG
	bar_bg.corner_radius_top_left = 3
	bar_bg.corner_radius_top_right = 3
	bar_bg.corner_radius_bottom_left = 3
	bar_bg.corner_radius_bottom_right = 3
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	var bar_fill := bar_bg.duplicate()
	bar_fill.bg_color = COLOR_ACCENT
	theme.set_stylebox("fill", "ProgressBar", bar_fill)

	var line := StyleBoxFlat.new()
	line.bg_color = COLOR_BG
	line.content_margin_left = 10
	line.content_margin_right = 10
	line.content_margin_top = 8
	line.content_margin_bottom = 8
	theme.set_stylebox("normal", "LineEdit", line)
	theme.set_stylebox("focus", "LineEdit", line)
	return theme


static func label(text: String, size: int = 18, color: Color = COLOR_TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func title(text: String) -> Label:
	return label(text, 24, COLOR_ACCENT)


static func muted(text: String, size: int = 15) -> Label:
	return label(text, size, COLOR_MUTED, true)


static func button(text: String, callback: Callable, accent: bool = false, min_height: int = 48) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = min_height
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if callback.is_valid():
		b.pressed.connect(callback)
	if accent:
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_ACCENT
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		b.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = COLOR_ACCENT.lightened(0.1)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_color_override("font_color", COLOR_BG)
		b.add_theme_color_override("font_hover_color", COLOR_BG)
		b.add_theme_color_override("font_pressed_color", COLOR_BG)
	return b


static func toggle(text: String, pressed: bool, callback: Callable) -> Button:
	var b := button(text, Callable())
	b.toggle_mode = true
	b.button_pressed = pressed
	b.custom_minimum_size.y = 44
	b.size_flags_horizontal = 0
	if callback.is_valid():
		b.toggled.connect(callback)
	var on := StyleBoxFlat.new()
	on.bg_color = COLOR_ACCENT.darkened(0.15)
	on.corner_radius_top_left = 6
	on.corner_radius_top_right = 6
	on.corner_radius_bottom_left = 6
	on.corner_radius_bottom_right = 6
	on.content_margin_left = 12
	on.content_margin_right = 12
	on.content_margin_top = 6
	on.content_margin_bottom = 6
	b.add_theme_stylebox_override("pressed", on)
	return b


static func hbox(spacing: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", spacing)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h


static func vbox(spacing: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", spacing)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


static func card(children: Array = []) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := vbox(6)
	p.add_child(v)
	for c in children:
		v.add_child(c)
	return p


static func card_content(p: PanelContainer) -> VBoxContainer:
	return p.get_child(0) as VBoxContainer


static func bar(value: float, max_value: float = 100.0, color: Color = COLOR_ACCENT, height: int = 14) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0
	b.max_value = max_value
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	b.add_theme_stylebox_override("fill", fill)
	return b


## Linha "Nome  [████░░] 72" usada para atributos e indicadores.
static func stat_row(name: String, value: float, color: Color = COLOR_ACCENT, label_width: int = 110) -> HBoxContainer:
	var h := hbox(8)
	var n := label(name, 15, COLOR_MUTED)
	n.custom_minimum_size.x = label_width
	h.add_child(n)
	h.add_child(bar(value, 100.0, color))
	var v := label(str(int(roundf(value))), 15)
	v.custom_minimum_size.x = 36
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	return h


static func attr_grid(e: Employee) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 4)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in Employee.ATTRS:
		var row := stat_row(ATTR_SHORT[key], e.attr(key), attr_color(key), 40)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(row)
	return g


static func attr_color(key: String) -> Color:
	match key:
		"creativity":
			return COLOR_PURPLE
		"strategy":
			return COLOR_BLUE
		"performance":
			return COLOR_GREEN
		"communication":
			return COLOR_ACCENT
		"management":
			return Color("#d98c5f")
		_:
			return Color("#5fd9d0")


static func indicator_color(key: String) -> Color:
	match key:
		"strategy":
			return COLOR_BLUE
		"creativity":
			return COLOR_PURPLE
		"execution":
			return COLOR_ACCENT
		_:
			return COLOR_GREEN


static func spacer(height: int = 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	return c


static func separator() -> HSeparator:
	return HSeparator.new()


static func money(value: float) -> String:
	return FinanceSystem.format_money(value)


static func _has_glyph(code: int) -> bool:
	var font := ThemeDB.fallback_font
	return font != null and font.has_char(code)


## Texto de estrelas (fallback quando não há espaço para os sprites).
static func stars(n: int) -> String:
	var full := "★" if _has_glyph(0x2605) else "*"
	var empty := "☆" if _has_glyph(0x2606) else "·"
	return full.repeat(clampi(n, 0, 5)) + empty.repeat(5 - clampi(n, 0, 5))


static func hearts(n: int) -> String:
	var full := "♥" if _has_glyph(0x2665) else "<3"
	var empty := "♡" if _has_glyph(0x2661) else "--"
	return full.repeat(clampi(n, 0, 5)) + empty.repeat(5 - clampi(n, 0, 5))


## Linha de 5 ícones em pixel art (estrelas ou corações), com n preenchidos.
static func icon_row(n: int, kind: String = "star", scale: int = 3) -> HBoxContainer:
	var h := hbox(4)
	h.size_flags_horizontal = 0
	var full: Texture2D = load("res://assets/sprites/%s.png" % kind)
	var empty: Texture2D = load("res://assets/sprites/%s_empty.png" % kind)
	for i in 5:
		var t := TextureRect.new()
		t.texture = full if i < n else empty
		t.custom_minimum_size = Vector2(9 * scale, 9 * scale)
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.add_child(t)
	return h


static func star_row(n: int, scale: int = 3) -> HBoxContainer:
	return icon_row(n, "star", scale)


static func heart_row(n: int, scale: int = 2) -> HBoxContainer:
	return icon_row(n, "heart", scale)


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func match_color(quality: String) -> Color:
	match quality:
		"perfect":
			return COLOR_GREEN
		"good":
			return COLOR_BLUE
		"poor":
			return COLOR_RED
		_:
			return COLOR_MUTED
