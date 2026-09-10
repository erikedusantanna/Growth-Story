extends Node
## Autoload "Game": dono do estado e dos sistemas. Orquestra o tick diário.

var content: ContentDB
var state: GameState
var services := ServiceSystem.new()
var employees := EmployeeSystem.new()
var clients := ClientSystem.new()
var projects := ProjectSystem.new()
var finance := FinanceSystem.new()
var reputation := ReputationSystem.new()
var events := EventSystem.new()
var office := OfficeSystem.new()
var objectives := ObjectiveSystem.new()
var hr := HRSystem.new()
var agency_events := AgencyEventSystem.new()
var era := EraSystem.new()
var save := SaveSystem.new()
var time := TimeSystem.new()

## Quando true, o tempo não avança sozinho em _process (usado pelos testes).
var manual_time := false
## A UI liga isso enquanto um modal está aberto; o tempo fica travado.
var ui_blocking := false


func _ready() -> void:
	content = ContentDB.new()
	content.load_all()
	for system in [services, employees, clients, projects, finance, reputation, events, office, objectives, hr, agency_events, era, time]:
		system.setup(self)
	EventBus.state_changed.connect(func(): if state != null: objectives.check())


func _process(delta: float) -> void:
	if manual_time or not is_running():
		return
	time.advance(delta)


func is_running() -> bool:
	return state != null and not state.paused and not ui_blocking and state.pending_event.is_empty() and not state.game_over


func has_game() -> bool:
	return state != null


# --- Ciclo de vida -----------------------------------------------------------------

func new_game(agency_name: String = "Minha Agência", founder_name: String = "Você", seed: int = -1) -> void:
	state = GameState.new()
	state.seed = seed if seed >= 0 else randi()
	state.rng.seed = state.seed
	state.agency_name = agency_name.strip_edges() if agency_name.strip_edges() != "" else "Minha Agência"
	state.employees.append(employees.create_founder(founder_name.strip_edges() if founder_name.strip_edges() != "" else "Você"))
	# Ano 1 como tutorial natural (GDD §37): já começa com um prospect pequeno e um candidato.
	var first := clients.spawn_prospect()
	first.relationship = 60.0
	employees.add_candidate("normal")
	add_log("Bem-vindo(a) à %s. Feche seu primeiro cliente!" % state.agency_name, "info")
	EventBus.game_started.emit()
	EventBus.state_changed.emit()


func load_game() -> bool:
	var loaded := save.load_state()
	if loaded == null:
		return false
	state = loaded
	state.paused = true
	EventBus.game_started.emit()
	EventBus.state_changed.emit()
	return true


func save_game() -> bool:
	if state == null:
		return false
	return save.save(state)


func end_game(reason: String) -> void:
	if state.game_over:
		return
	state.game_over = true
	state.paused = true
	add_log(reason, "warn")
	EventBus.game_over.emit(reason)


# --- Ticks ---------------------------------------------------------------------

func on_day() -> void:
	if state == null or state.game_over:
		return
	state.day += 1
	employees.on_day()
	projects.on_day()
	clients.on_day()
	events.on_day()
	hr.on_day()
	agency_events.on_day()
	objectives.check()
	if state.day % GameState.DAYS_PER_MONTH == 0:
		on_month()
	if state.day % (GameState.DAYS_PER_MONTH * GameState.MONTHS_PER_YEAR) == 0:
		on_year()
	EventBus.day_passed.emit(state.day)


func on_month() -> void:
	finance.on_month()
	employees.on_month()
	save_game()
	EventBus.month_passed.emit(state.month_index())
	EventBus.state_changed.emit()


func on_year() -> void:
	var year := state.year() - 1
	var revenue := 0.0
	for h in state.finance_history:
		if int(h.get("month_index", 0)) / GameState.MONTHS_PER_YEAR == year - GameState.START_YEAR:
			revenue += float(h.get("revenue", 0))
	add_log("Fim de %d: %d pessoas, %d clientes ativos, %s de receita. %s." % [
		year, state.employees.size(), state.active_clients().size(),
		FinanceSystem.format_money(revenue), reputation.phase_name()], "year")
	var old_era := era.at_year(year)
	var new_era := era.at_year(state.year())
	if String(old_era.get("id", "")) != String(new_era.get("id", "")):
		add_log("O mercado mudou: %d é a era de %s. %s" % [
			state.year(), String(new_era.get("name", "")), String(new_era.get("flavor", ""))], "year")
	EventBus.year_passed.emit(year)


# --- Utilidades ---------------------------------------------------------------------

func add_log(text: String, kind: String = "info") -> void:
	if state == null or text == "":
		return
	state.add_log(text, kind)
	EventBus.log_added.emit(text, kind)


func set_speed(speed: int) -> void:
	if state == null:
		return
	state.speed = clampi(speed, 1, 3)
	state.paused = false
	EventBus.state_changed.emit()


func toggle_pause() -> void:
	if state == null:
		return
	state.paused = not state.paused
	EventBus.state_changed.emit()


func resolve_event(choice_index: int) -> void:
	events.resolve(choice_index)
