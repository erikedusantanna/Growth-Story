class_name EmployeeSystem
extends RefCounted
## Contratação, treinamento, carreira, motivação e estresse.

const BURNOUT_DAYS := 10
const JOURNEY_MAX := 40
const MAX_CANDIDATES := 5
const CANDIDATE_LIFETIME := 45

var game


func setup(g) -> void:
	game = g


# --- Criação -------------------------------------------------------------------

func create_founder(founder_name: String) -> Employee:
	var e := Employee.new()
	e.id = game.state.new_id()
	e.name = founder_name
	e.role = "generalist"
	e.personality = "visionario"
	e.is_founder = true
	for key in Employee.ATTRS:
		e.attrs[key] = 42.0
	e.attrs["communication"] = 52.0
	e.attrs["strategy"] = 48.0
	e.motivation = 85.0
	e.loyalty = 100.0
	e.potential = 5
	e.salary = 0.0
	e.career_level = 2
	e.experience = 180.0
	e.age = 26
	e.color = "#f3a712"
	e.hired_on = 0
	e.journey.append({"day": 0, "text": "Fundou a agência"})
	return e


func generate_candidate(quality: String = "normal") -> Employee:
	var st: GameState = game.state
	var rng: RandomNumberGenerator = st.rng
	var content: ContentDB = game.content
	var e := Employee.new()
	e.id = st.new_id()
	e.name = "%s %s" % [content.names.first[rng.randi_range(0, content.names.first.size() - 1)],
		content.names.last[rng.randi_range(0, content.names.last.size() - 1)]]

	var role_pool: Array = ["generalist", "account"]
	for sid in st.unlocked_services:
		role_pool.append(sid)
		role_pool.append(sid)  # especialistas nos serviços ativos são mais comuns
	e.role = role_pool[rng.randi_range(0, role_pool.size() - 1)]

	var pkeys: Array = content.personalities.keys()
	e.personality = pkeys[rng.randi_range(0, pkeys.size() - 1)]
	var pers: Dictionary = content.personalities[e.personality]

	var base := 22.0 + st.reputation * 0.45
	if quality == "high":
		base += 18.0
	base += rng.randfn(0.0, 6.0)
	var focus: Array = content.roles.get(e.role, {}).get("focus", [])
	for key in Employee.ATTRS:
		var v := base + rng.randfn(0.0, 9.0)
		if key in focus:
			v += 16.0
		v += float(pers.get("attr_mods", {}).get(key, 0))
		e.attrs[key] = clampf(v, 5.0, 100.0)

	e.potential = clampi(rng.randi_range(1, 5), int(pers.get("potential_min", 1)), 5)
	e.motivation = rng.randf_range(55.0, 85.0)
	e.loyalty = float(pers.get("loyalty_base", rng.randf_range(40.0, 75.0)))
	e.age = rng.randi_range(19, 45)
	e.color = content.colors[rng.randi_range(0, content.colors.size() - 1)]

	var avg := e.average_attr()
	if avg < 35.0:
		e.career_level = 0
	elif avg < 50.0:
		e.career_level = 1
	elif avg < 65.0:
		e.career_level = 2
	else:
		e.career_level = 3
	e.experience = float(content.career[e.career_level]["xp"])
	e.salary = _salary_for(e)
	e.candidate_expires = st.day + CANDIDATE_LIFETIME
	return e


func _salary_for(e: Employee) -> float:
	var pers: Dictionary = game.content.personalities.get(e.personality, {})
	var career_mult := float(game.content.career[e.career_level].get("salary_mult", 1.0))
	var raw := (800.0 + e.average_attr() * 60.0) * career_mult * float(pers.get("salary_mult", 1.0))
	return roundf(raw / 50.0) * 50.0


func title(e: Employee) -> String:
	if e.is_founder:
		return "Fundador(a)"
	return "%s %s" % [game.content.role_name(e.role), game.content.career_name(e.career_level)]


func personality_name(e: Employee) -> String:
	return game.content.personalities.get(e.personality, {}).get("name", e.personality)


func productivity(e: Employee) -> float:
	var pers: Dictionary = game.content.personalities.get(e.personality, {})
	var base := float(pers.get("productivity", 1.0))
	return base * (0.7 + e.motivation / 100.0 * 0.6) * (1.0 - e.stress / 220.0)


# --- Candidatos ----------------------------------------------------------------

func refresh_candidates() -> void:
	var st: GameState = game.state
	st.candidates = st.candidates.filter(func(c): return c.candidate_expires > st.day)
	var new_count := st.rng.randi_range(1, 2)
	if st.reputation >= 30:
		new_count += 1
	for i in new_count:
		if st.candidates.size() >= MAX_CANDIDATES:
			break
		st.candidates.append(generate_candidate())


func add_candidate(quality: String = "normal") -> Employee:
	var c := generate_candidate(quality)
	game.state.candidates.append(c)
	return c


func can_hire(candidate: Employee) -> Dictionary:
	var st: GameState = game.state
	if st.employees.size() >= game.office.capacity():
		return {"ok": false, "reason": "Escritório lotado. Faça um upgrade."}
	if st.money < candidate.salary:
		return {"ok": false, "reason": "Caixa insuficiente para o primeiro salário."}
	return {"ok": true, "reason": ""}


func hire(candidate: Employee) -> Dictionary:
	var check := can_hire(candidate)
	if not check.ok:
		return check
	var st: GameState = game.state
	st.candidates.erase(candidate)
	candidate.hired_on = st.day
	candidate.candidate_expires = 0
	st.employees.append(candidate)
	st.stats["hires"] = int(st.stats["hires"]) + 1
	add_journey(candidate, "Entrou na agência como %s" % title(candidate))
	game.add_log(_pick(game.content.feed.get("hired", [])).replace("{emp}", candidate.name), "hire")
	EventBus.employee_hired.emit(candidate)
	EventBus.state_changed.emit()
	return {"ok": true, "reason": ""}


func decline(candidate: Employee) -> void:
	game.state.candidates.erase(candidate)
	EventBus.state_changed.emit()


func fire(e: Employee) -> Dictionary:
	if e.is_founder:
		return {"ok": false, "reason": "Você não pode se demitir."}
	_remove_from_team(e)
	game.state.employees.erase(e)
	game.finance.add_money(-e.salary, "Rescisão: %s" % e.name, "expense")
	game.add_log("%s foi desligado(a) da agência." % e.name, "warn")
	EventBus.employee_left.emit(e, "fired")
	EventBus.state_changed.emit()
	return {"ok": true, "reason": ""}


func _remove_from_team(e: Employee) -> void:
	if e.project_id != -1:
		var p: Project = game.state.project_by_id(e.project_id)
		if p != null:
			p.team.erase(e.id)
		e.project_id = -1


# --- Treinamento ---------------------------------------------------------------

func course_by_id(id: String) -> Dictionary:
	for c in game.content.courses:
		if c["id"] == id:
			return c
	return {}


func can_train(e: Employee, course_id: String) -> Dictionary:
	var course := course_by_id(course_id)
	if course.is_empty():
		return {"ok": false, "reason": "Curso inválido."}
	if not e.is_available(game.state.day):
		return {"ok": false, "reason": "%s está ocupado(a)." % e.name}
	if game.state.money < float(course["cost"]):
		return {"ok": false, "reason": "Caixa insuficiente."}
	return {"ok": true, "reason": ""}


func train(e: Employee, course_id: String) -> Dictionary:
	var check := can_train(e, course_id)
	if not check.ok:
		return check
	var course := course_by_id(course_id)
	game.finance.add_money(-float(course["cost"]), "Treinamento: %s" % course["name"], "expense")
	e.training_id = course_id
	e.busy_until = game.state.day + int(course["days"])
	e.busy_reason = "Em treinamento"
	game.state.stats["trainings"] = int(game.state.stats.get("trainings", 0)) + 1
	game.add_log("%s começou: %s." % [e.name, course["name"]], "info")
	EventBus.state_changed.emit()
	return {"ok": true, "reason": ""}


func _finish_training(e: Employee) -> void:
	var course := course_by_id(e.training_id)
	e.training_id = ""
	e.busy_reason = ""
	if course.is_empty():
		return
	var gains: Dictionary = course.get("gains", {})
	var potential_mult := 0.7 + e.potential * 0.15
	var parts: Array = []
	for key in gains:
		var gained: float = float(gains[key]) * potential_mult
		e.attrs[key] = clampf(e.attr(key) + gained, 1.0, 100.0)
		parts.append("+%d %s" % [int(roundf(gained)), Employee.ATTR_NAMES.get(key, key)])
	e.motivation = clampf(e.motivation + 5.0, 0.0, 100.0)
	add_journey(e, "Concluiu %s: %s" % [course["name"], ", ".join(parts)])
	game.add_log("%s concluiu %s (%s)." % [e.name, course["name"], ", ".join(parts)], "promo")
	EventBus.state_changed.emit()


# --- Carreira ------------------------------------------------------------------

func gain_experience(e: Employee, amount: float) -> void:
	var pers: Dictionary = game.content.personalities.get(e.personality, {})
	e.experience += amount * float(pers.get("xp_mult", 1.0))
	check_promotion(e)


func check_promotion(e: Employee) -> void:
	var career: Array = game.content.career
	while e.career_level + 1 < career.size() and e.experience >= float(career[e.career_level + 1]["xp"]):
		promote(e)


func promote(e: Employee) -> void:
	var career: Array = game.content.career
	if e.career_level + 1 >= career.size():
		return
	var old_mult := float(career[e.career_level].get("salary_mult", 1.0))
	e.career_level += 1
	var new_mult := float(career[e.career_level].get("salary_mult", 1.0))
	if not e.is_founder:
		e.salary = roundf(e.salary * (new_mult / maxf(old_mult, 0.1)) / 50.0) * 50.0
	e.experience = maxf(e.experience, float(career[e.career_level]["xp"]))
	e.motivation = clampf(e.motivation + 12.0, 0.0, 100.0)
	e.loyalty = clampf(e.loyalty + 8.0, 0.0, 100.0)
	for key in Employee.ATTRS:
		e.attrs[key] = clampf(e.attr(key) + 1.0, 1.0, 100.0)
	add_journey(e, "Promovido(a) a %s" % title(e))
	var text: String = _pick(game.content.feed.get("promotion", ["{emp} foi promovido(a) a {title}."]))
	game.add_log(text.replace("{emp}", e.name).replace("{title}", title(e)), "promo")
	EventBus.employee_promoted.emit(e)
	EventBus.state_changed.emit()


func give_raise(e: Employee, fraction: float) -> void:
	e.salary = roundf(e.salary * (1.0 + fraction) / 50.0) * 50.0
	e.months_since_raise = 0
	e.motivation = clampf(e.motivation + 10.0, 0.0, 100.0)


func best_employee() -> Employee:
	var best: Employee = null
	for e in game.state.employees:
		if e.is_founder:
			continue
		if best == null or e.average_attr() > best.average_attr():
			best = e
	return best


func employees_with_personality(personality: String) -> Array:
	return game.state.employees.filter(func(e): return e.personality == personality and not e.is_founder)


func quit(e: Employee, reason: String) -> void:
	_remove_from_team(e)
	game.state.employees.erase(e)
	game.add_log("%s saiu da agência (%s)." % [e.name, reason], "warn")
	EventBus.employee_left.emit(e, reason)
	EventBus.state_changed.emit()


# --- Ticks ---------------------------------------------------------------------

func on_day() -> void:
	var st: GameState = game.state
	for e in st.employees:
		var pers: Dictionary = game.content.personalities.get(e.personality, {})
		if e.project_id != -1:
			e.stress = clampf(e.stress + 0.7 * float(pers.get("stress_rate", 1.0)), 0.0, 100.0)
		else:
			e.stress = clampf(e.stress - 1.5, 0.0, 100.0)
		# motivação tende lentamente para 65
		e.motivation = clampf(e.motivation + (65.0 - e.motivation) * 0.01, 0.0, 100.0)
		if e.training_id != "" and e.busy_until < st.day:
			_finish_training(e)
		elif e.busy_reason != "" and e.training_id == "" and e.busy_until < st.day:
			e.busy_reason = ""
		if e.stress >= 100.0 and e.busy_until < st.day:
			_burnout(e)


func _burnout(e: Employee) -> void:
	_remove_from_team(e)
	e.stress = 45.0
	e.motivation = clampf(e.motivation - 25.0, 0.0, 100.0)
	e.busy_until = game.state.day + BURNOUT_DAYS
	e.busy_reason = "Burnout"
	add_journey(e, "Entrou em burnout e ficou %d dias afastado(a)" % BURNOUT_DAYS)
	game.add_log(_pick(game.content.feed.get("burnout", ["{emp} entrou em burnout."])).replace("{emp}", e.name), "warn")
	EventBus.state_changed.emit()


func on_month() -> void:
	var st: GameState = game.state
	var leaving: Array = []
	for e in st.employees:
		if e.is_founder:
			continue
		e.months_since_raise += 1
		e.loyalty = clampf(e.loyalty + (0.5 if e.motivation >= 40.0 else -2.5), 0.0, 100.0)
		if e.personality == "leal":
			continue
		if e.loyalty < 25.0 and e.motivation < 35.0 and st.rng.randf() < 0.25:
			leaving.append(e)
	for e in leaving:
		quit(e, "pediu demissão")
	refresh_candidates()


## Registra um marco na história do colaborador (visível em Equipe → Jornada).
func add_journey(e: Employee, text: String) -> void:
	e.journey.append({"day": game.state.day, "text": text})
	if e.journey.size() > JOURNEY_MAX:
		e.journey.pop_front()


func _pick(list: Array) -> String:
	if list.is_empty():
		return ""
	return list[game.state.rng.randi_range(0, list.size() - 1)]
