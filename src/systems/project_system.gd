class_name ProjectSystem
extends RefCounted
## Criação, execução diária e avaliação de projetos e retainers.

const MAX_SERVICES := 3
const RETAINER_MONTHS := 6
const RETAINER_CYCLE_DAYS := 30
const PAYMENT_MULT := [0.0, 0.6, 0.85, 1.0, 1.1, 1.25]
const STAR_THRESHOLDS := [35.0, 50.0, 65.0, 82.0]
const MICRO_EVENT_CHANCE := 0.05
## Projetos complexos (clientes tier 5, Região 5): equipe mínima, mais esforço e checkpoint na metade.
const COMPLEX_TIER := 5
const COMPLEX_MIN_TEAM := 4
const COMPLEX_MIN_ROLES := 2
const COMPLEX_EFFORT_MULT := 1.4
const COMPLEX_BUDGET_MULT := 1.5
const COMPLEX_REWORK := 0.25
## Quanto os serviços do projeto mandam nos pesos dos indicadores (0 = só os pesos base).
## Tráfego pago pesa Performance; design pesa Criatividade; CRM pesa Execução (tecnologia+gestão).
const SERVICE_WEIGHT_BLEND := 0.55
const FIT_NEUTRAL := 50.0            # habilidade média da equipe nos atributos do serviço que não soma nem tira
const FIT_PER_POINT := 0.5           # nota por ponto de habilidade acima/abaixo do neutro
const FIT_BONUS_MAX := 15.0
const FIT_PENALTY_MAX := 9.0         # errar o perfil dói, mas menos do que acertar recompensa
## Atributo → indicador da nota: como cada peso de serviço cai nos quatro indicadores.
const ATTR_TO_INDICATOR := {
	"creativity": {"creativity": 1.0}, "strategy": {"strategy": 1.0}, "performance": {"performance": 1.0},
	"management": {"execution": 1.0}, "technology": {"execution": 0.7, "performance": 0.3},
	"communication": {"strategy": 0.5, "creativity": 0.5},
}

var game


func setup(g) -> void:
	game = g


# --- Orçamento --------------------------------------------------------------------

func quote(c: Client, kind: int) -> Dictionary:
	var budget: float
	if kind == Project.Kind.RETAINER:
		budget = c.budget
	else:
		budget = c.budget * (1.2 + 0.3 * c.maturity) * float(briefing_for(c).get("budget_mult", 1.0))
	var complex := is_complex(c, kind)
	if complex:
		budget *= COMPLEX_BUDGET_MULT
	budget = roundf(budget / 100.0) * 100.0
	var deadline := RETAINER_CYCLE_DAYS if kind == Project.Kind.RETAINER else clampi(18 + int(budget / 800.0), 24, 60)
	if kind != Project.Kind.RETAINER:
		deadline = maxi(12, int(roundf(float(deadline) * float(briefing_for(c).get("deadline_mult", 1.0)))))
	var effort := 12.0 + budget / 350.0
	if complex:
		effort *= COMPLEX_EFFORT_MULT
	return {"budget": budget, "deadline": deadline, "effort": effort, "complex": complex}


func is_complex(c: Client, kind: int) -> bool:
	return c.tier >= COMPLEX_TIER and kind == Project.Kind.PROJECT


## Equipe mínima do projeto complexo: 4 pessoas e 2 papéis diferentes.
func complex_team_check(team_ids: Array) -> Dictionary:
	var roles := {}
	for id in team_ids:
		var e: Employee = game.state.employee_by_id(id)
		if e != null:
			roles[e.role] = true
	if team_ids.size() < COMPLEX_MIN_TEAM or roles.size() < COMPLEX_MIN_ROLES:
		return {"ok": false, "reason": "Projeto complexo (tier %d): equipe mínima de %d pessoas com %d especialidades diferentes." % [COMPLEX_TIER, COMPLEX_MIN_TEAM, COMPLEX_MIN_ROLES]}
	return {"ok": true, "reason": ""}


# --- Briefings -----------------------------------------------------------------------

func briefing_by_id(id: String) -> Dictionary:
	for b in game.content.briefings:
		if String(b.get("id", "")) == id:
			return b
	return {}


## Briefing do próximo projeto do cliente; sorteia (e guarda no cliente) se ainda não tem.
func briefing_for(c: Client) -> Dictionary:
	if c.briefing == "":
		c.briefing = String(_pick_briefing(c).get("id", ""))
	return briefing_by_id(c.briefing)


func _pick_briefing(c: Client) -> Dictionary:
	var st: GameState = game.state
	var all: Array = game.content.briefings
	if all.is_empty():
		return {}
	var month := st.month()
	var eligible: Array = all.filter(func(b):
		if b.has("segments") and not (b["segments"] as Array).has(c.segment):
			return false
		if b.has("months") and not (b["months"] as Array).has(month):
			return false
		if b.has("problems") and not (b["problems"] as Array).has(c.problem):
			return false
		return true)
	if eligible.is_empty():
		eligible = all.filter(func(b): return not b.has("months"))
	if eligible.is_empty():
		eligible = all
	return eligible[st.rng.randi_range(0, eligible.size() - 1)]


func briefing_of(p: Project) -> Dictionary:
	return briefing_by_id(p.briefing)


func briefing_desc(b: Dictionary, c: Client) -> String:
	return String(b.get("desc", "")).replace("{client}", c.name)


## Serviços-chave do briefing presentes no projeto (nomes).
func key_services_in(p: Project) -> Array:
	var b := briefing_of(p)
	var keys: Array = b.get("key_services", [])
	return p.services.filter(func(sid): return keys.has(sid))


func can_create(c: Client, services: Array, team_ids: Array, kind: int = Project.Kind.PROJECT) -> Dictionary:
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
	if is_complex(c, kind):
		var cc := complex_team_check(team_ids)
		if not cc.ok:
			return cc
	return {"ok": true, "reason": ""}


func create_project(c: Client, services: Array, team_ids: Array, kind: int = Project.Kind.PROJECT) -> Dictionary:
	var check := can_create(c, services, team_ids, kind)
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
	if kind == Project.Kind.PROJECT:
		p.briefing = String(briefing_for(c).get("id", ""))
		p.title = _title_for(c, services, kind, briefing_of(p))
	p.complex = bool(q.get("complex", false))
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


func _title_for(c: Client, services: Array, kind: int, briefing: Dictionary = {}) -> String:
	if kind == Project.Kind.RETAINER:
		return "Retainer mensal"
	var names: Array = services.map(func(s): return game.content.service_name(s))
	if not briefing.is_empty():
		return "%s: %s" % [String(briefing.get("name", "Campanha")), " + ".join(names)]
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


## Habilidade média da equipe nos atributos pedidos pelos serviços (0–100).
func team_fit(p: Project) -> float:
	var members := team_members(p)
	if members.is_empty():
		return 0.0
	var total := 0.0
	for e in members:
		total += team_skill(p, e)
	return total / float(members.size())


## Pesos dos quatro indicadores para estes serviços: os pesos base misturados com os atributos
## que os serviços pedem (ATTR_TO_INDICATOR). Somam 1.
func indicator_weights(services: Array) -> Dictionary:
	var base := {"strategy": 0.3, "creativity": 0.25, "execution": 0.25, "performance": 0.2}
	var from_services := {"strategy": 0.0, "creativity": 0.0, "execution": 0.0, "performance": 0.0}
	var n := 0
	for sid in services:
		var weights: Dictionary = game.content.services.get(sid, {}).get("weights", {})
		if weights.is_empty():
			continue
		n += 1
		for attr in weights:
			for ind in ATTR_TO_INDICATOR.get(attr, {}):
				from_services[ind] += float(weights[attr]) * float(ATTR_TO_INDICATOR[attr][ind])
	var out := {}
	var total := 0.0
	for key in base:
		var sv: float = from_services[key] / float(n) if n > 0 else float(base[key])
		out[key] = (1.0 - SERVICE_WEIGHT_BLEND) * float(base[key]) + SERVICE_WEIGHT_BLEND * sv
		total += out[key]
	for key in out:
		out[key] = out[key] / maxf(total, 0.001)
	return out


## Atributos que mais pesam nestes serviços, do maior para o menor (para dicas e rótulos).
func key_attrs(services: Array, n: int = 2) -> Array:
	var sums := {}
	for sid in services:
		var weights: Dictionary = game.content.services.get(sid, {}).get("weights", {})
		for attr in weights:
			sums[attr] = float(sums.get(attr, 0.0)) + float(weights[attr])
	var keys: Array = sums.keys()
	keys.sort_custom(func(a, b): return float(sums[a]) > float(sums[b]))
	return keys.slice(0, n)


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
	var execution: float = avg["management"] * 0.4 + avg["technology"] * 0.2 + (avg["motivation"] + 20.0) * 0.4 \
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
	var members := team_members(p)
	for e in members:
		total += (0.5 + team_skill(p, e) / 100.0 * 1.5) * game.employees.productivity(e)
	var chem: int = game.chemistry.team_chemistry(members)["score"]
	var focus_mult: float = 1.06 if game.calendar.has_focus("entrega") else 1.0
	return total * (1.0 + ChemistrySystem.OUTPUT_PER_POINT * float(chem)) * focus_mult


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
	if kind == Project.Kind.PROJECT:
		tmp.briefing = String(briefing_for(c).get("id", ""))
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
		game.chemistry.apply_daily(team_members(p))
		if p.complex and not p.checkpoint_done and p.progress() >= 0.5:
			_checkpoint(p)
		_maybe_decision(p)
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


# --- Decisões no meio do projeto ------------------------------------------------------

## Nem todo projeto tem uma: a chance é diária, dentro da janela de progresso, e cada projeto
## recebe no máximo uma (data/decisions.json). A escolha mexe em indicadores, prazo, esforço,
## dinheiro, moral ou relação com o cliente.

func decisions_data() -> Dictionary:
	return game.content.decisions


func decision_by_id(id: String) -> Dictionary:
	for d in decisions_data().get("decisions", []):
		if String(d.get("id", "")) == id:
			return d
	return {}


func _decision_eligible(d: Dictionary, p: Project) -> bool:
	var services: Array = d.get("requires_service", [])
	if not services.is_empty() and not p.services.any(func(sid): return sid in services):
		return false
	return true


## Sorteia e dispara a decisão de um projeto. Retorna a decisão escolhida (vazia se não houver).
func trigger_decision(p: Project, forced_id: String = "") -> Dictionary:
	var st: GameState = game.state
	var d := decision_by_id(forced_id) if forced_id != "" else {}
	if d.is_empty():
		var pool: Array = decisions_data().get("decisions", []).filter(func(item): return _decision_eligible(item, p))
		if pool.is_empty():
			return {}
		var total := 0.0
		for item in pool:
			total += float(item.get("weight", 1))
		var roll := st.rng.randf() * total
		for item in pool:
			roll -= float(item.get("weight", 1))
			if roll <= 0.0:
				d = item
				break
		if d.is_empty():
			d = pool.back()
	p.decision_done = true
	var c: Client = st.client_by_id(p.client_id)
	var members := team_members(p)
	var who: String = members[st.rng.randi_range(0, members.size() - 1)].name if not members.is_empty() else "alguém do time"
	var text := String(d.get("text", ""))
	text = text.replace("{client}", c.name if c != null else "O cliente").replace("{project}", p.title).replace("{employee}", who)
	var shown := d.duplicate(true)
	shown["text"] = text
	shown["project_id"] = p.id
	EventBus.project_decision.emit(p, shown)
	return shown


## Aplica a escolha do jogador. `index` é a opção escolhida.
func apply_decision(p: Project, d: Dictionary, index: int) -> void:
	var st: GameState = game.state
	var choices: Array = d.get("choices", [])
	if choices.is_empty():
		return
	var choice: Dictionary = choices[clampi(index, 0, choices.size() - 1)]
	var c: Client = st.client_by_id(p.client_id)
	game.add_log("%s %s: %s" % [String(d.get("icon", "🔀")), String(d.get("title", "Decisão")), String(choice.get("label", ""))], "project")
	for effect in choice.get("effects", []):
		var value := float(effect.get("value", 0))
		match String(effect.get("type", "")):
			"indicator":
				var key := String(effect.get("key", ""))
				if p.boosts.has(key):
					p.boosts[key] += value
			"effort":
				p.effort_total = maxf(p.effort_total * (1.0 + value), p.effort_done + 1.0)
			"deadline":
				p.deadline_days = maxi(p.deadline_days + int(value), 1)
			"budget":
				p.budget = maxf(p.budget * (1.0 + value), 0.0)
			"money":
				game.finance.add_money(value, String(d.get("title", "Decisão")), "expense" if value < 0.0 else "revenue")
			"morale":
				for e in team_members(p):
					game.employees.change_morale(e, value)
			"stress":
				for e in team_members(p):
					e.stress = clampf(e.stress + value, 0.0, 100.0)
			"relationship":
				if c != null:
					c.relationship = clampf(c.relationship + value, 0.0, 100.0)
			"reputation":
				if value < 0.0:
					game.reputation.penalize(-value, "decisão de projeto")
				else:
					game.reputation.add(value)
			"log":
				game.add_log(String(effect.get("text", "")), "project")
	st.stats["decisions"] = int(st.stats.get("decisions", 0)) + 1
	EventBus.state_changed.emit()


func _maybe_decision(p: Project) -> void:
	var st: GameState = game.state
	var data := decisions_data()
	if p.decision_done or p.team.is_empty() or not st.pending_event.is_empty():
		return
	var progress := p.progress()
	if progress < float(data.get("min_progress", 0.2)) or progress > float(data.get("max_progress", 0.75)):
		return
	if st.rng.randf() > float(data.get("chance_per_day", 0.07)):
		return
	trigger_decision(p)


## Checkpoint do projeto complexo: o cliente avalia na metade; nota abaixo de 50 vira refação.
func _checkpoint(p: Project) -> void:
	var c: Client = game.state.client_by_id(p.client_id)
	p.checkpoint_done = true
	var r := _score(p, c, false)
	var client_name: String = c.name if c != null else "O cliente"
	if float(r.score) < 50.0:
		p.effort_total *= 1.0 + COMPLEX_REWORK
		for e in team_members(p):
			game.employees.change_morale(e, -3.0)
			EventBus.office_feedback.emit(e.id, "refação…", "bad")
		game.add_log("🧩 Checkpoint de %s: %s pediu refação (nota parcial %d). +%d%% de trabalho." % [p.title, client_name, int(r.score), int(COMPLEX_REWORK * 100)], "warn")
	else:
		p.boosts["execution"] += 3.0
		game.add_log("🧩 Checkpoint de %s aprovado por %s (nota parcial %d). Equipe ganha fôlego." % [p.title, client_name, int(r.score)], "project")


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
	EventBus.office_feedback.emit(e.id, String(chosen.get("bubble", "...")), "bubble")


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

## Bônus que o jogador controla diretamente (aparecem no detalhamento do resultado).
const BONUS_ON_TIME := 5.0
const BONUS_DIAGNOSIS := 8.0
const BONUS_DIAGNOSIS_LUCKY := 3.0
const BONUS_SPECIALIST := 4.0
const BONUS_SPECIALIST_MAX := 8.0
const BONUS_TRENDING := 3.0
const PENALTY_COLD := 4.0            # serviço que uma notícia esfriou rende menos por alguns dias
const BONUS_KEY_SERVICE := 4.0
const BONUS_KEY_SERVICE_MAX := 8.0


## Nota, estrelas e detalhamento. Com with_noise=false serve de previsão (sem sorteio).
func _score(p: Project, c: Client, with_noise: bool, predicted_days: int = -1) -> Dictionary:
	var st: GameState = game.state
	var pers: Dictionary = {}
	if c != null:
		pers = game.content.client_personalities.get(c.personality, {})
	var pweights: Dictionary = pers.get("weights", {})
	var briefing := briefing_of(p)
	var bweights: Dictionary = briefing.get("weights", {})
	var base_weights := indicator_weights(p.services)
	var breakdown: Array = []
	var score := 0.0
	var weight_sum := 0.0
	var finals := {}
	for key in Project.INDICATORS:
		var noise: float = st.rng.randf_range(-4.0, 4.0) if with_noise else 0.0
		var final_value := clampf(p.targets[key] + p.boosts[key] + noise, 0.0, 100.0)
		finals[key] = final_value
		var w: float = base_weights[key] * float(pweights.get(key, 1.0)) * float(bweights.get(key, 1.0))
		score += final_value * w
		weight_sum += w
	score /= maxf(weight_sum, 0.001)
	breakdown.append({"label": "Base da equipe (indicadores)", "text": "%d" % int(roundf(score)), "good": true})

	# perfil da equipe para o serviço: a habilidade nos atributos que o serviço pede soma ou tira
	if not team_members(p).is_empty():
		var fit := team_fit(p)
		var fb := clampf((fit - FIT_NEUTRAL) * FIT_PER_POINT, -FIT_PENALTY_MAX, FIT_BONUS_MAX)
		if absf(fb) >= 0.5:
			score += fb
			var attr_names: Array = key_attrs(p.services).map(func(a): return Employee.ATTR_NAMES.get(a, a))
			breakdown.append({"label": "Perfil da equipe (%s: média %d)" % [", ".join(attr_names), int(roundf(fit))],
				"text": "%s%d" % ["+" if fb > 0 else "", int(roundf(fb))], "good": fb > 0})

	var mult: float = game.services.match_multiplier(p.match_quality)
	if mult != 1.0:
		var before := score
		score *= mult
		breakdown.append({"label": ServiceSystem.MATCH_NAMES.get(p.match_quality, "Combinação"),
			"text": "%s%d" % ["+" if score >= before else "", int(roundf(score - before))], "good": score >= before})

	if p.addresses_problem:
		if c != null and c.diagnosed:
			score += BONUS_DIAGNOSIS
			breakdown.append({"label": "Diagnóstico aplicado na estratégia", "text": "+%d" % int(BONUS_DIAGNOSIS), "good": true})
		else:
			score += BONUS_DIAGNOSIS_LUCKY
			breakdown.append({"label": "Acertou o problema sem diagnóstico", "text": "+%d" % int(BONUS_DIAGNOSIS_LUCKY), "good": true})

	var specialist_bonus := 0.0
	var specialist_names: Array = []
	for sid in p.services:
		for e in team_members(p):
			if e.role == sid:
				specialist_bonus += BONUS_SPECIALIST
				specialist_names.append(game.content.service_name(sid))
				break
	specialist_bonus = minf(specialist_bonus, BONUS_SPECIALIST_MAX)
	if specialist_bonus > 0.0:
		score += specialist_bonus
		breakdown.append({"label": "Especialista em %s" % ", ".join(specialist_names), "text": "+%d" % int(specialist_bonus), "good": true})

	if not briefing.is_empty():
		var keys := key_services_in(p)
		if not keys.is_empty():
			var kb := minf(BONUS_KEY_SERVICE * float(keys.size()), BONUS_KEY_SERVICE_MAX)
			score += kb
			breakdown.append({"label": "%s %s: %s" % [String(briefing.get("icon", "")), String(briefing.get("name", "Briefing")), ", ".join(keys.map(func(sid): return game.content.service_name(sid)))],
				"text": "+%d" % int(kb), "good": true})

	var chem: Dictionary = game.chemistry.team_chemistry(team_members(p))
	var chem_score: int = chem["score"]
	if chem_score != 0:
		var cb := ChemistrySystem.SCORE_BONUS * float(chem_score)
		score += cb
		breakdown.append({"label": "Química da equipe (%s)" % ("sinergia" if chem_score > 0 else "atrito"),
			"text": "%s%d" % ["+" if cb > 0 else "", int(cb)], "good": cb > 0})

	var trending: Array = p.services.filter(func(sid): return game.era.is_trending(sid))
	if not trending.is_empty():
		score += BONUS_TRENDING
		var trending_names: Array = trending.map(func(sid): return game.content.service_name(sid))
		breakdown.append({"label": "Em alta em %s: %s" % [String(game.era.current().get("id", "")), ", ".join(trending_names)],
			"text": "+%d" % int(BONUS_TRENDING), "good": true})

	var cold: Array = p.services.filter(func(sid): return game.era.is_cold(sid))
	if not cold.is_empty():
		score -= PENALTY_COLD
		var cold_names: Array = cold.map(func(sid): return game.content.service_name(sid))
		breakdown.append({"label": "Em baixa no mercado: %s" % ", ".join(cold_names),
			"text": "-%d" % int(PENALTY_COLD), "good": false})

	var difficulty := c.difficulty if c != null else 1
	if difficulty > 1:
		var before_d := score
		score *= 1.0 - 0.06 * (difficulty - 1)
		breakdown.append({"label": "Cliente difícil (tier %d)" % (c.tier if c != null else 1), "text": "%d" % int(roundf(score - before_d)), "good": false})

	var days: int = predicted_days if predicted_days >= 0 else p.days_elapsed
	var late_days := maxi(0, days - p.deadline_days)
	if p.kind != Project.Kind.RETAINER:
		if late_days > 0:
			var penalty := minf(20.0, late_days * 0.8)
			score -= penalty
			breakdown.append({"label": "%d dias de atraso" % late_days, "text": "-%d" % int(roundf(penalty)), "good": false})
		else:
			score += BONUS_ON_TIME
			breakdown.append({"label": "Entrega no prazo", "text": "+%d" % int(BONUS_ON_TIME), "good": true})
	elif predicted_days < 0:
		var before_r := score
		score *= 0.6 + 0.4 * p.progress()
		if p.progress() < 0.999:
			breakdown.append({"label": "Mês com %d%% do trabalho feito" % int(p.progress() * 100), "text": "%d" % int(roundf(score - before_r)), "good": false})
	score = clampf(score, 0.0, 100.0)

	var shift := 0.0
	if c != null and c.expectation == "alta":
		shift += 3.0
	elif c != null and c.expectation == "baixa":
		shift -= 3.0
	if c != null:
		shift += (c.price_factor - 1.0) * 10.0
	if absf(shift) >= 0.5:
		breakdown.append({"label": "Expectativa do cliente" + (" (preço acima da referência)" if c != null and c.price_factor > 1.05 else ""),
			"text": "%s%d pontos por estrela" % ["+" if shift > 0 else "", int(roundf(shift))], "good": shift < 0})

	var stars := 1
	for t in STAR_THRESHOLDS:
		if score >= float(t) + shift:
			stars += 1
	var next_gap := 0.0
	if stars < 5:
		next_gap = float(STAR_THRESHOLDS[stars - 1]) + shift - score
	return {"score": score, "stars": stars, "finals": finals, "breakdown": breakdown, "shift": shift,
		"late_days": late_days, "next_gap": next_gap}


func evaluate(p: Project) -> Dictionary:
	var st: GameState = game.state
	var c: Client = st.client_by_id(p.client_id)
	var r := _score(p, c, true)
	var stars: int = r.stars
	var payment: float = p.budget * PAYMENT_MULT[stars]
	var tier := c.tier if c != null else 1
	# 3 estrelas já rende reputação; 2 fica neutro; 1 custa.
	var rep_delta := (stars - 2) * (0.4 + tier * 0.3)
	if stars == 5 and p.match_quality == "perfect":
		rep_delta += 2.0
	rep_delta *= float(briefing_of(p).get("rep_mult", 1.0))   # crise: reputação em jogo dobrada
	var roi := snappedf((0.5 + r.score / 100.0 * 4.5) * game.services.match_multiplier(p.match_quality), 0.1)
	return {"score": r.score, "stars": stars, "payment": payment, "rep_delta": rep_delta, "roi": roi,
		"late_days": r.late_days, "indicators": r.finals, "match": p.match_quality,
		"breakdown": r.breakdown, "next_gap": r.next_gap, "shift": r.shift,
		"client_name": c.name if c != null else "", "project_title": p.title, "kind": p.kind}


## Previsão antes de iniciar: nota, estrelas, detalhamento e dicas do que faria a nota subir.
func predict(c: Client, services: Array, team_ids: Array, kind: int) -> Dictionary:
	var q := quote(c, kind)
	var tmp := Project.new()
	tmp.client_id = c.id
	tmp.kind = kind
	tmp.services = services.duplicate()
	tmp.team = team_ids.duplicate()
	tmp.effort_total = float(q.effort)
	tmp.deadline_days = int(q.deadline)
	tmp.match_quality = game.services.match_quality(c.segment, services)
	tmp.addresses_problem = game.services.addresses_problem(c.problem, services)
	var briefing: Dictionary = briefing_for(c) if kind == Project.Kind.PROJECT else {}
	tmp.briefing = String(briefing.get("id", ""))
	compute_targets(tmp)
	var days := estimated_days(tmp) if not team_ids.is_empty() else 0
	var r := _score(tmp, c, false, days)
	var hints: Array = []
	if not briefing.is_empty() and key_services_in(tmp).size() < 2:
		var key_names: Array = (briefing.get("key_services", []) as Array).filter(func(sid): return game.services.is_unlocked(sid)).map(func(sid): return game.content.service_name(sid))
		if not key_names.is_empty():
			hints.append("O briefing pede %s: +%d por serviço-chave (até +%d)." % [", ".join(key_names), int(BONUS_KEY_SERVICE), int(BONUS_KEY_SERVICE_MAX)])
	if not c.diagnosed:
		hints.append("Diagnóstico do cliente: +%d na nota e +15 de Estratégia se a solução for certa." % int(BONUS_DIAGNOSIS))
	if tmp.match_quality != "perfect":
		var best: Array = game.content.match_table.get(c.segment, {}).get("best", []).map(func(sid): return game.content.service_name(sid))
		hints.append("Combinação perfeita para %s: dois destes serviços (%s) rende ×1,35." % [game.clients.segment_name(c), ", ".join(best)])
	var missing: Array = []
	for sid in services:
		var has := false
		for id in team_ids:
			var e: Employee = game.state.employee_by_id(id)
			if e != null and e.role == sid:
				has = true
		if not has:
			missing.append(game.content.service_name(sid))
	if not missing.is_empty():
		hints.append("Especialista em %s na equipe: +%d por serviço." % [", ".join(missing), int(BONUS_SPECIALIST)])
	if not team_ids.is_empty() and not services.is_empty():
		var fit := team_fit(tmp)
		var attr_names: Array = key_attrs(services).map(func(a): return Employee.ATTR_NAMES.get(a, a))
		if fit < FIT_NEUTRAL - 4.0:
			hints.append("Esse trabalho pede %s: a equipe tem média %d nisso (%d de nota). Escale alguém forte nesses atributos ou treine." % [", ".join(attr_names), int(roundf(fit)), int(roundf(clampf((fit - FIT_NEUTRAL) * FIT_PER_POINT, -FIT_PENALTY_MAX, 0.0)))])
	var already_trending: bool = services.any(func(sid): return game.era.is_trending(sid))
	if not already_trending and not game.era.trending_names().is_empty():
		hints.append("Em alta agora: %s (+%d na nota)." % [", ".join(game.era.trending_names()), int(BONUS_TRENDING)])
	if days > int(q.deadline):
		hints.append("Previsão de atraso (%d dias para %d de prazo): mais gente na equipe evita a penalidade." % [days, int(q.deadline)])
	var chem_members: Array = []
	for id in team_ids:
		var e: Employee = game.state.employee_by_id(id)
		if e != null:
			chem_members.append(e)
	return {"score": r.score, "stars": r.stars, "breakdown": r.breakdown, "hints": hints, "days": days,
		"deadline": int(q.deadline), "budget": q.budget, "match": tmp.match_quality,
		"addresses_problem": tmp.addresses_problem, "targets": tmp.targets.duplicate(), "next_gap": r.next_gap,
		"briefing": briefing, "chemistry": game.chemistry.team_chemistry(chem_members)}


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
		EventBus.office_feedback.emit(e.id, "+%d XP" % int(12.0 + p.budget / 2500.0), "good" if stars >= 3 else "bad")
		game.employees.gain_experience(e, 12.0 + p.budget / 2500.0)
		var growth: float = 0.6 + e.potential * 0.25
		for s in p.services:
			var weights: Dictionary = game.content.services.get(s, {}).get("weights", {})
			for key in weights:
				e.attrs[key] = clampf(e.attr(key) + float(weights[key]) * growth * st.rng.randf_range(0.5, 1.5), 1.0, 100.0)
		game.employees.change_morale(e, {5: 5.0, 4: 3.0, 3: 0.0, 2: -4.0, 1: -8.0}.get(stars, 0.0))
		if stars == 5:
			game.employees.good_news(e)
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
