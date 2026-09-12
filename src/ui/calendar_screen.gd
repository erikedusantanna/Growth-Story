class_name CalendarScreen
extends Control
## Calendário anual em tela cheia (botão 📅 do HUD, ao lado do mapa): os 12 próximos meses com as
## datas comemorativas e a premiação, a agenda do que vem pela frente (fechamento do mês, prazos,
## missões, leads, aniversários de contrato), o foco do mês e a banca com as últimas notícias.

const MONTH_COLS := 4

var scroll: ScrollContainer
var body: VBoxContainer
var header_title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var bg := ColorRect.new()
	bg.color = Color("#161d2c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 64
	scroll.offset_bottom = -8
	scroll.offset_left = 8
	scroll.offset_right = -8
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	body = UIKit.vbox(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	var head := PanelContainer.new()
	head.theme = UIKit.theme()
	head.set_anchors_preset(Control.PRESET_TOP_WIDE)
	head.offset_left = 8
	head.offset_right = -8
	head.offset_top = 8
	head.offset_bottom = 60
	add_child(head)
	var row := UIKit.hbox(8)
	head.add_child(row)
	header_title = UIKit.label("📅 Calendário", 18, UIKit.COLOR_TEXT)
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(header_title)
	var close_btn := UIKit.button("✖️ Fechar", close, false, 40)
	close_btn.size_flags_horizontal = 0
	close_btn.custom_minimum_size.x = 110
	row.add_child(close_btn)
	EventBus.state_changed.connect(func(): if visible: _build())


func open() -> void:
	visible = true
	Game.ui_blocking = true
	_build()


func close() -> void:
	visible = false
	Game.ui_blocking = false


func _popups() -> Popups:
	return get_tree().get_first_node_in_group("popups") as Popups


func _build() -> void:
	UIKit.clear(body)
	if not Game.has_game():
		return
	var st: GameState = Game.state
	header_title.text = "📅 %s · %s" % [st.agency_name, st.date_text()]
	_build_focus()
	_build_months()
	_build_agenda()
	_build_news()


# --- Foco do mês -----------------------------------------------------------------------------

func _build_focus() -> void:
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	var current: Dictionary = Game.calendar.focus()
	if current.is_empty():
		v.add_child(UIKit.label("🎯 Foco do mês", 18, UIKit.COLOR_ACCENT))
		v.add_child(UIKit.muted("Escolha uma prioridade para este mês. Vale até a virada do mês e só pode ser escolhida uma vez.", 13))
		for f in CalendarSystem.FOCUS:
			var row := UIKit.hbox(8)
			var info := UIKit.vbox(0)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_child(UIKit.label("%s %s" % [String(f["icon"]), String(f["name"])], 15, UIKit.COLOR_TEXT))
			info.add_child(UIKit.muted(String(f["desc"]), 12))
			row.add_child(info)
			var b := UIKit.button("Escolher", func():
				var r: Dictionary = Game.calendar.set_focus(String(f["id"]))
				if not r.ok:
					_popups().show_info("Foco do mês", r.reason), true, 38)
			b.size_flags_horizontal = 0
			b.custom_minimum_size.x = 110
			row.add_child(b)
			v.add_child(row)
	else:
		v.add_child(UIKit.label("%s %s" % [String(current.get("icon", "🎯")), String(current.get("name", ""))], 18, UIKit.COLOR_ACCENT))
		v.add_child(UIKit.label(String(current.get("desc", "")), 14, UIKit.COLOR_TEXT, true))
		var left: int = GameState.DAYS_PER_MONTH - Game.state.day_of_month()
		v.add_child(UIKit.muted("Vale por mais %d dia(s), até a virada do mês." % maxi(left, 0), 13))
	body.add_child(card)


# --- Grade de 12 meses ------------------------------------------------------------------------

func _build_months() -> void:
	body.add_child(UIKit.title("🗓️ Os próximos 12 meses"))
	var grid := GridContainer.new()
	grid.columns = MONTH_COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st: GameState = Game.state
	for m in Game.calendar.month_markers():
		var cell := PanelContainer.new()
		cell.theme = UIKit.theme()
		var style := StyleBoxFlat.new()
		var is_now: bool = int(m["month_index"]) == st.month_index()
		style.bg_color = Color("#243049") if is_now else Color("#1c2434")
		style.border_color = UIKit.COLOR_ACCENT if is_now else Color("#33405a")
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		cell.add_theme_stylebox_override("panel", style)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := UIKit.vbox(2)
		cell.add_child(cv)
		var top := UIKit.label("%s %d" % [String(m["name"]), int(m["year"])], 14, UIKit.COLOR_ACCENT if is_now else Color("#dfe6f2"))
		top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(top)
		var icons: Array = m["icons"]
		var icon_label := UIKit.label(" ".join(icons) if not icons.is_empty() else "·", 15, Color("#aab4c8"))
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(icon_label)
		grid.add_child(cell)
	body.add_child(grid)


# --- Agenda -----------------------------------------------------------------------------------

const KIND_COLORS := {
	"money": Color("#5aa64f"), "season": Color("#c58ae0"), "award": Color("#f2c744"),
	"project": Color("#5b9ae0"), "quest": Color("#c58ae0"), "client": Color("#5aa64f"),
	"office": Color("#f28c3a"), "rival": Color("#e04a3c"),
}


func _build_agenda() -> void:
	var st: GameState = Game.state
	var items: Array = Game.calendar.upcoming(120)
	body.add_child(UIKit.title("⏳ O que vem pela frente"))
	if items.is_empty():
		body.add_child(UIKit.muted("Nada marcado nos próximos meses."))
		return
	for item in items.slice(0, 18):
		var day: int = int(item["day"])
		var card := UIKit.card()
		var v := UIKit.card_content(card)
		var top := UIKit.hbox(8)
		var title := UIKit.label("%s %s" % [String(item.get("icon", "•")), String(item.get("title", ""))], 15,
			KIND_COLORS.get(String(item.get("kind", "")), UIKit.COLOR_TEXT))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		top.add_child(title)
		var days_left: int = day - st.day
		top.add_child(UIKit.label("em %d d" % maxi(days_left, 0) if days_left > 0 else "hoje", 13,
			UIKit.COLOR_RED if days_left <= 3 else UIKit.COLOR_MUTED))
		v.add_child(top)
		v.add_child(UIKit.muted("%s · %s" % [GameState.date_text_for(day), String(item.get("detail", ""))], 12))
		if String(item.get("kind", "")) == "client" and String(item.get("title", "")).begins_with("Aniversário"):
			_add_gift_button(v, String(item.get("title", "")))
		body.add_child(card)


func _add_gift_button(v: VBoxContainer, title: String) -> void:
	var name := title.substr(title.find(": ") + 2)
	for c in Game.state.active_clients():
		if c.name != name:
			continue
		var check: Dictionary = Game.calendar.can_send_gift(c)
		var b := UIKit.button("🎁 Enviar presente (%s)" % UIKit.money(Game.calendar.gift_cost(c)), func():
			var r: Dictionary = Game.calendar.send_gift(c)
			if not r.ok:
				_popups().show_info("Presente", r.reason), true, 38)
		b.disabled = not check.ok
		b.tooltip_text = check.reason
		v.add_child(b)
		return


# --- Banca de notícias -------------------------------------------------------------------------

func _build_news() -> void:
	var feed: Array = Game.state.news_feed
	body.add_child(UIKit.title("📰 Banca"))
	if feed.is_empty():
		body.add_child(UIKit.muted("Nenhuma manchete ainda. O mercado sempre acaba aprontando alguma."))
		return
	for entry in feed.slice(0, 8):
		var n: Dictionary = Game.news.by_id(String(entry.get("id", "")))
		if n.is_empty():
			continue
		var card := UIKit.card()
		var v := UIKit.card_content(card)
		var top := UIKit.hbox(8)
		var outlet := UIKit.label("%s %s" % ["📰" if String(n.get("media", "jornal")) == "jornal" else "📱", Game.news.outlet(n)], 12, UIKit.COLOR_MUTED)
		outlet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(outlet)
		top.add_child(UIKit.label(GameState.date_text_for(int(entry.get("day", 0))), 12, UIKit.COLOR_MUTED))
		v.add_child(top)
		var b := UIKit.button(String(n.get("title", "")), func(): _popups().show_news(n), false, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.clip_text = false
		v.add_child(b)
		body.add_child(card)
