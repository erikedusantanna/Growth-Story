class_name CompanyScreen
extends BaseScreen
## Empresa: finanças, escritório, estatísticas, save e menu.


func build() -> void:
	var st: GameState = Game.state
	content.add_child(header("🏢 %s" % st.agency_name, Game.reputation.phase_name()))

	var fin := UIKit.card()
	var fv := UIKit.card_content(fin)
	fv.add_child(UIKit.label("💰 Finanças", 19, UIKit.COLOR_ACCENT))
	fv.add_child(_row("Caixa", UIKit.money(st.money), UIKit.COLOR_GREEN if st.money >= 0 else UIKit.COLOR_RED))
	fv.add_child(_row("MRR (retainers)", UIKit.money(st.mrr())))
	fv.add_child(_row("Receita no mês", UIKit.money(st.month_revenue)))
	fv.add_child(_row("Despesas no mês", UIKit.money(st.month_expenses)))
	var costs := Game.finance.monthly_costs()
	fv.add_child(_row("Custo fixo mensal", UIKit.money(costs.total), UIKit.COLOR_RED))
	fv.add_child(UIKit.muted("Salários %s · Aluguel %s · Ferramentas %s%s" % [UIKit.money(costs.salaries), UIKit.money(costs.rent), UIKit.money(costs.tools),
		(" · RH %s" % UIKit.money(costs.hr)) if costs.hr > 0.0 else ""], 13))
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
	rv.add_child(UIKit.label("⭐ Reputação", 19, UIKit.COLOR_ACCENT))
	rv.add_child(UIKit.stat_row(Game.reputation.tier_name(), st.reputation, UIKit.COLOR_ACCENT, 190))
	rv.add_child(UIKit.muted("Reputação maior atrai clientes de tiers mais altos e candidatos melhores.", 13))
	rv.add_child(UIKit.label("Como ganhar: 3 estrelas ou mais em campanhas. Diagnóstico, combinação perfeita, especialistas na equipe e entrega no prazo somam pontos na nota. 1 estrela tira reputação.", 13, UIKit.COLOR_TEXT, true))
	content.add_child(rep)

	var office := Game.office.current()
	var oc := UIKit.card()
	var ov := UIKit.card_content(oc)
	ov.add_child(UIKit.label("🏢 Escritório", 19, UIKit.COLOR_ACCENT))
	ov.add_child(_row(office.get("name", ""), "%d/%d pessoas" % [st.employees.size(), Game.office.capacity()]))
	ov.add_child(_row("Aluguel", UIKit.money(Game.office.rent())))
	var nxt := Game.office.next_level()
	if not nxt.is_empty():
		var check := Game.office.can_upgrade()
		ov.add_child(UIKit.muted("Próximo: %s · %d lugares · %s · aluguel %s/mês" % [nxt.name, int(nxt.capacity), UIKit.money(float(nxt.upgrade_cost)), UIKit.money(float(nxt.rent))], 13))
		var b := UIKit.button("🏗️ Mudar para %s" % nxt.name, func(): Game.office.upgrade(), true)
		b.disabled = not check.ok
		ov.add_child(b)
		if not check.ok:
			ov.add_child(UIKit.label(check.reason, 13, UIKit.COLOR_RED))
	content.add_child(oc)

	var fc := UIKit.card()
	var fcv := UIKit.card_content(fc)
	var fx := Game.office.furniture_effects()
	fcv.add_child(UIKit.label("🛋️ Mobília", 19, UIKit.COLOR_ACCENT))
	fcv.add_child(UIKit.muted("Teto de moral %d · estresse ×%.2f · produtividade ×%.2f · moral diária +%.2f" % [int(fx["morale_max"]), float(fx["stress_rate"]), float(fx["productivity"]), float(fx["morale_daily"])], 13))
	for f in Game.office.furniture_items():
		fcv.add_child(_furniture_row(f))
	content.add_child(fc)

	var stats := UIKit.card()
	var sv := UIKit.card_content(stats)
	sv.add_child(UIKit.label("📊 Números", 19, UIKit.COLOR_ACCENT))
	sv.add_child(_row("Ano de jogo", "%d (%d)" % [st.game_year(), st.year()]))
	sv.add_child(_row("Era do mercado", String(Game.era.current().get("name", "")), UIKit.COLOR_ACCENT))
	sv.add_child(_row("Campanhas entregues", str(int(st.stats.projects_done))))
	sv.add_child(_row("Cases de sucesso (5 estrelas)", str(st.cases)))
	sv.add_child(_row("Clientes fechados", str(int(st.stats.clients_signed))))
	sv.add_child(_row("Contratações", str(int(st.stats.hires))))
	sv.add_child(_row("Receita acumulada", UIKit.money(float(st.stats.total_revenue))))
	content.add_child(stats)

	var sound := UIKit.card()
	var soundv := UIKit.card_content(sound)
	soundv.add_child(UIKit.label("🔊 Som", 19, UIKit.COLOR_ACCENT))
	var sound_row := UIKit.hbox()
	sound_row.add_child(UIKit.toggle("🎵 Música", Audio.music_enabled, func(on): Audio.set_music_enabled(on)))
	sound_row.add_child(UIKit.toggle("🔊 Efeitos", Audio.sfx_enabled, func(on): Audio.set_sfx_enabled(on)))
	soundv.add_child(sound_row)
	content.add_child(sound)

	var actions := UIKit.hbox()
	actions.add_child(UIKit.button("💾 Salvar jogo", func():
		if Game.save_game():
			popups().show_info("Salvo", "Partida salva. O jogo também salva sozinho todo mês.")))
	actions.add_child(UIKit.button("🚪 Menu", func(): get_tree().call_group("main", "show_title")))
	content.add_child(actions)


func _furniture_row(f: Dictionary) -> VBoxContainer:
	var v := UIKit.vbox(2)
	var top := UIKit.hbox()
	var owned := Game.office.owns(f["id"])
	var name := UIKit.label(String(f["name"]), 16, UIKit.COLOR_TEXT if not owned else UIKit.COLOR_GREEN)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	if owned:
		top.add_child(UIKit.label("comprado", 13, UIKit.COLOR_GREEN))
	else:
		var check := Game.office.can_buy(f)
		var b := UIKit.button(UIKit.money(float(f.get("cost", 0))), func():
			var r := Game.office.buy(f)
			if not r.ok:
				popups().show_info("Mobília", r.reason), false, 36)
		b.size_flags_horizontal = 0
		b.custom_minimum_size.x = 110
		b.disabled = not check.ok
		b.tooltip_text = check.reason
		top.add_child(b)
	v.add_child(top)
	v.add_child(UIKit.muted(String(f.get("desc", "")), 13))
	if not owned:
		var check2 := Game.office.can_buy(f)
		if not check2.ok and check2.reason != "Caixa insuficiente.":
			v.add_child(UIKit.label(check2.reason, 12, UIKit.COLOR_RED))
	return v


func _row(left: String, right: String, color: Color = UIKit.COLOR_TEXT) -> HBoxContainer:
	var h := UIKit.hbox()
	var l := UIKit.label(left, 15, UIKit.COLOR_MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var r := UIKit.label(right, 15, color)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(r)
	return h
