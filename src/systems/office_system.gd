class_name OfficeSystem
extends RefCounted
## Níveis de escritório: capacidade, aluguel e layout.

var game


func setup(g) -> void:
	game = g


func current() -> Dictionary:
	return level_data(game.state.office_level)


func level_data(level: int) -> Dictionary:
	var offices: Array = game.content.offices
	if offices.is_empty():
		return {"level": 1, "name": "Escritório", "capacity": 2, "rent": 0, "width": 10, "height": 7, "desks": [[2, 2]], "props": []}
	return offices[clampi(level - 1, 0, offices.size() - 1)]


func next_level() -> Dictionary:
	var offices: Array = game.content.offices
	if game.state.office_level >= offices.size():
		return {}
	return offices[game.state.office_level]


func capacity() -> int:
	return int(current().get("capacity", 2))


func rent() -> float:
	return float(current().get("rent", 0)) * game.state.rent_modifier


func can_upgrade() -> Dictionary:
	var nxt := next_level()
	if nxt.is_empty():
		return {"ok": false, "reason": "Você já está no maior escritório disponível."}
	if game.state.reputation < float(nxt.get("rep_required", 0)):
		return {"ok": false, "reason": "Precisa de %d de reputação." % int(nxt["rep_required"])}
	if game.state.money < float(nxt.get("upgrade_cost", 0)):
		return {"ok": false, "reason": "Caixa insuficiente (%s)." % FinanceSystem.format_money(float(nxt["upgrade_cost"]))}
	return {"ok": true, "reason": ""}


func upgrade() -> bool:
	var check := can_upgrade()
	if not check.ok:
		return false
	var nxt := next_level()
	game.finance.add_money(-float(nxt.get("upgrade_cost", 0)), "Mudança para %s" % nxt["name"], "expense")
	game.state.office_level += 1
	game.add_log("A agência se mudou: %s. Cabem %d pessoas." % [nxt["name"], int(nxt["capacity"])], "unlock")
	EventBus.state_changed.emit()
	return true
