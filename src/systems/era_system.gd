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


func is_trending(service_id: String) -> bool:
	return service_id in current().get("trends", [])


func trending_services() -> Array:
	return current().get("trends", [])


func trending_names() -> Array:
	return trending_services().map(func(sid): return game.content.service_name(sid))
