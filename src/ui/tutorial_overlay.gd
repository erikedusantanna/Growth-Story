class_name TutorialOverlay
extends Control
## Guia dos primeiros objetivos (data/tutorial.json): destaca com um contorno pulsante o botão
## que leva ao objetivo atual e mostra um cartão curto explicando o porquê. Os botões são
## encontrados pela metadata "tutorial" (ex.: "nav:clients", "proposal"). Termina sozinho ao
## concluir os primeiros objetivos ou com "Pular".

const TUTORIAL_OBJECTIVES := 4          # first_client, first_diagnosis, first_project, first_hire
const SCAN_INTERVAL := 0.2
const CARD_WIDTH := 320.0

var step: Dictionary = {}
var target: Control = null
var card: PanelContainer
var text_label: Label
var was_active := false
var _scan := 0.0
var _pulse := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	card = PanelContainer.new()
	card.theme = UIKit.theme()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff4e6")
	style.border_color = UIKit.COLOR_ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	card.visible = false
	add_child(card)
	var v := UIKit.vbox(6)
	card.add_child(v)
	text_label = UIKit.label("", 15, UIKit.COLOR_TEXT, true)
	text_label.custom_minimum_size.x = CARD_WIDTH - 24
	v.add_child(text_label)
	var row := UIKit.hbox()
	row.add_child(UIKit.label("🧭 Guia", 13, UIKit.COLOR_ACCENT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var skip := UIKit.button("Pular guia", skip_tutorial, false, 30)
	skip.add_theme_font_size_override("font_size", 13)
	row.add_child(skip)
	v.add_child(row)


func active() -> bool:
	if not Game.has_game() or Game.state.tutorial_done:
		return false
	return Game.state.objective_index < TUTORIAL_OBJECTIVES and not Game.objectives.current().is_empty()


func skip_tutorial() -> void:
	if Game.has_game():
		Game.state.tutorial_done = true
	_clear()


func _process(delta: float) -> void:
	var main = get_tree().get_first_node_in_group("main")
	if main == null or main.title_screen.visible or not active():
		if was_active and Game.has_game() and not Game.state.tutorial_done and Game.state.objective_index >= TUTORIAL_OBJECTIVES:
			# concluiu os primeiros objetivos com o guia ligado: encerra com um aviso
			Game.state.tutorial_done = true
			main.popups.show_info("Você já sabe o básico",
				"Guia concluído. Os próximos objetivos aparecem acima do feed; siga-os no seu ritmo. Dica: reputação abre clientes maiores e treinamentos deixam a equipe mais forte.")
		was_active = false
		_clear()
		return
	was_active = true
	_scan -= delta
	if _scan <= 0.0:
		_scan = SCAN_INTERVAL
		_pick_step(main)
	if target != null and not is_instance_valid(target):
		target = null
	_pulse += delta
	_place_card()
	queue_redraw()


func _clear() -> void:
	step = {}
	target = null
	card.visible = false
	queue_redraw()


## Entre os passos do objetivo atual, vale o último cuja condição bate e cujo botão está na tela.
func _pick_step(main) -> void:
	var obj_id := String(Game.objectives.current().get("id", ""))
	var steps: Array = Game.content.tutorial
	var popup_open: bool = main.popups.is_open()
	step = {}
	target = null
	for i in range(steps.size() - 1, -1, -1):
		var s: Dictionary = steps[i]
		if String(s.get("objective", "")) != obj_id or not _condition_ok(String(s.get("when", ""))):
			continue
		var ctrl := _find_target(main, String(s.get("target", "")))
		if ctrl == null:
			continue
		# com um modal aberto só vale o que está dentro dele (o resto fica escurecido)
		if popup_open and not main.popups.holder.is_ancestor_of(ctrl):
			continue
		step = s
		target = ctrl
		break
	card.visible = target != null
	if target != null:
		text_label.text = String(step.get("text", ""))


func _condition_ok(when: String) -> bool:
	var st: GameState = Game.state
	var diag_running := false
	for c in st.clients:
		if c.diagnosis_days_left > 0:
			diag_running = true
	match when:
		"":
			return true
		"project_running":
			return not st.running_projects().is_empty()
		"no_project_running":
			return st.running_projects().is_empty()
		"diagnosis_running":
			return diag_running
		"diagnosis_idle":
			return not diag_running
	return true


func _find_target(root: Node, tag: String) -> Control:
	if tag == "":
		return null
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control and n.has_meta("tutorial") and String(n.get_meta("tutorial")) == tag:
			var c := n as Control
			if c.is_visible_in_tree() and c.size.x > 0.0 and not (c is BaseButton and (c as BaseButton).disabled):
				return c
		for child in n.get_children():
			stack.append(child)
	return null


func _place_card() -> void:
	if target == null:
		card.visible = false
		return
	card.visible = true
	card.reset_size()
	card.size.x = CARD_WIDTH
	var rect := target.get_global_rect()
	var vp := get_viewport_rect().size
	var below := rect.end.y + 14.0
	var y := below if below + card.size.y < vp.y - 8.0 else rect.position.y - card.size.y - 14.0
	var x := clampf(rect.get_center().x - card.size.x * 0.5, 8.0, vp.x - card.size.x - 8.0)
	card.position = Vector2(x, y).round()


func _draw() -> void:
	if target == null:
		return
	var rect := target.get_global_rect()
	var grow := 4.0 + 3.0 * (0.5 + 0.5 * sin(_pulse * 5.0))
	var outer := rect.grow(grow + 4.0)
	draw_rect(outer, Color(UIKit.COLOR_ACCENT, 0.35), false, 6.0)
	draw_rect(rect.grow(grow), UIKit.COLOR_ACCENT, false, 3.0)
	# seta do cartão para o alvo
	var cx := clampf(rect.get_center().x, card.position.x + 20.0, card.position.x + card.size.x - 20.0)
	var tri: PackedVector2Array
	if card.position.y > rect.end.y:
		tri = PackedVector2Array([Vector2(cx, card.position.y - 10.0), Vector2(cx - 9.0, card.position.y + 1.0), Vector2(cx + 9.0, card.position.y + 1.0)])
	else:
		var by := card.position.y + card.size.y
		tri = PackedVector2Array([Vector2(cx, by + 10.0), Vector2(cx - 9.0, by - 1.0), Vector2(cx + 9.0, by - 1.0)])
	draw_colored_polygon(tri, UIKit.COLOR_ACCENT)
