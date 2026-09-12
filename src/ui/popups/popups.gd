class_name Popups
extends CanvasLayer
## Camada de modais: eventos, resultados, novo projeto, treinamento e avisos.
## Enquanto um modal está aberto o tempo do jogo fica travado (Game.ui_blocking).

var dim: ColorRect
var holder: Control
var current: Control = null
var queue: Array = []


func _ready() -> void:
	layer = 10
	add_to_group("popups")
	dim = ColorRect.new()
	dim.color = Color(0.17, 0.16, 0.2, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	add_child(dim)
	holder = Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	EventBus.event_triggered.connect(show_event)
	EventBus.agency_event_finished.connect(show_agency_result)
	EventBus.awards_ceremony.connect(show_awards)
	EventBus.project_completed.connect(show_result)
	EventBus.game_over.connect(show_game_over)
	EventBus.quest_started.connect(show_quest)
	EventBus.news_published.connect(show_news)


func is_open() -> bool:
	return current != null


func _open(builder: Callable) -> void:
	if is_open():
		queue.append(builder)
		return
	current = builder.call()
	holder.add_child(current)
	dim.visible = true
	Game.ui_blocking = true


func close() -> void:
	var m = _main()
	if m != null:
		m.hide_event_scene()
	if current != null:
		current.queue_free()
		current = null
	if not queue.is_empty():
		var next: Callable = queue.pop_front()
		_open(next)
	else:
		dim.visible = false
		Game.ui_blocking = false


## Painel padrão: título, corpo rolável e barra de botões.
func _panel(title: String, top: float = 90.0) -> Dictionary:
	var panel := PanelContainer.new()
	panel.theme = UIKit.theme()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 20
	panel.offset_right = -20
	panel.offset_top = top
	panel.offset_bottom = -90
	var v := UIKit.vbox(10)
	panel.add_child(v)
	v.add_child(UIKit.title(title))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var body := UIKit.vbox(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var buttons := UIKit.vbox(6)
	v.add_child(buttons)
	return {"panel": panel, "body": body, "buttons": buttons}


func show_info(title: String, text: String) -> void:
	show_choice(title, text, ["OK"], Callable())


func show_choice(title: String, text: String, choices: Array, callback: Callable) -> void:
	_open(func():
		var parts := _panel(title)
		parts.body.add_child(UIKit.label(text, 17, UIKit.COLOR_TEXT, true))
		for i in choices.size():
			var idx := i
			parts.buttons.add_child(UIKit.button(choices[i], func():
				close()
				if callback.is_valid():
					callback.call(idx), i == 0))
		return parts.panel)


func _main():
	return get_tree().get_first_node_in_group("main")   # Variant: a cena principal expõe show_event_scene/hide_event_scene


## Abre a cena do evento (se houver) e devolve a altura em que o popup deve começar.
func _scene_top(ev: Dictionary, employees: Array) -> float:
	var kind := String(ev.get("scene", ""))
	var m = _main()
	if kind == "" or m == null or employees.is_empty():
		return 90.0
	m.show_event_scene(kind, employees)
	return m.below_office_y()


func show_event(ev: Dictionary) -> void:
	_open(func():
		var parts := _panel(ev.get("title", "Evento"), _scene_top(ev, Game.state.employees))
		parts.body.add_child(UIKit.label(ev.get("text", ""), 17, UIKit.COLOR_TEXT, true))
		var choices: Array = ev.get("choices", [])
		for i in choices.size():
			var idx := i
			parts.buttons.add_child(UIKit.button(choices[i].get("label", "OK"), func():
				close()
				Game.resolve_event(idx), i == 0))
		if choices.is_empty():
			parts.buttons.add_child(UIKit.button("OK", func():
				close()
				Game.resolve_event(0), true))
		return parts.panel)


## Notícia do mercado: página de jornal ou post de rede social, com ilustração.
## Só entretenimento — as marcas e pessoas são fictícias.
func show_news(n: Dictionary) -> void:
	_open(func():
		var paper: bool = String(n.get("media", "jornal")) == "jornal"
		var parts := _panel("%s %s" % ["📰" if paper else "📱", Game.news.outlet(n)])
		var frame := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#e8e2d4") if paper else Color("#eef3fa")
		style.border_color = Color("#3a3630") if paper else Color("#5b9ae0")
		style.set_border_width_all(3)
		style.set_corner_radius_all(4 if paper else 12)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 10
		frame.add_theme_stylebox_override("panel", style)
		var fv := UIKit.vbox(6)
		frame.add_child(fv)
		if not paper:
			var handle := UIKit.hbox(6)
			var avatar := ColorRect.new()
			avatar.color = Color("#5b9ae0")
			avatar.custom_minimum_size = Vector2(22, 22)
			handle.add_child(avatar)
			handle.add_child(UIKit.label("@mercado.hoje · agora", 13, Color("#5c6473")))
			fv.add_child(handle)
		else:
			var rule := ColorRect.new()
			rule.color = Color("#3a3630")
			rule.custom_minimum_size = Vector2(0, 2)
			fv.add_child(rule)
		var headline := UIKit.label(String(n.get("title", "")), 19 if paper else 17, Color("#26241f"), true)
		headline.add_theme_font_override("font", UIKit.pixel_font() if paper else UIKit.bold_font())
		fv.add_child(headline)
		var art := TextureRect.new()
		art.texture = load("res://assets/art/news/%s.png" % String(n.get("art", "office")))
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.custom_minimum_size = Vector2(0, 132)
		fv.add_child(art)
		fv.add_child(UIKit.label(String(n.get("text", "")), 15, Color("#3a3630"), true))
		var effect: Dictionary = n.get("effect", {})
		if not effect.is_empty():
			fv.add_child(UIKit.label(String(effect.get("text", "")), 14, Color("#8c3b2e"), true))
		parts.body.add_child(frame)
		parts.body.add_child(UIKit.muted("Ficção: empresas e pessoas citadas não existem.", 11))
		parts.buttons.add_child(UIKit.button("📰 Fechar o jornal" if paper else "📱 Continuar rolando", close, true))
		return parts.panel)


## Missão nova: o que fazer, prazo e recompensa (e o custo de deixar passar).
func show_quest(q: Dictionary) -> void:
	_open(func():
		var t: Dictionary = Game.quests.template(String(q.get("id", "")))
		var parts := _panel("📜 Missão nova")
		parts.body.add_child(UIKit.label("%s %s" % [String(t.get("icon", "📜")), String(t.get("title", ""))], 18, UIKit.COLOR_ACCENT, true))
		parts.body.add_child(UIKit.label(String(t.get("desc", "")), 16, UIKit.COLOR_TEXT, true))
		parts.body.add_child(UIKit.label("⏳ Prazo: %d dias (até %s)" % [int(t.get("days", 30)), GameState.date_text_for(int(q.get("deadline_day", 0)))], 15, UIKit.COLOR_BLUE))
		parts.body.add_child(UIKit.label("🎁 Recompensa: %s" % Game.quests.reward_text(t), 15, UIKit.COLOR_GREEN))
		parts.body.add_child(UIKit.label("⚠️ Se o prazo passar: −%d de reputação." % int(Game.quests.data().get("fail_rep", 1)), 14, UIKit.COLOR_RED))
		parts.body.add_child(UIKit.muted("Acompanhe em 📅 Calendário (ao lado do mapa) e no feed.", 13))
		parts.buttons.add_child(UIKit.button("📜 Combinado", close, true))
		return parts.panel)


## Fim de um evento promovido pela agência: a cena mostra quem foi e o resumo do que rendeu.
func show_agency_result(ev: Dictionary, people: Array, summary: String) -> void:
	_open(func():
		var team: Array = []
		for id in people:
			var e: Employee = Game.state.employee_by_id(int(id))
			if e != null:
				team.append(e)
		if team.is_empty():
			team = Game.state.employees.duplicate()
		var parts := _panel("🎪 %s" % String(ev.get("name", "Evento")), _scene_top(ev, team))
		parts.body.add_child(UIKit.label(String(ev.get("desc", "")), 16, UIKit.COLOR_TEXT, true))
		if summary != "":
			parts.body.add_child(UIKit.label("Rendeu: %s." % summary, 16, UIKit.COLOR_GREEN, true))
		parts.buttons.add_child(UIKit.button("➡️ Continuar", close, true))
		return parts.panel)


## Painel de uma agência concorrente (pelo mapa): força, carteira e equipe, com as investidas.
func show_rival(id: String) -> void:
	_open(func():
		var a: Dictionary = Game.competitors.agency_by_id(id)
		var rs: Dictionary = Game.competitors.rival_state(id)
		var parts := _panel("⚔️ %s" % String(a.get("name", "Concorrente")))
		var b: VBoxContainer = parts.body
		var region: Dictionary = Game.office.region_data(int(a.get("region", 1)))
		b.add_child(UIKit.label(String(a.get("desc", "")), 15, UIKit.COLOR_TEXT, true))
		b.add_child(UIKit.muted("%s · especialidade: %s%s" % [String(region.get("name", "")), Game.content.service_name(String(a.get("specialty", ""))),
			" · 😠 agressiva depois da sua investida" if Game.competitors.is_aggressive(id) else ""], 13))
		b.add_child(UIKit.stat_row("Força", float(rs.get("strength", a.get("strength", 40))), UIKit.COLOR_RED, 70))
		var raid: Dictionary = Game.competitors.can_raid()
		b.add_child(UIKit.label("Investidas: 1 a cada %d dias. %s" % [Game.competitors.raid_cooldown_days(), "Disponível agora." if raid.ok else String(raid.reason)], 14, UIKit.COLOR_GREEN if raid.ok else UIKit.COLOR_MUTED, true))
		b.add_child(UIKit.label("🤝 Clientes dela (proposta: −%d de reputação se aceitar)" % int(Game.content.competitors.get("rep_cost_client", 5)), 16, UIKit.COLOR_ACCENT))
		var clients: Array = rs.get("clients", [])
		for i in clients.size():
			var idx := i
			var cd: Dictionary = clients[i]
			var row := UIKit.hbox(8)
			var info := UIKit.vbox(0)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_child(UIKit.label("%s · Tier %d" % [String(cd.get("name", "")), int(cd.get("tier", 1))], 15))
			info.add_child(UIKit.muted("%s · %s/mês · %s" % [Game.content.segment_names.get(String(cd.get("segment", "")), ""), UIKit.money(float(cd.get("budget", 0))), Game.competitors.bond_name(String(cd.get("bond", "morna")))], 12))
			row.add_child(info)
			var chance := Game.competitors.raid_chance_client(a, cd)
			var pb := UIKit.button("🤝 Propor (%d%%)" % int(chance), func():
				var r: Dictionary = Game.competitors.raid_client(id, idx)
				close()
				if not r.ok:
					show_info("Proposta", r.reason)
				elif r.success:
					show_info("Cliente conquistado!", "%s agora é seu cliente (relação 40). Você perdeu %d de reputação e %s vai reagir." % [r.client.name, int(Game.content.competitors.get("rep_cost_client", 5)), String(a.get("name", ""))])
				else:
					show_info("Não deu", "%s recusou (chance era %d%%). A investida do trimestre foi gasta." % [String(cd.get("name", "")), int(r.chance)]), false, 40)
			pb.disabled = not raid.ok
			pb.size_flags_horizontal = 0
			pb.custom_minimum_size.x = 150
			row.add_child(pb)
			b.add_child(row)
		b.add_child(UIKit.label("💼 Equipe dela (contratar: −%d de reputação se aceitar)" % int(Game.content.competitors.get("rep_cost_employee", 3)), 16, UIKit.COLOR_ACCENT))
		var staff: Array = rs.get("staff", [])
		for i in staff.size():
			var idx := i
			var sd: Dictionary = staff[i]
			var tmp := Employee.from_dict(sd)
			var row := UIKit.hbox(8)
			row.add_child(UIKit.portrait(tmp, 3))
			var info := UIKit.vbox(0)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_child(UIKit.label(tmp.name, 15))
			info.add_child(UIKit.muted("%s · %s %d · salário %s · bônus %s" % [Game.content.role_name(tmp.role), UIKit.ATTR_SHORT[tmp.best_attr()], int(tmp.attr(tmp.best_attr())), UIKit.money(tmp.salary), UIKit.money(Game.competitors.signing_bonus(sd))], 12))
			row.add_child(info)
			var chance := Game.competitors.raid_chance_employee(a, sd)
			var hb := UIKit.button("💼 Contratar (%d%%)" % int(chance), func():
				var r: Dictionary = Game.competitors.raid_employee(id, idx)
				close()
				if not r.ok:
					show_info("Contratação", r.reason)
				elif r.success:
					show_info("Contratado!", "%s entrou na equipe. Bônus de assinatura pago, −%d de reputação, e %s vai reagir." % [r.employee.name, int(Game.content.competitors.get("rep_cost_employee", 3)), String(a.get("name", ""))])
				else:
					show_info("Não deu", "%s recusou (chance era %d%%). A investida do trimestre foi gasta." % [tmp.name, int(r.chance)]), false, 40)
			hb.disabled = not raid.ok
			hb.size_flags_horizontal = 0
			hb.custom_minimum_size.x = 150
			row.add_child(hb)
			b.add_child(row)
		b.add_child(UIKit.muted("Ela também faz propostas: todo mês pode tentar levar seu funcionário menos leal ou seu cliente com relação mais fraca.", 12))
		parts.buttons.add_child(UIKit.button("✖️ Fechar", close, true))
		return parts.panel)


## Prêmios do Marketing: o time no palco (vencedores na frente) e o resultado por categoria.
func show_awards(ceremony: Dictionary) -> void:
	_open(func():
		var st: GameState = Game.state
		var team: Array = []
		var seen := {}
		for r in ceremony.get("results", []):
			for id in r.get("people", []):
				var e: Employee = st.employee_by_id(int(id))
				if e != null and not seen.has(e.id):
					team.append(e)
					seen[e.id] = true
		for e in st.employees:
			if not seen.has(e.id) and team.size() < 7:
				team.append(e)
				seen[e.id] = true
		var won_any: bool = ceremony.get("results", []).any(func(r): return String(r.get("status", "")) == "won")
		var parts := _panel("🏆 Prêmios do Marketing %d" % int(ceremony.get("year", 0)), _scene_top({"scene": "stage" if won_any else "auditorium"}, team))
		var b: VBoxContainer = parts.body
		b.add_child(UIKit.label("A cerimônia do ano reúne as agências do mercado. Veja como a %s se saiu:" % st.agency_name, 15, UIKit.COLOR_TEXT, true))
		for r in ceremony.get("results", []):
			var status := String(r.get("status", "lost"))
			var color := UIKit.COLOR_GOLD if status == "won" else (UIKit.COLOR_BLUE if status == "nominated" else UIKit.COLOR_MUTED)
			var head := UIKit.hbox()
			var name := UIKit.label("%s %s" % [String(r.get("icon", "")), String(r.get("name", ""))], 17, color)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			head.add_child(name)
			head.add_child(UIKit.label({"won": "VENCEU!", "nominated": "indicada", "lost": "não levou"}[status], 14, color))
			b.add_child(head)
			b.add_child(UIKit.label(String(r.get("detail", "")), 14, UIKit.COLOR_TEXT, true))
		b.add_child(UIKit.separator())
		b.add_child(UIKit.muted("Vencer: Agência do Ano +6 reputação e +8 de moral para todos; Campanha +4 reputação e +10 de moral para a equipe; Profissional +15 de moral e lealdade. Indicação: +1 reputação.", 12))
		parts.buttons.add_child(UIKit.button("➡️ Continuar", close, true))
		return parts.panel)


func show_result(p: Project, result: Dictionary) -> void:
	_open(func():
		var is_retainer: bool = p.kind == Project.Kind.RETAINER
		var parts := _panel("MÊS DO RETAINER FECHADO" if is_retainer and p.is_running() else "CAMPANHA CONCLUÍDA!")
		var b: VBoxContainer = parts.body
		b.add_child(UIKit.label(String(result.get("client_name", "")), 22))
		b.add_child(UIKit.muted(String(result.get("project_title", ""))))
		var stars_center := CenterContainer.new()
		stars_center.add_child(UIKit.star_row(int(result.stars), 4))
		b.add_child(stars_center)
		var indicators: Dictionary = result.get("indicators", {})
		for key in Project.INDICATORS:
			b.add_child(UIKit.stat_row(Project.INDICATOR_NAMES[key], float(indicators.get(key, 0)), UIKit.indicator_color(key)))
		b.add_child(UIKit.label("ROI %.1fx · %s" % [float(result.roi), ServiceSystem.MATCH_NAMES.get(result.get("match", "neutral"), "")], 16, UIKit.match_color(result.get("match", "neutral"))))
		b.add_child(UIKit.separator())
		b.add_child(UIKit.label("O que pesou na nota %d" % int(roundf(float(result.score))), 16, UIKit.COLOR_TEXT))
		for item in result.get("breakdown", []):
			b.add_child(_breakdown_row(item))
		var gap: float = float(result.get("next_gap", 0.0))
		if int(result.stars) < 5 and gap > 0.0:
			b.add_child(UIKit.label("Faltaram %d pontos para %d estrelas." % [ceili(gap), int(result.stars) + 1], 14, UIKit.COLOR_BLUE, true))
		b.add_child(UIKit.separator())
		b.add_child(UIKit.label("+ %s" % UIKit.money(float(result.payment)), 22, UIKit.COLOR_GREEN))
		var rep: float = float(result.rep_delta)
		b.add_child(UIKit.label("%s reputação" % UIKit.signed(rep), 18, UIKit.COLOR_ACCENT if rep >= 0 else UIKit.COLOR_RED))
		if int(result.stars) == 5:
			b.add_child(UIKit.label("+1 case de sucesso", 18, UIKit.COLOR_PURPLE))
		if result.has("press"):
			b.add_child(UIKit.separator())
			b.add_child(UIKit.label(String(result.press), 15, UIKit.COLOR_BLUE, true))
		parts.buttons.add_child(UIKit.button("➡️ Continuar", close, true))
		return parts.panel)


## Linha do detalhamento: rótulo à esquerda, valor colorido à direita.
func _breakdown_row(item: Dictionary) -> HBoxContainer:
	var h := UIKit.hbox()
	var l := UIKit.label(String(item.get("label", "")), 14, UIKit.COLOR_MUTED, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var v := UIKit.number(String(item.get("text", "")), 15, UIKit.COLOR_GREEN if item.get("good", true) else UIKit.COLOR_RED)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.custom_minimum_size.x = 120
	h.add_child(v)
	return h


func show_game_over(reason: String) -> void:
	_open(func():
		var parts := _panel("💀 Fim de jogo")
		parts.body.add_child(UIKit.label(reason, 17, UIKit.COLOR_TEXT, true))
		parts.body.add_child(UIKit.muted("Toda agência tem uma história. A próxima pode ser diferente."))
		parts.buttons.add_child(UIKit.button("🚪 Voltar ao menu", func():
			close()
			get_tree().call_group("main", "show_title"), true))
		return parts.panel)


func show_training(e: Employee) -> void:
	_open(func():
		var parts := _panel("📚 Treinar %s" % e.name.split(" ")[0])
		parts.body.add_child(UIKit.muted("Cursos aumentam atributos. Quem tem mais potencial aproveita melhor."))
		for course in Game.content.courses:
			var card := UIKit.card()
			var v := UIKit.card_content(card)
			v.add_child(UIKit.label(course.name, 18))
			var gains: Array = []
			for key in course.gains:
				gains.append("+%d %s" % [int(course.gains[key]), Employee.ATTR_NAMES[key]])
			v.add_child(UIKit.muted("%s · %d dias · %s" % [UIKit.money(float(course.cost)), int(course.days), ", ".join(gains)], 13))
			var check := Game.employees.can_train(e, course.id)
			var b := UIKit.button("📚 Matricular", func():
				var r := Game.employees.train(e, course.id)
				close()
				if not r.ok:
					show_info("Treinamento", r.reason))
			b.disabled = not check.ok
			v.add_child(b)
			parts.body.add_child(card)
		parts.buttons.add_child(UIKit.button("✖️ Fechar", close))
		return parts.panel)


## Proposta comercial com slider de preço: desconto aumenta a chance, prêmio reduz e eleva a expectativa.
func show_proposal(c: Client) -> void:
	_open(func():
		var parts := _panel("🤝 Proposta para %s" % c.name)
		var b: VBoxContainer = parts.body
		b.add_child(UIKit.muted("%s · %s · Expectativa %s" % [Game.clients.segment_name(c), Game.clients.personality_name(c), c.expectation]))
		b.add_child(UIKit.label("\"%s\"" % c.goal, 16, UIKit.COLOR_TEXT, true))
		b.add_child(UIKit.muted("Orçamento de referência: %s/mês" % UIKit.money(c.budget)))
		b.add_child(UIKit.spacer(4))
		var price_label := UIKit.label("", 20, UIKit.COLOR_GREEN)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(price_label)
		var slider := HSlider.new()
		slider.min_value = ClientSystem.PRICE_MIN * 100.0
		slider.max_value = ClientSystem.PRICE_MAX * 100.0
		slider.step = 5
		slider.value = 100
		slider.custom_minimum_size.y = 44
		b.add_child(slider)
		var ends := UIKit.hbox()
		var lo := UIKit.muted("Barato: fecha fácil")
		lo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ends.add_child(lo)
		var hi := UIKit.muted("Caro: exige mais")
		hi.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ends.add_child(hi)
		b.add_child(ends)
		var chance_label := UIKit.label("", 18, UIKit.COLOR_ACCENT)
		chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(chance_label)
		b.add_child(UIKit.stat_row("Chance", 0.0, UIKit.COLOR_ACCENT, 70))
		var chance_bar: ProgressBar = b.get_child(b.get_child_count() - 1).get_child(1)
		var chance_value: Label = b.get_child(b.get_child_count() - 1).get_child(2)
		var hint := UIKit.muted("", 13)
		b.add_child(hint)
		var send := UIKit.button("📨 Enviar proposta", Callable(), true)
		send.set_meta("tutorial", "send_proposal")
		var refresh := func():
			var factor: float = slider.value / 100.0
			var pct := int(roundf((factor - 1.0) * 100.0))
			price_label.text = "%s/mês (%s%d%%)" % [UIKit.money(Game.clients.proposed_budget(c, factor)), "+" if pct >= 0 else "", pct]
			var chance := Game.clients.proposal_chance(c, factor)
			chance_label.text = "Chance de fechar: %d%%" % int(chance)
			chance_bar.value = chance
			chance_value.text = str(int(chance))
			if factor < 0.9:
				hint.text = "Desconto: fecha mais fácil, mas os projetos rendem menos."
			elif factor > 1.1:
				hint.text = "Prêmio: mais difícil de fechar e o cliente vai esperar entregas melhores."
			else:
				hint.text = "Preço de mercado."
			send.text = "📨 Enviar proposta (%d%%)" % int(chance)
		slider.value_changed.connect(func(_v): refresh.call())
		refresh.call()
		send.pressed.connect(func():
			var factor: float = slider.value / 100.0
			close()
			var r := Game.clients.propose(c, factor)
			if not r.ok:
				show_info("Proposta", r.reason)
			elif r.success:
				show_info("Contrato fechado!", "%s aceitou %s/mês. Faça um diagnóstico ou comece um projeto." % [c.name, UIKit.money(c.budget)])
			else:
				show_info("Ainda não...", "%s não fechou desta vez (chance era %d%%). A cada tentativa a chance cai; um preço menor ajuda." % [c.name, int(r.chance)]))
		parts.buttons.add_child(send)
		parts.buttons.add_child(UIKit.button("✖️ Cancelar", close))
		return parts.panel)


## Escolha de quem vai representar a agência em um evento.
func show_people_picker(ev: Dictionary) -> void:
	_open(func():
		var needed := int(ev.get("people", 0))
		var parts := _panel("🎤 %s: quem vai?" % ev["name"])
		var b: VBoxContainer = parts.body
		b.add_child(UIKit.muted("Escolha %d pessoa%s. Elas ficam fora %d dias." % [needed, "" if needed == 1 else "s", int(ev.get("days", 0))]))
		var chosen: Array = []
		var confirm := UIKit.button("📣 Promover (%s)" % UIKit.money(float(ev.get("cost", 0))), Callable(), true)
		confirm.disabled = true
		for emp in Game.state.available_employees():
			var e: Employee = emp
			var row := UIKit.hbox(10)
			row.add_child(UIKit.portrait(e, 2))
			var t := UIKit.toggle("%s · %s" % [e.name, Game.employees.title(e)], false, Callable())
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			t.toggled.connect(func(on: bool):
				if on:
					if chosen.size() >= needed:
						t.set_pressed_no_signal(false)
						return
					chosen.append(e.id)
				else:
					chosen.erase(e.id)
				confirm.disabled = chosen.size() < needed)
			row.add_child(t)
			b.add_child(row)
		confirm.pressed.connect(func():
			var r := Game.agency_events.run(ev, chosen)
			close()
			if not r.ok:
				show_info("Evento", r.reason))
		parts.buttons.add_child(confirm)
		parts.buttons.add_child(UIKit.button("✖️ Cancelar", close))
		return parts.panel)


## Linha do tempo do colaborador: contratação, cursos, promoções, campanhas, eventos.
func show_journey(e: Employee) -> void:
	_open(func():
		var parts := _panel("🗺️ Jornada de %s" % e.name.split(" ")[0])
		var b: VBoxContainer = parts.body
		var head := UIKit.hbox(12)
		head.add_child(UIKit.portrait(e, 4))
		var info := UIKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIKit.number(e.name, 19, UIKit.COLOR_TEXT))
		info.add_child(UIKit.muted("%s · %s" % [Game.employees.title(e), Game.employees.personality_name(e)]))
		info.add_child(UIKit.muted("Na agência desde %s" % GameState.date_text_for(maxi(e.hired_on, 0)), 13))
		head.add_child(info)
		b.add_child(head)
		b.add_child(UIKit.attr_grid(e))
		b.add_child(UIKit.separator())
		if e.journey.is_empty():
			b.add_child(UIKit.muted("Nenhum marco registrado ainda."))
		var entries: Array = e.journey.duplicate()
		entries.reverse()
		for entry in entries:
			var row := UIKit.hbox(10)
			var date := UIKit.label(GameState.date_text_for(int(entry.get("day", 0))), 13, UIKit.COLOR_MUTED)
			date.custom_minimum_size.x = 96
			row.add_child(date)
			row.add_child(UIKit.label(String(entry.get("text", "")), 15, UIKit.COLOR_TEXT, true))
			b.add_child(row)
		parts.buttons.add_child(UIKit.button("✖️ Fechar", close, true))
		return parts.panel)


func show_new_project(c: Client) -> void:
	_open(func(): return NewProjectDialog.new(c, self))
