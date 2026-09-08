class_name CompanyScreen
extends BaseScreen
## Empresa: finanças, escritório, estatísticas, save e menu.


func build() -> void:
	var st: GameState = Game.state
	content.add_child(header(st.agency_name, Game.reputation.phase_name()))

	var fin := UIKit.card()
	var fv := UIKit.card_content(fin)
	fv.add_child(UIKit.label("Finanças", 19, UIKit.COLOR_ACCENT))
	fv.add_child(_row("Caixa", UIKit.money(st.money), UIKit.COLOR_GREEN if st.money >= 0 else UIKit.COLOR_RED))
	fv.add_child(_row("MRR (retainers)", UIKit.money(st.mrr())))
	fv.add_child(_row("Receita no mês", UIKit.money(st.month_revenue)))
	fv.add_child(_row("Despesas no mês", UIKit.money(st.month_expenses)))
	var costs := Game.finance.monthly_costs()
	fv.add_child(_row("Custo fixo mensal", UIKit.money(costs.total), UIKit.COLOR_RED))
	fv.add_child(UIKit.muted("Salários %s · Aluguel %s · Ferramentas %s" % [UIKit.money(costs.salaries), UIKit.money(costs.rent), UIKit.money(costs.tools)], 13))
	if not st.finance_history.is_empty():
		fv.add_child(UIKit.spacer(2))
		fv.add_child(UIKit.muted("Últimos meses (receita / despesa)", 13))
		var recent: Array = st.finance_history.slice(maxi(st.finance_history.size() - 6, 0), st.finance_history.size())
		for h in recent:
			var mi := int(h.get("month_index", 0))
			var label := "%s %d" % [GameState.MONTH_NAMES[mi % 12], GameState.START_YEAR + mi / 12]
			var rev := float(h.get("revenue", 0))
			var exp := float(h.get("expenses", 0))
			fv.add_child(_row(label, "%s / %s" % [UIKit.money(rev), UIKit.money(exp)], UIKit.COLOR_GREEN if rev >= exp else UIKit.COLOR_RED))
	content.add_child(fin)

	var rep := UIKit.card()
	var rv := UIKit.card_content(rep)
	rv.add_child(UIKit.label("Reputação", 19, UIKit.COLOR_ACCENT))
	rv.add_child(UIKit.stat_row(Game.reputation.tier_name(), st.reputation, UIKit.COLOR_ACCENT, 190))
	rv.add_child(UIKit.muted("Reputação maior atrai clientes de tiers mais altos e candidatos melhores.", 13))
	rv.add_child(UIKit.label("Como ganhar: 3 estrelas ou mais em campanhas. Diagnóstico, combinação perfeita, especialistas na equipe e entrega no prazo somam pontos na nota. 1 estrela tira reputação.", 13, UIKit.COLOR_TEXT, true))
	content.add_child(rep)

	var office := Game.office.current()
	var oc := UIKit.card()
	var ov := UIKit.card_content(oc)
	ov.add_child(UIKit.label("Escritório", 19, UIKit.COLOR_ACCENT))
	ov.add_child(_row(office.get("name", ""), "%d/%d pessoas" % [st.employees.size(), Game.office.capacity()]))
	ov.add_child(_row("Aluguel", UIKit.money(Game.office.rent())))
	var nxt := Game.office.next_level()
	if not nxt.is_empty():
		var check := Game.office.can_upgrade()
		ov.add_child(UIKit.muted("Próximo: %s · %d lugares · %s · aluguel %s/mês" % [nxt.name, int(nxt.capacity), UIKit.money(float(nxt.upgrade_cost)), UIKit.money(float(nxt.rent))], 13))
		var b := UIKit.button("Mudar para %s" % nxt.name, func(): Game.office.upgrade(), true)
		b.disabled = not check.ok
		ov.add_child(b)
		if not check.ok:
			ov.add_child(UIKit.label(check.reason, 13, UIKit.COLOR_RED))
	content.add_child(oc)

	var stats := UIKit.card()
	var sv := UIKit.card_content(stats)
	sv.add_child(UIKit.label("Números", 19, UIKit.COLOR_ACCENT))
	sv.add_child(_row("Ano de jogo", "%d (%d)" % [st.game_year(), st.year()]))
	sv.add_child(_row("Campanhas entregues", str(int(st.stats.projects_done))))
	sv.add_child(_row("Cases de sucesso (5 estrelas)", str(st.cases)))
	sv.add_child(_row("Clientes fechados", str(int(st.stats.clients_signed))))
	sv.add_child(_row("Contratações", str(int(st.stats.hires))))
	sv.add_child(_row("Receita acumulada", UIKit.money(float(st.stats.total_revenue))))
	content.add_child(stats)

	var actions := UIKit.hbox()
	actions.add_child(UIKit.button("Salvar jogo", func():
		if Game.save_game():
			popups().show_info("Salvo", "Partida salva. O jogo também salva sozinho todo mês.")))
	actions.add_child(UIKit.button("Menu", func(): get_tree().call_group("main", "show_title")))
	content.add_child(actions)


func _row(left: String, right: String, color: Color = UIKit.COLOR_TEXT) -> HBoxContainer:
	var h := UIKit.hbox()
	var l := UIKit.label(left, 15, UIKit.COLOR_MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var r := UIKit.label(right, 15, color)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(r)
	return h
