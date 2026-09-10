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
	_run_simulation(game, 12345, 3)
	_test_save_roundtrip(game)
	_test_scoring(game)
	_test_hr_furniture_events(game)
	_test_audio(game)
	if failures == 0:
		print("\n[OK] Todos os testes passaram.")
		get_tree().quit(0)
	else:
		print("\n[FALHA] %d verificação(ões) falharam." % failures)
		get_tree().quit(1)


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
		if st.money > 60000 and st.employees.size() >= game.office.capacity() - 1:
			game.office.upgrade()
		if st.money > 30000:
			for sid in game.content.service_order:
				if game.services.can_unlock(sid).ok:
					game.services.unlock(sid)
					break
		if st.money > 6000 and st.day % 20 == 0:
			for e in st.available_employees():
				game.employees.train(e, "criativo")
				break
		if st.day % 30 == 5 and st.money > 15000:
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
		print("    ano %d (%d): equipe=%d clientes=%d receita=%s caixa=%s rep=%.0f escritório=%d projetos=%d" % [
			r.year, r.calendar, r.employees, r.clients, FinanceSystem.format_money(r.revenue),
			FinanceSystem.format_money(r.cash), r.rep, r.office, r.projects])
	if year_report.size() >= 3:
		var y3: Dictionary = year_report[2]
		check(y3.employees >= 2 and y3.employees <= 10, "ano 3: equipe entre 2 e 10 (%d)" % y3.employees)
		check(y3.revenue >= 120000.0 and y3.revenue <= 700000.0, "ano 3: receita anual entre R$ 120 mil e R$ 700 mil (%s)" % FinanceSystem.format_money(y3.revenue))
		check(y3.rep >= 20.0 and y3.rep <= 85.0, "ano 3: reputação entre 20 e 85 (%.0f)" % y3.rep)
	if year_report.size() >= 1:
		var y1: Dictionary = year_report[0]
		check(y1.employees >= 2 and y1.employees <= 5, "ano 1: equipe entre 2 e 5 (%d)" % y1.employees)
		check(y1.rep >= 8.0 and y1.rep <= 45.0, "ano 1: reputação entre 8 e 45 (%.0f)" % y1.rep)
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
	st.office_level = 3
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
	check(game.office.morale_max() == cap_before + 10.0, "teto de moral subiu 10 (%d)" % int(game.office.morale_max()))
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
