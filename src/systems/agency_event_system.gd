class_name AgencyEventSystem
extends RefCounted
## Eventos promovidos pela agência: custam dinheiro e/ou pessoas por alguns dias e rendem
## reputação, prospects, candidatos, moral ou patrocínio (data/agency_events.json).

var game


func setup(g) -> void:
	game = g


func is_unlocked() -> bool:
	return game.state.reputation >= float(game.content.agency_events.get("unlock", {}).get("reputation", 40))


func events() -> Array:
	return game.content.agency_events.get("events", [])


func event_by_id(id: String) -> Dictionary:
	for ev in events():
		if ev["id"] == id:
			return ev
	return {}


func cooldown_left(ev: Dictionary) -> int:
	var last: int = int(game.state.agency_events_last.get(ev["id"], -9999))
	return maxi(0, int(ev.get("cooldown_days", 0)) - (game.state.day - last))


func is_running(ev: Dictionary) -> bool:
	for r in game.state.agency_events:
		if r.get("id") == ev["id"]:
			return true
	return false


func can_run(ev: Dictionary, people: Array) -> Dictionary:
	var st: GameState = game.state
	if not is_unlocked():
		return {"ok": false, "reason": "Eventos abrem com 40 de reputação."}
	if st.reputation < float(ev.get("requires_rep", 0)):
		return {"ok": false, "reason": "Precisa de %d de reputação." % int(ev["requires_rep"])}
	if st.office_level < int(ev.get("requires_office", 1)):
		return {"ok": false, "reason": "Precisa de um escritório maior."}
	if is_running(ev):
		return {"ok": false, "reason": "Já está acontecendo."}
	if cooldown_left(ev) > 0:
		return {"ok": false, "reason": "Disponível em %d dias." % cooldown_left(ev)}
	if st.money < float(ev.get("cost", 0)):
		return {"ok": false, "reason": "Caixa insuficiente."}
	var needed := int(ev.get("people", 0))
	if people.size() < needed:
		return {"ok": false, "reason": "Escolha %d pessoa%s disponíve%s." % [needed, "" if needed == 1 else "s", "l" if needed == 1 else "is"]}
	for id in people:
		var e: Employee = st.employee_by_id(int(id))
		if e == null or not e.is_available(st.day):
			return {"ok": false, "reason": "Alguém escolhido não está disponível."}
	return {"ok": true, "reason": ""}


func run(ev: Dictionary, people: Array) -> Dictionary:
	var check := can_run(ev, people)
	if not check.ok:
		return check
	var st: GameState = game.state
	var cost := float(ev.get("cost", 0))
	if cost > 0.0:
		game.finance.add_money(-cost, "Evento: %s" % ev["name"], "expense")
	var days := int(ev.get("days", 0))
	for id in people:
		var e: Employee = st.employee_by_id(int(id))
		if e != null and days > 0:
			e.busy_until = st.day + days
			e.busy_reason = "Em evento"
			game.employees.add_journey(e, "Representou a agência em: %s" % ev["name"])
	st.agency_events_last[ev["id"]] = st.day
	st.stats["agency_events"] = int(st.stats.get("agency_events", 0)) + 1
	if days == 0:
		_apply_effects(ev)
		game.add_log("Evento: %s." % ev["name"], "unlock")
	else:
		st.agency_events.append({"id": ev["id"], "ends_day": st.day + days, "people": people.duplicate()})
		game.add_log("Evento começou: %s (%d dias)." % [ev["name"], days], "unlock")
	EventBus.state_changed.emit()
	return {"ok": true, "reason": ""}


func _apply_effects(ev: Dictionary) -> void:
	var st: GameState = game.state
	var fx: Dictionary = ev.get("effects", {})
	var parts: Array = []
	if fx.has("reputation"):
		game.reputation.add(float(fx["reputation"]))
		parts.append("+%d reputação" % int(fx["reputation"]))
	for i in int(fx.get("prospects", 0)):
		game.clients.spawn_prospect(int(fx.get("prospect_tier_bonus", 0)))
	if int(fx.get("prospects", 0)) > 0:
		parts.append("%d prospect(s)" % int(fx["prospects"]))
	for i in int(fx.get("candidates", 0)):
		game.employees.add_candidate("high")
	if int(fx.get("candidates", 0)) > 0:
		parts.append("%d candidato(s)" % int(fx["candidates"]))
	if fx.has("money"):
		game.finance.add_money(float(fx["money"]), "Patrocínio: %s" % ev["name"], "revenue")
		parts.append("patrocínio de %s" % FinanceSystem.format_money(float(fx["money"])))
	if fx.has("morale"):
		for e in st.employees:
			game.employees.change_morale(e, float(fx["morale"]))
		parts.append("+%d moral" % int(fx["morale"]))
	if int(fx.get("delay_days", 0)) > 0:
		game.projects.delay_all(int(fx["delay_days"]))
	game.add_log("Resultado do evento %s: %s." % [ev["name"], ", ".join(parts)], "unlock")


func on_day() -> void:
	var st: GameState = game.state
	var finished: Array = st.agency_events.filter(func(r): return int(r.get("ends_day", 0)) <= st.day)
	for r in finished:
		var ev := event_by_id(String(r.get("id", "")))
		if not ev.is_empty():
			_apply_effects(ev)
		for id in r.get("people", []):
			var e: Employee = st.employee_by_id(int(id))
			if e != null and e.busy_reason == "Em evento":
				e.busy_until = st.day - 1
				e.busy_reason = ""
	if not finished.is_empty():
		st.agency_events = st.agency_events.filter(func(r): return int(r.get("ends_day", 0)) > st.day)
		EventBus.state_changed.emit()
