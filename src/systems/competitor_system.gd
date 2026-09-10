class_name CompetitorSystem
extends RefCounted
## Concorrência (GDD §30-31 e §35): o mercado não espera. Um prospect que fica tempo
## demais sem proposta pode ser fechado por uma agência rival antes de você.
## Propostas recebidas por funcionários (proposta_concorrente) e o crescimento de um
## rival específico já existem como eventos (data/events.json); este sistema cobre a
## outra ponta: a disputa por clientes ainda não fechados.

var game
var _last_steal_day := -9999


func setup(g) -> void:
	game = g


func _data() -> Dictionary:
	return game.content.competitors


func agency_names() -> Array:
	return _data().get("agencies", ["Uma agência concorrente"])


func on_day() -> void:
	var st: GameState = game.state
	if st.day < int(_data().get("min_day", 60)):
		return
	if st.day == _last_steal_day:
		return
	var idle_days := int(_data().get("steal_after_idle_days", 22))
	var chance := float(_data().get("steal_chance_per_day", 0.05))
	for c in st.prospects():
		if st.day - c.known_on < idle_days:
			continue
		if st.rng.randf() < chance:
			var names: Array = agency_names()
			var agency: String = names[st.rng.randi_range(0, names.size() - 1)]
			game.clients.lose_client(c, "foi fechado por %s antes de você" % agency)
			_last_steal_day = st.day
			break
