class_name ReputationSystem
extends RefCounted
## Reputação de 0 a 100 e faixas de percepção do mercado.

var game


func setup(g) -> void:
	game = g


func add(delta: float) -> void:
	var st: GameState = game.state
	var before := st.reputation
	# Ganhos ficam mais difíceis conforme a reputação sobe (retornos decrescentes).
	if delta > 0.0:
		delta *= clampf(1.0 - st.reputation / 100.0, 0.05, 1.0)
	else:
		# Quem ainda é desconhecido tem menos a perder.
		delta *= clampf(0.3 + st.reputation / 100.0 * 0.7, 0.3, 1.0)
	st.reputation = clampf(st.reputation + delta, 0.0, 100.0)
	var real_delta := st.reputation - before
	if absf(real_delta) >= 0.5:
		game.add_log("%s%d reputação" % ["+" if real_delta > 0 else "", int(roundf(real_delta))], "rep")
	EventBus.reputation_changed.emit(st.reputation, real_delta)


func tier_name() -> String:
	var rep: float = game.state.reputation
	if rep < 20.0:
		return "Freelancer desconhecido"
	if rep < 40.0:
		return "Agência local"
	if rep < 60.0:
		return "Agência reconhecida"
	if rep < 80.0:
		return "Agência nacional"
	return "Agência de elite"


## Fase de crescimento da agência (GDD §29).
func phase_name() -> String:
	var st: GameState = game.state
	var n := st.employees.size()
	var rep := st.reputation
	if rep >= 85.0 and n >= 16:
		return "Grupo de agências"
	if rep >= 70.0 and n >= 10:
		return "Agência global"
	if rep >= 45.0 and n >= 6:
		return "Agência nacional"
	if rep >= 20.0 and n >= 3:
		return "Agência local"
	if n >= 2:
		return "Micro agência"
	return "Freelancer"
