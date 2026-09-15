extends Control
## Cena principal: HUD, escritório, feed, telas e navegação inferior.

const SCREEN_ORDER := ["team", "clients", "projects", "company", "hr", "unlocks"]
const SCREEN_ICONS := {"team": "👥", "clients": "🤝", "projects": "📣", "company": "🏢", "hr": "❤️", "unlocks": "🏆"}
## A barra de baixo usa ícones pixel art, sem texto: fica mais dinâmica e não depende de fonte de
## emoji. O nome da aba vira tooltip, e o contador de aviso aparece ao lado do ícone.
const NAV_ICONS := {"team": "nav_team", "clients": "nav_clients", "projects": "nav_projects",
	"company": "nav_company", "hr": "nav_hr", "unlocks": "nav_agency"}
const SCREEN_LABELS := {"team": "Equipe", "clients": "Clientes", "projects": "Projetos", "company": "Empresa", "hr": "RH", "unlocks": "Agência"}
## Layout de PC: navegação em coluna à esquerda, escritório no meio, aba ativa à direita.
const NAV_COL_W := 172.0
const TAB_COL_W := 532.0        # a mesma largura de leitura do celular: os cartões não esticam
const WIDE_FEED_H := 200.0      # o feed cabe mais linhas quando a tela é alta e larga
const PORTRAIT_FEED_H := 96.0
const WIDE_FEED_LINES := 8
const PORTRAIT_FEED_LINES := 4

var hud: Hud
var office_view: OfficeView
var feed: RichTextLabel
var objective_label: Label
var quest_label: Label
var screens: Dictionary = {}
var nav_buttons: Dictionary = {}
var popups: Popups
var event_stage: EventStage
var title_screen: TitleScreen
var tutorial: TutorialOverlay
var world_map: WorldMapScreen
var current_screen := "clients"
var _blink_t := 0.0
# --- layout: a mesma cena serve celular (retrato) e PC (largo) -----------------------------
var root: VBoxContainer
var portrait_box: VBoxContainer     # celular: escritório, feed, aba e navegação empilhados
var wide_box: HBoxContainer         # PC: navegação | escritório + feed | aba, lado a lado
var wide_nav_col: VBoxContainer
var wide_center_col: VBoxContainer
var wide_right_col: VBoxContainer
var feed_panel: PanelContainer
var holder: MarginContainer
var nav: GridContainer
var office_frame: PanelContainer
var wide := false
var _laid_out := false


func _ready() -> void:
	add_to_group("main")
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = UIKit.COLOR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	root = UIKit.vbox(6)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = UIKit.ROOT_MARGIN
	root.offset_right = -UIKit.ROOT_MARGIN
	root.offset_top = UIKit.ROOT_MARGIN
	root.offset_bottom = -UIKit.ROOT_MARGIN
	add_child(root)

	hud = Hud.new()
	root.add_child(hud)

	# as duas montagens vivem juntas; _apply_layout() move os quatro blocos de uma para a outra
	portrait_box = UIKit.vbox(6)
	portrait_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(portrait_box)
	wide_box = UIKit.hbox(10)
	wide_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wide_box.visible = false
	root.add_child(wide_box)
	wide_nav_col = UIKit.vbox(6)
	wide_nav_col.size_flags_horizontal = Control.SIZE_FILL
	wide_nav_col.custom_minimum_size.x = NAV_COL_W
	wide_box.add_child(wide_nav_col)
	wide_center_col = UIKit.vbox(8)
	wide_center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wide_box.add_child(wide_center_col)
	# no PC o escritório ganha moldura: sem ela ele flutuaria solto no fundo creme
	office_frame = PanelContainer.new()
	office_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wide_center_col.add_child(office_frame)
	wide_right_col = UIKit.vbox(6)
	wide_right_col.size_flags_horizontal = Control.SIZE_FILL
	wide_right_col.custom_minimum_size.x = TAB_COL_W
	wide_box.add_child(wide_right_col)

	office_view = OfficeView.new()
	office_view.custom_minimum_size = Vector2(0, 336)
	office_view.worker_tapped.connect(func(id):
		var e: Employee = Game.state.employee_by_id(id)
		if e != null:
			popups.show_journey(e))
	portrait_box.add_child(office_view)

	feed_panel = PanelContainer.new()
	feed_panel.custom_minimum_size = Vector2(0, 96)
	var feed_box := UIKit.vbox(2)
	feed_panel.add_child(feed_box)
	objective_label = UIKit.label("", 14, UIKit.COLOR_ACCENT, true)
	objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	feed_box.add_child(objective_label)
	quest_label = UIKit.label("", 13, UIKit.COLOR_PURPLE, true)
	quest_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	quest_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	quest_label.visible = false
	feed_box.add_child(quest_label)
	feed = RichTextLabel.new()
	feed.bbcode_enabled = true
	feed.scroll_active = false
	feed.fit_content = false
	feed.add_theme_font_size_override("normal_font_size", 13)
	feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feed_box.add_child(feed)
	portrait_box.add_child(feed_panel)

	holder = MarginContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_box.add_child(holder)
	screens["team"] = TeamScreen.new()
	screens["clients"] = ClientsScreen.new()
	screens["projects"] = ProjectsScreen.new()
	screens["company"] = CompanyScreen.new()
	screens["hr"] = HRScreen.new()
	screens["unlocks"] = UnlocksScreen.new()
	for key in SCREEN_ORDER:
		holder.add_child(screens[key])
		screens[key].visible = false

	# uma grade: 6 colunas no celular (barra de baixo) e 1 coluna no PC (rail lateral)
	nav = GridContainer.new()
	nav.columns = SCREEN_ORDER.size()
	nav.add_theme_constant_override("h_separation", 4)
	nav.add_theme_constant_override("v_separation", 4)
	for key in SCREEN_ORDER:
		var name: String = key
		var b := UIKit.button("", func(): show_screen(name), false, 56)
		b.icon = UIKit.icon_texture(NAV_ICONS[key])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 14)
		b.clip_text = true
		b.tooltip_text = "%s  ·  tecla %d" % [SCREEN_LABELS[key], SCREEN_ORDER.find(key) + 1]
		b.set_meta("tutorial", "nav:%s" % key)
		nav.add_child(b)
		nav_buttons[key] = b
	portrait_box.add_child(nav)

	popups = Popups.new()
	add_child(popups)
	var stage_layer := CanvasLayer.new()
	stage_layer.layer = 11   # acima do escurecimento dos popups
	add_child(stage_layer)
	event_stage = EventStage.new()
	stage_layer.add_child(event_stage)
	var map_layer := CanvasLayer.new()
	map_layer.layer = 9   # cobre escritório e abas; fica abaixo dos modais
	add_child(map_layer)
	world_map = WorldMapScreen.new()
	map_layer.add_child(world_map)
	var guide_layer := CanvasLayer.new()
	guide_layer.layer = 12   # acima dos modais: destaca botões dentro deles também
	add_child(guide_layer)
	tutorial = TutorialOverlay.new()
	guide_layer.add_child(tutorial)

	title_screen = TitleScreen.new()
	title_screen.start_requested.connect(_on_game_started)
	add_child(title_screen)

	EventBus.log_added.connect(func(_t, _k): _refresh_feed())
	EventBus.game_started.connect(_refresh_feed)
	EventBus.state_changed.connect(_refresh_objective)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_layout()
	title_screen.open()


func _on_viewport_resized() -> void:
	_apply_layout()
	_apply_root_width()   # o teto do layout de celular acompanha a janela mesmo sem trocar de modo


## No layout de PC a raiz ocupa a janela inteira. No de celular ela tem teto de largura e fica
## centrada: numa janela de 960 px os cartões ficariam com 944 px, largos demais para ler.
func _apply_root_width() -> void:
	if root == null:
		return
	if wide:
		root.anchor_left = 0.0
		root.anchor_right = 1.0
		root.offset_left = UIKit.ROOT_MARGIN
		root.offset_right = -UIKit.ROOT_MARGIN
		return
	var vw: float = UIKit.viewport_size(self).x
	var half: float = minf(UIKit.PORTRAIT_MAX_WIDTH, vw - 2.0 * UIKit.ROOT_MARGIN) * 0.5
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.offset_left = -half
	root.offset_right = half


## O ÚNICO ponto que decide entre a montagem de celular e a de PC. Só a largura do viewport manda
## (a altura é sempre 960, ver UIKit). Nada é reconstruído: os quatro blocos — escritório, feed,
## aba ativa e navegação — trocam de pai e mudam de tamanho.
func _apply_layout() -> void:
	var w: bool = UIKit.is_wide(self)
	if w == wide and _laid_out:
		return
	wide = w
	_laid_out = true
	for node in [office_view, feed_panel, holder, nav]:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
	office_frame.visible = wide
	if wide:
		wide_nav_col.add_child(nav)
		office_frame.add_child(office_view)
		wide_center_col.add_child(feed_panel)
		wide_right_col.add_child(holder)
		nav.columns = 1
		office_view.custom_minimum_size = Vector2(0, 0)
		office_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		feed_panel.custom_minimum_size = Vector2(0, WIDE_FEED_H)
	else:
		portrait_box.add_child(office_view)
		portrait_box.add_child(feed_panel)
		portrait_box.add_child(holder)
		portrait_box.add_child(nav)
		nav.columns = SCREEN_ORDER.size()
		office_view.custom_minimum_size = Vector2(0, 336)
		office_view.size_flags_vertical = Control.SIZE_FILL
		feed_panel.custom_minimum_size = Vector2(0, PORTRAIT_FEED_H)
	portrait_box.visible = not wide
	wide_box.visible = wide
	_apply_root_width()
	hud.set_wide(wide)
	for key in SCREEN_ORDER:
		var b: Button = nav_buttons[key]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT if wide else HORIZONTAL_ALIGNMENT_CENTER
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT if wide else HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(0, 52 if wide else 56)
	_refresh_nav_labels()
	_refresh_feed()
	if Game.has_game():
		show_screen(current_screen)


## Atalhos de teclado (só fazem sentido no PC, mas não atrapalham no celular): 1 a 6 trocam de
## aba na ordem da navegação, espaço pausa, M abre o mapa e N a central de notificações.
## Ficam desligados na tela inicial e enquanto um modal espera resposta.
const KEY_TO_TAB := {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4, KEY_6: 5}


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if not Game.has_game() or Game.ui_blocking or title_screen.visible:
		return
	if world_map.visible:
		if k.keycode == KEY_ESCAPE or k.keycode == KEY_M:
			world_map.close()
			get_viewport().set_input_as_handled()
		return
	if KEY_TO_TAB.has(k.keycode):
		show_screen(SCREEN_ORDER[int(KEY_TO_TAB[k.keycode])])
	elif k.keycode == KEY_SPACE:
		Game.toggle_pause()
	elif k.keycode == KEY_M:
		show_world_map()
	elif k.keycode == KEY_N:
		show_notifications()
	else:
		return
	get_viewport().set_input_as_handled()


## Abas que chamam atenção: Clientes enquanto houver prospect esperando resposta, Equipe enquanto
## houver currículo que o jogador ainda não abriu. As duas ganham contador e pulso.
func _process(delta: float) -> void:
	if not Game.has_game() or not nav_buttons.has("clients"):
		return
	_blink_t += delta
	_alert_nav("clients", Game.state.prospects().size())
	_alert_nav("team", Game.state.new_candidates)


## Texto do botão de navegação: no PC o nome da aba; no celular só o contador (o nome é tooltip).
func _nav_label(key: String, count: int) -> String:
	if wide:
		return "%s (%d)" % [SCREEN_LABELS[key], count] if count > 0 else String(SCREEN_LABELS[key])
	return "" if count <= 0 else "%d" % count


func _refresh_nav_labels() -> void:
	for key in SCREEN_ORDER:
		var count: int = 0
		if Game.has_game():
			if key == "clients":
				count = Game.state.prospects().size()
			elif key == "team":
				count = Game.state.new_candidates
		(nav_buttons[key] as Button).text = _nav_label(key, count)


func _alert_nav(key: String, count: int) -> void:
	if not nav_buttons.has(key):
		return
	var b: Button = nav_buttons[key]
	# o contador entra como texto ao lado do ícone; sem aviso, o botão fica só com o ícone
	var label := _nav_label(key, count)
	if b.text != label:
		b.text = label
		if not wide:
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if count <= 0 else HORIZONTAL_ALIGNMENT_LEFT
	if count > 0 and current_screen != key:
		var k := 0.5 + 0.5 * sin(_blink_t * 5.0)
		b.modulate = Color(1.0, 1.0 - 0.25 * k, 1.0 - 0.45 * k)
	elif b.modulate != Color.WHITE:
		b.modulate = Color.WHITE


func show_screen(name: String) -> void:
	current_screen = name
	if name == "team" and Game.has_game() and Game.state.new_candidates > 0:
		Game.state.new_candidates = 0   # o jogador viu os currículos: o aviso apaga
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


## Corte de câmera: o cenário do evento cobre exatamente o painel do escritório — e continua
## cobrindo se a janela do PC for redimensionada com a cena aberta.
func show_event_scene(kind: String, employees: Array) -> void:
	event_stage.track(office_view)
	event_stage.show_scene(kind, employees)


func hide_event_scene() -> void:
	event_stage.hide_scene()


## Altura em que um popup deve começar para não cobrir a cena do evento (layout de celular).
func below_office_y() -> float:
	return office_view.global_position.y + office_view.size.y + 10.0


## Caixa em que o modal de um evento deve caber sem tapar a cena. No celular devolve um retângulo
## vazio (o modal usa o comportamento padrão, começando abaixo do escritório); no PC o modal vai
## para a coluna da aba, à direita da cena, que continua visível o tempo todo.
func event_popup_rect() -> Rect2:
	if not wide or holder == null:
		return Rect2()
	var r := holder.get_global_rect()
	return Rect2(r.position.x, r.position.y, r.size.x, r.size.y)


func show_notifications() -> void:
	if Game.has_game():
		popups.show_notifications()


func show_world_map() -> void:
	if Game.has_game():
		world_map.open()


func show_title() -> void:
	if world_map.visible:
		world_map.close()
	if Game.has_game():
		Game.state.paused = true
	Audio.stop_ambience()
	title_screen.open()


func _on_game_started() -> void:
	show_screen("clients")
	office_view.refresh()
	hud.refresh()
	_refresh_feed()
	if Game.state.day == 0:
		popups.show_info("Sua história começa aqui",
			"Você é um freelancer com %s no caixa. O guia laranja mostra onde tocar para cumprir os primeiros objetivos (eles aparecem acima do feed). Dinheiro e reputação abrem clientes maiores. Use os botões 1x, 2x e 3x para controlar o ritmo. Arraste o escritório com o dedo e use dois dedos para dar zoom." % UIKit.money(Game.state.money))
	Game.state.paused = false


func _refresh_objective() -> void:
	if not Game.has_game():
		return
	var quests: Array = Game.quests.active()
	var crisis_line: String = Game.crisis.headline()
	quest_label.visible = not quests.is_empty() or crisis_line != ""
	if quest_label.visible:
		var parts: Array = []
		if crisis_line != "":
			parts.append(crisis_line)
		for q in quests:
			var t: Dictionary = Game.quests.template(String(q.get("id", "")))
			parts.append("%s %s (%s · %d d)" % [String(t.get("icon", "📜")), String(t.get("title", "")), Game.quests.progress_text(q), Game.quests.days_left(q)])
		quest_label.text = " · ".join(parts)
		quest_label.add_theme_color_override("font_color", UIKit.COLOR_RED if crisis_line != "" else UIKit.COLOR_PURPLE)
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
	var keep: int = WIDE_FEED_LINES if wide else PORTRAIT_FEED_LINES
	var lines: Array = Game.state.log.slice(maxi(Game.state.log.size() - keep, 0), Game.state.log.size())
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
