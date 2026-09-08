class_name TeamScreen
extends BaseScreen
## Equipe: funcionários, treinamento, demissão e candidatos.


func build() -> void:
	var st: GameState = Game.state
	content.add_child(header("Equipe", "%d/%d lugares · moral média %d" % [st.employees.size(), Game.office.capacity(), int(Game.employees.morale_average())]))
	content.add_child(_office_banner())
	for e in st.employees:
		content.add_child(_employee_card(e))
	content.add_child(UIKit.spacer(4))
	content.add_child(header("Candidatos", "%d disponíveis" % st.candidates.size()))
	if st.candidates.is_empty():
		content.add_child(UIKit.muted("Nenhum candidato no momento. Novos currículos chegam todo mês."))
	for c in st.candidates:
		content.add_child(_candidate_card(c))


## Faixa do escritório: mostra lotação e o caminho para ampliar sem precisar achar a aba Empresa.
func _office_banner() -> PanelContainer:
	var st: GameState = Game.state
	var office := Game.office.current()
	var full: bool = st.employees.size() >= Game.office.capacity()
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	var top := UIKit.hbox()
	var name := UIKit.label("%s · %d/%d lugares" % [office.get("name", ""), st.employees.size(), Game.office.capacity()], 16, UIKit.COLOR_RED if full else UIKit.COLOR_MUTED)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	v.add_child(top)
	var nxt := Game.office.next_level()
	if nxt.is_empty():
		v.add_child(UIKit.muted("Você já está no maior escritório disponível.", 13))
		return card
	if full:
		v.add_child(UIKit.label("Escritório lotado. Amplie para contratar mais gente.", 14, UIKit.COLOR_RED, true))
	var check := Game.office.can_upgrade()
	v.add_child(UIKit.muted("Próximo: %s · %d lugares · rep %d" % [nxt.name, int(nxt.capacity), int(nxt.rep_required)], 13))
	var b := UIKit.button("Ampliar por %s" % UIKit.money(float(nxt.upgrade_cost)), func():
		if Game.office.upgrade():
			popups().show_info("Mudança feita!", "A agência agora está em %s. Cabem %d pessoas. O aluguel passa a %s/mês." % [nxt.name, int(nxt.capacity), UIKit.money(float(nxt.rent) * Game.state.rent_modifier)]), full)
	b.disabled = not check.ok
	v.add_child(b)
	if not check.ok:
		v.add_child(UIKit.label(check.reason, 13, UIKit.COLOR_RED))
	else:
		v.add_child(UIKit.muted("Aluguel passa a %s/mês." % UIKit.money(float(nxt.rent) * st.rent_modifier), 13))
	return card


func _employee_card(e: Employee) -> PanelContainer:
	var st: GameState = Game.state
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	var status := e.is_busy_reason(st.day)
	var status_color := UIKit.COLOR_GREEN if status == "Livre" else (UIKit.COLOR_RED if status == "Burnout" else UIKit.COLOR_ACCENT)
	v.add_child(_person_header(e, status, status_color))
	v.add_child(UIKit.attr_grid(e))
	var morale_row := UIKit.stat_row("Moral", e.motivation, UIKit.COLOR_GREEN if e.motivation >= 50 else UIKit.COLOR_RED, 60)
	var morale_bar: ProgressBar = morale_row.get_child(1)
	morale_bar.max_value = Game.office.morale_max()
	v.add_child(morale_row)
	var meta := UIKit.hbox(14)
	meta.add_child(UIKit.label("Teto de moral %d" % int(Game.office.morale_max()), 14, UIKit.COLOR_MUTED))
	meta.add_child(UIKit.label("Estresse %d" % int(e.stress), 14, UIKit.COLOR_RED if e.stress > 70 else UIKit.COLOR_MUTED))
	meta.add_child(UIKit.label("Potencial", 14, UIKit.COLOR_MUTED))
	meta.add_child(UIKit.star_row(e.potential, 2))
	v.add_child(meta)
	var meta2 := UIKit.hbox(14)
	meta2.add_child(UIKit.label("Salário %s/mês" % UIKit.money(e.salary), 14, UIKit.COLOR_MUTED))
	meta2.add_child(UIKit.label("XP %d" % int(e.experience), 14, UIKit.COLOR_MUTED))
	v.add_child(meta2)
	var actions := UIKit.hbox()
	var train := UIKit.button("Treinar", func(): popups().show_training(e))
	train.disabled = not e.is_available(st.day)
	actions.add_child(train)
	actions.add_child(UIKit.button("Jornada", func(): popups().show_journey(e)))
	if not e.is_founder:
		actions.add_child(UIKit.button("Demitir", func(): _confirm_fire(e)))
	v.add_child(actions)
	return card


## Retrato + nome em negrito + cargo + personalidade, como o cartão das referências.
func _person_header(e: Employee, right_text: String, right_color: Color) -> HBoxContainer:
	var h := UIKit.hbox(12)
	h.add_child(UIKit.portrait(e, 4))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UIKit.hbox()
	var name := UIKit.number(e.name, 19, UIKit.COLOR_TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name)
	top.add_child(UIKit.label(right_text, 14, right_color))
	v.add_child(top)
	v.add_child(UIKit.label(Game.employees.title(e), 15, UIKit.COLOR_MUTED))
	v.add_child(UIKit.label("%s · %s" % [Game.employees.personality_name(e), Game.content.personalities.get(e.personality, {}).get("desc", "")], 13, UIKit.COLOR_BLUE, true))
	h.add_child(v)
	return h


func _confirm_fire(e: Employee) -> void:
	popups().show_choice("Demitir %s?" % e.name,
		"A rescisão custa um salário (%s). A equipe pode perder motivação." % UIKit.money(e.salary),
		["Demitir", "Cancelar"],
		func(i: int):
			if i == 0:
				Game.employees.fire(e)
				for other in Game.state.employees:
					other.motivation = clampf(other.motivation - 4.0, 0.0, 100.0))


func _candidate_card(c: Employee) -> PanelContainer:
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	v.add_child(_person_header(c, "%d anos" % c.age, UIKit.COLOR_MUTED))
	v.add_child(UIKit.attr_grid(c))
	var meta := UIKit.hbox(14)
	meta.add_child(UIKit.label("Salário %s/mês" % UIKit.money(c.salary), 15, UIKit.COLOR_GREEN))
	meta.add_child(UIKit.label("Potencial", 14, UIKit.COLOR_MUTED))
	meta.add_child(UIKit.star_row(c.potential, 2))
	v.add_child(meta)
	v.add_child(UIKit.muted("Sai da lista em %d dias" % maxi(0, c.candidate_expires - Game.state.day), 13))
	var actions := UIKit.hbox()
	var check := Game.employees.can_hire(c)
	var hire := UIKit.button("Contratar", func():
		var r := Game.employees.hire(c)
		if not r.ok:
			popups().show_info("Não foi possível contratar", r.reason), true)
	hire.disabled = not check.ok
	hire.tooltip_text = check.reason
	actions.add_child(hire)
	actions.add_child(UIKit.button("Recusar", func(): Game.employees.decline(c)))
	v.add_child(actions)
	if not check.ok:
		v.add_child(UIKit.label(check.reason, 13, UIKit.COLOR_RED))
	return card
