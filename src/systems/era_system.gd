class_name EraSystem
extends RefCounted
## Evolução histórica do mercado (GDD §23). O calendário do jogo já avança por anos reais
## (GameState.year()); cada era do arquivo data/eras.json cobre uma faixa desses anos e
## define quais serviços estão "em alta" — eles rendem um pequeno bônus na nota do projeto
## (ver ProjectSystem.BONUS_TRENDING), então a melhor estratégia muda com o tempo em vez de
## ficar sempre igual.

var game


func setup(g) -> void:
	game = g


func all() -> Array:
	return game.content.eras


## Era correspondente ao ano atual do jogo (fica na última era se o tempo passar de 2025+).
func current() -> Dictionary:
	return at_year(game.state.year())


func at_year(year: int) -> Dictionary:
	var eras: Array = all()
	for e in eras:
		var start := int(e.get("year_start", 0))
		var end_raw = e.get("year_end")
		var ends: bool = end_raw == null or year <= int(end_raw)
		if year >= start and ends:
			return e
	return eras.back() if not eras.is_empty() else {}


## Serviços em alta agora: os da era mais os que uma notícia esquentou por alguns dias.
func is_trending(service_id: String) -> bool:
	return service_id in current().get("trends", []) or _has_market(service_id, "hot")


## Serviço que uma notícia esfriou: rende menos na nota enquanto durar.
func is_cold(service_id: String) -> bool:
	return _has_market(service_id, "cold") and not (service_id in current().get("trends", []))


func _has_market(service_id: String, kind: String) -> bool:
	for m in game.state.market:
		if String(m.get("service", "")) == service_id and String(m.get("kind", "")) == kind:
			return true
	return false


## Cria (ou renova) uma tendência temporária. kind: "hot" ou "cold".
func add_market_trend(service_id: String, kind: String, days: int, source: String = "") -> void:
	var st: GameState = game.state
	for m in st.market:
		if String(m.get("service", "")) == service_id and String(m.get("kind", "")) == kind:
			m["until_day"] = maxi(int(m.get("until_day", 0)), st.day + days)
			return
	st.market.append({"service": service_id, "kind": kind, "until_day": st.day + days, "source": source})


## Tendências temporárias ativas, com dias restantes.
func market_trends() -> Array:
	var st: GameState = game.state
	return st.market.map(func(m): return {
		"service": String(m.get("service", "")),
		"name": game.content.service_name(String(m.get("service", ""))),
		"kind": String(m.get("kind", "hot")),
		"days_left": int(m.get("until_day", 0)) - st.day,
		"until_day": int(m.get("until_day", 0)),
		"source": String(m.get("source", "")),
	})


func on_day() -> void:
	var st: GameState = game.state
	var gone: Array = st.market.filter(func(m): return int(m.get("until_day", 0)) <= st.day)
	for m in gone:
		var name: String = game.content.service_name(String(m.get("service", "")))
		game.add_log("O mercado voltou ao normal em %s." % name, "info")
	if not gone.is_empty():
		st.market = st.market.filter(func(m): return int(m.get("until_day", 0)) > st.day)
		EventBus.state_changed.emit()


func trending_services() -> Array:
	return current().get("trends", [])


func trending_names() -> Array:
	return trending_services().map(func(sid): return game.content.service_name(sid))
