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
		if not nxt_office.is_empty() and st.money > float(nxt_office.get("upgrade_cost", 0)) + 30000.0 and st.employees.size() >= game.office.capacity() - 1:
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
		if st.day % 30 == 10:
			var costs_now: Dictionary = game.finance.monthly_costs()
			for e in st.employees:
				if not e.is_founder and e.months_since_raise >= EmployeeSystem.RAISE_MONTHS_LIMIT and st.money > float(costs_now.total) * 2.0:
					game.employees.raise_by_player(e)
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
		print("    ano %d (%d): equipe=%d clientes=%d receita=%s caixa=%s rep=%.0f escritório=%d projetos=%d moral=%.0f" % [
			r.year, r.calendar, r.employees, r.clients, FinanceSystem.format_money(r.revenue),
			FinanceSystem.format_money(r.cash), r.rep, r.office, r.projects, float(r.get("morale", 0))])
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
		check(y1.rep >= 8.0 and y1.rep <= 50.0, "ano 1: reputação entre 8 e 50 (%.0f)" % y1.rep)
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
		"morale": game.employees.morale_average(),
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
	st.office_level = 4
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
	check(float((noon["tint"] as Color).a) < 0.001 and float(noon["lamp"]) == 0.0, "meio-dia sem tinta nem luminárias")
	check(float((night["tint"] as Color).a) > 0.2 and float(night["lamp"]) == 1.0 and float(night["night"]) == 1.0, "20:00 é noite com luminárias acesas")
	check((dusk["sky_bottom"] as Color).r > (noon["sky_bottom"] as Color).r, "fim de tarde tem céu mais alaranjado")
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
