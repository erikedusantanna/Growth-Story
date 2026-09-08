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


# --- Mobília --------------------------------------------------------------------

func furniture_items() -> Array:
	return game.content.furniture.get("items", [])


func furniture_by_id(id: String) -> Dictionary:
	for f in furniture_items():
		if f["id"] == id:
			return f
	return {}


func owns(id: String) -> bool:
	return id in game.state.furniture


func can_buy(f: Dictionary) -> Dictionary:
	var st: GameState = game.state
	if owns(f["id"]):
		return {"ok": false, "reason": "Já comprado."}
	if st.office_level < int(f.get("requires_office", 1)):
		return {"ok": false, "reason": "Precisa do escritório nível %d." % int(f["requires_office"])}
	if st.reputation < float(f.get("requires_rep", 0)):
		return {"ok": false, "reason": "Precisa de %d de reputação." % int(f["requires_rep"])}
	if st.money < float(f.get("cost", 0)):
		return {"ok": false, "reason": "Caixa insuficiente."}
	return {"ok": true, "reason": ""}


func buy(f: Dictionary) -> Dictionary:
	var check := can_buy(f)
	if not check.ok:
		return check
	var st: GameState = game.state
	game.finance.add_money(-float(f.get("cost", 0)), "Mobília: %s" % f["name"], "expense")
	st.furniture.append(f["id"])
	st.stats["furniture"] = int(st.stats.get("furniture", 0)) + 1
	var fx: Dictionary = f.get("effects", {})
	for e in st.employees:
		apply_furniture_bonus(e, f)
		if fx.has("morale_once"):
			game.employees.change_morale(e, float(fx["morale_once"]))
	game.add_log("Nova mobília: %s." % f["name"], "unlock")
	EventBus.state_changed.emit()
	return {"ok": true, "reason": ""}


## Bônus permanente de atributo de uma mobília (aplicado a quem já está e a quem entra).
func apply_furniture_bonus(e: Employee, f: Dictionary) -> void:
	var bonus: Dictionary = f.get("effects", {}).get("attr_bonus", {})
	for key in bonus:
		e.attrs[key] = clampf(e.attr(key) + float(bonus[key]), 1.0, 100.0)


func apply_all_furniture_bonuses(e: Employee) -> void:
	for id in game.state.furniture:
		var f := furniture_by_id(id)
		if not f.is_empty():
			apply_furniture_bonus(e, f)


## Efeitos agregados de toda a mobília comprada.
func furniture_effects() -> Dictionary:
	var out := {"morale_max": float(game.content.furniture.get("base_morale_max", 85)), "morale_daily": 0.0,
		"stress_rate": 1.0, "productivity": 1.0}
	for id in game.state.furniture:
		var fx: Dictionary = furniture_by_id(id).get("effects", {})
		out["morale_max"] += float(fx.get("morale_max", 0))
		out["morale_daily"] += float(fx.get("morale_daily", 0))
		out["stress_rate"] *= 1.0 + float(fx.get("stress_rate", 0))
		out["productivity"] *= 1.0 + float(fx.get("productivity", 0))
	out["morale_max"] = minf(out["morale_max"], 100.0)
	return out


func morale_max() -> float:
	return float(furniture_effects()["morale_max"])


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
