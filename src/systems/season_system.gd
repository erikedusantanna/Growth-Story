class_name SeasonSystem
extends RefCounted
## Datas comemorativas (data/seasons.json): em certos meses o escritório ganha decoração
## (guirlanda na parede + um objeto no chão) e o feed avisa. Só visual, sem efeito na simulação.

var game


func setup(g) -> void:
	game = g


func themes() -> Array:
	return game.content.seasons


## Tema do mês (0 = janeiro) ou {} se o mês não tem data comemorativa.
func theme_for_month(month: int) -> Dictionary:
	for t in themes():
		if int(t.get("month", -1)) == month:
			return t
	return {}


func current() -> Dictionary:
	if game.state == null:
		return {}
	return theme_for_month(game.state.month())


func on_month() -> void:
	var t := current()
	if not t.is_empty():
		game.add_log(String(t.get("log", "")), "fun")
