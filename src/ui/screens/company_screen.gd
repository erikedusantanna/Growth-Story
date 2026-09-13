class_name CompanyScreen
extends BaseScreen
## Empresa: foco do mês, agenda, finanças, escritório, estatísticas, save e menu.
##
## O foco e a agenda vieram da tela de calendário, que foi cortada: era uma tela inteira para duas
## coisas que se usam de relance, e a grade de 12 meses ninguém abria duas vezes.


func build() -> void:
	var st: GameState = Game.state
	content.add_child(header("🏢 %s" % st.agency_name, Game.reputation.phase_name()))
	content.add_child(_focus_card())
	content.add_child(_agenda_card())

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
	sv.add_child(_row("Prêmios do Marketing", str(Game.awards.won_count())))
	content.add_child(stats)

	var aw := UIKit.card()
	var av := UIKit.card_content(aw)
	av.add_child(UIKit.label("🏆 Prêmios do Marketing", 19, UIKit.COLOR_ACCENT))
	av.add_child(UIKit.muted("Cerimônia todo fim de ano: Campanha, Agência e Profissional do Ano. Agência do Ano exige %d pontos este ano (entregas ×3, cases de 5 estrelas ×10, clientes ativos ×2, reputação ×0,5); você tem %d." % [int(Game.awards.agency_threshold(st.year())), int(Game.awards.agency_score(st.year()))], 13))
	if st.awards.is_empty():
		av.add_child(UIKit.muted("Nenhuma cerimônia ainda. A primeira é na virada do ano.", 13))
	var shown := 0
	for i in range(st.awards.size() - 1, -1, -1):
		var a: Dictionary = st.awards[i]
		if String(a.get("status", "")) == "lost":
			continue
		var cat: Dictionary = AwardSystem.CATEGORIES.get(String(a.get("category", "")), {})
		var won: bool = String(a.get("status", "")) == "won"
		av.add_child(_row("%s %s %d" % [String(cat.get("icon", "")), String(cat.get("name", "")), int(a.get("year", 0))],
			"Vencedora" if won else "Indicada", UIKit.COLOR_GOLD if won else UIKit.COLOR_MUTED))
		shown += 1
		if shown >= 9:
			break
	content.add_child(aw)

	var sound := UIKit.card()
	var soundv := UIKit.card_content(sound)
	soundv.add_child(UIKit.label("🔊 Som", 19, UIKit.COLOR_ACCENT))
	var sound_row := UIKit.hbox()
	sound_row.add_child(UIKit.toggle("🎵 Música", Audio.music_enabled, func(on): Audio.set_music_enabled(on)))
	sound_row.add_child(UIKit.toggle("🔊 Efeitos", Audio.sfx_enabled, func(on): Audio.set_sfx_enabled(on)))
	sound_row.add_child(UIKit.toggle("🏢 Escritório", Audio.ambience_enabled, func(on): Audio.set_ambience_enabled(on)))
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


## Foco do mês: uma prioridade por mês, escolhida uma única vez. Era o que a tela de calendário
## tinha de mais útil, então veio para cá, no topo da aba.
func _focus_card() -> PanelContainer:
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	var current: Dictionary = Game.calendar.focus()
	if current.is_empty():
		v.add_child(UIKit.label("🎯 Foco do mês", 19, UIKit.COLOR_ACCENT))
		v.add_child(UIKit.muted("Escolha uma prioridade para este mês. Vale até a virada do mês e só dá para escolher uma vez.", 13))
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
					popups().show_info("Foco do mês", r.reason), true, 38)
			b.size_flags_horizontal = 0
			b.custom_minimum_size.x = 106
			row.add_child(b)
			v.add_child(row)
	else:
		v.add_child(UIKit.label("%s %s" % [String(current.get("icon", "🎯")), String(current.get("name", ""))], 19, UIKit.COLOR_ACCENT))
		v.add_child(UIKit.label(String(current.get("desc", "")), 14, UIKit.COLOR_TEXT, true))
		var left: int = GameState.DAYS_PER_MONTH - Game.state.day_of_month()
		v.add_child(UIKit.muted("Vale por mais %d dia(s), até a virada do mês." % maxi(left, 0), 13))
	return card


## Agenda curta: só o que está próximo. A lista longa da tela de calendário virava ruído.
func _agenda_card() -> PanelContainer:
	var st: GameState = Game.state
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	v.add_child(UIKit.label("⏳ O que vem pela frente", 19, UIKit.COLOR_ACCENT))
	var items: Array = Game.calendar.upcoming(45)
	if items.is_empty():
		v.add_child(UIKit.muted("Nada marcado para os próximos dias."))
		return card
	for item in items.slice(0, 5):
		var day: int = int(item["day"])
		var days_left: int = day - st.day
		var row := UIKit.hbox(8)
		var title := UIKit.label("%s %s" % [String(item.get("icon", "•")), String(item.get("title", ""))], 14, UIKit.COLOR_TEXT)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.clip_text = true
		row.add_child(title)
		var when := UIKit.label("hoje" if days_left <= 0 else "em %d d" % days_left, 13,
			UIKit.COLOR_RED if days_left <= 3 else UIKit.COLOR_MUTED)
		when.size_flags_horizontal = 0
		row.add_child(when)
		v.add_child(row)
	# o presente de aniversário de contrato era a única ação da agenda; continua aqui
	for c in st.active_clients():
		var check: Dictionary = Game.calendar.can_send_gift(c)
		if not check.ok:
			continue
		var client: Client = c
		var gift := UIKit.button("🎁 Presente de aniversário: %s (%s)" % [c.name, UIKit.money(Game.calendar.gift_cost(c))], func():
			var r: Dictionary = Game.calendar.send_gift(client)
			if not r.ok:
				popups().show_info("Presente", r.reason), true, 40)
		v.add_child(gift)
	return card
