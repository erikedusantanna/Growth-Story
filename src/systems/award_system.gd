class_name AwardSystem
extends RefCounted
## Prêmios do Marketing: cerimônia anual na virada do ano com três categorias avaliadas
## pelo que a agência fez nos 12 meses (GDD §36 — reconhecimento). Vencer rende reputação
## e moral; ser indicado rende um pouco. O histórico fica em state.awards.

const CATEGORIES := {
	"campaign": {"name": "Campanha do Ano", "icon": "🎬"},
	"agency": {"name": "Agência do Ano", "icon": "🏆"},
	"professional": {"name": "Profissional do Ano", "icon": "🌟"},
}
const AGENCY_BASE := 45.0      # pontos para vencer no primeiro ano; sobe 8 por ano
const AGENCY_PER_YEAR := 8.0

var game


func setup(g) -> void:
	game = g


func year_projects(year: int) -> Array:
	var idx := year - GameState.START_YEAR
	return game.state.projects.filter(func(p): return p.status == Project.Status.DONE and p.finished_on >= 0 and p.finished_on / (GameState.DAYS_PER_MONTH * GameState.MONTHS_PER_YEAR) == idx)


## Pontuação da agência no ano (transparente para o jogador): entregas, cases, clientes e reputação.
func agency_score(year: int) -> float:
	var st: GameState = game.state
	var projects := year_projects(year)
	var five := 0
	for p in projects:
		if int(p.result.get("stars", 0)) == 5:
			five += 1
	return float(projects.size()) * 3.0 + float(five) * 10.0 + float(st.active_clients().size()) * 2.0 + st.reputation * 0.5


func agency_threshold(year: int) -> float:
	return AGENCY_BASE + AGENCY_PER_YEAR * float(year - GameState.START_YEAR)


## Avalia o ano: {year, results: [{category, name, icon, status: won|nominated|lost, title, detail, people}]}
func evaluate_year(year: int) -> Dictionary:
	var st: GameState = game.state
	var projects := year_projects(year)
	var results: Array = []
	var rivals: Array = game.competitors.agency_names()
	var rival: String = rivals[st.rng.randi_range(0, rivals.size() - 1)]

	# Campanha do Ano: melhor nota do ano
	var best: Project = null
	for p in projects:
		if p.kind != Project.Kind.PROJECT:
			continue
		if best == null or float(p.result.get("score", 0)) > float(best.result.get("score", 0)):
			best = p
	var camp := {"category": "campaign", "name": CATEGORIES.campaign.name, "icon": CATEGORIES.campaign.icon, "people": []}
	if best != null and int(best.result.get("stars", 0)) == 5:
		var c: Client = st.client_by_id(best.client_id)
		camp["status"] = "won"
		camp["title"] = best.title
		camp["detail"] = "%s para %s, nota %d" % [best.title, c.name if c != null else "?", int(roundf(float(best.result.get("score", 0))))]
		camp["people"] = best.team.duplicate()
	elif best != null and int(best.result.get("stars", 0)) >= 4:
		camp["status"] = "nominated"
		camp["title"] = best.title
		camp["detail"] = "%s foi indicada (%d estrelas); o prêmio ficou com %s." % [best.title, int(best.result.get("stars", 0)), rival]
	else:
		camp["status"] = "lost"
		camp["title"] = ""
		camp["detail"] = "Nenhuma campanha de 4+ estrelas este ano. Levou %s." % rival
	results.append(camp)

	# Agência do Ano: pontuação do ano contra a régua do mercado
	var score := agency_score(year)
	var threshold := agency_threshold(year)
	var ag := {"category": "agency", "name": CATEGORIES.agency.name, "icon": CATEGORIES.agency.icon, "people": [], "title": st.agency_name}
	if score >= threshold:
		ag["status"] = "won"
		ag["detail"] = "%d pontos no ano (meta %d): entregas, cases de 5 estrelas, clientes ativos e reputação." % [int(score), int(threshold)]
	elif score >= threshold * 0.6:
		ag["status"] = "nominated"
		ag["detail"] = "Indicada com %d pontos (meta %d). %s levou." % [int(score), int(threshold), rival]
	else:
		ag["status"] = "lost"
		ag["detail"] = "%d pontos (meta %d). %s levou." % [int(score), int(threshold), rival]
	results.append(ag)

	# Profissional do Ano: quem mais entregou (participações) com boa média
	var count: Dictionary = {}
	var stars_sum: Dictionary = {}
	for p in projects:
		for id in p.team:
			count[id] = int(count.get(id, 0)) + 1
			stars_sum[id] = float(stars_sum.get(id, 0.0)) + float(p.result.get("stars", 0))
	var top_id := -1
	var top_key := -1.0
	for id in count:
		var e: Employee = st.employee_by_id(int(id))
		if e == null:
			continue
		var key: float = float(count[id]) * 10.0 + e.average_attr() * 0.01
		if key > top_key:
			top_key = key
			top_id = int(id)
	var pro := {"category": "professional", "name": CATEGORIES.professional.name, "icon": CATEGORIES.professional.icon, "people": []}
	if top_id != -1:
		var e: Employee = st.employee_by_id(top_id)
		var n := int(count[top_id])
		var avg: float = float(stars_sum[top_id]) / float(n)
		pro["title"] = e.name
		pro["people"] = [top_id]
		if n >= 3 and avg >= 4.0:
			pro["status"] = "won"
			pro["detail"] = "%s: %d entregas no ano com média de %.1f estrelas." % [e.name, n, avg]
		else:
			pro["status"] = "nominated"
			pro["detail"] = "%s foi indicado(a) (%d entregas, média %.1f). Precisa de 3+ entregas com média 4,0+." % [e.name, n, avg]
	else:
		pro["status"] = "lost"
		pro["title"] = ""
		pro["detail"] = "Ninguém da equipe entregou projetos este ano."
	results.append(pro)
	return {"year": year, "results": results}


## Aplica os efeitos, guarda no histórico e abre a cerimônia.
func on_year(year: int) -> void:
	var st: GameState = game.state
	var ceremony := evaluate_year(year)
	var won: Array = []
	for r in ceremony.results:
		st.awards.append({"year": year, "category": r.category, "status": r.status, "title": r.get("title", ""), "detail": r.detail})
		match String(r.status):
			"won":
				won.append("%s %s" % [r.icon, r.name])
				st.stats["awards"] = int(st.stats.get("awards", 0)) + 1
				_apply_win(r)
			"nominated":
				game.reputation.add(1.0)
	if won.is_empty():
		game.add_log("🏆 Prêmios do Marketing %d: a %s saiu sem troféu desta vez." % [year, st.agency_name], "year")
	else:
		game.add_log("🏆 Prêmios do Marketing %d: a %s levou %s!" % [year, st.agency_name, ", ".join(won)], "year")
	EventBus.awards_ceremony.emit(ceremony)


func _apply_win(r: Dictionary) -> void:
	var st: GameState = game.state
	match String(r.category):
		"agency":
			game.reputation.add(6.0)
			for e in st.employees:
				game.employees.change_morale(e, 8.0)
		"campaign":
			game.reputation.add(4.0)
			for id in r.people:
				var e: Employee = st.employee_by_id(int(id))
				if e != null:
					game.employees.change_morale(e, 10.0)
					game.employees.good_news(e)
					game.employees.add_journey(e, "Campanha do Ano: %s" % String(r.get("title", "")))
		"professional":
			for id in r.people:
				var e: Employee = st.employee_by_id(int(id))
				if e != null:
					game.employees.change_morale(e, 15.0)
					game.employees.good_news(e)
					e.loyalty = clampf(e.loyalty + 10.0, 0.0, 100.0)
					game.employees.add_journey(e, "Profissional do Ano nos Prêmios do Marketing")


func won_count() -> int:
	return int(game.state.stats.get("awards", 0))
