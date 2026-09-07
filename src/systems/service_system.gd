class_name ServiceSystem
extends RefCounted
## Árvore de serviços, desbloqueios e combinações estratégicas (match).

const MULTIPLIERS := {"perfect": 1.35, "good": 1.12, "neutral": 1.0, "poor": 0.75}
const MATCH_NAMES := {"perfect": "PERFECT MATCH", "good": "Boa combinação", "neutral": "Combinação neutra", "poor": "Combinação ruim"}

var game


func setup(g) -> void:
	game = g


func is_unlocked(id: String) -> bool:
	return id in game.state.unlocked_services


func unlocked_services() -> Array:
	return game.content.service_order.filter(func(id): return is_unlocked(id))


func can_unlock(id: String) -> Dictionary:
	var svc: Dictionary = game.content.services.get(id, {})
	if svc.is_empty():
		return {"ok": false, "reason": "Serviço desconhecido."}
	if is_unlocked(id):
		return {"ok": false, "reason": "Já desbloqueado."}
	if game.state.reputation < float(svc.get("rep_required", 0)):
		return {"ok": false, "reason": "Reputação insuficiente (precisa de %d)." % int(svc["rep_required"])}
	if game.state.money < float(svc.get("unlock_cost", 0)):
		return {"ok": false, "reason": "Caixa insuficiente."}
	return {"ok": true, "reason": ""}


func unlock(id: String) -> bool:
	var check := can_unlock(id)
	if not check.ok:
		return false
	var svc: Dictionary = game.content.services[id]
	game.finance.add_money(-float(svc.get("unlock_cost", 0)), "Desbloqueio: %s" % svc["name"], "expense")
	game.state.unlocked_services.append(id)
	game.add_log("Novo serviço desbloqueado: %s." % svc["name"], "unlock")
	EventBus.state_changed.emit()
	return true


## Qualidade da combinação de serviços para o segmento do cliente.
func match_quality(segment: String, services: Array) -> String:
	var table: Dictionary = game.content.match_table.get(segment, {})
	var best: Array = table.get("best", [])
	var poor: Array = table.get("poor", [])
	var hits := 0
	for s in services:
		if s in poor:
			return "poor"
		if s in best:
			hits += 1
	if hits >= 2:
		return "perfect"
	if hits == 1:
		return "good"
	return "neutral"


func match_multiplier(quality: String) -> float:
	return float(MULTIPLIERS.get(quality, 1.0))


func addresses_problem(problem: String, services: Array) -> bool:
	var solutions: Array = game.content.problem_solutions.get(problem, [])
	for s in services:
		if s in solutions:
			return true
	return false
