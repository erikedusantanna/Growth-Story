class_name ObjectiveSystem
extends RefCounted
## Objetivos sequenciais que guiam o primeiro ano (GDD §37). Lidos de data/objectives.json.

var game
var _checking := false


func setup(g) -> void:
	game = g


func all() -> Array:
	return game.content.objectives


func current() -> Dictionary:
	var list := all()
	var idx: int = game.state.objective_index
	if idx < 0 or idx >= list.size():
		return {}
	return list[idx]


func completed_count() -> int:
	return mini(game.state.objective_index, all().size())


func progress_value(obj: Dictionary) -> float:
	var st: GameState = game.state
	match String(obj.get("type", "")):
		"clients_signed", "diagnoses", "projects_done", "hires", "trainings", "retainers", "five_stars":
			return float(st.stats.get(obj["type"], 0))
		"services_unlocked":
			return float(st.unlocked_services.size())
		"office_level":
			return float(st.office_level)
		"reputation":
			return st.reputation
		"employees":
			return float(st.employees.size())
		_:
			return 0.0


func is_done(obj: Dictionary) -> bool:
	return progress_value(obj) >= float(obj.get("value", 1))


## Avança pelos objetivos concluídos. Chamado a cada dia e quando o estado muda.
func check() -> void:
	if _checking or game.state == null:
		return
	_checking = true
	var advanced := false
	while true:
		var obj := current()
		if obj.is_empty() or not is_done(obj):
			break
		game.state.objective_index += 1
		advanced = true
		var reward := float(obj.get("reward_money", 0))
		if reward > 0.0:
			game.finance.add_money(reward, "Bônus por objetivo", "revenue")
		game.add_log("Objetivo concluído: %s" % obj["text"], "unlock")
	_checking = false
	if advanced:
		EventBus.state_changed.emit()
