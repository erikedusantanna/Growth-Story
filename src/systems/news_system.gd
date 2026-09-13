class_name NewsSystem
extends RefCounted
## Notícias do mercado: manchetes cômicas que aparecem de tempos em tempos como página de jornal
## ou post de rede social (data/news.json). Servem de entretenimento e de tempero do mundo; só
## algumas têm um efeito pequeno, sempre declarado no próprio texto. As marcas e pessoas são
## fictícias, com nomes que apenas lembram as reais.

var game


func setup(g) -> void:
	game = g


func data() -> Dictionary:
	return game.content.news


func all() -> Array:
	return data().get("news", [])


func by_id(id: String) -> Dictionary:
	for n in all():
		if String(n.get("id", "")) == id:
			return n
	return {}


## Nome do veículo: jornal ou rede, sorteado de forma estável pelo id da notícia.
func outlet(n: Dictionary) -> String:
	var list: Array = data().get("papers", ["Jornal do Mercado"]) if String(n.get("media", "jornal")) == "jornal" else data().get("networks", ["Bluesocial"])
	if list.is_empty():
		return "Jornal do Mercado"
	return String(list[absi(String(n.get("id", "")).hash()) % list.size()])


func _eligible(n: Dictionary) -> bool:
	var st: GameState = game.state
	var last: int = int(st.news_seen.get(String(n.get("id", "")), -9999))
	return st.day - last >= int(data().get("cooldown_days", 200))


func _pick() -> Dictionary:
	var st: GameState = game.state
	var pool: Array = all().filter(func(n): return _eligible(n))
	if pool.is_empty():
		return {}
	return pool[st.rng.randi_range(0, pool.size() - 1)]


## Publica uma notícia (usada pelo sorteio diário e pelos testes). Aplica o efeito, se houver.
func publish(id: String = "") -> Dictionary:
	var st: GameState = game.state
	var n := by_id(id) if id != "" else _pick()
	if n.is_empty():
		return {}
	st.news_seen[String(n.get("id", ""))] = st.day
	st.last_news_day = st.day
	st.news_feed.push_front({"id": String(n.get("id", "")), "day": st.day})
	if st.news_feed.size() > 12:
		st.news_feed.pop_back()
	st.stats["news"] = int(st.stats.get("news", 0)) + 1
	_apply_effect(n)
	game.add_log("📰 %s: %s" % [outlet(n), String(n.get("title", ""))], "fun")
	EventBus.news_published.emit(n)
	EventBus.state_changed.emit()
	return n


func _apply_effect(n: Dictionary) -> void:
	for effect in _effects(n):
		_apply_one(n, effect)


## A notícia pode ter um efeito (`effect`) ou vários (`effects`).
func _effects(n: Dictionary) -> Array:
	var list: Array = (n.get("effects", []) as Array).duplicate()
	var single: Dictionary = n.get("effect", {})
	if not single.is_empty():
		list.append(single)
	return list


func _apply_one(n: Dictionary, effect: Dictionary) -> void:
	var value := float(effect.get("value", 0))
	match String(effect.get("type", "")):
		"money_pct":
			game.finance.add_money(game.state.money * value, "Notícia: %s" % String(n.get("title", "")), "expense" if value < 0.0 else "revenue")
		"money":
			game.finance.add_money(value, "Notícia: %s" % String(n.get("title", "")), "expense" if value < 0.0 else "revenue")
		"reputation":
			if value < 0.0:
				game.reputation.penalize(-value, "repercussão")
			else:
				game.reputation.add(value)
		"morale":
			for e in game.state.employees:
				game.employees.change_morale(e, value)
		"trend":
			game.era.add_market_trend(String(effect.get("service", "")), "hot", int(effect.get("days", 30)), String(n.get("title", "")))
		"cold":
			game.era.add_market_trend(String(effect.get("service", "")), "cold", int(effect.get("days", 30)), String(n.get("title", "")))
		"client_budget":
			for c in game.state.active_clients():
				c.budget = maxf(c.budget * (1.0 + value), 500.0)
		"prospects":
			for i in int(value):
				game.clients.spawn_prospect()


func on_day() -> void:
	var st: GameState = game.state
	if not st.pending_event.is_empty():
		return
	if st.day - st.last_news_day < int(data().get("gap_days", 9)):
		return
	if st.rng.randf() > float(data().get("daily_chance", 0.2)):
		return
	publish()
