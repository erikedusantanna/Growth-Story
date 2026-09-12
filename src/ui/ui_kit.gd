class_name UIKit
extends RefCounted
## Helpers estáticos para montar a interface em código (mobile-first).

## Paleta clara e colorida (cozy): fundo creme, painéis brancos, números em azul-marinho.
const COLOR_BG := Color("#f3ecdf")
const COLOR_PANEL := Color("#fffdf8")
const COLOR_PANEL_LIGHT := Color("#efe6d6")
const COLOR_BORDER := Color("#dccfb8")
const COLOR_TEXT := Color("#2b2a33")
const COLOR_MUTED := Color("#7d7a86")
const COLOR_NUMBER := Color("#2b4fa8")
const COLOR_ACCENT := Color("#ff8f3d")
const COLOR_GREEN := Color("#2fa66b")
const COLOR_RED := Color("#e05d5d")
const COLOR_BLUE := Color("#3b6fd8")
const COLOR_PURPLE := Color("#8e6ce0")
const COLOR_GOLD := Color("#e8b034")

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


static var _emoji: Font = null
static var _default: FontVariation = null
static var _bold: FontVariation = null


## Fonte de emoji embutida (Noto Emoji, monocromática, licença OFL em assets/fonts).
## A fonte padrão do Godot não tem emoji e o fallback do sistema não funciona em toda
## plataforma (no Windows os botões ficavam vazios), então ela entra como fallback de
## todas as fontes da interface.
static func emoji_font() -> Font:
	if _emoji == null:
		_emoji = load("res://assets/fonts/NotoEmoji.ttf")
	return _emoji


static func _with_emoji(f: Font) -> Font:
	if f != null and emoji_font() != null and not f.fallbacks.has(emoji_font()):
		f.fallbacks = f.fallbacks + [emoji_font()]
	return f


## Fonte padrão da interface: a fonte do Godot com os emojis como fallback.
static func default_font() -> Font:
	if _default == null:
		_default = FontVariation.new()
		_default.base_font = ThemeDB.fallback_font
		_with_emoji(_default)
	return _default


## Fonte em negrito derivada da fonte padrão (títulos e números, como nas referências).
static func bold_font() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.9
		_with_emoji(_bold)
	return _bold


static var _pixel: Font = null


## Fonte pixel art (matriz de pontos 5x7, res://assets/fonts/pixel.fnt) usada em
## títulos e números do HUD — o corpo de texto segue na fonte do sistema para não
## cansar a leitura (GDD §40: "não precisa parecer retrô demais").
static func pixel_font() -> Font:
	if _pixel == null:
		var f: Font = load("res://assets/fonts/pixel.fnt")
		_pixel = _with_emoji(f) if f != null else bold_font()
	return _pixel


static func _rounded(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 10, border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = default_font()
	theme.default_font_size = 18

	theme.set_stylebox("panel", "PanelContainer", _rounded(COLOR_PANEL, COLOR_BORDER, 10, 2))

	var btn := _rounded(Color.WHITE, COLOR_BORDER, 8, 2)
	btn.content_margin_top = 8
	btn.content_margin_bottom = 8
	theme.set_stylebox("normal", "Button", btn)
	var btn_hover := btn.duplicate()
	btn_hover.bg_color = COLOR_PANEL_LIGHT
	theme.set_stylebox("hover", "Button", btn_hover)
	var btn_pressed := btn.duplicate()
	btn_pressed.bg_color = COLOR_ACCENT.lightened(0.55)
	btn_pressed.border_color = COLOR_ACCENT
	theme.set_stylebox("pressed", "Button", btn_pressed)
	var btn_disabled := btn.duplicate()
	btn_disabled.bg_color = COLOR_PANEL_LIGHT
	btn_disabled.border_color = COLOR_PANEL_LIGHT
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_hover_color", "Button", COLOR_TEXT)
	theme.set_color("font_pressed_color", "Button", COLOR_TEXT)
	theme.set_color("font_disabled_color", "Button", COLOR_MUTED)
	theme.set_color("font_color", "Label", COLOR_TEXT)

	var bar_bg := _rounded(COLOR_PANEL_LIGHT, Color.TRANSPARENT, 4)
	bar_bg.content_margin_left = 0
	bar_bg.content_margin_right = 0
	bar_bg.content_margin_top = 0
	bar_bg.content_margin_bottom = 0
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	var bar_fill := bar_bg.duplicate()
	bar_fill.bg_color = COLOR_ACCENT
	theme.set_stylebox("fill", "ProgressBar", bar_fill)

	var line := _rounded(Color.WHITE, COLOR_BORDER, 8, 2)
	line.content_margin_top = 8
	line.content_margin_bottom = 8
	theme.set_stylebox("normal", "LineEdit", line)
	var line_focus := line.duplicate()
	line_focus.border_color = COLOR_BLUE
	theme.set_stylebox("focus", "LineEdit", line_focus)
	theme.set_color("font_color", "LineEdit", COLOR_TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", COLOR_MUTED)

	var slider_bg := _rounded(COLOR_PANEL_LIGHT, Color.TRANSPARENT, 4)
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", _rounded(COLOR_ACCENT, Color.TRANSPARENT, 4))
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
	var l := label(text, 24, COLOR_TEXT)
	l.add_theme_font_override("font", pixel_font())
	l.add_theme_constant_override("line_spacing", 2)
	return l


## Número grande em negrito azul-marinho, como nas referências. Usa a fonte pixel art.
static func number(text: String, size: int = 20, color: Color = COLOR_NUMBER) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", pixel_font())
	return l


static func icon_texture(name: String) -> Texture2D:
	return load("res://assets/art/icons/%s.png" % name)


static func icon(name: String, scale: int = 2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon_texture(name)
	t.custom_minimum_size = Vector2(10 * scale, 10 * scale)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


## Retrato do personagem (cabeça do sprite em camadas), ampliado.
static func portrait(e: Employee, scale: int = 4) -> Control:
	var box := PanelContainer.new()
	var style := _rounded(COLOR_PANEL_LIGHT, COLOR_BORDER, 8, 2)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", style)
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(16 * scale, 16 * scale)
	box.add_child(holder)
	var region := Rect2(3, 0, 26, 26)   # cabeça do quadro parado de frente
	var style_idx: int = clampi(e.hair_style, 0, Employee.HAIR_STYLES - 1)
	var tag := "%d%s" % [style_idx, "g" if e.glasses else ""]
	var layers := [
		["res://assets/art/characters/skin.png", Color(e.skin)],
		["res://assets/art/characters/shirt.png", Color(e.color)],
		["res://assets/art/characters/hair_%s.png" % tag, Color(e.hair_color)],
		["res://assets/art/characters/outline_%s.png" % tag, Color.WHITE],
	]
	for layer in layers:
		var atlas := AtlasTexture.new()
		atlas.atlas = load(layer[0])
		atlas.region = region
		var t := TextureRect.new()
		t.texture = atlas
		t.modulate = layer[1]
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(t)
	return box


static func muted(text: String, size: int = 15) -> Label:
	return label(text, size, COLOR_MUTED, true)


static func button(text: String, callback: Callable, accent: bool = false, min_height: int = 48) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = min_height
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.pressed.connect(func(): Audio.play_sfx("click"))
	if callback.is_valid():
		b.pressed.connect(callback)
	if accent:
		var style := _rounded(COLOR_ACCENT, COLOR_ACCENT.darkened(0.15), 8, 2)
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		b.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = COLOR_ACCENT.lightened(0.1)
		b.add_theme_stylebox_override("hover", hover)
		var pressed := style.duplicate()
		pressed.bg_color = COLOR_ACCENT.darkened(0.15)
		b.add_theme_stylebox_override("pressed", pressed)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_font_override("font", bold_font())
	return b


static func toggle(text: String, pressed: bool, callback: Callable) -> Button:
	var b := button(text, Callable())
	b.toggle_mode = true
	b.button_pressed = pressed
	b.custom_minimum_size.y = 44
	b.size_flags_horizontal = 0
	b.clip_text = false   # toggles têm largura pelo texto
	b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	if callback.is_valid():
		b.toggled.connect(callback)
	var on := _rounded(COLOR_BLUE.lightened(0.7), COLOR_BLUE, 8, 2)
	on.content_margin_top = 6
	on.content_margin_bottom = 6
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_color_override("font_pressed_color", COLOR_BLUE.darkened(0.2))
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
	b.add_theme_stylebox_override("fill", _rounded(color, Color.TRANSPARENT, 4))
	return b


## Linha "Nome  [████░░] 72" usada para atributos e indicadores.
static func stat_row(name: String, value: float, color: Color = COLOR_ACCENT, label_width: int = 110) -> HBoxContainer:
	var h := hbox(8)
	var n := label(name, 15, COLOR_MUTED)
	n.custom_minimum_size.x = label_width
	h.add_child(n)
	h.add_child(bar(value, 100.0, color))
	var v := number(str(int(roundf(value))), 15, COLOR_TEXT)
	v.custom_minimum_size.x = 36
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	return h


static func attr_grid(e: Employee) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 4)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in Employee.ATTRS:
		g.add_child(attr_cell(key, e.attr(key)))
	return g


## Ícone + nome curto + número, com barrinha fina embaixo.
static func attr_cell(key: String, value: float) -> VBoxContainer:
	var v := vbox(2)
	var row := hbox(6)
	row.add_child(icon("attr_" + key))
	row.add_child(label(ATTR_SHORT[key], 13, COLOR_MUTED))
	var n := number(str(int(roundf(value))), 17, attr_color(key).darkened(0.2))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	v.add_child(row)
	v.add_child(bar(value, 100.0, attr_color(key), 5))
	return v


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
			return Color("#8a8a96")
		_:
			return Color("#3fbfbf")


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


static func signed(value: float) -> String:
	var text := "%+.1f" % value
	return text.replace(".", ",")


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
