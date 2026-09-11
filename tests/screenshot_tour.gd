extends Node
## Captura screenshots das telas principais (precisa de um display; use xvfb-run).
## Uso: xvfb-run godot --path . --rendering-driver opengl3 res://tests/screenshot_tour.tscn
## Saída: user://shots/*.png

var main: Control
var out_dir := "user://shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	main = load("res://src/ui/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	await _shot("01_title")
	main.title_screen.agency_input.text = "Growth Lab"
	main.title_screen.founder_input.text = "Erik"
	main.title_screen._on_new_game()
	await _frames(3)
	await _shot("02_intro")
	main.popups.close()
	await _frames(2)
	await _shot("02b_escritorio_inicial")
	main.show_screen("clients")
	await get_tree().create_timer(0.4).timeout
	await _shot("02c_guia_proposta")
	main.popups.show_proposal(Game.state.prospects()[0])
	await get_tree().create_timer(0.4).timeout
	await _shot("02d_guia_enviar")
	main.popups.close()
	Game.state.tutorial_done = true
	Game.manual_time = true
	# prepara um estado interessante: 3 pessoas, cliente ativo, projeto rodando
	var st: GameState = Game.state
	st.office_level = 4
	st.money = 50000.0
	for i in 2:
		Game.employees.hire(Game.employees.generate_candidate("high"))
	var c: Client = st.prospects()[0]
	c.status = Client.Status.ACTIVE
	c.diagnosed = true
	Game.projects.create_project(c, ["social_media", "paid_traffic"], [st.employees[0].id, st.employees[1].id])
	for i in 5:
		Game.on_day()
	Game.clients.spawn_prospect()
	EventBus.state_changed.emit()
	await _frames(3)
	await _settle()
	main.show_screen("clients")
	await _frames(2)
	await _shot("03_clients")
	if not st.prospects().is_empty():
		main.popups.show_proposal(st.prospects()[0])
		await _frames(2)
		await _shot("03b_proposal")
		main.popups.close()
		await _settle()
	main.show_screen("team")
	await _frames(2)
	await _shot("04_team")
	Game.employees.train(st.employees[2], "performance")
	Game.on_day()
	await _settle()
	await get_tree().create_timer(4.5).timeout   # personagem caminha até a porta e sai
	await _shot("04a_training")
	for i in 12:
		Game.on_day()
	await _settle()
	await get_tree().create_timer(1.0).timeout
	main.popups.show_journey(st.employees[2])
	await _frames(2)
	await _shot("04b_journey")
	main.popups.close()
	await _settle()
	main.show_screen("projects")
	await _frames(2)
	await _shot("05_projects")
	main.show_screen("company")
	await _frames(2)
	await _shot("06_company")
	main.show_screen("unlocks")
	await _frames(2)
	await _shot("07_unlocks")
	st.office_level = 7
	st.reputation = 45.0
	st.money = 120000.0
	Game.office.buy(Game.office.furniture_by_id("plantas"))
	Game.office.buy(Game.office.furniture_by_id("pingpong"))
	EventBus.state_changed.emit()
	await _frames(3)
	main.show_screen("hr")
	await _frames(2)
	await _shot("07b_rh_contratar")
	Game.hr.hire()
	Game.hr.use(Game.hr.action_by_id("pet_dog"))
	Game.hr.use(Game.hr.action_by_id("pet_cat"))
	for id in ["cadeiras", "monitores", "cafe_premium", "quadro_metas"]:
		Game.office.buy(Game.office.furniture_by_id(id))
	EventBus.state_changed.emit()
	await _frames(3)
	main.show_screen("hr")
	await _frames(2)
	await _shot("07c_rh_acoes")
	main.show_screen("company")
	await _frames(2)
	main.screens["company"].scroll_vertical = 700
	await _frames(2)
	await _shot("07d_mobilia")
	main.screens["company"].scroll_vertical = 4000
	await _frames(2)
	await _shot("07d2_som")
	main.show_screen("unlocks")
	await get_tree().create_timer(1.5).timeout
	await _shot("07e_escritorio_mobilia")
	main.office_view.world.position.x = -9999.0
	main.office_view._clamp_world()
	await get_tree().create_timer(1.0).timeout
	await _shot("07f_escritorio_rh_pets")
	main.office_view.set_zoom(main.office_view.min_zoom(), Vector2(260, 160))
	await _frames(2)
	await _shot("07g_escritorio_zoom_out")
	main.office_view._layout_world(true)
	# hora do dia: fim de tarde e noite (a fração do dia vem do acumulador do TimeSystem)
	Game.time.accumulator = TimeSystem.SECONDS_PER_DAY * 0.8
	await _frames(2)
	await _shot("07i_escritorio_tarde")
	Game.time.accumulator = TimeSystem.SECONDS_PER_DAY * 0.99
	await _frames(2)
	await _shot("07j_escritorio_noite")
	Game.time.accumulator = TimeSystem.SECONDS_PER_DAY * 0.3
	# dezembro: decoração de Natal
	var saved_day := st.day
	st.day = GameState.DAYS_PER_MONTH * 11 + 3
	EventBus.state_changed.emit()
	await _frames(2)
	await _shot("07k_escritorio_natal")
	st.day = GameState.DAYS_PER_MONTH * 5 + 3
	EventBus.state_changed.emit()
	await _frames(2)
	await _shot("07l_escritorio_junina")
	st.day = saved_day
	EventBus.state_changed.emit()
	await _frames(2)
	# humores: um em burnout, um exausto, um feliz, um desanimado
	var moods_backup: Array = st.employees.map(func(e): return [e.motivation, e.stress, e.busy_reason, e.busy_until])
	var forced: Array = ["burnout", "exhausted", "sad", "happy"]
	for i in mini(st.employees.size(), forced.size()):
		var fe: Employee = st.employees[i]
		fe.last_good_news_day = -99   # "celebrando" tem prioridade sobre desanimado/feliz
		match forced[i]:
			"burnout":
				fe.busy_reason = "Burnout"
				fe.busy_until = st.day + 5
			"exhausted":
				fe.stress = 90.0
			"sad":
				fe.stress = 0.0
				fe.motivation = 20.0
			"happy":
				fe.stress = 0.0
				fe.motivation = 74.0
	EventBus.state_changed.emit()
	await get_tree().create_timer(1.2).timeout
	await _shot("07m_humores")
	for i in st.employees.size():
		var e: Employee = st.employees[i]
		e.motivation = moods_backup[i][0]
		e.stress = moods_backup[i][1]
		e.busy_reason = moods_backup[i][2]
		e.busy_until = moods_backup[i][3]
	EventBus.state_changed.emit()
	await _frames(2)
	main.popups.show_people_picker(Game.agency_events.event_by_id("workshop"))
	await _frames(2)
	await _shot("07h_evento_pessoas")
	main.popups.close()
	await _settle()
	main.popups.show_new_project(_second_client())
	await _frames(2)
	await _shot("08_new_project")
	main.popups.close()
	await _settle()
	Game.events.trigger(Game.content.events[0])
	await _frames(2)
	await _shot("09_event")
	main.popups.close()
	Game.resolve_event(0)
	await _settle()
	# cenas de evento: a câmera sai do escritório e vai para o palco / auditório / coletiva
	for pair in [["premio", "09b_cena_premio"], ["viralizou", "09c_cena_coletiva"], ["investidor_de_peso", "09d_cena_reuniao"]]:
		var ev: Dictionary = Game.content.events.filter(func(e): return e.get("id", "") == pair[0])[0]
		Game.events.trigger(ev)
		await _frames(3)
		await get_tree().create_timer(0.4).timeout
		await _shot(pair[1])
		main.popups.close()
		Game.resolve_event(0)
		await _settle()
	main.popups.show_agency_result(Game.agency_events.event_by_id("palestra"), [st.employees[0].id, st.employees[1].id], "+6 reputação, 1 prospect")
	await _frames(3)
	await get_tree().create_timer(0.4).timeout
	await _shot("09e_cena_palestra")
	main.popups.close()
	await _settle()
	# prêmios do marketing: finge um ano com uma campanha 5 estrelas
	var done_list: Array = st.projects.filter(func(pp): return pp.status == Project.Status.DONE)
	if not done_list.is_empty():
		done_list[0].result["stars"] = 5
		done_list[0].result["score"] = 90.0
	main.popups.show_awards(Game.awards.evaluate_year(st.year()))
	await _frames(3)
	await get_tree().create_timer(0.4).timeout
	await _shot("09f_premios")
	main.popups.close()
	await _settle()
	if st.running_projects().is_empty():
		var c2 := _second_client()
		Game.projects.create_project(c2, ["social_media"], [st.employees[0].id])
	var p: Project = st.running_projects()[0]
	print("aguardando projeto %d (dia %d/%d, progresso %.0f%%)" % [p.id, p.days_elapsed, p.deadline_days, p.progress() * 100])
	var guard := 0
	while p.is_running() and guard < 400:
		Game.on_day()
		guard += 1
		if not st.pending_event.is_empty():
			Game.resolve_event(0)
			await get_tree().process_frame
			main.popups.close()
	print("projeto terminou após %d dias; popups abertos: %s" % [guard, main.popups.is_open()])
	await _frames(2)
	await _shot("10_result")
	main.popups.close()
	await _settle()
	main.show_screen("company")
	await _frames(2)
	await _shot("11_company_after")
	main.show_screen("unlocks")
	await _frames(2)
	await _shot("12_concorrencia")
	st.office_level = 11
	st.money = 200000.0
	st.employees[0].career_level = 5
	Game.departments.assign(st.employees[0], "criacao")
	if st.employees.size() > 1:
		Game.departments.assign(st.employees[1], "criacao")
	EventBus.state_changed.emit()
	main.show_screen("team")
	await _frames(3)
	await _shot("13_departamentos")
	# mapa e sede na Capital (região 3) com a semana de mudança
	st.money = 500000.0
	st.reputation = 60.0
	main.show_world_map()
	await _frames(3)
	await _shot("14_mapa")
	main.world_map.close()
	Game.office.move_to(2)
	Game.office.move_to(3)
	main.show_screen("clients")
	await _frames(3)
	await get_tree().create_timer(0.8).timeout
	await _shot("14b_escritorio_capital_mudanca")
	main.show_world_map()
	await _frames(3)
	await _shot("14c_mapa_capital")
	main.world_map.close()
	if not Game.competitors.active_rivals().is_empty():
		main.popups.show_rival(String(Game.competitors.active_rivals()[0].id))
		await _frames(2)
		await _shot("14d_concorrente")
		main.popups.close()
	print("screenshots em %s" % ProjectSettings.globalize_path(out_dir))
	get_tree().quit(0)


func _second_client() -> Client:
	var c := Game.clients.spawn_prospect()
	c.status = Client.Status.ACTIVE
	return c


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _settle() -> void:
	# fecha modais abertos por eventos aleatórios para a captura mostrar a tela pedida
	while main.popups.is_open():
		main.popups.close()
		if not Game.state.pending_event.is_empty():
			Game.resolve_event(0)
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	print("shot %s" % name)
