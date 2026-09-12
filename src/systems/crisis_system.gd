class_name CrisisSystem
extends RefCounted
## Crises da região: apagão, enchente, greve e afins. Atingem todo mundo que está na região,
## inclusive as agências rivais, por alguns dias: a produtividade cai, os clientes seguram
## verba e quase não chega prospect novo. O jogador vê no feed, no calendário e no aviso do topo.
## Conteúdo em data/crises.json.

var game


func setup(g) -> void:
	game = g


func data() -> Dictionary:
	return game.content.crises


func all() -> Array:
	return data().get("crises", [])


func by_id(id: String) -> Dictionary:
	for c in all():
		if String(c.get("id", "")) == id:
			return c
	return {}


## Crise em andamento ({} se não houver).
func current() -> Dictionary:
	var st: GameState = game.state
	if st.crisis.is_empty() or int(st.crisis.get("until_day", 0)) <= st.day:
		return {}
	return by_id(String(st.crisis.get("id", "")))


func is_active() -> bool:
	return not current().is_empty()


func days_left() -> int:
	return maxi(int(game.state.crisis.get("until_day", 0)) - game.state.day, 0)


func until_day() -> int:
	return int(game.state.crisis.get("until_day", 0))


## Multiplicador de produtividade da crise (1.0 quando não há crise).
func productivity_multiplier() -> float:
	return float(current().get("productivity", 1.0))


## Multiplicador na chance de aparecer prospect orgânico.
func prospect_multiplier() -> float:
	return float(current().get("prospects", 1.0))


func headline() -> String:
	var c := current()
	if c.is_empty():
		return ""
	return "%s %s · %d dia(s)" % [String(c.get("icon", "⚠️")), String(c.get("name", "Crise")), days_left()]


## Começa uma crise (sorteada ou forçada pelo id, usado nos testes).
func start(forced_id: String = "") -> Dictionary:
	var st: GameState = game.state
	var region: int = game.office.region()
	var c := by_id(forced_id) if forced_id != "" else {}
	if c.is_empty():
		var pool: Array = all().filter(func(item): return region >= int(item.get("min_region", 1)) and region <= int(item.get("max_region", 5)))
		if pool.is_empty():
			return {}
		var total := 0.0
		for item in pool:
			total += float(item.get("weight", 1))
		var roll := st.rng.randf() * total
		for item in pool:
			roll -= float(item.get("weight", 1))
			if roll <= 0.0:
				c = item
				break
		if c.is_empty():
			c = pool.back()
	var days := int(c.get("days", 7))
	st.crisis = {"id": String(c.get("id", "")), "region": region, "until_day": st.day + days, "start_day": st.day}
	st.last_crisis_day = st.day
	st.stats["crises"] = int(st.stats.get("crises", 0)) + 1
	# a crise também pega as rivais da região: elas perdem força enquanto dura
	for a in game.competitors.active_rivals():
		if int(a.get("region", 1)) != region:
			continue
		var rd: Dictionary = st.rivals.get(String(a.get("id", "")), {})
		if not rd.is_empty():
			rd["strength"] = clampf(float(rd.get("strength", 40)) - float(c.get("rival_strength", 3)), 0.0, 100.0)
	var money := float(c.get("money", 0))
	if money < 0.0:
		game.finance.add_money(money, "Crise: %s" % String(c.get("name", "")), "expense")
	for e in st.employees:
		game.employees.change_morale(e, float(c.get("morale", 0)))
	game.add_log("%s %s: %s (%d dias)" % [String(c.get("icon", "⚠️")), String(c.get("name", "Crise")), String(c.get("text", "")), days], "warn")
	EventBus.crisis_started.emit(st.crisis)
	EventBus.state_changed.emit()
	return st.crisis


func _end() -> void:
	var st: GameState = game.state
	var c := by_id(String(st.crisis.get("id", "")))
	st.crisis = {}
	game.add_log("A região voltou ao normal depois de %s." % String(c.get("name", "a crise")).to_lower(), "info")
	EventBus.state_changed.emit()


func on_day() -> void:
	var st: GameState = game.state
	if not st.crisis.is_empty():
		if int(st.crisis.get("until_day", 0)) <= st.day:
			_end()
		return
	if st.day < int(data().get("min_day", 200)) or st.day - st.last_crisis_day < int(data().get("gap_days", 200)):
		return
	if st.rng.randf() < float(data().get("daily_chance", 0.012)):
		start()
