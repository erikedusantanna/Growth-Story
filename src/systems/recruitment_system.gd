class_name RecruitmentSystem
extends RefCounted
## Recrutamento: o equivalente da mídia paga, mas para gente.
##
## Esperar os candidatos do mês trava o jogo quando a agência precisa crescer rápido, então há
## duas saídas pagas: buscas avulsas (anúncio, freela, headhunter), que entregam currículos
## depois de alguns dias, e uma **recrutadora interna** contratada em tempo integral, que ocupa
## um lugar no escritório e mantém o funil cheio todo mês. Conteúdo em data/recruitment.json.

var game


func setup(g) -> void:
	game = g


func data() -> Dictionary:
	return game.content.recruitment


# --- Buscas pagas -----------------------------------------------------------------

func searches() -> Array:
	return data().get("searches", [])


func search_by_id(id: String) -> Dictionary:
	for s in searches():
		if String(s.get("id", "")) == id:
			return s
	return {}


## O custo sobe com a região da sede, como na mídia paga: procurar gente na capital é mais caro.
func cost(s: Dictionary) -> float:
	var region: int = game.office.region()
	return float(s.get("cost", 0)) * (1.0 + float(data().get("cost_per_region", 0.35)) * float(region - 1))


## Currículos comprados que ainda não chegaram.
func pending() -> int:
	var total := 0
	for h in game.state.hunts:
		total += int(h.get("candidates", 0))
	return total


func can_start(s: Dictionary) -> Dictionary:
	var st: GameState = game.state
	if s.is_empty():
		return {"ok": false, "reason": "Busca desconhecida."}
	if st.reputation < float(s.get("requires_rep", 0)):
		return {"ok": false, "reason": "Precisa de %d de reputação." % int(s.get("requires_rep", 0))}
	if st.money < cost(s):
		return {"ok": false, "reason": "Caixa insuficiente (%s)." % FinanceSystem.format_money(cost(s))}
	if pending() >= int(data().get("max_pending", 3)):
		return {"ok": false, "reason": "Já há currículos a caminho. Espere chegarem."}
	if st.candidates.size() >= EmployeeSystem.MAX_CANDIDATES:
		return {"ok": false, "reason": "A lista de candidatos está cheia."}
	return {"ok": true, "reason": ""}


func start(id: String) -> Dictionary:
	var s := search_by_id(id)
	var check := can_start(s)
	if not check.ok:
		return check
	var st: GameState = game.state
	game.finance.add_money(-cost(s), "Recrutamento: %s" % String(s.get("name", "")), "expense")
	var days: Array = s.get("days", [3, 5])
	var n: int = int(s.get("candidates", 1))
	for k in n:
		# cada currículo chega num dia diferente; só um deles disputa a chance de vir acima da média
		st.hunts.append({
			"id": id,
			"arrive_day": st.day + st.rng.randi_range(int(days[0]), int(days[1])),
			"candidates": 1,
			"quality": String(s.get("quality", "normal")),
			"high_chance": float(s.get("high_chance", 0.0)) if k == 0 else 0.0,
		})
	st.stats["searches"] = int(st.stats.get("searches", 0)) + 1
	game.add_log("%s Recrutamento: %s. %d currículo(s) a caminho." % [
		String(s.get("icon", "🔎")), String(s.get("name", "")), n], "hire")
	EventBus.state_changed.emit()
	return {"ok": true, "reason": ""}


func _tick_hunts() -> void:
	var st: GameState = game.state
	var due: Array = st.hunts.filter(func(h): return int(h.get("arrive_day", 0)) <= st.day)
	if due.is_empty():
		return
	st.hunts = st.hunts.filter(func(h): return int(h.get("arrive_day", 0)) > st.day)
	for h in due:
		if st.candidates.size() >= EmployeeSystem.MAX_CANDIDATES:
			game.add_log("Chegou currículo, mas a lista de candidatos está cheia.", "warn")
			continue
		var quality := String(h.get("quality", "normal"))
		if quality != "high" and st.rng.randf() < float(h.get("high_chance", 0.0)):
			quality = "high"
		var e: Employee = game.employees.add_candidate(quality)
		game.add_log("📄 Currículo novo: %s (%s). Está na aba Equipe." % [e.name, game.employees.title(e)], "hire")
	EventBus.candidates_arrived.emit()
	EventBus.state_changed.emit()


# --- Recrutadora interna ----------------------------------------------------------

func recruiter_data() -> Dictionary:
	return data().get("recruiter", {})


func has_recruiter() -> bool:
	return game.state.recruiter_hired


## Salário mensal da recrutadora (zero quando não há nenhuma).
func salary() -> float:
	return float(recruiter_data().get("salary", 0)) if has_recruiter() else 0.0


func hire_cost() -> float:
	return float(recruiter_data().get("cost", 0))


func can_hire_recruiter() -> Dictionary:
	var st: GameState = game.state
	var r := recruiter_data()
	if st.recruiter_hired:
		return {"ok": false, "reason": "Já existe uma recrutadora na equipe."}
	if st.office_level < int(r.get("requires_office", 2)):
		var office_name: String = game.office.level_data(int(r.get("requires_office", 2))).get("name", "")
		return {"ok": false, "reason": "Precisa do %s para abrir essa vaga." % office_name}
	if st.reputation < float(r.get("requires_rep", 0)):
		return {"ok": false, "reason": "Precisa de %d de reputação." % int(r.get("requires_rep", 0))}
	if st.employees.size() >= game.office.capacity():
		return {"ok": false, "reason": "Não há lugar livre no escritório. Amplie antes."}
	if st.money < hire_cost():
		return {"ok": false, "reason": "Caixa insuficiente (%s)." % FinanceSystem.format_money(hire_cost())}
	return {"ok": true, "reason": ""}


func hire_recruiter() -> Dictionary:
	var check := can_hire_recruiter()
	if not check.ok:
		return check
	var st: GameState = game.state
	game.finance.add_money(-hire_cost(), "Contratação: %s" % String(recruiter_data().get("name", "recrutadora")), "expense")
	st.recruiter_hired = true
	game.add_log("%s %s contratada. Ela ocupa um lugar e traz candidatos todo mês (%s/mês)." % [
		String(recruiter_data().get("icon", "🧑‍💼")), String(recruiter_data().get("name", "Recrutadora")),
		FinanceSystem.format_money(salary())], "hire")
	EventBus.state_changed.emit()
	return {"ok": true, "reason": ""}


## Demitir libera o lugar no escritório e corta o salário. Sem custo de rescisão.
func fire_recruiter() -> Dictionary:
	if not has_recruiter():
		return {"ok": false, "reason": "Não há recrutadora contratada."}
	game.state.recruiter_hired = false
	game.add_log("A recrutadora saiu da agência. O lugar dela está livre de novo.", "warn")
	EventBus.state_changed.emit()
	return {"ok": true, "reason": ""}


## Quantos candidatos a recrutadora soma ao lote mensal.
func monthly_bonus() -> int:
	return int(recruiter_data().get("monthly_candidates", 0)) if has_recruiter() else 0


## Chance de um candidato do lote mensal vir acima da média por causa dela.
func high_chance() -> float:
	return float(recruiter_data().get("high_chance", 0.0)) if has_recruiter() else 0.0


func on_day() -> void:
	_tick_hunts()
	if not has_recruiter():
		return
	# fora do lote mensal, ela ainda pode trazer alguém no meio do caminho
	var st: GameState = game.state
	if st.candidates.size() >= EmployeeSystem.MAX_CANDIDATES:
		return
	if st.day % 7 != 0:
		return
	if st.rng.randf() < float(recruiter_data().get("weekly_chance", 0.0)):
		var e: Employee = game.employees.add_candidate("high" if st.rng.randf() < high_chance() else "normal")
		game.add_log("🧑‍💼 A recrutadora trouxe %s para conversar." % e.name, "hire")
		EventBus.candidates_arrived.emit()
		EventBus.state_changed.emit()
