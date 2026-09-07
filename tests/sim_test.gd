extends Node
## Teste de simulação headless.
## Uso: godot --headless --path . res://tests/sim_test.tscn
## Roda alguns anos de jogo com uma política automática e verifica invariantes.

var failures := 0
var completed := 0
var stars_hist := [0, 0, 0, 0, 0, 0]


func _ready() -> void:
	var game = Game
	game.manual_time = true
	_run_simulation(game, 12345, 3)
	_test_save_roundtrip(game)
	_test_scoring(game)
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
	for i in total_days:
		game.on_day()
		if st.game_over:
			break
		# política automática
		if not st.pending_event.is_empty():
			var n: int = st.pending_event.choices.size()
			game.resolve_event(st.rng.randi_range(0, maxi(n - 1, 0)))
			events_resolved += 1
		for c in st.prospects():
			if st.active_clients().size() < st.employees.size() + 1:
				game.clients.propose(c)
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
	print("  dia=%d ano=%d caixa=%s rep=%.1f equipe=%d clientes=%d projetos=%d eventos=%d contratações=%d fase=%s" % [
		st.day, st.year(), FinanceSystem.format_money(st.money), st.reputation, st.employees.size(),
		st.active_clients().size(), completed, events_resolved, hires, game.reputation.phase_name()])
	print("  estrelas: 1=%d 2=%d 3=%d 4=%d 5=%d" % [stars_hist[1], stars_hist[2], stars_hist[3], stars_hist[4], stars_hist[5]])
	check(not st.game_over, "não faliu com política simples")
	check(completed >= 6, "concluiu pelo menos 6 projetos/ciclos (%d)" % completed)
	check(events_resolved >= 3, "eventos dispararam (%d)" % events_resolved)
	check(hires >= 1, "contratou alguém (%d)" % hires)
	check(st.reputation > 5.0, "reputação subiu (%.1f)" % st.reputation)
	check(st.money > 5000.0, "caixa cresceu (%s)" % FinanceSystem.format_money(st.money))
	for e in st.employees:
		check(e.project_id == -1 or st.project_by_id(e.project_id) != null and st.project_by_id(e.project_id).is_running(),
			"%s aponta para projeto válido" % e.name)
	for p in st.running_projects():
		for id in p.team:
			check(st.employee_by_id(id) != null, "equipe do projeto %d existe" % p.id)
	print("  log recente:")
	for entry in st.log.slice(maxi(st.log.size() - 6, 0), st.log.size()):
		print("    [%s] %s" % [entry.kind, entry.text])


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
	check(FinanceSystem.format_money(1234567.0) == "R$ 1.234.567", "formatação de dinheiro")
	check(FinanceSystem.format_money(-950.0) == "-R$ 950", "formatação negativa")
