class_name TeamScreen
extends BaseScreen
## Equipe: funcionários, treinamento, demissão e candidatos.


func build() -> void:
	var st: GameState = Game.state
	content.add_child(header("Equipe", "%d/%d lugares" % [st.employees.size(), Game.office.capacity()]))
	for e in st.employees:
		content.add_child(_employee_card(e))
	content.add_child(UIKit.spacer(4))
	content.add_child(header("Candidatos", "%d disponíveis" % st.candidates.size()))
	if st.candidates.is_empty():
		content.add_child(UIKit.muted("Nenhum candidato no momento. Novos currículos chegam todo mês."))
	for c in st.candidates:
		content.add_child(_candidate_card(c))


func _employee_card(e: Employee) -> PanelContainer:
	var st: GameState = Game.state
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	var top := UIKit.hbox()
	var name := UIKit.label(e.name, 20, Color(e.color).lightened(0.35))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	top.add_child(UIKit.label(Game.employees.personality_name(e), 14, UIKit.COLOR_MUTED))
	v.add_child(top)
	var status := e.is_busy_reason(st.day)
	var status_color := UIKit.COLOR_GREEN if status == "Livre" else (UIKit.COLOR_RED if status == "Burnout" else UIKit.COLOR_ACCENT)
	var sub := UIKit.hbox()
	var title := UIKit.label(Game.employees.title(e), 15, UIKit.COLOR_MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.add_child(title)
	sub.add_child(UIKit.label(status, 15, status_color))
	v.add_child(sub)
	v.add_child(UIKit.attr_grid(e))
	var meta := UIKit.hbox(14)
	meta.add_child(UIKit.label("Motivação %d" % int(e.motivation), 14, UIKit.COLOR_MUTED))
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
	var top := UIKit.hbox()
	var name := UIKit.label(c.name, 20)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	top.add_child(UIKit.label(Game.employees.personality_name(c), 14, UIKit.COLOR_MUTED))
	v.add_child(top)
	v.add_child(UIKit.muted("%s · %d anos" % [Game.employees.title(c), c.age]))
	v.add_child(UIKit.muted(Game.content.personalities.get(c.personality, {}).get("desc", ""), 13))
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
