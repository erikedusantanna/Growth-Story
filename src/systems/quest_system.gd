class_name QuestSystem
extends RefCounted
## Missões: pedidos que surgem na rotina com prazo. Cumprir dá dinheiro e/ou reputação; deixar
## o prazo passar custa reputação (data/quests.json). Algumas formam arcos de três etapas: só a
## primeira entra no sorteio e cada etapa cumprida começa a seguinte, com prêmio maior no fim. Progresso por contadores de stats (delta
## desde o início da missão), por entregas com N estrelas, por dias seguidos de moral alta, por
## caixa no fim do prazo ou por tamanho da equipe. A UI mostra em Calendário e no feed.

var game
var _checking := false


func setup(g) -> void:
	game = g
	EventBus.project_completed.connect(_on_project_completed)


func data() -> Dictionary:
	return game.content.quests


func templates() -> Array:
	return data().get("quests", [])


func template(id: String) -> Dictionary:
	for q in templates():
		if String(q.get("id", "")) == id:
			return q
	return {}


func active() -> Array:
	return game.state.quests


func active_ids() -> Array:
	return active().map(func(q): return String(q.get("id", "")))


# --- Progresso ----------------------------------------------------------------------------

func progress(q: Dictionary) -> float:
	var st: GameState = game.state
	var t := template(String(q.get("id", "")))
	match String(t.get("type", "")):
		"stars_delivery", "morale_days":
			return float(q.get("progress", 0))
		"money":
			return st.money
		"team_size":
			return float(st.employees.size())
		_:
			return float(st.stats.get(String(t.get("type", "")), 0)) - float(q.get("start_stat", 0))


func target(q: Dictionary) -> float:
	var t := template(String(q.get("id", "")))
	match String(t.get("type", "")):
		"stars_delivery":
			return 1.0
		_:
			return float(t.get("value", 1))


func is_done(q: Dictionary) -> bool:
	return progress(q) >= target(q)


func days_left(q: Dictionary) -> int:
	return int(q.get("deadline_day", 0)) - game.state.day


## Texto curto de progresso ("1/2", "7/10 dias", "R$ 12.000 / R$ 30.000", "4★+").
func progress_text(q: Dictionary) -> String:
	var t := template(String(q.get("id", "")))
	match String(t.get("type", "")):
		"stars_delivery":
			return "entregue" if is_done(q) else "%d★ ou mais" % int(t.get("value", 4))
		"morale_days":
			return "%d/%d dias" % [int(progress(q)), int(target(q))]
		"money":
			return "%s / %s" % [FinanceSystem.format_money(progress(q)), FinanceSystem.format_money(target(q))]
		_:
			return "%d/%d" % [int(progress(q)), int(target(q))]


func reward_text(t: Dictionary) -> String:
	var parts: Array = []
	if float(t.get("reward_money", 0)) > 0.0:
		parts.append(FinanceSystem.format_money(float(t.get("reward_money", 0))))
	if float(t.get("reward_rep", 0)) > 0.0:
		parts.append("+%d de reputação" % int(t.get("reward_rep", 0)))
	return " e ".join(parts) if not parts.is_empty() else "reconhecimento"


# --- Sorteio ------------------------------------------------------------------------------

func _eligible(t: Dictionary) -> bool:
	var st: GameState = game.state
	var id := String(t.get("id", ""))
	if id in active_ids():
		return false
	# etapas 2 e 3 de um arco só entram quando a etapa anterior é cumprida
	if int(t.get("step", 1)) > 1:
		return false
	if st.day < int(t.get("min_day", 0)) or st.reputation < float(t.get("min_rep", 0)):
		return false
	var last_done: int = int(st.quests_done.get(id, -9999))
	if st.day - last_done < int(data().get("cooldown_days", 120)):
		return false
	if bool(t.get("requires_hr", false)) and not game.hr.is_unlocked():
		return false
	if bool(t.get("requires_agency_events", false)) and not game.agency_events.is_unlocked():
		return false
	if bool(t.get("requires_capacity", false)) and st.employees.size() >= game.office.capacity():
		return false
	match String(t.get("type", "")):
		"team_size":
			return st.employees.size() < int(t.get("value", 5)) and game.office.capacity() >= int(t.get("value", 5))
		"money":
			return st.money < float(t.get("value", 0)) * 0.8
		"diagnoses":
			return st.active_clients().any(func(c): return not c.diagnosed and c.diagnosis_days_left == 0)
		"trainings", "campaigns", "hr_actions", "agency_events", "clients_signed", "projects_done", "stars_delivery", "retainers", "furniture", "hires", "morale_days":
			return true
	return true


func _pick() -> Dictionary:
	var st: GameState = game.state
	var pool: Array = templates().filter(func(t): return _eligible(t))
	if pool.is_empty():
		return {}
	return pool[st.rng.randi_range(0, pool.size() - 1)]


## Rótulo do arco, quando a missão faz parte de um ("" se for avulsa).
func arc_label(t: Dictionary) -> String:
	if String(t.get("arc", "")) == "":
		return ""
	return "%s · etapa %d de %d" % [String(t.get("arc_name", "")), int(t.get("step", 1)), int(t.get("steps", 3))]


## Começa uma missão (usado pelo sorteio diário e pelos testes).
func start(id: String) -> Dictionary:
	var st: GameState = game.state
	var t := template(id)
	if t.is_empty() or id in active_ids():
		return {}
	var q := {"id": id, "start_day": st.day, "deadline_day": st.day + int(t.get("days", 30)),
		"start_stat": int(st.stats.get(String(t.get("type", "")), 0)), "progress": 0}
	st.quests.append(q)
	st.last_quest_day = st.day
	game.add_log("📜 %s: %s (%d dias, vale %s)." % ["Missão nova" if String(t.get("arc", "")) == "" else "Arco %s, etapa %d/%d" % [String(t.get("arc_name", "")), int(t.get("step", 1)), int(t.get("steps", 3))], String(t.get("title", "")), int(t.get("days", 30)), reward_text(t)], "unlock")
	EventBus.quest_started.emit(q)
	EventBus.state_changed.emit()
	return q


# --- Conclusão e falha --------------------------------------------------------------------

func _complete(q: Dictionary) -> void:
	var st: GameState = game.state
	var t := template(String(q.get("id", "")))
	st.quests.erase(q)
	st.quests_done[String(q.get("id", ""))] = st.day
	st.stats["quests_done"] = int(st.stats.get("quests_done", 0)) + 1
	var money := float(t.get("reward_money", 0))
	if money > 0.0:
		game.finance.add_money(money, "Missão: %s" % String(t.get("title", "")), "revenue")
	var rep := float(t.get("reward_rep", 0))
	if rep > 0.0:
		game.reputation.add(rep)
	game.add_log("✅ Missão cumprida: %s. Recompensa: %s." % [String(t.get("title", "")), reward_text(t)], "unlock")
	EventBus.quest_finished.emit(q, true)
	# arco: a etapa seguinte começa na hora
	var next_id := String(t.get("next", ""))
	if next_id != "":
		start(next_id)


func _fail(q: Dictionary) -> void:
	var st: GameState = game.state
	var t := template(String(q.get("id", "")))
	st.quests.erase(q)
	st.quests_done[String(q.get("id", ""))] = st.day
	st.stats["quests_failed"] = int(st.stats.get("quests_failed", 0)) + 1
	game.reputation.penalize(float(data().get("fail_rep", 1)), "missão perdida: %s" % String(t.get("title", "")))
	game.add_log("⌛ Missão perdida: %s (−%d de reputação)." % [String(t.get("title", "")), int(data().get("fail_rep", 1))], "warn")
	EventBus.quest_finished.emit(q, false)


## Conclui o que já foi cumprido. Chamado a cada dia e quando o estado muda.
func check() -> void:
	if _checking or game.state == null:
		return
	_checking = true
	var done: Array = active().filter(func(q): return is_done(q) and String(template(String(q.get("id", ""))).get("type", "")) != "money")
	for q in done:
		_complete(q)
	_checking = false
	if not done.is_empty():
		EventBus.state_changed.emit()


func _on_project_completed(_p, result: Dictionary) -> void:
	if game.state == null:
		return
	var stars := int(result.get("stars", 0))
	for q in active():
		var t := template(String(q.get("id", "")))
		if String(t.get("type", "")) == "stars_delivery" and stars >= int(t.get("value", 4)):
			q["progress"] = 1
	check()


func on_day() -> void:
	var st: GameState = game.state
	# dias seguidos de moral alta
	for q in active():
		var t := template(String(q.get("id", "")))
		if String(t.get("type", "")) == "morale_days":
			if game.employees.morale_average() >= float(t.get("threshold", 60)):
				q["progress"] = int(q.get("progress", 0)) + 1
			else:
				q["progress"] = 0
	check()
	# prazo: caixa é avaliado no último dia; o resto falha se não cumpriu
	var expired: Array = active().filter(func(q): return st.day >= int(q.get("deadline_day", 0)))
	for q in expired:
		if is_done(q):
			_complete(q)
		else:
			_fail(q)
	# sorteio
	if active().size() < int(data().get("max_active", 2)) and st.day - st.last_quest_day >= int(data().get("spawn_gap_days", 18)) \
			and st.pending_event.is_empty() and st.rng.randf() < float(data().get("daily_chance", 0.14)):
		var t := _pick()
		if not t.is_empty():
			start(String(t.get("id", "")))
	if not expired.is_empty():
		EventBus.state_changed.emit()
