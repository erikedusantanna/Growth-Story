extends Node
## Teste de simulação headless.
## Uso: godot --headless --path . res://tests/sim_test.tscn
## Roda alguns anos de jogo com uma política automática e verifica invariantes.

var failures := 0
var completed := 0
var year_report: Array = []
var stars_hist := [0, 0, 0, 0, 0, 0]


func _ready() -> void:
	var game = Game
	game.manual_time = true
	var sim_seed: int = int(OS.get_environment("SIM_SEED")) if OS.has_environment("SIM_SEED") else 12345
	_run_simulation(game, sim_seed, 3)
	_test_save_roundtrip(game)
	_test_scoring(game)
	_test_hr_furniture_events(game)
	_test_audio(game)
	_test_era(game)
	_test_departments(game)
	_test_competitors(game)
	_test_office_life(game)
	_test_briefings_chemistry_awards(game)
	_test_morale_moods(game)
	_test_regions(game)
	_test_rivals(game)
	_test_region_content(game)
	_test_service_fit(game)
	_test_quests(game)
	_test_news(game)
	_test_calendar(game)
	_test_paid_media(game)
	_test_pets(game)
	_test_specialization(game)
	_test_decisions(game)
	_test_market_trends(game)
	_test_quest_arcs(game)
	_test_talent(game)
	_test_crisis(game)
	_test_save_slots(game)
	if failures == 0:
		print("\n[OK] Todos os testes passaram.")
		get_tree().quit(0)
	else:
		print("\n[FALHA] %d verificação(ões) falharam." % failures)
		get_tree().quit(1)


func _test_service_fit(game) -> void:
	print("== Atributos por serviço ==")
	game.new_game("Perfil", "Chefe", 31)
	var st = game.state
	var w_traffic: Dictionary = game.projects.indicator_weights(["paid_traffic"])
	var w_design: Dictionary = game.projects.indicator_weights(["design"])
	check(float(w_traffic["performance"]) > float(w_design["performance"]), "tráfego pago pesa mais Performance que design (%.2f vs %.2f)" % [w_traffic["performance"], w_design["performance"]])
	check(float(w_design["creativity"]) > float(w_traffic["creativity"]), "design pesa mais Criatividade que tráfego pago (%.2f vs %.2f)" % [w_design["creativity"], w_traffic["creativity"]])
	check(game.projects.key_attrs(["paid_traffic"], 1) == ["performance"], "atributo-chave do tráfego pago é Performance")
	check(game.projects.key_attrs(["design"], 1) == ["creativity"], "atributo-chave do design é Criatividade")
	# duas equipes iguais, menos no atributo que o serviço pede
	var c = game.clients.spawn_prospect()
	c.status = Client.Status.ACTIVE
	c.difficulty = 1
	var specialist: Employee = game.employees.generate_candidate("normal")
	var wrong: Employee = game.employees.generate_candidate("normal")
	for key in Employee.ATTRS:
		specialist.attrs[key] = 45.0
		wrong.attrs[key] = 45.0
	specialist.attrs["performance"] = 90.0
	specialist.attrs["technology"] = 80.0
	wrong.attrs["creativity"] = 90.0
	specialist.motivation = 60.0
	wrong.motivation = 60.0
	st.employees.append(specialist)
	st.employees.append(wrong)
	var p_fit: Dictionary = game.projects.predict(c, ["paid_traffic"], [specialist.id], Project.Kind.PROJECT)
	var p_off: Dictionary = game.projects.predict(c, ["paid_traffic"], [wrong.id], Project.Kind.PROJECT)
	check(float(p_fit.score) > float(p_off.score) + 5.0, "no tráfego pago quem tem Performance entrega bem mais (%.0f vs %.0f)" % [p_fit.score, p_off.score])
	var d_fit: Dictionary = game.projects.predict(c, ["design"], [wrong.id], Project.Kind.PROJECT)
	var d_off: Dictionary = game.projects.predict(c, ["design"], [specialist.id], Project.Kind.PROJECT)
	check(float(d_fit.score) > float(d_off.score) + 5.0, "no design quem tem Criatividade entrega bem mais (%.0f vs %.0f)" % [d_fit.score, d_off.score])
	var best: Array = game.employees.best_services(specialist, 1)
	check(best.has("paid_traffic"), "a ficha aponta tráfego pago para quem tem Performance (%s)" % str(best))


func _test_quests(game) -> void:
	print("== Missões ==")
	game.new_game("Missões", "Chefe", 44)
	var st = game.state
	st.day = 60
	var q: Dictionary = game.quests.start("dois_projetos")
	check(not q.is_empty() and game.quests.active().size() == 1, "missão começou")
	check(game.quests.days_left(q) > 0 and not game.quests.is_done(q), "missão tem prazo e ainda não está cumprida")
	var money_before: float = st.money
	var rep_before: float = st.reputation
	st.stats["projects_done"] = int(st.stats.get("projects_done", 0)) + 2
	game.quests.check()
	check(game.quests.active().is_empty(), "missão cumprida sai da lista")
	check(st.money > money_before and st.reputation > rep_before, "missão cumprida paga dinheiro e reputação")
	check(int(st.stats.get("quests_done", 0)) == 1, "estatística de missões conta a cumprida")
	# perder o prazo custa reputação
	st.day = 200
	var q2: Dictionary = game.quests.start("dois_projetos")
	check(not q2.is_empty(), "missão nova depois do cooldown")
	var rep2: float = st.reputation
	st.day = int(q2.deadline_day)
	game.quests.on_day()
	check(game.quests.active().is_empty(), "missão vencida sai da lista")
	check(st.reputation < rep2, "perder o prazo custa reputação (%.1f → %.1f)" % [rep2, st.reputation])
	# entrega com estrelas
	st.day = 400
	var q3: Dictionary = game.quests.start("entrega_4")
	game.quests._on_project_completed(null, {"stars": 5})
	check(game.quests.active().is_empty(), "entrega 5★ cumpre a missão de 4★")
	# sobrevive ao save
	st.day = 600
	game.quests.start("dois_projetos")
	check(game.save.save(st), "salvou com missão ativa")
	var loaded = game.save.load_state()
	check(loaded != null and loaded.quests.size() == 1, "missão ativa sobrevive ao save")


func _test_news(game) -> void:
	print("== Notícias ==")
	game.new_game("Notícias", "Chefe", 45)
	var st = game.state
	check(game.news.all().size() >= 20, "banca tem %d manchetes" % game.news.all().size())
	var published: Array = []
	EventBus.news_published.connect(func(n): published.append(n))
	var n: Dictionary = game.news.publish("b4_pivot")
	check(not n.is_empty() and published.size() == 1, "notícia publicada avisa a interface")
	check(st.news_feed.size() == 1 and String(st.news_feed[0].id) == "b4_pivot", "notícia entra na banca")
	check(game.news.outlet(n) != "", "notícia tem veículo (%s)" % game.news.outlet(n))
	var rep_before: float = st.reputation
	game.news.publish("algoritmo_muda")
	check(st.reputation < rep_before, "notícia com efeito declarado mexe no jogo")
	var ids := {}
	for item in game.news.all():
		check(not ids.has(String(item.id)), "id de notícia único: %s" % String(item.id))
		ids[String(item.id)] = true
		check(FileAccess.file_exists("res://assets/art/news/%s.png" % String(item.get("art", ""))), "ilustração existe para %s" % String(item.id))


func _test_calendar(game) -> void:
	print("== Calendário e agenda ==")
	game.new_game("Agenda", "Chefe", 46)
	var st = game.state
	st.money = 200000.0
	check(game.calendar.focus().is_empty(), "mês começa sem foco")
	check(game.calendar.set_focus("caixa").ok, "foco do mês escolhido")
	check(game.calendar.has_focus("caixa"), "foco em caixa ativo")
	check(not game.calendar.set_focus("vendas").ok, "só um foco por mês")
	var costs_focus: float = float(game.finance.monthly_costs().total)
	st.focus = {}
	var costs_plain: float = float(game.finance.monthly_costs().total)
	check(costs_focus < costs_plain, "foco em caixa baixa o custo do mês (%s < %s)" % [FinanceSystem.format_money(costs_focus), FinanceSystem.format_money(costs_plain)])
	check(game.calendar.month_markers().size() == 12, "grade mostra 12 meses")
	var items: Array = game.calendar.upcoming(120)
	check(items.size() >= 3, "agenda lista o que vem pela frente (%d itens)" % items.size())
	var kinds: Array = items.map(func(i): return String(i.kind))
	check(kinds.has("money"), "fechamento do mês está na agenda")
	var sorted_ok := true
	for i in range(1, items.size()):
		if int(items[i].day) < int(items[i - 1].day):
			sorted_ok = false
	check(sorted_ok, "agenda vem em ordem de data")
	# aniversário de contrato e presente
	var c = game.clients.spawn_prospect()
	c.status = Client.Status.ACTIVE
	c.known_on = 0
	c.relationship = 40.0
	st.day = 360
	check(game.calendar.anniversary_day(c) == 360, "aniversário de contrato cai 1 ano depois")
	check(game.calendar.can_send_gift(c).ok, "dá para mandar presente na semana do aniversário")
	check(game.calendar.send_gift(c).ok and c.relationship > 40.0, "presente melhora a relação (%.0f)" % c.relationship)
	check(not game.calendar.can_send_gift(c).ok, "só um presente por aniversário")


func _test_paid_media(game) -> void:
	print("== Mídia paga ==")
	game.new_game("Mídia", "Chefe", 47)
	var st = game.state
	st.money = 100000.0
	var before: int = st.prospects().size()
	check(game.clients.start_campaign("boost").ok, "campanha contratada")
	check(game.clients.pending_leads() >= 1 and st.money < 100000.0, "lead a caminho e campanha cobrada")
	var guard := 0
	while game.clients.pending_leads() > 0 and guard < 30:
		st.day += 1
		game.clients.on_day()
		guard += 1
	check(st.prospects().size() > before, "lead da mídia paga virou prospect")
	var paid_found := false
	for c in st.prospects():
		if c.paid:
			paid_found = true
	check(paid_found, "prospect pago vem marcado")
	check(int(st.stats.get("campaigns", 0)) == 1, "estatística de campanhas conta")
	st.money = 100.0
	check(not game.clients.can_start_campaign(game.clients.campaign_by_id("launch")).ok, "sem caixa não dá para comprar mídia")


func _test_pets(game) -> void:
	print("== Pets ==")
	game.new_game("Pets", "Chefe", 48)
	var st = game.state
	var kinds: Array = []
	for a in game.hr.actions():
		if a.has("pet"):
			kinds.append(String(a["pet"]))
			check(FileAccess.file_exists("res://assets/art/furniture/%s.png" % String(a["pet"])), "sprite do pet %s existe" % String(a["pet"]))
			check(Pet.SPEED.has(String(a["pet"])), "pet %s tem velocidade definida" % String(a["pet"]))
	check(kinds.size() == 6, "seis pets disponíveis (%s)" % ", ".join(kinds))


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("  FALHOU: " + msg)
	else:
		print("  ok: " + msg)


func _run_simulation(game, seed: int, years: int) -> void:
	print("== Simulação (%d anos, seed %d) ==" % [years, seed])
	game.new_game("Agência Teste", "Fundador", seed)
	var st = game.state
	check(st.employees.size() == 1, "começa com 1 pessoa (fundador)")
	check(st.prospects().size() == 1, "começa com 1 prospect")
	completed = 0
	stars_hist = [0, 0, 0, 0, 0, 0]
	var events_resolved := 0
	var hires := 0
	EventBus.project_completed.connect(_on_project_completed)
	var total_days := years * 360
	year_report = []
	for i in total_days:
		game.on_day()
		if st.day % 360 == 0:
			year_report.append(_snapshot(game))
		if OS.has_environment("SIM_VERBOSE") and st.day % 90 == 0:
			var stress_sum := 0.0
			for e in st.employees:
				stress_sum += e.stress
			var costs_v: Dictionary = game.finance.monthly_costs()
			print("    [dia %d] caixa=%s equipe=%d moral=%.0f estresse=%.0f projetos=%d custo/mês=%s receita/mês=%s rep=%.0f" % [st.day, FinanceSystem.format_money(st.money), st.employees.size(), game.employees.morale_average(), stress_sum / maxf(st.employees.size(), 1.0), st.running_projects().size(), FinanceSystem.format_money(float(costs_v.total)), FinanceSystem.format_money(st.month_revenue), st.reputation])
		if st.game_over:
			break
		# política automática
		if not st.pending_event.is_empty():
			var n: int = st.pending_event.choices.size()
			game.resolve_event(st.rng.randi_range(0, maxi(n - 1, 0)))
			events_resolved += 1
		for c in st.prospects():
			if st.active_clients().size() < st.employees.size() + 1:
				game.clients.propose(c, [0.8, 1.0, 1.2][st.rng.randi_range(0, 2)])
		for c in st.active_clients():
			if st.project_for_client(c.id) == null:
				if not c.diagnosed and c.diagnosis_days_left == 0 and st.money > 5000:
					game.clients.start_diagnosis(c)
				var free: Array = st.available_employees()
				if free.is_empty():
					continue
				var team: Array = []
				for e in free.slice(0, 3):
					team.append(e.id)
				var svcs: Array = _best_services(game, c)
				var kind: int = Project.Kind.RETAINER if game.clients.retainer_available(c) and st.rng.randf() < 0.5 else Project.Kind.PROJECT
				game.projects.create_project(c, svcs, team, kind)
		var costs: Dictionary = game.finance.monthly_costs()
		var can_afford: bool = st.money > costs.total * 4.0 + 12000.0
		if can_afford and st.employees.size() <= st.active_clients().size() and not st.candidates.is_empty() and st.employees.size() < game.office.capacity():
			var best = st.candidates[0]
			for cand in st.candidates:
				if cand.average_attr() > best.average_attr():
					best = cand
			if game.employees.hire(best).ok:
				hires += 1
		var nxt_office: Dictionary = game.office.next_level()
		# só cresce com fôlego: o aluguel novo precisa caber por meses (evita escritório grande e vazio)
		if not nxt_office.is_empty() and st.money > float(nxt_office.get("upgrade_cost", 0)) + 30000.0 + float(nxt_office.get("rent", 0)) * 6.0 and st.employees.size() >= game.office.capacity() - 1:
			game.office.upgrade()
		elif nxt_office.is_empty() and game.office.region() < game.office.regions().size():
			var next_region: Dictionary = game.office.region_data(game.office.region() + 1)
			var first_level: Dictionary = game.office.level_data(int(next_region.get("first_level", 1)))
			if game.office.can_move(game.office.region() + 1).ok and st.employees.size() >= 5 and st.money > float(next_region.get("move_cost", 0)) + 30000.0 + float(first_level.get("rent", 0)) * 6.0:
				game.office.move_to(game.office.region() + 1)
		# foco do mês: de graça e sempre vale a pena (o bot alterna caixa e vendas)
		if game.calendar.focus().is_empty():
			game.calendar.set_focus("caixa" if st.money < costs.total * 3.0 else "vendas")
		# mídia paga quando falta prospect e sobra caixa
		if st.prospects().is_empty() and game.clients.pending_leads() == 0 and st.money > costs.total * 5.0:
			game.clients.start_campaign("boost")
		if st.money > costs.total * 3.0 + 30000:
			for sid in game.content.service_order:
				if game.services.can_unlock(sid).ok:
					game.services.unlock(sid)
					break
		if st.money > costs.total + 6000 and st.day % 20 == 0:
			for e in st.available_employees():
				game.employees.train(e, "criativo")
				break
		if st.day % 30 == 10:
			var costs_now: Dictionary = game.finance.monthly_costs()
			for e in st.employees:
				if not e.is_founder and e.months_since_raise >= EmployeeSystem.RAISE_MONTHS_LIMIT and st.money > float(costs_now.total) * 2.0:
					game.employees.raise_by_player(e)
		if st.day % 30 == 5 and st.money > costs.total * 2.0 + 15000:
			for f in game.office.furniture_items():
				if game.office.can_buy(f).ok:
					game.office.buy(f)
					break
		if not game.hr.is_unlocked() and st.money > game.hr.hire_cost() + 30000 and game.hr.can_hire().ok:
			game.hr.hire()
		if game.hr.is_unlocked() and st.day % 25 == 0:
			for a in game.hr.actions():
				if game.hr.can_use(a).ok and st.money > game.hr.total_cost(a) + 10000:
					game.hr.use(a)
					break
		if game.agency_events.is_unlocked() and st.day % 40 == 0:
			for ev in game.agency_events.events():
				var free_ids: Array = st.available_employees().slice(0, int(ev.get("people", 0))).map(func(e): return e.id)
				if game.agency_events.can_run(ev, free_ids).ok and st.money > float(ev.get("cost", 0)) + 10000:
					game.agency_events.run(ev, free_ids)
					break
	print("  dia=%d ano=%d caixa=%s rep=%.1f equipe=%d clientes=%d projetos=%d eventos=%d contratações=%d fase=%s" % [
		st.day, st.year(), FinanceSystem.format_money(st.money), st.reputation, st.employees.size(),
		st.active_clients().size(), completed, events_resolved, hires, game.reputation.phase_name()])
	print("  estrelas: 1=%d 2=%d 3=%d 4=%d 5=%d" % [stars_hist[1], stars_hist[2], stars_hist[3], stars_hist[4], stars_hist[5]])
	print("  ritmo (régua GDD §53: ano 3 ≈ 6 pessoas, R$ 300 mil/ano, agência local):")
	for r in year_report:
		print("    ano %d (%d): equipe=%d clientes=%d receita=%s caixa=%s rep=%.0f escritório=%d região=%d projetos=%d moral=%.0f" % [
			r.year, r.calendar, r.employees, r.clients, FinanceSystem.format_money(r.revenue),
			FinanceSystem.format_money(r.cash), r.rep, r.office, int(r.get("region", 1)), r.projects, float(r.get("morale", 0))])
	if not year_report.is_empty():
		var morale_sum := 0.0
		for r in year_report:
			morale_sum += float(r.get("morale", 0))
		var morale_avg := morale_sum / float(year_report.size())
		check(morale_avg >= 45.0 and morale_avg <= 75.0, "moral média dos anos entre 45 e 75 (%.0f)" % morale_avg)
	if year_report.size() >= 3:
		var y3: Dictionary = year_report[2]
		check(y3.employees >= 2 and y3.employees <= 10, "ano 3: equipe entre 2 e 10 (%d)" % y3.employees)
		check(y3.revenue >= 120000.0 and y3.revenue <= 700000.0, "ano 3: receita anual entre R$ 120 mil e R$ 700 mil (%s)" % FinanceSystem.format_money(y3.revenue))
		check(y3.rep >= 20.0 and y3.rep <= 90.0, "ano 3: reputação entre 20 e 90 (%.0f)" % y3.rep)
	if year_report.size() >= 1:
		var y1: Dictionary = year_report[0]
		check(y1.employees >= 2 and y1.employees <= 5, "ano 1: equipe entre 2 e 5 (%d)" % y1.employees)
		check(y1.rep >= 8.0 and y1.rep <= 62.0, "ano 1: reputação entre 8 e 62 (%.0f)" % y1.rep)
	check(not st.game_over, "não faliu com política simples")
	check(completed >= 6, "concluiu pelo menos 6 projetos/ciclos (%d)" % completed)
	check(events_resolved >= 3, "eventos dispararam (%d)" % events_resolved)
	check(hires >= 1, "contratou alguém (%d)" % hires)
	check(st.reputation > 5.0, "reputação subiu (%.1f)" % st.reputation)
	check(st.money > -20000.0, "caixa longe da falência (%s)" % FinanceSystem.format_money(st.money))
	check(st.objective_index >= 5, "objetivos avançaram (%d/%d)" % [st.objective_index, game.content.objectives.size()])
	var with_journey: int = st.employees.filter(func(e): return e.journey.size() >= 2).size()
	check(with_journey >= 1, "colaboradores têm jornada registrada (%d)" % with_journey)
	var repeated := 0
	for id in st.events_seen:
		if int(st.events_seen[id]) > 1080 / 120 + 1:
			repeated += 1
	check(repeated == 0, "nenhum evento repetiu além do cooldown")
	print("  RH: %d ações · mobília: %d · eventos da agência: %d · teto de moral: %d" % [int(st.stats.get("hr_actions", 0)), int(st.stats.get("furniture", 0)), int(st.stats.get("agency_events", 0)), int(game.office.morale_max())])
	check(int(st.stats.get("furniture", 0)) >= 1, "bot comprou mobília")
	for e in st.employees:
		check(e.motivation <= game.office.morale_max() + 0.01, "moral de %s respeita o teto" % e.name)
	for e in st.employees:
		check(e.project_id == -1 or st.project_by_id(e.project_id) != null and st.project_by_id(e.project_id).is_running(),
			"%s aponta para projeto válido" % e.name)
	for p in st.running_projects():
		for id in p.team:
			check(st.employee_by_id(id) != null, "equipe do projeto %d existe" % p.id)
	print("  log recente:")
	for entry in st.log.slice(maxi(st.log.size() - 6, 0), st.log.size()):
		print("    [%s] %s" % [entry.kind, entry.text])


func _snapshot(game) -> Dictionary:
	var st = game.state
	var year_idx: int = st.day / 360 - 1
	var revenue := 0.0
	var projects := 0
	for h in st.finance_history:
		if int(h.get("month_index", 0)) / 12 == year_idx:
			revenue += float(h.get("revenue", 0))
	for p in st.projects:
		if p.finished_on >= year_idx * 360 and p.finished_on < (year_idx + 1) * 360 and p.status == Project.Status.DONE:
			projects += 1
	return {"year": year_idx + 1, "calendar": GameState.START_YEAR + year_idx, "employees": st.employees.size(),
		"clients": st.active_clients().size(), "revenue": revenue, "cash": st.money, "rep": st.reputation,
		"morale": game.employees.morale_average(), "region": game.office.region(),
		"office": st.office_level, "projects": projects}


func _on_project_completed(_p, result: Dictionary) -> void:
	completed += 1
	stars_hist[int(result.stars)] += 1


func _best_services(game, c) -> Array:
	var best: Array = game.content.match_table.get(c.segment, {}).get("best", [])
	var chosen: Array = []
	for s in best:
		if game.services.is_unlocked(s) and chosen.size() < 2:
			chosen.append(s)
	if c.diagnosed:
		for s in game.content.problem_solutions.get(c.problem, []):
			if game.services.is_unlocked(s) and not (s in chosen) and chosen.size() < 3:
				chosen.append(s)
				break
	if chosen.is_empty():
		chosen.append(game.state.unlocked_services[0])
	return chosen


func _test_save_roundtrip(game) -> void:
	print("== Save/Load ==")
	var before: Dictionary = game.state.to_dict()
	check(game.save_game(), "salvou em user://")
	check(game.load_game(), "carregou o save")
	var after: Dictionary = game.state.to_dict()
	var norm_before: String = JSON.stringify(JSON.parse_string(JSON.stringify(before)))
	var norm_after: String = JSON.stringify(JSON.parse_string(JSON.stringify(after)))
	check(norm_before == norm_after, "estado idêntico após roundtrip")
	if norm_before != norm_after:
		for key in before:
			if JSON.stringify(before[key]) != JSON.stringify(after.get(key)):
				printerr("    campo diferente: %s\n      antes: %s\n      depois: %s" % [key, JSON.stringify(before[key]).left(300), JSON.stringify(after.get(key)).left(300)])
	EventBus.project_completed.disconnect(_on_project_completed)
	game.state.paused = false
	for i in 30:
		game.on_day()
		if not game.state.pending_event.is_empty():
			game.resolve_event(0)
	check(game.state.day == before.day + 30, "jogo continua após carregar")


func _test_hr_furniture_events(game) -> void:
	print("== RH, mobília e eventos ==")
	game.new_game("Bem-estar", "Chefe", 99)
	var st = game.state
	check(not game.hr.is_unlocked(), "RH começa fechado")
	st.office_level = 7
	st.reputation = 45.0
	st.money = 100000.0
	for i in 3:
		var c = game.employees.generate_candidate("normal")
		st.candidates.append(c)
		game.employees.hire(c)
	check(not game.hr.is_unlocked(), "RH continua fechado até contratar a analista")
	check(game.hr.can_hire().ok, "com escritório 3, rep 30+ e caixa dá para contratar")
	var money_before: float = st.money
	check(game.hr.hire().ok, "contratou o RH")
	check(is_equal_approx(st.money, money_before - game.hr.hire_cost()), "pagou a montagem da sala")
	check(game.hr.is_unlocked(), "RH aberto após contratar")
	check(not game.hr.can_hire().ok, "não contrata duas vezes")
	check(float(game.finance.monthly_costs().hr) > 0.0, "salário do RH entra no custo fixo mensal")
	var pizza = game.hr.action_by_id("pizza")
	st.employees[1].motivation = 50.0
	var before: float = st.employees[1].motivation
	check(game.hr.use(pizza).ok, "noite de pizza")
	check(st.employees[1].motivation > before, "moral subiu com a pizza")
	check(not game.hr.can_use(pizza).ok, "pizza entra em cooldown")
	var energetico = game.hr.action_by_id("energetico")
	var prod_before: float = game.employees.productivity(st.employees[0])
	check(game.hr.use(energetico).ok, "energético com paçoca")
	check(game.employees.productivity(st.employees[0]) > prod_before, "buff de produtividade ativo (%.2f > %.2f)" % [game.employees.productivity(st.employees[0]), prod_before])
	for i in 12:
		game.on_day()
		if not st.pending_event.is_empty():
			game.resolve_event(0)
	check(st.buffs.is_empty(), "buff expira após 10 dias")
	var dog = game.hr.action_by_id("pet_dog")
	var cat = game.hr.action_by_id("pet_cat")
	check(not game.hr.can_use(cat).ok, "gato exige o cachorro antes")
	var daily_before: float = float(game.office.furniture_effects().morale_daily)
	check(game.hr.use(dog).ok, "adotou o cachorro")
	check(game.hr.has_pet("dog") and not game.hr.can_use(dog).ok, "cachorro é permanente e só uma vez")
	check(game.hr.use(cat).ok, "adotou o gato")
	check(st.pets.size() == 2, "dois pets no escritório")
	check(float(game.office.furniture_effects().morale_daily) > daily_before, "pets dão moral diária")
	var cadeiras = game.office.furniture_by_id("cadeiras")
	var cap_before: float = game.office.morale_max()
	check(game.office.buy(cadeiras).ok, "comprou cadeiras ergonômicas")
	check(game.office.morale_max() == cap_before + 5.0, "teto de moral subiu 5 (%d)" % int(game.office.morale_max()))
	var cafe = game.office.furniture_by_id("cafe_premium")
	var cri_before: float = st.employees[1].attr("creativity")
	check(game.office.buy(cafe).ok, "comprou máquina de café")
	check(st.employees[1].attr("creativity") == cri_before + 3.0, "café deu +3 de criatividade")
	var novato = game.employees.generate_candidate("normal")
	var novato_cri: float = novato.attr("creativity")
	st.candidates.append(novato)
	game.employees.hire(novato)
	check(novato.attr("creativity") == novato_cri + 3.0, "quem entra depois também ganha o bônus da mobília")
	check(game.agency_events.is_unlocked(), "eventos abrem com rep 40+")
	var palestra = game.agency_events.event_by_id("palestra")
	var speaker = st.available_employees()[0]
	var rep_before: float = st.reputation
	var prospects_before: int = st.prospects().size()
	check(game.agency_events.run(palestra, [speaker.id]).ok, "palestra começou")
	check(speaker.busy_reason == "Em evento" and not speaker.is_available(st.day), "palestrante fica fora")
	for i in 4:
		game.on_day()
		if not st.pending_event.is_empty():
			game.resolve_event(0)
	check(st.agency_events.is_empty(), "palestra terminou")
	check(st.reputation > rep_before, "palestra rendeu reputação (%.1f > %.1f)" % [st.reputation, rep_before])
	check(st.prospects().size() > prospects_before, "palestra trouxe prospect")
	check(speaker.is_available(st.day), "palestrante voltou")
	var saved: Dictionary = st.to_dict()
	var loaded = GameState.from_dict(saved)
	check(loaded.furniture.size() == 2 and loaded.hr_last_used.has("pizza"), "mobília e RH sobrevivem ao save")
	check(loaded.hr_hired and loaded.pets.size() == 2, "contratação do RH e pets sobrevivem ao save")


func _test_audio(game) -> void:
	print("== Áudio ==")
	check(Audio != null, "singleton Audio existe")
	check(Audio.sfx_enabled, "efeitos começam ligados")
	check(Audio.music_enabled, "música começa ligada")
	var stream = Audio._music_player.stream
	check(stream != null and stream is AudioStreamWAV, "trilha carregada como WAV")
	if stream != null and stream is AudioStreamWAV:
		var seconds: float = float(stream.data.size()) / 2.0 / float(stream.mix_rate)
		check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end > 0, "trilha em loop com fim marcado (loop_end %d)" % stream.loop_end)
		check(seconds >= 50.0, "trilha tem pelo menos 50 s (%.1f s)" % seconds)
	check(Audio.music_volume_db >= -9.0, "música não fica 20 dB abaixo dos efeitos (%.0f dB)" % Audio.music_volume_db)
	Audio.toggle_music()
	check(not Audio.music_enabled, "botão de mudo desliga a música")
	Audio.toggle_music()
	check(Audio.music_enabled, "botão de mudo religa a música")
	Audio.set_sfx_enabled(false)
	check(not Audio.sfx_enabled, "desligar efeitos")
	Audio.set_music_enabled(false)
	check(not Audio.music_enabled, "desligar música")
	var reloaded = load("res://src/core/audio_manager.gd").new()
	reloaded._load_settings()
	check(not reloaded.music_enabled and not reloaded.sfx_enabled, "preferência de áudio persiste em disco")
	reloaded.free()
	Audio.set_sfx_enabled(true)
	Audio.set_music_enabled(true)
	# não deve travar mesmo sem placa de som real (driver headless)
	Audio.play_sfx("payment")
	Audio.play_music()
	check(true, "play_sfx/play_music não travam em ambiente headless")


func _test_era(game) -> void:
	print("== Eras históricas ==")
	game.new_game("Era Test", "Chefe", 21)
	var st = game.state
	check(String(game.era.current().get("id", "")) == "2010", "2010 cai na era certa (%s)" % game.era.current().get("id", ""))
	check(game.era.is_trending("social_media") and game.era.is_trending("design"), "social_media e design em alta em 2010")
	check(not game.era.is_trending("seo"), "SEO ainda não está em alta em 2010")
	check(String(game.era.at_year(2018).get("id", "")) == "2016_2019", "2018 cai em Stories e performance")
	check(String(game.era.at_year(2030).get("id", "")) == "2025", "anos após 2025 ficam na era da IA (sem fim definido)")
	var c: Client = st.prospects()[0]
	c.status = Client.Status.ACTIVE
	var founder = st.employees[0]
	var with_trend: Dictionary = game.projects.predict(c, ["design"], [founder.id], 0)
	var without_trend: Dictionary = game.projects.predict(c, ["copywriting"], [founder.id], 0)
	var has_trend_label: bool = with_trend.breakdown.any(func(b): return String(b.label).begins_with("Em alta"))
	var no_trend_label: bool = without_trend.breakdown.any(func(b): return String(b.label).begins_with("Em alta"))
	check(has_trend_label, "bônus de tendência aparece no detalhamento ao usar serviço em alta")
	check(not no_trend_label, "bônus de tendência não aparece com serviço fora de moda")
	# avança até a virada 2011->2012 (a única troca de era nesse intervalo) e confere o log na hora
	st.money = 500000.0   # não deixa a simulação falir no caminho, sem bot administrando
	var guard := 0
	while st.year() < 2012 and not st.game_over and guard < 900:
		game.on_day()
		if not st.pending_event.is_empty():
			game.resolve_event(0)
		guard += 1
	var changed_era: bool = st.log.any(func(l): return String(l.get("text", "")).begins_with("O mercado mudou"))
	check(changed_era, "log de mudança de era aparece na virada 2011→2012")


func _test_departments(game) -> void:
	print("== Departamentos ==")
	game.new_game("Depto Test", "Chefe", 5)
	var st = game.state
	check(not game.departments.is_unlocked(), "departamentos começam fechados")
	st.office_level = 11
	check(game.departments.is_unlocked(), "departamentos abrem no escritório com departamentos")
	st.money = 500000.0
	var a = game.employees.generate_candidate("normal")
	st.candidates.append(a)
	game.employees.hire(a)
	var b = game.employees.generate_candidate("normal")
	st.candidates.append(b)
	game.employees.hire(b)
	a.career_level = DepartmentSystem.MANAGER_CAREER_LEVEL
	var prod_before: float = game.employees.productivity(b)
	check(game.departments.assign(a, "criacao").ok, "atribuiu gerente ao departamento de Criação")
	check(not game.departments.has_bonus("criacao"), "só 1 pessoa ainda não rende bônus")
	check(game.departments.assign(b, "criacao").ok, "segunda pessoa entra no mesmo departamento")
	check(game.departments.has_bonus("criacao"), "gerente + 2 pessoas rende bônus")
	check(game.employees.productivity(b) > prod_before, "produtividade sobe com o bônus de departamento (%.3f > %.3f)" % [game.employees.productivity(b), prod_before])
	var saved: Dictionary = st.to_dict()
	var loaded = GameState.from_dict(saved)
	check(loaded.employee_by_id(b.id).department == "criacao", "departamento sobrevive ao save")


func _test_competitors(game) -> void:
	print("== Concorrência ==")
	game.new_game("Competitor Test", "Chefe", 9)
	var st = game.state
	st.day = 100
	st.money = 500000.0
	var c: Client = game.clients.spawn_prospect()
	c.known_on = st.day - 30   # já passou do tempo de espera
	var guard := 0
	while c.status == Client.Status.PROSPECT and guard < 400:
		game.competitors.on_day()
		st.day += 1
		guard += 1
	check(c.status == Client.Status.LOST, "concorrente fecha com o prospect esquecido (%d dias)" % guard)


func _test_scoring(game) -> void:
	print("== Avaliação ==")
	game.new_game("Score", "Chefe", 7)
	var st = game.state
	var c = st.prospects()[0]
	c.status = Client.Status.ACTIVE
	var founder = st.employees[0]
	var q = game.services.match_quality("alimentacao", ["social_media", "paid_traffic"])
	check(q == "perfect", "social+tráfego é PERFECT MATCH para alimentação (%s)" % q)
	check(game.services.match_quality("alimentacao", ["crm"]) == "poor", "CRM é combinação ruim para alimentação")
	check(game.services.match_quality("alimentacao", ["design"]) == "good", "um serviço bom = boa combinação")
	var res = game.projects.create_project(c, ["social_media", "design"], [founder.id])
	check(res.ok, "projeto criado: %s" % res.reason)
	var p = res.project
	var days := 0
	while p.is_running() and days < 200:
		game.on_day()
		if not st.pending_event.is_empty():
			game.resolve_event(0)
		days += 1
	check(not p.is_running(), "projeto terminou em %d dias" % days)
	check(p.result.stars >= 1 and p.result.stars <= 5, "estrelas em 1..5 (%d)" % p.result.stars)
	check(p.result.payment > 0.0, "pagamento positivo (%s)" % FinanceSystem.format_money(p.result.payment))
	check(founder.project_id == -1, "fundador liberado ao fim do projeto")
	print("  score=%.1f estrelas=%d match=%s prazo=%d dias" % [p.result.score, p.result.stars, p.match_quality, days])
	var cheap: float = game.clients.proposal_chance(c, 0.6)
	var fair: float = game.clients.proposal_chance(c, 1.0)
	var pricey: float = game.clients.proposal_chance(c, 1.4)
	check(cheap > fair and fair > pricey, "desconto aumenta a chance (%.0f > %.0f > %.0f)" % [cheap, fair, pricey])
	check(game.clients.proposed_budget(c, 0.8) < c.budget, "preço proposto acompanha o slider")
	check(FinanceSystem.format_money(1234567.0) == "R$ 1.234.567", "formatação de dinheiro")
	check(FinanceSystem.format_money(-950.0) == "-R$ 950", "formatação negativa")


func _test_office_life(game) -> void:
	print("== Vida no escritório ==")
	# datas comemorativas por mês (0 = janeiro)
	check(game.seasons.theme_for_month(0).is_empty(), "janeiro não tem decoração")
	check(String(game.seasons.theme_for_month(1).get("id", "")) == "carnaval", "fevereiro é Carnaval")
	check(String(game.seasons.theme_for_month(5).get("id", "")) == "junina", "junho é Festa Junina")
	check(String(game.seasons.theme_for_month(9).get("id", "")) == "halloween", "outubro é Halloween")
	check(String(game.seasons.theme_for_month(10).get("id", "")) == "black_friday", "novembro é Black Friday")
	check(String(game.seasons.theme_for_month(11).get("id", "")) == "natal", "dezembro é Natal")
	for t in game.seasons.themes():
		check(ResourceLoader.exists("res://assets/art/seasons/%s.png" % t.get("garland", "")), "guirlanda de %s existe" % t.get("id"))
		check(ResourceLoader.exists("res://assets/art/seasons/%s.png" % t.get("prop", "")), "objeto de %s existe" % t.get("id"))
	for o in game.content.offices:
		check(o.has("season_slot"), "escritório nível %d tem lugar para a decoração" % int(o.get("level", 0)))
	# feed avisa na virada do mês
	game.new_game("Teste Natal", "Tester")
	game.state.day = GameState.DAYS_PER_MONTH * 11 - 1   # último dia de novembro
	var before: int = game.state.log.size()
	game.on_day()
	check(game.state.month() == 11, "virou dezembro")
	var logged := false
	for entry in game.state.log.slice(before, game.state.log.size()):
		if String(entry.get("text", "")).contains("Natal"):
			logged = true
	check(logged, "feed avisa da decoração de Natal")
	# hora do dia e luz
	check(is_equal_approx(OfficeView.hour_of(0.0), 8.0) and is_equal_approx(OfficeView.hour_of(1.0), 20.0), "dia de trabalho vai das 08:00 às 20:00")
	var noon: Dictionary = OfficeView.daylight(13.0)
	var night: Dictionary = OfficeView.daylight(20.0)
	var dusk: Dictionary = OfficeView.daylight(17.5)
	check((noon["tint"] as Color).is_equal_approx(Color.WHITE) and float(noon["lamp"]) == 0.0, "meio-dia com luz branca e sem luminárias")
	var night_tint: Color = night["tint"]
	check(night_tint.r < 0.4 and night_tint.g < 0.4 and night_tint.b < 0.6 and float(night["lamp"]) == 1.0 and float(night["night"]) == 1.0, "20:00 é noite escura com luminárias acesas")
	var dusk_tint: Color = dusk["tint"]
	check(dusk_tint.r > dusk_tint.b + 0.15 and dusk_tint.r > 0.85, "17:30 tem luz alaranjada no escritório")
	check(is_equal_approx(TimeSystem.SECONDS_PER_DAY / float(TimeSystem.SPEEDS[1]), 3.5) and float(TimeSystem.SPEEDS[0]) == 1.0 and float(TimeSystem.SPEEDS[2]) < 9.0, "2x é o antigo 1x (3,5 s por dia) e 3x é mais lento que 3x o antigo 1x")
	check((dusk["sky_bottom"] as Color).r > (noon["sky_bottom"] as Color).r, "fim de tarde tem céu mais alaranjado")
	var golden: Dictionary = OfficeView.daylight(16.5)
	check(float((golden["tint"] as Color).a) > 0.05, "às 16h30 o entardecer já começou")
	check(Hud.clock_text().length() == 5, "relógio do HUD formata HH:MM (%s)" % Hud.clock_text())
	# som ambiente
	var amb = Audio._ambience_player.stream
	check(amb != null and amb is AudioStreamWAV and amb.loop_mode == AudioStreamWAV.LOOP_FORWARD and amb.loop_end > 0, "som ambiente do escritório carregado em loop")
	check(Audio.ambience_enabled, "som ambiente começa ligado")
	Audio.set_ambience_people(1)
	var quiet: float = Audio._ambience_player.volume_db
	Audio.set_ambience_people(10)
	check(Audio._ambience_player.volume_db > quiet, "mais gente, escritório mais barulhento (%.1f → %.1f dB)" % [quiet, Audio._ambience_player.volume_db])
	Audio.set_ambience_enabled(false)
	check(not Audio.ambience_enabled, "toggle desliga o som ambiente")
	Audio.set_ambience_enabled(true)
	# guia inicial: passos apontam para objetivos existentes e o estado persiste no save
	var objective_ids: Array = game.content.objectives.map(func(o): return String(o.get("id", "")))
	var steps_ok: bool = not game.content.tutorial.is_empty()
	for s in game.content.tutorial:
		if not objective_ids.has(String(s.get("objective", ""))) or String(s.get("target", "")) == "":
			steps_ok = false
	check(steps_ok, "passos do guia apontam para objetivos e botões válidos (%d passos)" % game.content.tutorial.size())
	game.state.tutorial_done = true
	var restored = GameState.from_dict(game.state.to_dict())
	check(restored.tutorial_done, "tutorial_done sobrevive ao save")


func _test_briefings_chemistry_awards(game) -> void:
	print("== Briefings, química e prêmios ==")
	game.new_game("Premiada", "Chefe", 4242)
	var st = game.state
	st.money = 200000.0
	st.reputation = 40.0
	# briefing: cliente ativo ganha tema; entra no título e no contrato
	var c = st.prospects()[0]
	c.status = Client.Status.ACTIVE
	var b: Dictionary = game.projects.briefing_for(c)
	check(not b.is_empty() and c.briefing == String(b.get("id", "")), "cliente ativo recebe um briefing (%s)" % b.get("name", ""))
	check(game.projects.briefing_for(c).get("id", "") == b.get("id", ""), "briefing fica fixo até o projeto sair")
	var base_deadline := clampi(18 + int(c.budget * (1.2 + 0.3 * c.maturity) / 800.0), 24, 60)
	var q = game.projects.quote(c, Project.Kind.PROJECT)
	var expected_deadline := maxi(12, int(roundf(float(clampi(18 + int(float(q.budget) / 800.0), 24, 60)) * float(b.get("deadline_mult", 1.0)))))
	check(int(q.deadline) == expected_deadline, "prazo do contrato segue o briefing (%d dias, base %d)" % [int(q.deadline), base_deadline])
	var months_ok := true
	for bb in game.content.briefings:
		for m in bb.get("months", []):
			if int(m) < 0 or int(m) > 11:
				months_ok = false
	check(months_ok and game.content.briefings.size() >= 8, "%d briefings com meses válidos" % game.content.briefings.size())
	# química: par criativo + analítico é sinergia; estrela + estrela é atrito
	var a = game.employees.generate_candidate("normal")
	a.personality = "criativo"
	var d = game.employees.generate_candidate("normal")
	d.personality = "analitico"
	var chem: Dictionary = game.chemistry.team_chemistry([a, d])
	check(int(chem.score) == 1 and chem.items.size() == 1, "criativo + analítico = sinergia")
	var s1 = game.employees.generate_candidate("normal")
	s1.personality = "estrela"
	var s2 = game.employees.generate_candidate("normal")
	s2.personality = "estrela"
	check(int(game.chemistry.team_chemistry([s1, s2]).score) == -1, "duas estrelas = atrito")
	check(int(game.chemistry.team_chemistry([a, d, s1, s2]).score) == 0, "soma dos pares")
	check(not game.chemistry.partners_for("criativo").synergy.is_empty(), "ficha mostra com quem combina")
	# a nota reflete a química e os serviços-chave do briefing
	for e in [a, d]:
		st.candidates.append(e)
		game.employees.hire(e)
	var keys: Array = b.get("key_services", [])
	var chosen: Array = keys.filter(func(sid): return game.services.is_unlocked(sid))
	if chosen.is_empty():
		chosen = ["social_media"]
	var pv = game.projects.predict(c, chosen.slice(0, 2), [a.id, d.id], Project.Kind.PROJECT)
	var labels: Array = pv.breakdown.map(func(i): return String(i.label))
	check(labels.any(func(l): return l.begins_with("Química")), "prévia mostra a química da equipe")
	check(int(pv.chemistry.score) == 1, "prévia devolve a química (%d)" % int(pv.chemistry.score))
	if not keys.filter(func(sid): return game.services.is_unlocked(sid)).is_empty():
		check(labels.any(func(l): return l.contains(String(b.get("name", "")))), "serviço-chave do briefing conta na nota")
	var r = game.projects.create_project(c, chosen.slice(0, 2), [a.id, d.id])
	check(r.ok, "projeto criado com briefing")
	var p: Project = st.running_projects()[0]
	check(p.briefing == String(b.get("id", "")) and p.title.begins_with(String(b.get("name", ""))), "projeto guarda o briefing e o título usa o tema (%s)" % p.title)
	var stress_before: float = a.stress
	game.chemistry.apply_daily([s1, s2])
	check(s1.stress > 0.0, "atrito sobe o estresse por dia")
	game.chemistry.apply_daily([a, d])
	check(a.stress == stress_before, "sinergia não estressa")
	# prêmios: ano com uma campanha 5 estrelas ganha Campanha do Ano
	game.on_day()
	p.result = {"stars": 5, "score": 90.0}
	p.status = Project.Status.DONE
	p.finished_on = st.day
	for e in [a, d]:
		e.project_id = -1
	var ceremony: Dictionary = game.awards.evaluate_year(GameState.START_YEAR)
	var by_cat := {}
	for res in ceremony.results:
		by_cat[res.category] = res
	check(String(by_cat.campaign.status) == "won" and by_cat.campaign.people.has(a.id), "Campanha do Ano para a campanha 5 estrelas")
	check(String(by_cat.professional.status) == "nominated", "uma entrega só: profissional indicado, não vencedor")
	check(by_cat.agency.has("status") and float(game.awards.agency_threshold(GameState.START_YEAR)) == AwardSystem.AGENCY_BASE, "Agência do Ano usa a régua do primeiro ano")
	var rep_before: float = st.reputation
	var awards_before: int = st.awards.size()
	game.awards.on_year(GameState.START_YEAR)
	check(st.awards.size() == awards_before + 3, "cerimônia guarda as 3 categorias no histórico")
	check(st.reputation > rep_before, "vencer rende reputação")
	check(int(st.stats.get("awards", 0)) >= 1, "contador de prêmios")
	var restored = GameState.from_dict(st.to_dict())
	check(restored.awards.size() == st.awards.size() and restored.projects[0].briefing == p.briefing and restored.clients[0].briefing == c.briefing, "prêmios e briefings sobrevivem ao save")


func _test_morale_moods(game) -> void:
	print("== Moral e humores ==")
	game.new_game("Humores", "Chefe", 777)
	var st = game.state
	var f: Employee = st.employees[0]
	check(f.motivation <= game.office.morale_max(), "fundador começa dentro do teto (%d ≤ %d)" % [int(f.motivation), int(game.office.morale_max())])
	check(game.office.morale_max() <= 80.0, "teto base de moral baixou (%d)" % int(game.office.morale_max()))
	# pressão de estresse derruba a moral mesmo no ponto de equilíbrio
	f.motivation = EmployeeSystem.MORALE_BASELINE
	f.stress = 90.0
	var pressures: Array = game.employees.morale_pressures(f)
	check(pressures.any(func(pr): return pr.id == "stress"), "estresse alto aparece como pressão")
	game.on_day()
	check(f.motivation < EmployeeSystem.MORALE_BASELINE, "moral cai com estresse alto (%.2f)" % f.motivation)
	check(game.employees.mood_of(f, st.day) == "exhausted", "estresse ≥ 75 = exausto")
	# sem projeto por muitos dias = "sem desafio"
	f.stress = 0.0
	f.idle_days = EmployeeSystem.IDLE_DAYS_LIMIT
	check(game.employees.morale_pressures(f).any(func(pr): return pr.id == "idle"), "ficar na reserva pesa")
	f.idle_days = 0
	# humores
	f.motivation = 20.0
	check(game.employees.mood_of(f, st.day) == "sad", "moral ≤ 35 = desanimado")
	f.motivation = 72.0
	check(game.employees.mood_of(f, st.day) == "happy", "moral ≥ 70 = feliz")
	game.employees.good_news(f)
	check(game.employees.mood_of(f, st.day) == "celebrating", "boa notícia = celebrando por 3 dias")
	f.last_good_news_day = -99
	f.busy_reason = "Burnout"
	f.busy_until = st.day + 5
	check(game.employees.mood_of(f, st.day) == "burnout", "burnout tem prioridade")
	f.busy_reason = ""
	f.busy_until = -1
	f.last_offer_day = st.day
	check(game.employees.mood_of(f, st.day) == "courted", "proposta de concorrente = assediado")
	f.last_offer_day = -999
	check(game.employees.mood_label("happy").contains("Feliz"), "rótulo do humor")
	# entrega: 5 estrelas anima, 1 estrela derruba
	var c = st.prospects()[0]
	c.status = Client.Status.ACTIVE
	var before: float = f.motivation
	game.projects.create_project(c, ["social_media"], [f.id])
	var p: Project = st.running_projects()[0]
	for i in 200:
		if not p.is_running():
			break
		game.on_day()
		if not st.pending_event.is_empty():
			game.resolve_event(0)
	check(not p.is_running(), "projeto terminou")
	var stars: int = int(p.result.get("stars", 0))
	check(stars >= 1, "resultado com estrelas (%d)" % stars)
	var restored = Employee.from_dict(f.to_dict())
	check(restored.idle_days == f.idle_days and restored.last_good_news_day == f.last_good_news_day, "campos novos sobrevivem ao save")


func _test_regions(game) -> void:
	print("== Regiões e mudança de sede ==")
	check(game.content.offices.size() == 16 and game.office.regions().size() == 5, "16 níveis em 5 regiões")
	var caps_ok := true
	for i in range(1, game.content.offices.size()):
		if int(game.content.offices[i].capacity) < int(game.content.offices[i - 1].capacity):
			caps_ok = false
	check(caps_ok, "capacidade nunca diminui ao subir de nível")
	game.new_game("Mapa", "Chefe", 31)
	var st = game.state
	check(game.office.region() == 1 and game.clients.max_tier() == 1, "começa na Região 1 com clientes tier 1")
	st.money = 2000000.0
	st.reputation = 90.0
	check(not game.office.can_move(3).ok, "não pula região")
	check(game.office.can_move(2).ok, "com caixa e reputação pode mudar para a Região 2")
	var money_before: float = st.money
	check(game.office.move_to(2).ok, "mudou para o Centro Regional")
	check(game.office.region() == 2 and st.office_level == 4 and game.office.capacity() == 8, "sede nova no nível 1 da região (%s)" % game.office.current().name)
	check(is_equal_approx(st.money, money_before - 40000.0), "pagou a mudança")
	check(game.office.is_moving() and st.moving_until_day == st.day + 7 and game.office.moving_multiplier() < 1.0, "semana de mudança ativa")
	for i in 8:
		st.candidates.append(game.employees.generate_candidate("normal"))
		game.employees.hire(st.candidates[st.candidates.size() - 1])
	check(game.clients.max_tier() == 2, "tier máximo segue a região (%d)" % game.clients.max_tier())
	check(game.office.upgrade() and st.office_level == 5, "expansão 1 dentro da região")
	check(game.office.upgrade() and st.office_level == 6, "expansão 2 dentro da região")
	check(not game.office.can_upgrade().ok and game.office.can_upgrade().reason.contains("mapa"), "no máximo da região, pede para mudar de sede")
	check(game.office.move_to(3).ok and st.office_level == 7 and game.office.current().has("hr_room"), "Capital tem sala de RH no layout")
	for i in 8:
		game.on_day()
	check(not game.office.is_moving(), "semana de mudança termina")
	var restored = GameState.from_dict(st.to_dict())
	check(restored.office_level == st.office_level and restored.moving_until_day == st.moving_until_day, "região e mudança sobrevivem ao save")


func _test_rivals(game) -> void:
	print("== Concorrentes reais ==")
	game.new_game("Rivais", "Chefe", 55)
	var st = game.state
	check(game.competitors.active_rivals().is_empty(), "no bairro não há rival")
	st.money = 3000000.0
	st.reputation = 90.0
	check(game.office.move_to(2).ok, "mudou para o Centro Regional")
	var rivals: Array = game.competitors.active_rivals()
	check(rivals.size() == 1 and String(rivals[0].id) == "vertice", "Vértice Digital aparece na Região 2")
	var rs: Dictionary = game.competitors.rival_state("vertice")
	check(rs.clients.size() == 3 and rs.staff.size() == 2, "rival tem 3 clientes e 2 pessoas")
	check(game.competitors.can_raid().ok, "investida disponível")
	var rep_before: float = st.reputation
	var clients_before: int = st.active_clients().size()
	var r: Dictionary = game.competitors.raid_client("vertice", 0, 1)
	check(r.ok and r.success and st.active_clients().size() == clients_before + 1, "proposta forçada leva o cliente da rival")
	check(is_equal_approx(st.reputation, rep_before - 5.0), "custa 5 de reputação")
	check(game.competitors.is_aggressive("vertice") and not game.competitors.can_raid().ok, "rival fica agressiva e a investida entra em cooldown")
	check(game.competitors.can_raid().days_left == 90, "cooldown de 90 dias")
	st.last_raid_day = -999
	for i in 6:
		st.candidates.append(game.employees.generate_candidate("normal"))
		game.employees.hire(st.candidates[st.candidates.size() - 1])
	var team_before: int = st.employees.size()
	rep_before = st.reputation
	var money_before: float = st.money
	var r2: Dictionary = game.competitors.raid_employee("vertice", 0, 1)
	check(r2.ok and r2.success and st.employees.size() == team_before + 1, "contratação forçada traz a pessoa da rival")
	check(is_equal_approx(st.reputation, rep_before - 3.0) and st.money < money_before, "custa 3 de reputação e o bônus de assinatura")
	st.last_raid_day = -999
	var r3: Dictionary = game.competitors.raid_client("vertice", 0, 0)
	check(r3.ok and not r3.success and not game.competitors.can_raid().ok, "investida que falha também gasta o trimestre")
	game.competitors.ensure_rivals()
	check(game.competitors.rival_state("vertice").clients.size() == 3, "carteira da rival se recompõe")
	# investidas da rival: funcionário e cliente
	st.pending_event = {}
	check(game.competitors.rival_offer_employee("vertice"), "rival faz proposta a um funcionário")
	var target_id: int = int(st.pending_event.targets.employee_id)
	check(st.employee_by_id(target_id).last_offer_day == st.day, "alvo fica com humor assediado")
	var size_before: int = st.employees.size()
	game.resolve_event(2)
	check(st.employees.size() == size_before - 1, "\"deixar sair\" perde a pessoa")
	var c = st.prospects()[0] if not st.prospects().is_empty() else game.clients.spawn_prospect()
	c.status = Client.Status.ACTIVE
	c.relationship = 30.0
	c.tier = 1
	check(game.competitors.rival_offer_client("vertice"), "rival faz proposta a um cliente")
	var budget_before: float = c.budget
	game.resolve_event(0)
	check(c.budget < budget_before and c.is_active(), "igualar o desconto mantém o cliente com orçamento menor")
	var restored = GameState.from_dict(st.to_dict())
	check(restored.rivals.has("vertice") and restored.last_raid_day == st.last_raid_day, "rivais sobrevivem ao save")


func _test_region_content(game) -> void:
	print("== Conteúdo por região e projetos complexos ==")
	game.new_game("Conteúdo", "Chefe", 8)
	var st = game.state
	st.day = 400
	var pool_r1: Array = game.content.events.filter(func(ev): return game.events._eligible(ev)).map(func(ev): return String(ev.id))
	check(pool_r1.has("vizinho_logo") and not pool_r1.has("greve_transporte") and not pool_r1.has("cliente_internacional"), "no bairro só os eventos da Região 1 entram no sorteio")
	var fi = game.agency_events.event_by_id("feira_internacional")
	check(not fi.is_empty() and not game.agency_events.can_run(fi, []).ok, "feira internacional trancada fora do Hub Global")
	var terraco = game.office.furniture_by_id("terraco")
	st.money = 5000000.0
	check(not game.office.can_buy(terraco).ok, "terraço exige a torre global")
	# vai até o Hub Global
	st.reputation = 95.0
	for r in [2, 3, 4, 5]:
		check(game.office.move_to(r).ok, "mudou para a região %d" % r)
	check(game.office.upgrade(), "expandiu no Hub Global")
	check(game.office.can_buy(terraco).ok, "terraço liberado na torre global")
	var pool_r5: Array = game.content.events.filter(func(ev): return game.events._eligible(ev)).map(func(ev): return String(ev.id))
	check(pool_r5.has("cambio") and not pool_r5.has("vizinho_logo"), "no Hub Global entram os eventos globais e saem os do bairro")
	check(game.clients.max_tier() == 1, "tier ainda limitado pela equipe pequena")
	for i in 12:
		st.candidates.append(game.employees.generate_candidate("high"))
		game.employees.hire(st.candidates[st.candidates.size() - 1])
	check(game.clients.max_tier() == 5, "com equipe grande no Hub Global chegam clientes tier 5")
	var c = game.clients.spawn_prospect()
	check(c.tier >= 4, "prospect do topo (tier %d)" % c.tier)
	c.tier = 5
	c.status = Client.Status.ACTIVE
	check(game.projects.is_complex(c, Project.Kind.PROJECT), "cliente tier 5 gera projeto complexo")
	var two: Array = [st.employees[0].id, st.employees[1].id]
	check(not game.projects.can_create(c, ["social_media"], two).ok, "projeto complexo recusa equipe pequena")
	var team: Array = []
	var roles := {}
	for e in st.employees:
		if team.size() >= 5:
			break
		if e.is_available(st.day):
			team.append(e.id)
			roles[e.role] = true
	if roles.size() < 2:
		st.employees[1].role = "design"
	var q = game.projects.quote(c, Project.Kind.PROJECT)
	check(bool(q.complex) and float(q.effort) > 12.0 + float(q.budget) / 350.0, "orçamento e esforço maiores no projeto complexo")
	var r = game.projects.create_project(c, ["social_media", "design"], team)
	check(r.ok, "projeto complexo criado com 5 pessoas e 2 papéis (%s)" % r.reason)
	var p: Project = st.running_projects()[0]
	check(p.complex and not p.checkpoint_done, "projeto marcado como complexo")
	for i in 120:
		if p.checkpoint_done or not p.is_running():
			break
		game.on_day()
		if not st.pending_event.is_empty():
			game.resolve_event(0)
	check(p.checkpoint_done, "checkpoint aconteceu na metade")
	check(Project.from_dict(p.to_dict()).complex, "projeto complexo sobrevive ao save")
	check(game.content.client_templates.filter(func(t): return int(t.tier) == 5).size() >= 6, "há clientes tier 5 suficientes")


func _test_specialization(game) -> void:
	print("== Especialização de carreira ==")
	game.new_game("Carreira", "Chefe", 71)
	var st = game.state
	st.money = 200000.0
	var e: Employee = game.employees.generate_candidate("high")
	game.employees.hire(e)
	var target := ""
	for sid in game.employees.spec_options(e):
		if game.employees.spec_skill(e, sid) >= EmployeeSystem.SPEC_MIN_SKILL:
			target = sid
			break
	if target == "":
		# garante aptidão suficiente para a trilha do primeiro serviço liberado
		target = String(game.employees.spec_options(e)[0])
		for key in Employee.ATTRS:
			e.attrs[key] = 90.0
	check(game.employees.can_specialize(e, target).ok, "pode entrar na trilha de %s" % target)
	check(not game.employees.can_specialize(st.employees[0], target).ok, "fundador não troca de especialidade")
	var money_before: float = st.money
	var old_role: String = e.role
	check(game.employees.specialize(e, target).ok, "entrou na especialização")
	check(e.specializing == target and not e.is_available(st.day), "fica ocupado durante a trilha")
	check(st.money < money_before, "especialização custa dinheiro")
	check(int(st.stats.get("specializations", 0)) == 1, "estatística de especializações conta")
	var weights: Dictionary = game.content.services.get(target, {}).get("weights", {})
	var main_key := ""
	for k in weights:
		if main_key == "" or float(weights[k]) > float(weights[main_key]):
			main_key = String(k)
	var attr_before: float = e.attr(main_key)
	st.day = e.busy_until + 1
	game.employees.on_day()
	check(e.specializing == "" and e.role == target and old_role != target, "terminou e mudou de cargo para %s" % target)
	check(e.attr(main_key) > attr_before, "ganhou pontos no atributo principal (%.0f → %.0f)" % [attr_before, e.attr(main_key)])
	var restored := Employee.from_dict(e.to_dict())
	check(restored.role == target, "cargo novo sobrevive ao save")


func _test_decisions(game) -> void:
	print("== Decisões no meio do projeto ==")
	game.new_game("Decisões", "Chefe", 72)
	var st = game.state
	var c = game.clients.spawn_prospect()
	c.status = Client.Status.ACTIVE
	var r = game.projects.create_project(c, [String(st.unlocked_services[0])], [st.employees[0].id])
	check(r.ok, "projeto criado (%s)" % r.reason)
	var p: Project = st.running_projects()[0]
	check(not p.decision_done, "projeto começa sem decisão")
	var d: Dictionary = game.projects.trigger_decision(p, "pedido_ultima_hora")
	check(not d.is_empty() and p.decision_done, "decisão disparada e marcada no projeto")
	check(String(d.get("id", "")) == "pedido_ultima_hora" and (d.get("choices", []) as Array).size() >= 2, "a decisão chega com as opções e o projeto a que pertence")
	check(int(d.get("project_id", -1)) == p.id, "decisão aponta para o projeto certo")
	check(not String(d.get("text", "")).contains("{client}"), "os nomes entram no texto: %s" % String(d.get("text", "")).substr(0, 60))
	var effort_before: float = p.effort_total
	var deadline_before: int = p.deadline_days
	var indicators_before: float = p.boosts.values().reduce(func(a, b): return a + b, 0.0)
	game.projects.apply_decision(p, d, 0)
	check(int(st.stats.get("decisions", 0)) == 1, "estatística de decisões conta a escolha")
	check(p.effort_total != effort_before or p.deadline_days != deadline_before \
		or p.boosts.values().reduce(func(a, b): return a + b, 0.0) != indicators_before, "a escolha mexeu no projeto")
	# cada projeto recebe no máximo uma
	game.projects._maybe_decision(p)
	check(int(st.stats.get("decisions", 0)) == 1, "o mesmo projeto não recebe uma segunda decisão")
	check(Project.from_dict(p.to_dict()).decision_done, "marca de decisão sobrevive ao save")
	check(game.content.decisions.get("decisions", []).size() >= 10, "há decisões suficientes no conteúdo")


func _test_market_trends(game) -> void:
	print("== Notícias que mexem no mercado ==")
	game.new_game("Mercado", "Chefe", 73)
	var st = game.state
	st.day = 300
	check(not game.era.is_cold("paid_traffic"), "tráfego pago começa normal")
	var n: Dictionary = game.news.publish("eleicao_debate")
	check(not n.is_empty(), "notícia publicada")
	check(game.era.is_cold("paid_traffic"), "a notícia esfriou o tráfego pago")
	var trends: Array = game.era.market_trends()
	check(trends.size() == 1 and int(trends[0]["days_left"]) > 0, "tendência temporária listada com prazo")
	# serviço frio penaliza a nota do projeto
	var c = game.clients.spawn_prospect()
	c.status = Client.Status.ACTIVE
	var restored = GameState.from_dict(st.to_dict())
	check(restored.market.size() == 1, "tendência temporária sobrevive ao save")
	st.day = int(st.market[0]["until_day"])
	game.era.on_day()
	check(not game.era.is_cold("paid_traffic") and game.era.market_trends().is_empty(), "a tendência acaba no prazo")
	var hot: Dictionary = game.news.publish("influencer_sumiu")
	check(not hot.is_empty() and game.era.is_trending("influencer"), "notícia também aquece um serviço")
	var clients_before: int = st.prospects().size()
	game.news.publish("startup_unicornio")
	check(st.prospects().size() > clients_before, "notícia de captação traz prospects")


func _test_quest_arcs(game) -> void:
	print("== Missões em arco ==")
	game.new_game("Arcos", "Chefe", 74)
	var st = game.state
	st.day = 60
	var t1: Dictionary = game.quests.template("arco_case_1")
	check(String(t1.get("arc", "")) == "primeiro_case" and int(t1.get("steps", 0)) == 3, "etapa 1 do arco existe com 3 passos")
	check(game.quests.arc_label(t1).contains("etapa 1 de 3"), "rótulo do arco: %s" % game.quests.arc_label(t1))
	check(not game.quests._eligible(game.quests.template("arco_case_2")), "etapa 2 não entra no sorteio sozinha")
	var q: Dictionary = game.quests.start("arco_case_1")
	check(not q.is_empty(), "arco começou")
	st.stats["clients_signed"] = int(st.stats.get("clients_signed", 0)) + 1
	game.quests.check()
	check(game.quests.active_ids() == ["arco_case_2"], "etapa 1 cumprida começa a etapa 2 na hora")
	game.quests._on_project_completed(null, {"stars": 4})
	check(game.quests.active_ids() == ["arco_case_3"], "etapa 2 cumprida começa a etapa 3")
	var t3: Dictionary = game.quests.template("arco_case_3")
	check(float(t3.get("reward_money", 0)) > float(t1.get("reward_money", 0)), "a última etapa paga mais que a primeira")
	var rep_before: float = st.reputation
	st.stats["retainers"] = int(st.stats.get("retainers", 0)) + 1
	game.quests.check()
	check(game.quests.active().is_empty() and st.reputation > rep_before, "arco concluído paga o prêmio grande")
	var arcs := {}
	for t in game.quests.templates():
		if String(t.get("arc", "")) != "":
			arcs[String(t.get("arc", ""))] = true
	check(arcs.size() >= 3, "há pelo menos 3 arcos no conteúdo (%d)" % arcs.size())


func _test_talent(game) -> void:
	print("== Talento raro ==")
	game.new_game("Talento", "Chefe", 75)
	var st = game.state
	st.day = 200
	st.money = 300000.0
	var e: Employee = game.talent.spawn()
	check(e != null and e.legendary, "talento raro apareceu")
	check(game.talent.active() == e and e in st.candidates, "entra na lista de candidatos")
	var normal: Employee = game.employees.generate_candidate("high")
	var sum_legend := 0.0
	var sum_normal := 0.0
	for key in Employee.ATTRS:
		sum_legend += e.attr(key)
		sum_normal += normal.attr(key)
	check(sum_legend > sum_normal, "atributos acima de um candidato bom (%.0f vs %.0f)" % [sum_legend, sum_normal])
	check(game.talent.signing_bonus(e) > 0.0 and e.candidate_expires > st.day, "tem bônus de contratação e prazo")
	check(game.talent.spawn() == null, "não aparece um segundo talento ao mesmo tempo")
	var money_before: float = st.money
	check(game.talent.hire(e).ok, "contratou o talento")
	check(e in st.employees and st.money < money_before - e.salary, "entrou na equipe e o bônus foi pago")
	check(int(st.stats.get("legends", 0)) == 1, "estatística de lendas conta")
	check(Employee.from_dict(e.to_dict()).legendary, "marca de lenda sobrevive ao save")
	# prazo perdido: a rival leva e fica mais forte
	game.new_game("Talento2", "Chefe", 76)
	st = game.state
	st.day = 200
	st.reputation = 95.0
	st.money = 300000.0
	check(game.office.move_to(2).ok, "mudou para a região 2, onde há rivais")
	game.competitors.ensure_rivals()
	var e2: Employee = game.talent.spawn()
	var rivals: Array = game.competitors.active_rivals()
	check(not rivals.is_empty(), "há rivais na região para disputar o talento")
	var before := 0.0
	for a in rivals:
		before += float(st.rivals.get(String(a.get("id", "")), {}).get("strength", 0))
	st.day = e2.candidate_expires
	game.talent.on_day()
	var after := 0.0
	for a in rivals:
		after += float(st.rivals.get(String(a.get("id", "")), {}).get("strength", 0))
	check(not (e2 in st.candidates), "talento sai da lista quando o prazo passa")
	check(after > before, "a rival que levou o talento ficou mais forte (%.1f → %.1f)" % [before, after])


func _test_crisis(game) -> void:
	print("== Crises regionais ==")
	game.new_game("Crise", "Chefe", 77)
	var st = game.state
	st.day = 250
	check(not game.crisis.is_active() and game.crisis.productivity_multiplier() == 1.0, "sem crise a produtividade é normal")
	var morale_before: float = game.employees.morale_average()
	var c: Dictionary = game.crisis.start("apagao")
	check(not c.is_empty() and game.crisis.is_active(), "crise começou")
	check(game.crisis.productivity_multiplier() < 1.0 and game.crisis.prospect_multiplier() < 1.0, "produtividade e prospects caem")
	check(game.crisis.days_left() > 0 and game.crisis.headline().contains("Apagão"), "aviso do topo: %s" % game.crisis.headline())
	check(game.employees.morale_average() < morale_before, "a crise derruba a moral")
	check(int(st.stats.get("crises", 0)) == 1, "estatística de crises conta")
	var restored = GameState.from_dict(st.to_dict())
	check(not restored.crisis.is_empty(), "crise sobrevive ao save")
	st.day = int(st.crisis["until_day"])
	game.crisis.on_day()
	check(not game.crisis.is_active() and game.crisis.productivity_multiplier() == 1.0, "a crise acaba no prazo")
	# a crise também bate nas rivais da região
	game.new_game("Crise2", "Chefe", 78)
	st = game.state
	st.day = 250
	st.reputation = 95.0
	st.money = 300000.0
	check(game.office.move_to(2).ok, "mudou para a região 2, onde há rivais")
	game.competitors.ensure_rivals()
	var region: int = game.office.region()
	var locals: Array = game.competitors.active_rivals().filter(func(a): return int(a.get("region", 1)) == region)
	var before := 0.0
	for a in locals:
		before += float(st.rivals.get(String(a.get("id", "")), {}).get("strength", 0))
	game.crisis.start("enchente")
	var after := 0.0
	for a in locals:
		after += float(st.rivals.get(String(a.get("id", "")), {}).get("strength", 0))
	check(not locals.is_empty(), "há rivais na região para sentir a crise")
	check(after < before, "as rivais da região também perdem força (%.1f → %.1f)" % [before, after])
	check(game.content.crises.get("crises", []).size() >= 8, "há crises suficientes no conteúdo")


func _test_save_slots(game) -> void:
	print("== Espaços de save ==")
	game.save.delete_save()
	check(not game.save.has_save() and game.save.first_free_slot() == 1, "começa sem nenhum save")
	game.new_game("Agência Um", "Chefe", 81, 1)
	var st = game.state
	st.day = 120
	st.money = 45000.0
	check(game.save.current_slot == 1, "partida nova ocupa o espaço escolhido")
	check(game.save.save(st), "salvou no espaço 1")
	check(game.save.has_slot(1) and game.save.first_free_slot() == 2, "espaço 1 ocupado, o 2 é o próximo livre")
	game.new_game("Agência Dois", "Chefe", 82, 3)
	game.state.day = 400
	check(game.save.save(game.state, 3), "salvou no espaço 3")
	var info: Dictionary = game.save.slot_info(1)
	check(bool(info.exists) and String(info.agency_name) == "Agência Um" and int(info.day) == 120, "resumo do espaço 1: %s, dia %d" % [info.agency_name, info.day])
	check(String(info.date) != "" and float(info.money) == 45000.0 and int(info.saved_at) > 0, "resumo traz data, caixa e horário do save")
	check(not bool(game.save.slot_info(2).exists), "espaço 2 continua vazio")
	var loaded = game.save.load_state(1)
	check(loaded != null and loaded.agency_name == "Agência Um" and loaded.day == 120, "carregou o espaço 1 sem tocar no 3")
	check(game.save.load_state(3).agency_name == "Agência Dois", "carregou o espaço 3")
	check(game.save.slots().size() == SaveSystem.MAX_SLOTS, "a tela inicial lista %d espaços" % SaveSystem.MAX_SLOTS)
	game.save.delete_slot(1)
	check(not game.save.has_slot(1) and game.save.has_slot(3), "apagar um espaço não mexe nos outros")
	# partida nova sem espaço indicado vai para o primeiro livre
	game.new_game("Agência Três", "Chefe", 83)
	check(game.save.current_slot == 1, "sem espaço indicado, a partida nova usa o primeiro livre")
	game.save.delete_save()
	check(not game.save.has_save(), "limpeza final")
