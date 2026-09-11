class_name EventSystem
extends RefCounted
## Eventos aleatórios com escolhas (GDD §24). O evento pendente pausa o tempo até ser resolvido.

const MIN_GAP_DAYS := 10
const DAILY_CHANCE := 0.07
## Um mesmo evento não repete antes deste intervalo (o JSON pode sobrescrever com "cooldown_days").
const DEFAULT_COOLDOWN_DAYS := 120

var game


func setup(g) -> void:
	game = g


func on_day() -> void:
	var st: GameState = game.state
	if not st.pending_event.is_empty():
		return
	if st.day - st.last_event_day < MIN_GAP_DAYS:
		return
	if st.rng.randf() > DAILY_CHANCE:
		return
	var ev := _pick_event()
	if ev.is_empty():
		return
	trigger(ev)


func trigger(ev: Dictionary) -> void:
	var st: GameState = game.state
	var targets: Dictionary = (ev.get("targets", {}) as Dictionary).duplicate()
	var text: String = ev.get("text", "")
	if text.contains("{best_employee}"):
		var best: Employee = game.employees.best_employee()
		if best == null:
			return
		targets["employee_id"] = best.id
		text = text.replace("{best_employee}", best.name)
	if text.contains("{personality_employee}"):
		var list: Array = game.employees.employees_with_personality(ev.get("requires_personality", ""))
		if list.is_empty():
			return
		var e: Employee = list[st.rng.randi_range(0, list.size() - 1)]
		targets["employee_id"] = e.id
		text = text.replace("{personality_employee}", e.name)
	if text.contains("{random_client}"):
		var c: Client = game.clients.random_active_client()
		if c == null:
			return
		targets["client_id"] = c.id
		text = text.replace("{random_client}", c.name)
	st.pending_event = {"id": ev["id"], "title": ev.get("title", "Evento"), "text": text,
		"choices": ev.get("choices", []), "targets": targets, "scene": ev.get("scene", "")}
	st.last_event_day = st.day
	st.events_seen[ev["id"]] = int(st.events_seen.get(ev["id"], 0)) + 1
	st.events_last_day[ev["id"]] = st.day
	EventBus.event_triggered.emit(st.pending_event)


func _eligible(ev: Dictionary) -> bool:
	var st: GameState = game.state
	if ev.get("once", false) and st.events_seen.has(ev["id"]):
		return false
	var last: int = int(st.events_last_day.get(ev["id"], -9999))
	if st.day - last < int(ev.get("cooldown_days", DEFAULT_COOLDOWN_DAYS)):
		return false
	if st.day < int(ev.get("min_day", 0)):
		return false
	if st.reputation < float(ev.get("min_reputation", 0)):
		return false
	if st.employees.size() < int(ev.get("min_employees", 0)):
		return false
	if st.active_clients().size() < int(ev.get("min_active_clients", 0)):
		return false
	if st.running_projects().size() < int(ev.get("min_running_projects", 0)):
		return false
	if st.cases < int(ev.get("min_cases", 0)):
		return false
	if st.office_level < int(ev.get("min_office_level", 0)):
		return false
	if ev.has("min_avg_stress"):
		var total := 0.0
		for e in st.employees:
			total += e.stress
		if st.employees.is_empty() or total / st.employees.size() < float(ev["min_avg_stress"]):
			return false
	if ev.has("requires_personality") and game.employees.employees_with_personality(ev["requires_personality"]).is_empty():
		return false
	if ev.get("id") == "proposta_concorrente" and game.employees.best_employee() == null:
		return false
	return true


func _pick_event() -> Dictionary:
	var st: GameState = game.state
	var pool: Array = game.content.events.filter(func(ev): return _eligible(ev))
	if pool.is_empty():
		return {}
	var total := 0.0
	for ev in pool:
		total += float(ev.get("weight", 1))
	var roll := st.rng.randf() * total
	for ev in pool:
		roll -= float(ev.get("weight", 1))
		if roll <= 0.0:
			return ev
	return pool.back()


func resolve(choice_index: int) -> void:
	var st: GameState = game.state
	var ev: Dictionary = st.pending_event
	if ev.is_empty():
		return
	var choices: Array = ev.get("choices", [])
	var idx := clampi(choice_index, 0, maxi(choices.size() - 1, 0))
	st.pending_event = {}
	if choices.is_empty():
		EventBus.state_changed.emit()
		return
	var choice: Dictionary = choices[idx]
	game.add_log("%s: %s" % [ev.get("title", "Evento"), choice.get("label", "")], "event")
	for effect in choice.get("effects", []):
		_apply_effect(effect, ev.get("targets", {}), String(ev.get("title", "Evento")))
	EventBus.state_changed.emit()


func _apply_effect(effect: Dictionary, targets: Dictionary, title: String = "Evento") -> void:
	var st: GameState = game.state
	var type: String = effect.get("type", "")
	var value: float = float(effect.get("value", 0))
	var target_employee: Employee = st.employee_by_id(int(targets.get("employee_id", -1)))
	var target_client: Client = st.client_by_id(int(targets.get("client_id", -1)))
	match type:
		"money":
			game.finance.add_money(value, "Evento", "event")
		"reputation":
			game.reputation.add(value)
		"motivation":
			for e in st.employees:
				e.motivation = clampf(e.motivation + value, 0.0, 100.0)
		"stress_all":
			for e in st.employees:
				e.stress = clampf(e.stress + value, 0.0, 100.0)
		"attr_all":
			var attr: String = effect.get("attr", "creativity")
			for e in st.employees:
				e.attrs[attr] = clampf(e.attr(attr) + value, 1.0, 100.0)
				game.employees.add_journey(e, "%s: %s%d %s" % [title, "+" if value >= 0 else "", int(value), Employee.ATTR_NAMES.get(attr, attr)])
			game.add_log("Toda a equipe: %s%d de %s." % ["+" if value >= 0 else "", int(value), Employee.ATTR_NAMES.get(attr, attr)], "promo")
		"log":
			game.add_log(effect.get("text", ""), "event")
		"flag":
			st.flags[effect.get("id", "flag")] = effect.get("value", true)
		"raise_best":
			if target_employee != null:
				game.employees.give_raise(target_employee, value)
				game.employees.add_journey(target_employee, "Recebeu aumento de %d%% após proposta da concorrência" % int(value * 100))
		"loyalty_best":
			if target_employee != null:
				target_employee.loyalty = clampf(target_employee.loyalty + value, 0.0, 100.0)
		"promote_best":
			if target_employee != null:
				game.employees.promote(target_employee)
		"lose_best":
			if target_employee != null:
				game.employees.quit(target_employee, "aceitou a proposta da concorrente")
		"raise_personality", "motivation_personality", "loyalty_personality":
			if target_employee != null:
				if type == "raise_personality":
					game.employees.give_raise(target_employee, value)
				elif type == "motivation_personality":
					target_employee.motivation = clampf(target_employee.motivation + value, 0.0, 100.0)
				else:
					target_employee.loyalty = clampf(target_employee.loyalty + value, 0.0, 100.0)
		"client_relationship":
			var c: Client = target_client if target_client != null else game.clients.random_active_client()
			if c != null:
				c.relationship = clampf(c.relationship + value, 0.0, 100.0)
				if c.relationship <= 0.0:
					game.clients.lose_client(c, "cancelou o contrato")
		"project_boost":
			game.projects.apply_boost(effect.get("indicator", "execution"), value)
		"project_delay":
			game.projects.delay_all(int(effect.get("days", 1)))
		"project_extra_work":
			game.projects.extra_work(value)
		"spawn_candidate":
			game.employees.add_candidate(effect.get("quality", "normal"))
		"spawn_prospect":
			game.clients.spawn_prospect(int(effect.get("tier_bonus", 0)))
		"rent_mod":
			st.rent_modifier += value
		"client_budget_mult":
			if target_client != null:
				target_client.budget = roundf(target_client.budget * value / 100.0) * 100.0
		"rival_strength", "client_retention", "lose_client_target":
			game.competitors.apply_rival_effect(effect, target_client)
		_:
			push_warning("Efeito de evento desconhecido: %s" % type)
