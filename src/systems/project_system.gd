class_name ProjectSystem
extends RefCounted
## Criação, execução diária e avaliação de projetos e retainers.

const MAX_SERVICES := 3
const RETAINER_MONTHS := 6
const RETAINER_CYCLE_DAYS := 30
const PAYMENT_MULT := [0.0, 0.6, 0.85, 1.0, 1.1, 1.25]
const STAR_THRESHOLDS := [35.0, 50.0, 65.0, 82.0]
const MICRO_EVENT_CHANCE := 0.05

var game


func setup(g) -> void:
	game = g


# --- Orçamento --------------------------------------------------------------------

func quote(c: Client, kind: int) -> Dictionary:
	var budget: float
	if kind == Project.Kind.RETAINER:
		budget = c.budget
	else:
		budget = c.budget * (2.0 + 0.5 * c.maturity)
	budget = roundf(budget / 100.0) * 100.0
	var deadline := RETAINER_CYCLE_DAYS if kind == Project.Kind.RETAINER else clampi(15 + int(budget / 1000.0), 20, 60)
	var effort := 10.0 + budget / 600.0
	return {"budget": budget, "deadline": deadline, "effort": effort}


func can_create(c: Client, services: Array, team_ids: Array) -> Dictionary:
	var st: GameState = game.state
	if not c.is_active():
		return {"ok": false, "reason": "O cliente ainda não fechou contrato."}
	if st.project_for_client(c.id) != null:
		return {"ok": false, "reason": "Já existe um projeto rodando para este cliente."}
	if services.is_empty() or services.size() > MAX_SERVICES:
		return {"ok": false, "reason": "Escolha de 1 a %d serviços." % MAX_SERVICES}
	for s in services:
		if not game.services.is_unlocked(s):
			return {"ok": false, "reason": "Serviço não desbloqueado: %s" % game.content.service_name(s)}
	if team_ids.is_empty():
		return {"ok": false, "reason": "Escolha pelo menos uma pessoa para a equipe."}
	for id in team_ids:
		var e: Employee = st.employee_by_id(id)
		if e == null or not e.is_available(st.day):
			return {"ok": false, "reason": "Alguém da equipe não está disponível."}
	return {"ok": true, "reason": ""}


func create_project(c: Client, services: Array, team_ids: Array, kind: int = Project.Kind.PROJECT) -> Dictionary:
	var check := can_create(c, services, team_ids)
	if not check.ok:
		return check
	var st: GameState = game.state
	var q := quote(c, kind)
	var p := Project.new()
	p.id = st.new_id()
	p.client_id = c.id
	p.kind = kind
	p.title = _title_for(c, services, kind)
	p.budget = float(q.budget)
	p.deadline_days = int(q.deadline)
	p.effort_total = float(q.effort)
	p.objective = c.goal
	p.services = services.duplicate()
	p.team = team_ids.duplicate()
	p.started_on = st.day
	p.months_left = RETAINER_MONTHS if kind == Project.Kind.RETAINER else 0
	p.match_quality = game.services.match_quality(c.segment, services)
	p.addresses_problem = game.services.addresses_problem(c.problem, services)
	for id in team_ids:
		st.employee_by_id(id).project_id = p.id
	compute_targets(p)
	for key in Project.INDICATORS:
		p.indicators[key] = p.targets[key] * 0.3
	st.projects.append(p)
	c.last_project_day = st.day
	if kind == Project.Kind.RETAINER:
		c.retainer_months_left = RETAINER_MONTHS
		st.stats["retainers"] = int(st.stats.get("retainers", 0)) + 1
	game.add_log("Projeto iniciado: %s (%s)." % [p.title, c.name], "project")
	EventBus.project_started.emit(p)
	EventBus.state_changed.emit()
	return {"ok": true, "reason": "", "project": p}


func _title_for(c: Client, services: Array, kind: int) -> String:
	if kind == Project.Kind.RETAINER:
		return "Retainer mensal"
	var names: Array = services.map(func(s): return game.content.service_name(s))
	if names.size() == 1:
		return "Campanha de %s" % names[0]
	return "Campanha 360: %s" % " + ".join(names)


func team_members(p: Project) -> Array:
	var members: Array = []
	for id in p.team:
		var e: Employee = game.state.employee_by_id(id)
		if e != null:
			members.append(e)
	return members


func team_skill(p: Project, e: Employee) -> float:
	var total := 0.0
	for s in p.services:
		total += e.skill_for(game.content.services.get(s, {}).get("weights", {}))
	return total / maxf(p.services.size(), 1.0)


## Alvos dos indicadores a partir da equipe, dos serviços e do briefing.
func compute_targets(p: Project) -> void:
	var members := team_members(p)
	if members.is_empty():
		for key in Project.INDICATORS:
			p.targets[key] = 5.0
		return
	var n := float(members.size())
	var avg := {"strategy": 0.0, "creativity": 0.0, "management": 0.0, "technology": 0.0,
		"performance": 0.0, "motivation": 0.0, "stress": 0.0, "experience": 0.0}
	var max_creativity := 0.0
	var max_skill := 0.0
	for e in members:
		for key in ["strategy", "creativity", "management", "technology", "performance"]:
			avg[key] += e.attr(key) / n
		avg["motivation"] += e.motivation / n
		avg["stress"] += e.stress / n
		avg["experience"] += e.experience / n
		max_creativity = maxf(max_creativity, e.attr("creativity"))
		max_skill = maxf(max_skill, team_skill(p, e))

	var c: Client = game.state.client_by_id(p.client_id)
	var strategy: float = avg["strategy"]
	if p.addresses_problem:
		strategy += 15.0 if (c != null and c.diagnosed) else 7.0
	var creativity: float = avg["creativity"] * 0.6 + max_creativity * 0.4
	var execution: float = avg["management"] * 0.4 + avg["technology"] * 0.2 + avg["motivation"] * 0.4 \
		- avg["stress"] * 0.15 + minf(10.0, avg["experience"] / 60.0)
	if members.size() == 1 and p.effort_total > 40.0:
		execution -= 10.0
	var performance: float = avg["performance"] * 0.6 + max_skill * 0.4

	p.targets["strategy"] = clampf(strategy, 5.0, 100.0)
	p.targets["creativity"] = clampf(creativity, 5.0, 100.0)
	p.targets["execution"] = clampf(execution, 5.0, 100.0)
	p.targets["performance"] = clampf(performance, 5.0, 100.0)


func daily_output(p: Project) -> float:
	var total := 0.0
	for e in team_members(p):
		total += (0.5 + team_skill(p, e) / 100.0 * 1.5) * game.employees.productivity(e)
	return total


func estimated_days(p: Project) -> int:
	var out := daily_output(p)
	if out <= 0.0:
		return 999
	return ceili((p.effort_total - p.effort_done) / out)


## Estimativa antes de iniciar (usada na tela de novo projeto).
func preview(c: Client, services: Array, team_ids: Array, kind: int) -> Dictionary:
	var q := quote(c, kind)
	var tmp := Project.new()
	tmp.client_id = c.id
	tmp.services = services.duplicate()
	tmp.team = team_ids.duplicate()
	tmp.effort_total = float(q.effort)
	tmp.match_quality = game.services.match_quality(c.segment, services)
	tmp.addresses_problem = game.services.addresses_problem(c.problem, services)
	compute_targets(tmp)
	var days := estimated_days(tmp) if not team_ids.is_empty() else 0
	return {"budget": q.budget, "deadline": q.deadline, "days": days, "match": tmp.match_quality,
		"addresses_problem": tmp.addresses_problem, "targets": tmp.targets.duplicate()}


# --- Execução ------------------------------------------------------------------

func on_day() -> void:
	var st: GameState = game.state
	for p in st.running_projects():
		p.days_elapsed += 1
		compute_targets(p)
		p.effort_done += daily_output(p)
		for key in Project.INDICATORS:
			var goal: float = clampf(p.targets[key] + p.boosts[key], 0.0, 100.0)
			p.indicators[key] = lerpf(p.indicators[key], goal, 0.12) + st.rng.randf_range(-1.5, 1.5)
			p.indicators[key] = clampf(p.indicators[key], 0.0, 100.0)
		if not p.team.is_empty() and st.rng.randf() < MICRO_EVENT_CHANCE * _micro_mult(p):
			_micro_event(p)
		if p.kind == Project.Kind.RETAINER:
			if p.days_elapsed >= RETAINER_CYCLE_DAYS:
				_finish_cycle(p)
		elif p.effort_done >= p.effort_total or p.team.is_empty() and p.days_elapsed > p.deadline_days + 15:
			complete(p)


func _micro_mult(p: Project) -> float:
	var c: Client = game.state.client_by_id(p.client_id)
	if c == null:
		return 1.0
	return float(game.content.client_personalities.get(c.personality, {}).get("micro_events_mod", 1.0))


func _micro_event(p: Project) -> void:
	var st: GameState = game.state
	var list: Array = game.content.feed.get("micro_events", [])
	if list.is_empty():
		return
	var total := 0.0
	for m in list:
		total += float(m.get("weight", 1))
	var roll := st.rng.randf() * total
	var chosen: Dictionary = list[0]
	for m in list:
		roll -= float(m.get("weight", 1))
		if roll <= 0.0:
			chosen = m
			break
	var members := team_members(p)
	var e: Employee = members[st.rng.randi_range(0, members.size() - 1)]
	var effects: Dictionary = chosen.get("effects", {})
	for key in effects:
		if key == "motivation":
			for m in members:
				m.motivation = clampf(m.motivation + float(effects[key]), 0.0, 100.0)
		elif p.boosts.has(key):
			p.boosts[key] += float(effects[key])
	game.add_log(String(chosen["text"]).replace("{emp}", e.name), "fun")


func apply_boost(indicator: String, value: float) -> void:
	for p in game.state.running_projects():
		if p.boosts.has(indicator):
			p.boosts[indicator] += value


func delay_all(days: int) -> void:
	for p in game.state.running_projects():
		p.effort_done = maxf(0.0, p.effort_done - daily_output(p) * days)


func extra_work(fraction: float, project: Project = null) -> void:
	var targets: Array = [project] if project != null else game.state.running_projects()
	for p in targets:
		if p != null:
			p.effort_total *= (1.0 + fraction)


# --- Avaliação ------------------------------------------------------------------

func evaluate(p: Project) -> Dictionary:
	var st: GameState = game.state
	var c: Client = st.client_by_id(p.client_id)
	var pers: Dictionary = {}
	if c != null:
		pers = game.content.client_personalities.get(c.personality, {})
	var pweights: Dictionary = pers.get("weights", {})
	var base_weights := {"strategy": 0.3, "creativity": 0.25, "execution": 0.25, "performance": 0.2}
	var score := 0.0
	var weight_sum := 0.0
	var finals := {}
	for key in Project.INDICATORS:
		var final_value := clampf(p.targets[key] + p.boosts[key] + st.rng.randf_range(-4.0, 4.0), 0.0, 100.0)
		finals[key] = final_value
		var w: float = base_weights[key] * float(pweights.get(key, 1.0))
		score += final_value * w
		weight_sum += w
	score /= maxf(weight_sum, 0.001)
	score *= game.services.match_multiplier(p.match_quality)
	var difficulty := 1
	if c != null:
		difficulty = c.difficulty
	score *= 1.0 - 0.06 * (difficulty - 1)
	var late_days := maxi(0, p.days_elapsed - p.deadline_days)
	score -= minf(20.0, late_days * 0.8)
	if p.kind == Project.Kind.RETAINER:
		score *= 0.6 + 0.4 * p.progress()
	score = clampf(score, 0.0, 100.0)

	var thresholds := STAR_THRESHOLDS.duplicate()
	var shift := 0.0
	if c != null and c.expectation == "alta":
		shift = 3.0
	elif c != null and c.expectation == "baixa":
		shift = -3.0
	if c != null:
		# Quem paga mais caro espera mais; quem pagou barato é mais tolerante.
		shift += (c.price_factor - 1.0) * 10.0
	var stars := 1
	for t in thresholds:
		if score >= float(t) + shift:
			stars += 1
	var payment: float = p.budget * PAYMENT_MULT[stars]
	var tier := c.tier if c != null else 1
	var rep_delta := (stars - 2.5) * (0.8 + tier * 0.7)
	if stars == 5 and p.match_quality == "perfect":
		rep_delta += 2.0
	var roi := snappedf((0.5 + score / 100.0 * 4.5) * game.services.match_multiplier(p.match_quality), 0.1)
	return {"score": score, "stars": stars, "payment": payment, "rep_delta": rep_delta, "roi": roi,
		"late_days": late_days, "indicators": finals, "match": p.match_quality,
		"client_name": c.name if c != null else "", "project_title": p.title, "kind": p.kind}


func complete(p: Project) -> void:
	var st: GameState = game.state
	var result := evaluate(p)
	p.result = result
	p.status = Project.Status.DONE
	p.finished_on = st.day
	_apply_result(p, result)
	for e in team_members(p):
		e.project_id = -1
	game.add_log("Campanha concluída: %s — %d estrelas." % [p.title, result.stars], "project")
	EventBus.project_completed.emit(p, result)
	EventBus.state_changed.emit()


func _finish_cycle(p: Project) -> void:
	var st: GameState = game.state
	var result := evaluate(p)
	p.result = result
	p.history.append({"stars": result.stars, "score": result.score, "day": st.day})
	p.cycle += 1
	p.months_left -= 1
	_apply_result(p, result)
	var c: Client = st.client_by_id(p.client_id)
	if c != null:
		c.retainer_months_left = p.months_left
	p.days_elapsed = 0
	p.effort_done = 0.0
	for key in Project.INDICATORS:
		p.boosts[key] = 0.0
	if p.months_left <= 0 or (c != null and not c.is_active()):
		p.status = Project.Status.DONE
		p.finished_on = st.day
		for e in team_members(p):
			e.project_id = -1
		game.add_log("Retainer encerrado: %s." % (c.name if c != null else p.title), "project")
	else:
		game.add_log("Mês do retainer fechado: %s — %d estrelas." % [(c.name if c != null else p.title), result.stars], "project")
	EventBus.project_completed.emit(p, result)
	EventBus.state_changed.emit()


func _apply_result(p: Project, result: Dictionary) -> void:
	var st: GameState = game.state
	var c: Client = st.client_by_id(p.client_id)
	var stars: int = result.stars
	game.finance.add_money(float(result.payment), "Pagamento: %s" % (c.name if c != null else p.title), "revenue")
	game.reputation.add(float(result.rep_delta))
	st.stats["projects_done"] = int(st.stats["projects_done"]) + 1
	if stars == 5:
		st.stats["five_stars"] = int(st.stats["five_stars"]) + 1
		st.cases += 1
	for e in team_members(p):
		game.employees.add_journey(e, "%s para %s: %d estrelas" % ["Ciclo de retainer" if p.kind == Project.Kind.RETAINER else "Entregou " + p.title, c.name if c != null else "?", stars])
		game.employees.gain_experience(e, 12.0 + p.budget / 2500.0)
		var growth: float = 0.6 + e.potential * 0.25
		for s in p.services:
			var weights: Dictionary = game.content.services.get(s, {}).get("weights", {})
			for key in weights:
				e.attrs[key] = clampf(e.attr(key) + float(weights[key]) * growth * st.rng.randf_range(0.5, 1.5), 1.0, 100.0)
		e.motivation = clampf(e.motivation + (6.0 if stars >= 4 else (-8.0 if stars <= 2 else 1.0)), 0.0, 100.0)
		e.stress = clampf(e.stress - 8.0, 0.0, 100.0)
	if c != null:
		game.clients.on_project_result(c, result)
		var tier := c.tier
		if tier >= 2 or stars == 5 or stars == 1:
			var list: Array = game.content.feed.get("press_good" if stars >= 4 else "press_bad", [])
			if stars == 3:
				list = []
			if not list.is_empty():
				var headline: String = list[st.rng.randi_range(0, list.size() - 1)]
				result["press"] = headline.replace("{client}", c.name)
				game.add_log(result["press"], "press")


func cancel(p: Project) -> void:
	if not p.is_running():
		return
	p.status = Project.Status.CANCELLED
	p.finished_on = game.state.day
	for e in team_members(p):
		e.project_id = -1
	EventBus.state_changed.emit()


func recent_finished(limit: int = 10) -> Array:
	var done: Array = game.state.projects.filter(func(p): return not p.is_running())
	done.reverse()
	return done.slice(0, limit)
