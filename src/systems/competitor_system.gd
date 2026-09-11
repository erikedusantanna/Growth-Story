class_name CompetitorSystem
extends RefCounted
## Concorrência (GDD §30-31 e §35) em três frentes:
## 1. Prospects esquecidos são fechados por uma rival antes de você (como antes).
## 2. Rivais reais (data/competitors.json) dominam as regiões 2–4 do World Map. Quando você chega
##    à região delas, ganham carteira (3 clientes) e equipe (2 pessoas) e todo mês podem fazer
##    proposta a um funcionário seu ou a um cliente seu — você responde num evento.
## 3. Você pode investir contra elas pelo mapa: propor a um cliente delas ou contratar alguém da
##    equipe, 1 investida a cada 3 meses. Se der certo, perde reputação (−5 cliente, −3 pessoa) e
##    a rival fica agressiva por 3 meses.

var game
var _last_steal_day := -9999


func setup(g) -> void:
	game = g


func _data() -> Dictionary:
	return game.content.competitors


func agencies() -> Array:
	return _data().get("agencies", [])


func agency_names() -> Array:
	return agencies().map(func(a): return String(a.get("name", "")))


func agency_by_id(id: String) -> Dictionary:
	for a in agencies():
		if String(a.get("id", "")) == id:
			return a
	return {}


## Rivais das regiões já alcançadas (só as que têm região no mapa).
func active_rivals() -> Array:
	var out: Array = []
	for a in agencies():
		var r := int(a.get("region", 0))
		if r >= 1 and r <= game.office.region():
			out.append(a)
	return out


func rival_state(id: String) -> Dictionary:
	return game.state.rivals.get(id, {})


## Cria carteira e equipe das rivais das regiões alcançadas (idempotente).
func ensure_rivals() -> void:
	var st: GameState = game.state
	for a in active_rivals():
		var id := String(a.get("id", ""))
		if not st.rivals.has(id):
			st.rivals[id] = _generate(a)
		_top_up(a, st.rivals[id])


func _generate(a: Dictionary) -> Dictionary:
	return {"strength": float(a.get("strength", 40)), "aggressive_until": -1, "clients": [], "staff": [], "wins": 0, "losses": 0}


func _top_up(a: Dictionary, rs: Dictionary) -> void:
	while (rs.clients as Array).size() < 3:
		(rs.clients as Array).append(_make_rival_client(a))
	while (rs.staff as Array).size() < 2:
		(rs.staff as Array).append(_make_rival_staff(a))


func _make_rival_client(a: Dictionary) -> Dictionary:
	var st: GameState = game.state
	var tier := int(a.get("region", 2))
	var known: Array = st.clients.map(func(c): return c.template_id)
	for rs in st.rivals.values():
		for cd in rs.get("clients", []):
			known.append(String(cd.get("template_id", "")))
	var pool: Array = game.content.client_templates.filter(func(t): return int(t["tier"]) == tier and not (t["id"] in known))
	var bond: String = ["fragil", "morna", "solida"][st.rng.randi_range(0, 2)]
	if not pool.is_empty():
		var t: Dictionary = pool[st.rng.randi_range(0, pool.size() - 1)]
		return {"template_id": t["id"], "name": t["name"], "segment": t["segment"], "tier": tier, "budget": float(t["budget"]), "bond": bond}
	var tmp := Client.new()
	tmp.id = st.new_id()
	game.clients._fill_procedural(tmp, tier)
	tmp.tier = tier
	return {"template_id": tmp.template_id, "name": tmp.name, "segment": tmp.segment, "tier": tier, "budget": tmp.budget, "bond": bond,
		"personality": tmp.personality, "goal": tmp.goal, "problem": tmp.problem, "expectation": tmp.expectation, "patience": tmp.patience,
		"maturity": tmp.maturity, "difficulty": tmp.difficulty}


func _make_rival_staff(a: Dictionary) -> Dictionary:
	var e: Employee = game.employees.generate_candidate("high")
	e.role = String(a.get("specialty", e.role))
	e.hired_on = -1
	e.candidate_expires = 0
	return e.to_dict()


func bond_name(bond: String) -> String:
	return {"fragil": "relação frágil", "morna": "relação morna", "solida": "relação sólida"}.get(bond, bond)


func is_aggressive(id: String) -> bool:
	return int(rival_state(id).get("aggressive_until", -1)) >= game.state.day


# --- Investidas do jogador (pelo mapa) -------------------------------------------------

func raid_cooldown_days() -> int:
	return int(_data().get("raid_cooldown_days", 90))


func can_raid() -> Dictionary:
	var st: GameState = game.state
	var left: int = raid_cooldown_days() - (st.day - st.last_raid_day)
	if st.last_raid_day >= 0 and left > 0:
		return {"ok": false, "reason": "Próxima investida em %d dias." % left, "days_left": left}
	return {"ok": true, "reason": "", "days_left": 0}


func raid_chance_client(a: Dictionary, cd: Dictionary) -> float:
	var st: GameState = game.state
	var best_comm := 0.0
	for e in st.employees:
		best_comm = maxf(best_comm, e.attr("communication"))
	var strength := float(rival_state(String(a.get("id", ""))).get("strength", a.get("strength", 40)))
	var bond_bonus: float = {"fragil": 20.0, "morna": 0.0, "solida": -20.0}.get(String(cd.get("bond", "morna")), 0.0)
	return clampf(35.0 + best_comm * 0.3 + st.reputation * 0.2 - strength * 0.3 + bond_bonus, 5.0, 90.0)


func raid_chance_employee(a: Dictionary, sd: Dictionary) -> float:
	var st: GameState = game.state
	var strength := float(rival_state(String(a.get("id", ""))).get("strength", a.get("strength", 40)))
	return clampf(30.0 + st.reputation * 0.3 + (100.0 - strength) * 0.2 - float(sd.get("loyalty", 50)) * 0.2, 10.0, 85.0)


func signing_bonus(sd: Dictionary) -> float:
	return float(sd.get("salary", 0)) * 2.0


## Proposta a um cliente da rival. force: -1 sorteia, 1 força sucesso, 0 força falha (testes).
func raid_client(id: String, index: int, force: int = -1) -> Dictionary:
	var st: GameState = game.state
	var check := can_raid()
	if not check.ok:
		return {"ok": false, "success": false, "reason": check.reason}
	var a := agency_by_id(id)
	var rs := rival_state(id)
	if a.is_empty() or rs.is_empty() or index < 0 or index >= (rs.clients as Array).size():
		return {"ok": false, "success": false, "reason": "Cliente não encontrado."}
	var cd: Dictionary = rs.clients[index]
	var chance := raid_chance_client(a, cd)
	var success: bool = (st.rng.randf() * 100.0 < chance) if force < 0 else force == 1
	st.last_raid_day = st.day
	if success:
		(rs.clients as Array).remove_at(index)
		var c := _adopt_client(cd)
		rs["strength"] = maxf(10.0, float(rs.get("strength", 40)) - 5.0)
		rs["aggressive_until"] = st.day + int(_data().get("aggressive_days", 90))
		rs["losses"] = int(rs.get("losses", 0)) + 1
		game.reputation.penalize(float(_data().get("rep_cost_client", 5)), "caça a cliente de rival")
		game.add_log("⚔️ %s trocou %s pela %s. O mercado comenta a caça (−%d de reputação); %s promete revanche." % [
			c.name, String(a.get("name", "")), st.agency_name, int(_data().get("rep_cost_client", 5)), String(a.get("name", ""))], "warn")
		EventBus.state_changed.emit()
		return {"ok": true, "success": true, "chance": chance, "reason": "", "client": c}
	game.add_log("⚔️ %s recusou a proposta e continua com %s." % [String(cd.get("name", "")), String(a.get("name", ""))], "warn")
	EventBus.state_changed.emit()
	return {"ok": true, "success": false, "chance": chance, "reason": ""}


## Contratar alguém da equipe da rival (bônus de assinatura de 2 salários; salário 10% acima).
func raid_employee(id: String, index: int, force: int = -1) -> Dictionary:
	var st: GameState = game.state
	var check := can_raid()
	if not check.ok:
		return {"ok": false, "success": false, "reason": check.reason}
	var a := agency_by_id(id)
	var rs := rival_state(id)
	if a.is_empty() or rs.is_empty() or index < 0 or index >= (rs.staff as Array).size():
		return {"ok": false, "success": false, "reason": "Pessoa não encontrada."}
	var sd: Dictionary = rs.staff[index]
	if st.employees.size() >= game.office.capacity():
		return {"ok": false, "success": false, "reason": "Escritório lotado. Amplie antes de contratar."}
	var bonus := signing_bonus(sd)
	if st.money < bonus + float(sd.get("salary", 0)):
		return {"ok": false, "success": false, "reason": "Caixa insuficiente para o bônus de assinatura (%s)." % FinanceSystem.format_money(bonus)}
	var chance := raid_chance_employee(a, sd)
	var success: bool = (st.rng.randf() * 100.0 < chance) if force < 0 else force == 1
	st.last_raid_day = st.day
	if success:
		(rs.staff as Array).remove_at(index)
		var e := Employee.from_dict(sd)
		e.id = st.new_id()
		e.salary = roundf(e.salary * 1.1 / 50.0) * 50.0
		e.loyalty = 50.0
		e.motivation = 65.0
		st.candidates.append(e)
		var hired: Dictionary = game.employees.hire(e)
		if not hired.ok:
			st.candidates.erase(e)
			return {"ok": false, "success": false, "reason": hired.reason}
		game.finance.add_money(-bonus, "Bônus de assinatura: %s" % e.name, "expense")
		game.employees.add_journey(e, "Veio da %s com bônus de assinatura" % String(a.get("name", "")))
		rs["strength"] = maxf(10.0, float(rs.get("strength", 40)) - 3.0)
		rs["aggressive_until"] = st.day + int(_data().get("aggressive_days", 90))
		rs["losses"] = int(rs.get("losses", 0)) + 1
		game.reputation.penalize(float(_data().get("rep_cost_employee", 3)), "caça a talento de rival")
		game.add_log("⚔️ %s deixou a %s pela %s (−%d de reputação: o mercado fala em caça de talentos)." % [
			e.name, String(a.get("name", "")), st.agency_name, int(_data().get("rep_cost_employee", 3))], "warn")
		EventBus.state_changed.emit()
		return {"ok": true, "success": true, "chance": chance, "reason": "", "employee": e}
	game.add_log("⚔️ %s recusou sua oferta e ficou na %s." % [String(sd.get("name", "")), String(a.get("name", ""))], "warn")
	EventBus.state_changed.emit()
	return {"ok": true, "success": false, "chance": chance, "reason": ""}


func _adopt_client(cd: Dictionary) -> Client:
	var st: GameState = game.state
	var c := Client.new()
	c.id = st.new_id()
	var t: Dictionary = {}
	for tpl in game.content.client_templates:
		if String(tpl.get("id", "")) == String(cd.get("template_id", "")):
			t = tpl
	c.template_id = String(cd.get("template_id", "proc_%d" % c.id))
	c.name = String(cd.get("name", t.get("name", "Cliente")))
	c.segment = String(cd.get("segment", t.get("segment", "servicos")))
	c.tier = int(cd.get("tier", t.get("tier", 2)))
	c.budget = float(cd.get("budget", t.get("budget", 5000)))
	c.expectation = String(cd.get("expectation", t.get("expectation", "media")))
	c.patience = float(cd.get("patience", t.get("patience", 50)))
	c.maturity = int(cd.get("maturity", t.get("maturity", 1)))
	c.personality = String(cd.get("personality", t.get("personality", "loyal")))
	c.difficulty = int(cd.get("difficulty", t.get("difficulty", c.tier)))
	c.goal = String(cd.get("goal", t.get("goal", "Quero resultados melhores que os da agência anterior.")))
	c.problem = String(cd.get("problem", t.get("problem", "leads")))
	c.status = Client.Status.ACTIVE
	c.known_on = st.day
	c.relationship = 40.0
	st.clients.append(c)
	st.stats["clients_signed"] = int(st.stats.get("clients_signed", 0)) + 1
	EventBus.client_signed.emit(c)
	return c


# --- Investidas das rivais (todo mês) ----------------------------------------------------

func on_month() -> void:
	var st: GameState = game.state
	ensure_rivals()
	if not st.pending_event.is_empty():
		return
	for a in active_rivals():
		var id := String(a.get("id", ""))
		var chance := float(a.get("aggression", 0.3)) * (2.0 if is_aggressive(id) else 1.0)
		if st.rng.randf() >= chance:
			continue
		if st.rng.randf() < 0.5 and rival_offer_employee(id):
			return
		if rival_offer_client(id):
			return


## A rival tenta levar o funcionário de menor lealdade. Devolve true se abriu o evento.
func rival_offer_employee(id: String) -> bool:
	var st: GameState = game.state
	var a := agency_by_id(id)
	var target: Employee = null
	for e in st.employees:
		if e.is_founder:
			continue
		if target == null or e.loyalty < target.loyalty:
			target = e
	if target == null or not st.pending_event.is_empty():
		return false
	target.last_offer_day = st.day
	game.events.trigger({
		"id": "rival_offer_employee", "title": "⚔️ Proposta da %s" % String(a.get("name", "")),
		"text": "%s ofereceu a %s um salário 25%% maior para trocar de agência. %s" % [String(a.get("name", "")), target.name,
			"Ela está agressiva depois da sua investida." if is_aggressive(id) else "Lealdade atual: %d." % int(target.loyalty)],
		"choices": [
			{"label": "Cobrir a oferta (+20% de salário)", "effects": [{"type": "raise_best", "value": 0.2}, {"type": "loyalty_best", "value": 20}]},
			{"label": "Promover", "effects": [{"type": "promote_best"}, {"type": "loyalty_best", "value": 10}]},
			{"label": "Deixar sair", "effects": [{"type": "lose_best"}, {"type": "rival_strength", "rival": id, "value": 4}]},
		],
		"targets": {"employee_id": target.id}, "scene": "boardroom"})
	return true


## A rival tenta levar o cliente de relação mais fraca. Devolve true se abriu o evento.
func rival_offer_client(id: String) -> bool:
	var st: GameState = game.state
	var a := agency_by_id(id)
	var target: Client = null
	for c in st.active_clients():
		if c.tier > int(a.get("region", 2)) + 1:
			continue
		if target == null or c.relationship < target.relationship:
			target = c
	if target == null or target.relationship >= 60.0 or not st.pending_event.is_empty():
		return false
	game.events.trigger({
		"id": "rival_offer_client", "title": "⚔️ %s quer %s" % [String(a.get("name", "")), target.name],
		"text": "%s ofereceu 15%% de desconto para %s. A relação de vocês está em %d." % [String(a.get("name", "")), target.name, int(target.relationship)],
		"choices": [
			{"label": "Igualar (orçamento −15%)", "effects": [{"type": "client_budget_mult", "value": 0.85}, {"type": "client_relationship", "value": 10}]},
			{"label": "Reunião de retenção", "effects": [{"type": "client_retention", "rival": id}]},
			{"label": "Deixar ir", "effects": [{"type": "lose_client_target", "rival": id}]},
		],
		"targets": {"client_id": target.id}, "scene": "boardroom"})
	return true


## Efeitos usados pelos eventos das rivais (chamados por EventSystem._apply_effect).
func apply_rival_effect(effect: Dictionary, target_client: Client) -> void:
	var st: GameState = game.state
	var id := String(effect.get("rival", ""))
	var a := agency_by_id(id)
	var rs := rival_state(id)
	match String(effect.get("type", "")):
		"rival_strength":
			if not rs.is_empty():
				rs["strength"] = clampf(float(rs.get("strength", 40)) + float(effect.get("value", 0)), 10.0, 100.0)
				rs["wins"] = int(rs.get("wins", 0)) + 1
		"client_retention":
			if target_client == null:
				return
			var best_comm := 0.0
			for e in st.employees:
				best_comm = maxf(best_comm, e.attr("communication"))
			var chance := clampf(40.0 + best_comm * 0.5, 20.0, 95.0)
			if st.rng.randf() * 100.0 < chance:
				target_client.relationship = clampf(target_client.relationship + 15.0, 0.0, 100.0)
				game.add_log("🤝 Reunião de retenção funcionou: %s fica (chance era %d%%)." % [target_client.name, int(chance)], "client")
			else:
				game.clients.lose_client(target_client, "foi para a %s" % String(a.get("name", "")))
				game.reputation.add(-1.0)
				if not rs.is_empty():
					rs["strength"] = clampf(float(rs.get("strength", 40)) + 3.0, 10.0, 100.0)
					rs["wins"] = int(rs.get("wins", 0)) + 1
		"lose_client_target":
			if target_client != null:
				game.clients.lose_client(target_client, "foi para a %s" % String(a.get("name", "")))
				game.reputation.add(-1.0)
				if not rs.is_empty():
					rs["strength"] = clampf(float(rs.get("strength", 40)) + 3.0, 10.0, 100.0)
					rs["wins"] = int(rs.get("wins", 0)) + 1


# --- Prospects esquecidos (mecânica anterior) ----------------------------------------------

func on_day() -> void:
	var st: GameState = game.state
	ensure_rivals()
	if st.day < int(_data().get("min_day", 60)):
		return
	if st.day == _last_steal_day:
		return
	var idle_days := int(_data().get("steal_after_idle_days", 22))
	var chance := float(_data().get("steal_chance_per_day", 0.05))
	for c in st.prospects():
		if st.day - c.known_on < idle_days:
			continue
		if st.rng.randf() < chance:
			var names: Array = agency_names()
			var agency: String = names[st.rng.randi_range(0, names.size() - 1)]
			var actives := active_rivals()
			if not actives.is_empty():
				agency = String(actives[st.rng.randi_range(0, actives.size() - 1)].get("name", agency))
			game.clients.lose_client(c, "foi fechado por %s antes de você" % agency)
			_last_steal_day = st.day
			break
