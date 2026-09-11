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


## Próxima expansão dentro da região atual ({} se a região já está no nível máximo).
func next_level() -> Dictionary:
	var offices: Array = game.content.offices
	if game.state.office_level >= offices.size():
		return {}
	var nxt: Dictionary = offices[game.state.office_level]
	if int(nxt.get("region", 1)) != region():
		return {}
	return nxt


# --- Regiões (World Map) -------------------------------------------------------------

func regions() -> Array:
	return game.content.regions.get("regions", [])


func region_data(r: int) -> Dictionary:
	for rd in regions():
		if int(rd.get("region", 0)) == r:
			return rd
	return {}


## Região atual (1 = Bairro Criativo … 5 = Hub Global).
func region() -> int:
	return int(current().get("region", 1))


func region_level() -> int:
	return int(current().get("region_level", 1))


func is_region_maxed() -> bool:
	return next_level().is_empty()


func can_move(r: int) -> Dictionary:
	var rd := region_data(r)
	if rd.is_empty():
		return {"ok": false, "reason": "Região desconhecida."}
	if r <= region():
		return {"ok": false, "reason": "A agência já passou por aqui."}
	if r != region() + 1:
		return {"ok": false, "reason": "Primeiro mude para %s." % String(region_data(region() + 1).get("name", "a próxima região"))}
	if game.state.reputation < float(rd.get("rep_required", 0)):
		return {"ok": false, "reason": "Precisa de %d de reputação." % int(rd["rep_required"])}
	if game.state.money < float(rd.get("move_cost", 0)):
		return {"ok": false, "reason": "Caixa insuficiente (%s)." % FinanceSystem.format_money(float(rd["move_cost"]))}
	return {"ok": true, "reason": ""}


## Mudança de sede: paga, abre o nível 1 da região nova e começa a semana de mudança.
func move_to(r: int) -> Dictionary:
	var check := can_move(r)
	if not check.ok:
		return check
	var rd := region_data(r)
	var st: GameState = game.state
	game.finance.add_money(-float(rd.get("move_cost", 0)), "Mudança de sede: %s" % String(rd.get("name", "")), "expense")
	st.office_level = int(rd.get("first_level", st.office_level + 1))
	st.moving_until_day = st.day + int(game.content.regions.get("moving_days", 7))
	game.competitors.ensure_rivals()
	var office := current()
	game.add_log("🌎 A agência mudou de sede: %s (%s). Cabem %d pessoas; clientes tier %d passam a aparecer. Semana de mudança: produtividade reduzida." % [
		String(rd.get("name", "")), String(office.get("name", "")), int(office.get("capacity", 0)), int(rd.get("tier", r))], "unlock")
	EventBus.state_changed.emit()
	return {"ok": true, "reason": ""}


func is_moving() -> bool:
	return game.state != null and game.state.day < game.state.moving_until_day


func moving_multiplier() -> float:
	return float(game.content.regions.get("moving_productivity", 0.85)) if is_moving() else 1.0


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
	out["morale_daily"] += game.hr.pets_morale_daily()
	out["morale_max"] = minf(out["morale_max"], 100.0)
	return out


func morale_max() -> float:
	return float(furniture_effects()["morale_max"])


func can_upgrade() -> Dictionary:
	var nxt := next_level()
	if nxt.is_empty():
		if region() < regions().size():
			return {"ok": false, "reason": "Este escritório está no tamanho máximo da região. Mude de sede pelo mapa 🌎."}
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
	game.finance.add_money(-float(nxt.get("upgrade_cost", 0)), "Ampliação: %s" % nxt["name"], "expense")
	game.state.office_level += 1
	game.add_log("O escritório foi ampliado: %s. Cabem %d pessoas." % [nxt["name"], int(nxt["capacity"])], "unlock")
	EventBus.state_changed.emit()
	return true
