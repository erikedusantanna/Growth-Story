class_name HRSystem
extends RefCounted
## Departamento de RH: ações que mexem na moral, no estresse e no ritmo dos projetos.
## Libera com escritório profissional + reputação 30 (data/hr_actions.json).

var game


func setup(g) -> void:
	game = g


func unlock_requirements() -> Dictionary:
	return game.content.hr.get("unlock", {"office_level": 3, "reputation": 30})


func is_unlocked() -> bool:
	var req := unlock_requirements()
	var st: GameState = game.state
	return st.office_level >= int(req.get("office_level", 3)) and st.reputation >= float(req.get("reputation", 30))


func actions() -> Array:
	return game.content.hr.get("actions", [])


func action_by_id(id: String) -> Dictionary:
	for a in actions():
		if a["id"] == id:
			return a
	return {}


func total_cost(a: Dictionary) -> float:
	return float(a.get("cost", 0)) + float(a.get("cost_per_employee", 0)) * game.state.employees.size()


func cooldown_left(a: Dictionary) -> int:
	var last: int = int(game.state.hr_last_used.get(a["id"], -9999))
	return maxi(0, int(a.get("cooldown_days", 0)) - (game.state.day - last))


func can_use(a: Dictionary) -> Dictionary:
	var st: GameState = game.state
	if not is_unlocked():
		return {"ok": false, "reason": "RH ainda não aberto."}
	if st.reputation < float(a.get("requires_rep", 0)):
		return {"ok": false, "reason": "Precisa de %d de reputação." % int(a["requires_rep"])}
	if st.office_level < int(a.get("requires_office", 1)):
		return {"ok": false, "reason": "Precisa de um escritório maior."}
	if cooldown_left(a) > 0:
		return {"ok": false, "reason": "Disponível em %d dias." % cooldown_left(a)}
	if st.money < total_cost(a):
		return {"ok": false, "reason": "Caixa insuficiente (%s)." % FinanceSystem.format_money(total_cost(a))}
	return {"ok": true, "reason": ""}


func use(a: Dictionary) -> Dictionary:
	var check := can_use(a)
	if not check.ok:
		return check
	var st: GameState = game.state
	var cost := total_cost(a)
	if cost > 0.0:
		game.finance.add_money(-cost, "RH: %s" % a["name"], "expense")
	var morale := float(a.get("morale", 0))
	var stress := float(a.get("stress", 0))
	var loyalty := float(a.get("loyalty", 0))
	for e in st.employees:
		if morale != 0.0:
			game.employees.change_morale(e, morale)
		if stress != 0.0:
			e.stress = clampf(e.stress + stress, 0.0, 100.0)
		if loyalty != 0.0:
			e.loyalty = clampf(e.loyalty + loyalty, 0.0, 100.0)
		if morale != 0.0:
			EventBus.office_feedback.emit(e.id, "%s%d moral" % ["+" if morale > 0 else "", int(morale)], "good" if morale > 0 else "bad")
	var delay := int(a.get("delay_days", 0))
	if delay > 0:
		game.projects.delay_all(delay)
	if a.has("buff"):
		var b: Dictionary = a["buff"]
		st.buffs.append({"id": a["id"], "name": a["name"], "until_day": st.day + int(b.get("days", 10)),
			"productivity": float(b.get("productivity", 1.0)), "stress_rate": float(b.get("stress_rate", 1.0))})
	st.hr_last_used[a["id"]] = st.day
	st.stats["hr_actions"] = int(st.stats.get("hr_actions", 0)) + 1
	game.add_log("RH: %s.%s" % [a["name"], (" Projetos atrasam %d dias." % delay) if delay > 0 else ""], "promo")
	EventBus.state_changed.emit()
	return {"ok": true, "reason": ""}


## Multiplicadores ativos dos buffs (produtividade, taxa de estresse).
func buff_multipliers() -> Dictionary:
	var prod := 1.0
	var stress := 1.0
	for b in game.state.buffs:
		prod *= float(b.get("productivity", 1.0))
		stress *= float(b.get("stress_rate", 1.0))
	return {"productivity": prod, "stress_rate": stress}


func on_day() -> void:
	var st: GameState = game.state
	var expired: Array = st.buffs.filter(func(b): return int(b.get("until_day", 0)) < st.day)
	for b in expired:
		game.add_log("Efeito encerrado: %s." % String(b.get("name", b.get("id", ""))), "info")
	if not expired.is_empty():
		st.buffs = st.buffs.filter(func(b): return int(b.get("until_day", 0)) >= st.day)
		EventBus.state_changed.emit()
