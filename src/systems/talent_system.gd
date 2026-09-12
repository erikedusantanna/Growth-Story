class_name TalentSystem
extends RefCounted
## Talento raro: de tempos em tempos aparece no mercado um profissional muito acima da média,
## com prazo curto e concorrência. Ele entra na lista de candidatos marcado como lenda; se o
## prazo passar, uma agência rival leva (e fica mais forte). Contratar custa um bônus de
## contratação além do salário, que é alto.

const MIN_GAP_DAYS := 150            # intervalo mínimo entre aparições
const MIN_DAY := 180                 # antes disso a agência nem entra no radar dessa gente
const DAILY_CHANCE := 0.02
const WINDOW_DAYS := 12              # tempo até a rival levar
const ATTR_BONUS := 16.0             # acima de um candidato "high"
const SALARY_MULT := 1.6
const SIGNING_MULT := 2.0            # bônus de contratação = N salários
const RIVAL_STRENGTH_GAIN := 4.0

var game


func setup(g) -> void:
	game = g


func active() -> Employee:
	for c in game.state.candidates:
		if c.legendary:
			return c
	return null


func signing_bonus(e: Employee) -> float:
	return e.salary * SIGNING_MULT


func can_hire(e: Employee) -> Dictionary:
	var st: GameState = game.state
	if st.employees.size() >= game.office.capacity():
		return {"ok": false, "reason": "Escritório lotado. Amplie antes de trazer essa contratação."}
	if st.money < e.salary + signing_bonus(e):
		return {"ok": false, "reason": "Precisa de %s (salário + bônus de contratação)." % FinanceSystem.format_money(e.salary + signing_bonus(e))}
	return {"ok": true, "reason": ""}


## Contrata o talento raro: paga o bônus e entra na equipe.
func hire(e: Employee) -> Dictionary:
	var check := can_hire(e)
	if not check.ok:
		return check
	game.finance.add_money(-signing_bonus(e), "Bônus de contratação: %s" % e.name, "expense")
	var r: Dictionary = game.employees.hire(e)
	if not r.ok:
		return r
	game.state.stats["legends"] = int(game.state.stats.get("legends", 0)) + 1
	game.reputation.add(3.0)
	game.add_log("⭐ %s assinou com a agência. O mercado inteiro viu." % e.name, "promo")
	return {"ok": true, "reason": ""}


## Cria o talento e coloca na lista de candidatos.
func spawn() -> Employee:
	var st: GameState = game.state
	if active() != null:
		return null
	var e: Employee = game.employees.generate_candidate("high")
	for key in Employee.ATTRS:
		e.attrs[key] = clampf(e.attr(key) + ATTR_BONUS, 5.0, 100.0)
	e.potential = 5
	e.motivation = 75.0
	e.loyalty = maxf(e.loyalty, 60.0)
	e.salary *= SALARY_MULT
	e.legendary = true
	e.candidate_expires = st.day + WINDOW_DAYS
	st.candidates.append(e)
	st.last_talent_day = st.day
	game.add_log("⭐ Talento raro no mercado: %s (%s). Só por %d dias, e a concorrência está de olho." % [
		e.name, game.employees.title(e), WINDOW_DAYS], "unlock")
	EventBus.talent_appeared.emit(e)
	EventBus.state_changed.emit()
	return e


## O prazo passou sem contratação: uma rival leva o talento.
func _lost_to_rival(e: Employee) -> void:
	var st: GameState = game.state
	st.candidates.erase(e)
	var rivals: Array = game.competitors.active_rivals()
	if rivals.is_empty():
		game.add_log("⭐ %s fechou com uma agência de fora da sua região." % e.name, "warn")
	else:
		var a: Dictionary = rivals[st.rng.randi_range(0, rivals.size() - 1)]
		var data: Dictionary = st.rivals.get(String(a.get("id", "")), {})
		if not data.is_empty():
			data["strength"] = clampf(float(data.get("strength", 40)) + RIVAL_STRENGTH_GAIN, 0.0, 100.0)
		game.add_log("⭐ %s assinou com a %s. A rival ficou mais forte." % [e.name, String(a.get("name", "concorrência"))], "warn")
	EventBus.state_changed.emit()


func on_day() -> void:
	var st: GameState = game.state
	var current := active()
	if current != null:
		if st.day >= current.candidate_expires:
			_lost_to_rival(current)
		return
	if st.day < MIN_DAY or st.day - st.last_talent_day < MIN_GAP_DAYS:
		return
	if st.employees.size() >= game.office.capacity():
		return
	if st.rng.randf() < DAILY_CHANCE:
		spawn()
