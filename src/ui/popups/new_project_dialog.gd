class_name NewProjectDialog
extends PanelContainer
## Briefing → estratégia (serviços) → equipe → prévia → iniciar.

var client: Client
var popups: Popups
var kind: int = Project.Kind.PROJECT
var services: Array = []
var team: Array = []
var preview_box: VBoxContainer
var start_button: Button
var error_label: Label


func _init(c: Client, owner_popups: Popups) -> void:
	client = c
	popups = owner_popups


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 20
	offset_right = -20
	offset_top = 70
	offset_bottom = -70
	var v := UIKit.vbox(8)
	add_child(v)
	v.add_child(UIKit.title("Novo projeto"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var body := UIKit.vbox(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	# Briefing
	var brief := UIKit.card()
	var bv := UIKit.card_content(brief)
	bv.add_child(UIKit.label(client.name, 20))
	bv.add_child(UIKit.muted("%s · %s · Expectativa %s · Paciência %d" % [Game.clients.segment_name(client), Game.clients.personality_name(client), client.expectation, int(client.patience)]))
	bv.add_child(UIKit.label("\"%s\"" % client.goal, 16, UIKit.COLOR_TEXT, true))
	if client.diagnosed:
		bv.add_child(UIKit.label("Problema real: %s" % Game.clients.problem_name(client), 15, UIKit.COLOR_ACCENT, true))
		var sol: Array = Game.content.problem_solutions.get(client.problem, []).map(func(s): return Game.content.service_name(s))
		bv.add_child(UIKit.label("Resolve com: %s" % ", ".join(sol), 13, UIKit.COLOR_GREEN, true))
	else:
		bv.add_child(UIKit.muted("Problema real desconhecido. Um diagnóstico dá +15 de Estratégia se a solução for certa.", 13))
	body.add_child(brief)

	# Contrato
	body.add_child(UIKit.label("Contrato", 17, UIKit.COLOR_ACCENT))
	var qp := Game.projects.quote(client, Project.Kind.PROJECT)
	var kinds := UIKit.hbox()
	var project_toggle := UIKit.toggle("Projeto: %s · %d dias" % [UIKit.money(qp.budget), int(qp.deadline)], true, Callable())
	project_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kinds.add_child(project_toggle)
	var retainer_toggle: Button = null
	if Game.clients.retainer_available(client):
		var qr := Game.projects.quote(client, Project.Kind.RETAINER)
		retainer_toggle = UIKit.toggle("Retainer: %s/mês · %d meses" % [UIKit.money(qr.budget), ProjectSystem.RETAINER_MONTHS], false, Callable())
		retainer_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kinds.add_child(retainer_toggle)
		project_toggle.toggled.connect(func(on: bool):
			if on:
				kind = Project.Kind.PROJECT
				retainer_toggle.set_pressed_no_signal(false)
			elif not retainer_toggle.button_pressed:
				project_toggle.set_pressed_no_signal(true)
			_update_preview())
		retainer_toggle.toggled.connect(func(on: bool):
			if on:
				kind = Project.Kind.RETAINER
				project_toggle.set_pressed_no_signal(false)
			elif not project_toggle.button_pressed:
				retainer_toggle.set_pressed_no_signal(true)
			_update_preview())
	else:
		project_toggle.toggled.connect(func(_on: bool): project_toggle.set_pressed_no_signal(true))
		bv.add_child(UIKit.muted("Retainer fica disponível após uma boa entrega (relação 60+).", 13))
	body.add_child(kinds)

	# Estratégia
	body.add_child(UIKit.label("Estratégia (1 a %d serviços)" % ProjectSystem.MAX_SERVICES, 17, UIKit.COLOR_ACCENT))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for sid in Game.services.unlocked_services():
		var id: String = sid
		var t := UIKit.toggle(Game.content.service_name(id), false, Callable())
		t.toggled.connect(func(on: bool):
			if on:
				if services.size() >= ProjectSystem.MAX_SERVICES:
					t.set_pressed_no_signal(false)
					return
				services.append(id)
			else:
				services.erase(id)
			_update_preview())
		flow.add_child(t)
	body.add_child(flow)

	# Equipe
	body.add_child(UIKit.label("Equipe", 17, UIKit.COLOR_ACCENT))
	var available: Array = Game.state.available_employees()
	if available.is_empty():
		body.add_child(UIKit.label("Ninguém disponível. Espere um projeto terminar ou contrate.", 15, UIKit.COLOR_RED, true))
	for emp in available:
		var e: Employee = emp
		var row := UIKit.hbox()
		var t := UIKit.toggle(e.name, false, Callable())
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.toggled.connect(func(on: bool):
			if on:
				team.append(e.id)
			else:
				team.erase(e.id)
			_update_preview())
		row.add_child(t)
		row.add_child(UIKit.label("%s · %s %d" % [Game.employees.title(e), UIKit.ATTR_SHORT[e.best_attr()], int(e.attr(e.best_attr()))], 13, UIKit.COLOR_MUTED))
		body.add_child(row)

	# Prévia
	body.add_child(UIKit.label("Prévia", 17, UIKit.COLOR_ACCENT))
	preview_box = UIKit.vbox(6)
	body.add_child(preview_box)

	error_label = UIKit.label("", 14, UIKit.COLOR_RED, true)
	v.add_child(error_label)
	var buttons := UIKit.hbox()
	buttons.add_child(UIKit.button("Cancelar", popups.close))
	start_button = UIKit.button("Iniciar projeto", _start, true)
	buttons.add_child(start_button)
	v.add_child(buttons)
	_update_preview()


func _update_preview() -> void:
	UIKit.clear(preview_box)
	if services.is_empty() or team.is_empty():
		preview_box.add_child(UIKit.muted("Escolha serviços e equipe para ver a prévia."))
		start_button.disabled = true
		return
	var pv := Game.projects.predict(client, services, team, kind)
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	var head := UIKit.hbox(10)
	head.add_child(UIKit.star_row(int(pv.stars), 3))
	var score_label := UIKit.number("nota prevista %d" % int(roundf(float(pv.score))), 15, UIKit.COLOR_NUMBER)
	score_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(score_label)
	v.add_child(head)
	v.add_child(UIKit.label(ServiceSystem.MATCH_NAMES.get(pv.match, ""), 16, UIKit.match_color(pv.match)))
	var deadline_color := UIKit.COLOR_GREEN if int(pv.days) <= int(pv.deadline) else UIKit.COLOR_RED
	v.add_child(UIKit.label("Estimativa: %d dias (prazo %d) · %s%s" % [int(pv.days), int(pv.deadline), UIKit.money(float(pv.budget)), "/mês" if kind == Project.Kind.RETAINER else ""], 14, deadline_color))
	for item in pv.breakdown:
		var h := UIKit.hbox()
		var l := UIKit.label(String(item.label), 13, UIKit.COLOR_MUTED, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var val := UIKit.number(String(item.text), 13, UIKit.COLOR_GREEN if item.good else UIKit.COLOR_RED)
		val.custom_minimum_size.x = 110
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(val)
		v.add_child(h)
	if not pv.hints.is_empty():
		v.add_child(UIKit.label("Para subir a nota:", 14, UIKit.COLOR_BLUE))
		for hint in pv.hints:
			v.add_child(UIKit.label("• " + String(hint), 13, UIKit.COLOR_TEXT, true))
	preview_box.add_child(card)
	start_button.disabled = false


func _start() -> void:
	var r := Game.projects.create_project(client, services, team, kind)
	if r.ok:
		popups.close()
	else:
		error_label.text = r.reason
