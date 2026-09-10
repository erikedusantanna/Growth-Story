class_name ClientSystem
extends RefCounted
## Prospecção, fechamento, diagnóstico e relacionamento com clientes.

const MAX_PROSPECTS := 3
const PROSPECT_INTERVAL := 15
const IDLE_DAYS_BEFORE_DECAY := 45

const PROCEDURAL_NAMES := {
	"alimentacao": ["Cantina da {n}", "Burger {n}", "Padaria {n}", "Sushi {n}", "Café {n}"],
	"varejo": ["Loja {n}", "Magazine {n}", "{n} Store", "Empório {n}"],
	"servicos": ["Studio {n}", "Clínica {n}", "Escola {n}", "Consultoria {n}"],
	"tecnologia": ["{n} Tech", "{n} App", "{n} Labs", "{n} Cloud"],
	"fashion": ["{n} Moda", "Ateliê {n}", "{n} Beauty"],
	"industria": ["Indústria {n}", "{n} Metais", "Grupo {n}"],
	"saude": ["Clínica {n}", "Lab {n}", "Odonto {n}"],
	"imobiliario": ["Imobiliária {n}", "{n} Incorporações", "Construtora {n}"],
}

var game


func setup(g) -> void:
	game = g


## Tier máximo dos prospects: reputação abre portas, mas o tamanho da equipe limita
## (um cliente tier 3 exige estrutura; sem isso o projeto atrasa e vira 1 estrela).
func max_tier() -> int:
	var rep: float = game.state.reputation
	var by_rep := 1
	if rep >= 80.0:
		by_rep = 5
	elif rep >= 60.0:
		by_rep = 4
	elif rep >= 40.0:
		by_rep = 3
	elif rep >= 20.0:
		by_rep = 2
	var by_team: int = 1 + game.state.employees.size() / 3
	return clampi(mini(by_rep, by_team), 1, 5)


func segment_name(c: Client) -> String:
	return game.content.segment_names.get(c.segment, c.segment)


func personality_name(c: Client) -> String:
	return game.content.client_personalities.get(c.personality, {}).get("name", c.personality)


func problem_name(c: Client) -> String:
	return game.content.problem_names.get(c.problem, c.problem)


# --- Prospecção -----------------------------------------------------------------

func spawn_prospect(tier_bonus: int = 0) -> Client:
	var st: GameState = game.state
	var tier_cap := mini(max_tier() + tier_bonus, 5)
	var known: Array = st.clients.map(func(c): return c.template_id)
	var pool: Array = game.content.client_templates.filter(
		func(t): return int(t["tier"]) <= tier_cap and int(t["tier"]) >= tier_cap - 1 and not (t["id"] in known))
	var c := Client.new()
	c.id = st.new_id()
	if not pool.is_empty():
		var t: Dictionary = pool[st.rng.randi_range(0, pool.size() - 1)]
		c.template_id = t["id"]
		c.name = t["name"]
		c.segment = t["segment"]
		c.tier = int(t["tier"])
		c.budget = float(t["budget"])
		c.expectation = t.get("expectation", "media")
		c.patience = float(t.get("patience", 50))
		c.maturity = int(t.get("maturity", 1))
		c.personality = t.get("personality", "loyal")
		c.difficulty = int(t.get("difficulty", 1))
		c.goal = t.get("goal", "")
		c.problem = t.get("problem", "leads")
	else:
		_fill_procedural(c, tier_cap)
	c.status = Client.Status.PROSPECT
	c.known_on = st.day
	c.relationship = 40.0 + float(game.content.client_personalities.get(c.personality, {}).get("relationship_mod", 0))
	st.clients.append(c)
	game.add_log("Novo prospect: %s (%s)." % [c.name, segment_name(c)], "client")
	EventBus.state_changed.emit()
	return c


func _fill_procedural(c: Client, tier_cap: int) -> void:
	var st: GameState = game.state
	var rng := st.rng
	var segments: Array = game.content.segment_names.keys()
	c.segment = segments[rng.randi_range(0, segments.size() - 1)]
	c.tier = maxi(1, tier_cap - rng.randi_range(0, 1))
	var patterns: Array = PROCEDURAL_NAMES.get(c.segment, ["Empresa {n}"])
	var surname: String = game.content.names.last[rng.randi_range(0, game.content.names.last.size() - 1)]
	c.template_id = "proc_%d" % c.id
	c.name = patterns[rng.randi_range(0, patterns.size() - 1)].replace("{n}", surname)
	var budgets := [3000.0, 9000.0, 20000.0, 45000.0, 120000.0]
	c.budget = budgets[c.tier - 1] * rng.randf_range(0.8, 1.3)
	c.budget = roundf(c.budget / 100.0) * 100.0
	c.expectation = ["baixa", "media", "alta"][rng.randi_range(0, 2)]
	c.patience = rng.randf_range(30.0, 75.0)
	c.maturity = rng.randi_range(1, 3)
	var pkeys: Array = game.content.client_personalities.keys()
	c.personality = pkeys[rng.randi_range(0, pkeys.size() - 1)]
	c.difficulty = clampi(c.tier + rng.randi_range(-1, 0), 1, 5)
	var goals := ["Quero vender mais.", "Preciso de mais clientes.", "Quero ser lembrado no mercado.", "Quero um funil que funcione."]
	c.goal = goals[rng.randi_range(0, goals.size() - 1)]
	var problems: Array = game.content.problem_solutions.keys()
	c.problem = problems[rng.randi_range(0, problems.size() - 1)]


const PRICE_MIN := 0.6
const PRICE_MAX := 1.4
const PRICE_CHANCE_PER_PERCENT := 0.6   # cada 1% de desconto = +0,6 pontos de chance


## Chance de fechar (0–100). price_factor < 1 é desconto (mais fácil), > 1 é prêmio (mais difícil).
func proposal_chance(c: Client, price_factor: float = 1.0) -> float:
	var st: GameState = game.state
	var best_comm := 0.0
	var seller_bonus := 0.0
	for e in st.employees:
		best_comm = maxf(best_comm, e.attr("communication"))
		if e.personality == "vendedor":
			seller_bonus = 10.0
	var chance := 45.0 + best_comm * 0.35 + st.reputation * 0.3 - c.difficulty * 8.0 - c.proposal_attempts * 12.0 + seller_bonus
	chance += (1.0 - clampf(price_factor, PRICE_MIN, PRICE_MAX)) * 100.0 * PRICE_CHANCE_PER_PERCENT
	return clampf(chance, 5.0, 95.0)


func proposed_budget(c: Client, price_factor: float) -> float:
	return roundf(c.budget * clampf(price_factor, PRICE_MIN, PRICE_MAX) / 100.0) * 100.0


## Tenta fechar contrato com um prospect pelo preço proposto. Retorna {ok, success, chance}.
func propose(c: Client, price_factor: float = 1.0) -> Dictionary:
	var st: GameState = game.state
	if c.status != Client.Status.PROSPECT:
		return {"ok": false, "success": false, "chance": 0.0, "reason": "Não é um prospect."}
	var chance := proposal_chance(c, price_factor)
	var success: bool = st.rng.randf() * 100.0 < chance
	c.proposal_attempts += 1
	if success:
		c.budget = proposed_budget(c, price_factor)
		c.price_factor = clampf(price_factor, PRICE_MIN, PRICE_MAX)
		c.status = Client.Status.ACTIVE
		c.relationship = clampf(c.relationship + 10.0, 0.0, 100.0)
		st.stats["clients_signed"] = int(st.stats["clients_signed"]) + 1
		game.add_log("Contrato fechado com %s!" % c.name, "client")
		EventBus.client_signed.emit(c)
	else:
		if c.proposal_attempts >= 3:
			c.status = Client.Status.LOST
			game.add_log("%s fechou com outra agência." % c.name, "warn")
			EventBus.client_lost.emit(c)
		else:
			game.add_log("%s pediu para \"pensar melhor\". Tente de novo." % c.name, "warn")
	EventBus.state_changed.emit()
	return {"ok": true, "success": success, "chance": chance, "reason": ""}


func drop_prospect(c: Client) -> void:
	if c.status == Client.Status.PROSPECT:
		c.status = Client.Status.LOST
		EventBus.state_changed.emit()


# --- Diagnóstico ----------------------------------------------------------------

func diagnosis_cost(c: Client) -> float:
	return 400.0 * c.tier + 200.0


func diagnosis_days(c: Client) -> int:
	return 3 + c.tier


func can_diagnose(c: Client) -> Dictionary:
	if c.diagnosed:
		return {"ok": false, "reason": "Diagnóstico já realizado."}
	if c.diagnosis_days_left > 0:
		return {"ok": false, "reason": "Diagnóstico em andamento."}
	if game.state.money < diagnosis_cost(c):
		return {"ok": false, "reason": "Caixa insuficiente."}
	return {"ok": true, "reason": ""}


func start_diagnosis(c: Client) -> Dictionary:
	var check := can_diagnose(c)
	if not check.ok:
		return check
	game.finance.add_money(-diagnosis_cost(c), "Diagnóstico: %s" % c.name, "expense")
	c.diagnosis_days_left = diagnosis_days(c)
	game.state.stats["diagnoses"] = int(game.state.stats.get("diagnoses", 0)) + 1
	game.add_log("Auditoria de marketing iniciada em %s." % c.name, "info")
	EventBus.state_changed.emit()
	return {"ok": true, "reason": ""}


# --- Resultados -----------------------------------------------------------------

func on_project_result(c: Client, result: Dictionary) -> void:
	var st: GameState = game.state
	var stars: int = int(result.get("stars", 3))
	var rel_delta := (stars - 3) * 15.0
	if c.personality == "loyal":
		rel_delta += 5.0
	c.relationship = clampf(c.relationship + rel_delta, 0.0, 100.0)
	c.satisfaction = stars
	c.projects_done += 1
	c.last_project_day = st.day
	c.briefing = ""   # próximo projeto vem com um briefing novo
	if stars <= 2 and c.patience < 50.0 and st.rng.randf() < 0.5:
		lose_client(c, "cancelou após resultado ruim")
	elif stars <= 1:
		c.relationship = clampf(c.relationship - 10.0, 0.0, 100.0)


func lose_client(c: Client, reason: String) -> void:
	if c.status == Client.Status.LOST:
		return
	c.status = Client.Status.LOST
	var p: Project = game.state.project_for_client(c.id)
	if p != null:
		game.projects.cancel(p)
	game.add_log("%s %s." % [c.name, reason], "warn")
	EventBus.client_lost.emit(c)
	EventBus.state_changed.emit()


func random_active_client() -> Client:
	var actives: Array = game.state.active_clients()
	if actives.is_empty():
		return null
	return actives[game.state.rng.randi_range(0, actives.size() - 1)]


func retainer_available(c: Client) -> bool:
	return c.is_active() and c.projects_done >= 1 and c.relationship >= 60.0


# --- Ticks ---------------------------------------------------------------------

func on_day() -> void:
	var st: GameState = game.state
	for c in st.clients:
		if c.diagnosis_days_left > 0:
			c.diagnosis_days_left -= 1
			if c.diagnosis_days_left == 0:
				c.diagnosed = true
				game.add_log("Diagnóstico de %s: %s." % [c.name, problem_name(c)], "client")
				EventBus.diagnosis_done.emit(c)
				EventBus.state_changed.emit()
		if c.is_active() and st.project_for_client(c.id) == null:
			var idle_since: int = c.last_project_day if c.last_project_day >= 0 else c.known_on
			if st.day - idle_since > IDLE_DAYS_BEFORE_DECAY:
				c.relationship = clampf(c.relationship - 0.2, 0.0, 100.0)
				if c.relationship <= 5.0:
					lose_client(c, "cansou de esperar e foi embora")
	# Agência desconhecida recebe poucos contatos; reputação traz mais prospects.
	var max_prospects: int = 2 if st.reputation < 20.0 else MAX_PROSPECTS
	if st.day % PROSPECT_INTERVAL == 0 and st.prospects().size() < max_prospects and st.rng.randf() < 0.15 + st.reputation / 160.0:
		spawn_prospect()
