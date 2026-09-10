extends Control
## Cena principal: HUD, escritório, feed, telas e navegação inferior.

const SCREEN_ORDER := ["team", "clients", "projects", "company", "hr", "unlocks"]
const SCREEN_ICONS := {"team": "👥", "clients": "🤝", "projects": "📣", "company": "🏢", "hr": "❤️", "unlocks": "🏆"}
const SCREEN_LABELS := {"team": "Equipe", "clients": "Clientes", "projects": "Projetos", "company": "Empresa", "hr": "RH", "unlocks": "Agência"}

var hud: Hud
var office_view: OfficeView
var feed: RichTextLabel
var objective_label: Label
var screens: Dictionary = {}
var nav_buttons: Dictionary = {}
var popups: Popups
var title_screen: TitleScreen
var current_screen := "clients"


func _ready() -> void:
	add_to_group("main")
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = UIKit.COLOR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := UIKit.vbox(6)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_right = -8
	root.offset_top = 8
	root.offset_bottom = -8
	add_child(root)

	hud = Hud.new()
	root.add_child(hud)

	office_view = OfficeView.new()
	office_view.custom_minimum_size = Vector2(0, 336)
	office_view.worker_tapped.connect(func(id):
		var e: Employee = Game.state.employee_by_id(id)
		if e != null:
			popups.show_journey(e))
	root.add_child(office_view)

	var feed_panel := PanelContainer.new()
	feed_panel.custom_minimum_size = Vector2(0, 96)
	var feed_box := UIKit.vbox(2)
	feed_panel.add_child(feed_box)
	objective_label = UIKit.label("", 14, UIKit.COLOR_ACCENT, true)
	objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	feed_box.add_child(objective_label)
	feed = RichTextLabel.new()
	feed.bbcode_enabled = true
	feed.scroll_active = false
	feed.fit_content = false
	feed.add_theme_font_size_override("normal_font_size", 13)
	feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feed_box.add_child(feed)
	root.add_child(feed_panel)

	var holder := MarginContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(holder)
	screens["team"] = TeamScreen.new()
	screens["clients"] = ClientsScreen.new()
	screens["projects"] = ProjectsScreen.new()
	screens["company"] = CompanyScreen.new()
	screens["hr"] = HRScreen.new()
	screens["unlocks"] = UnlocksScreen.new()
	for key in SCREEN_ORDER:
		holder.add_child(screens[key])
		screens[key].visible = false

	var nav := UIKit.hbox(4)
	for key in SCREEN_ORDER:
		var name: String = key
		var b := UIKit.button("%s\n%s" % [SCREEN_ICONS[key], SCREEN_LABELS[key]], func(): show_screen(name), false, 56)
		b.add_theme_font_size_override("font_size", 12)
		b.clip_text = true
		b.tooltip_text = SCREEN_LABELS[key]
		nav.add_child(b)
		nav_buttons[key] = b
	root.add_child(nav)

	popups = Popups.new()
	add_child(popups)

	title_screen = TitleScreen.new()
	title_screen.start_requested.connect(_on_game_started)
	add_child(title_screen)

	EventBus.log_added.connect(func(_t, _k): _refresh_feed())
	EventBus.game_started.connect(_refresh_feed)
	EventBus.state_changed.connect(_refresh_objective)
	title_screen.open()


func show_screen(name: String) -> void:
	current_screen = name
	for key in screens:
		screens[key].visible = key == name
		var b: Button = nav_buttons[key]
		if key == name:
			b.add_theme_stylebox_override("normal", b.get_theme_stylebox("pressed"))
			b.add_theme_color_override("font_color", UIKit.COLOR_ACCENT.darkened(0.25))
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_color_override("font_color")
	screens[name].refresh()


func show_title() -> void:
	if Game.has_game():
		Game.state.paused = true
	title_screen.open()


func _on_game_started() -> void:
	show_screen("clients")
	office_view.refresh()
	hud.refresh()
	_refresh_feed()
	if Game.state.day == 0:
		popups.show_info("Sua história começa aqui",
			"Você é um freelancer com %s no caixa. Siga os objetivos mostrados acima do feed: feche o primeiro cliente, monte a estratégia e entregue resultado. Dinheiro e reputação abrem clientes maiores. Use os botões 1x, 2x e 3x para controlar o ritmo. Arraste o escritório com o dedo e use dois dedos para dar zoom." % UIKit.money(Game.state.money))
	Game.state.paused = false


func _refresh_objective() -> void:
	if not Game.has_game():
		return
	var obj := Game.objectives.current()
	if obj.is_empty():
		objective_label.text = "Todos os objetivos concluídos. Agora a história é sua."
		return
	var target := float(obj.get("value", 1))
	var value := Game.objectives.progress_value(obj)
	var progress := " (%d/%d)" % [int(value), int(target)] if target > 1.0 else ""
	objective_label.text = "Objetivo %d/%d: %s%s" % [Game.objectives.completed_count() + 1, Game.objectives.all().size(), obj["text"], progress]


func _refresh_feed() -> void:
	if not Game.has_game():
		return
	_refresh_objective()
	var lines: Array = Game.state.log.slice(maxi(Game.state.log.size() - 4, 0), Game.state.log.size())
	feed.clear()
	for entry in lines:
		var color := _feed_color(String(entry.get("kind", "info")))
		feed.append_text("[color=%s]%s[/color]\n" % [color.to_html(false), String(entry.get("text", ""))])


func _feed_color(kind: String) -> Color:
	match kind:
		"money":
			return UIKit.COLOR_GREEN
		"warn":
			return UIKit.COLOR_RED
		"fun", "press":
			return UIKit.COLOR_PURPLE
		"rep", "unlock", "promo", "year":
			return UIKit.COLOR_ACCENT
		"client", "project":
			return UIKit.COLOR_BLUE
		_:
			return UIKit.COLOR_TEXT
