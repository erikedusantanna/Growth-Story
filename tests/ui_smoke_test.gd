extends Node
## Teste de fumaça da interface: abre cada tela e cada popup sem erros.
## Uso: godot --headless --path . res://tests/ui_smoke_test.tscn

var main: Control


func _ready() -> void:
	var training_seen := false
	main = load("res://src/ui/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	print("== UI smoke ==")
	# título -> novo jogo
	main.title_screen.agency_input.text = "Agência Smoke"
	main.title_screen.founder_input.text = "Tester"
	main.title_screen._on_new_game()
	await get_tree().process_frame
	print("  jogo iniciado: %s" % Game.state.agency_name)
	main.popups.close()  # fecha o aviso inicial
	await get_tree().process_frame
	# guia dos primeiros objetivos: fora da aba Clientes aponta para ela; nela, para a proposta
	main.show_screen("team")
	await get_tree().create_timer(0.3).timeout
	var guide_nav: String = String(main.tutorial.step.get("target", ""))
	main.show_screen("clients")
	await get_tree().create_timer(0.3).timeout
	var guide_proposal: String = String(main.tutorial.step.get("target", ""))
	print("  guia: %s → %s" % [guide_nav, guide_proposal])
	var guide_ok: bool = guide_nav == "nav:clients" and guide_proposal == "proposal" and main.tutorial.card.visible
	main.tutorial.skip_tutorial()
	await get_tree().process_frame
	guide_ok = guide_ok and Game.state.tutorial_done and not main.tutorial.card.visible
	for key in main.SCREEN_ORDER:
		main.show_screen(key)
		await get_tree().process_frame
		print("  tela ok: %s (%d nós)" % [key, main.screens[key].content.get_child_count()])
	# fecha o primeiro cliente à força e abre o diálogo de novo projeto
	var c: Client = Game.state.prospects()[0]
	c.status = Client.Status.ACTIVE
	main.show_screen("clients")
	await get_tree().process_frame
	main.popups.show_new_project(c)
	await get_tree().process_frame
	var dlg: NewProjectDialog = main.popups.current
	print("  diálogo novo projeto: %s" % (dlg != null))
	dlg.services = ["social_media"]
	dlg.team = [Game.state.employees[0].id]
	dlg._update_preview()
	await get_tree().process_frame
	dlg._start()
	await get_tree().process_frame
	print("  projeto criado: %d em execução" % Game.state.running_projects().size())
	main.show_screen("projects")
	await get_tree().process_frame
	main.popups.show_training(Game.state.employees[0])
	await get_tree().process_frame
	main.popups.close()
	main.popups.show_choice("Teste", "corpo", ["A", "B"], func(i): print("  escolha: %d" % i))
	await get_tree().process_frame
	main.popups.close()
	Game.clients.spawn_prospect()
	main.popups.show_proposal(Game.state.prospects()[0])
	await get_tree().process_frame
	print("  popup proposta: %s" % main.popups.is_open())
	main.popups.close()
	main.popups.show_journey(Game.state.employees[0])
	await get_tree().process_frame
	print("  popup jornada: %s" % main.popups.is_open())
	main.popups.close()
	print("  objetivo atual: %s" % main.objective_label.text)
	Game.state.money = 50000.0
	Game.state.office_level = 2
	var trainee: Employee = Game.employees.generate_candidate("normal")
	Game.state.candidates.append(trainee)
	Game.employees.hire(trainee)
	var tr := Game.employees.train(trainee, "criativo")
	print("  matrícula: %s %s" % [tr.ok, tr.reason])
	Game.on_day()
	await get_tree().process_frame
	training_seen = main.office_view.training_room.visible
	print("  sala de treinamento visível: %s" % training_seen)
	for i in 10:
		Game.on_day()
	await get_tree().process_frame
	print("  sala de treinamento escondida após o curso: %s" % (not main.office_view.training_room.visible))
	Game.state.office_level = 3
	Game.state.reputation = 45.0
	Game.state.money = 80000.0
	EventBus.state_changed.emit()
	main.show_screen("unlocks")
	await get_tree().process_frame
	print("  aba Agência com eventos: %d nós" % main.screens["unlocks"].content.get_child_count())
	main.show_screen("hr")
	await get_tree().process_frame
	print("  aba RH antes de contratar: %d nós" % main.screens["hr"].content.get_child_count())
	print("  contratou RH: %s" % Game.hr.hire().ok)
	print("  adotou cachorro: %s" % Game.hr.use(Game.hr.action_by_id("pet_dog")).ok)
	Game.office.buy(Game.office.furniture_by_id("cadeiras"))
	await get_tree().process_frame
	print("  painel do escritório: %s · zoom %.2f · posição %s · ajuste %.2f" % [main.office_view.size, main.office_view.world.scale.x, main.office_view.world.position, main.office_view.fit_zoom])
	print("  anexo do RH no escritório: %s · pets: %d · largura total: %d tiles" % [main.office_view.hr_worker != null, main.office_view.pets.size(), main.office_view._total_width()])
	main.office_view.set_zoom(3.5, Vector2(50, 50))
	print("  zoom do escritório: %.2f (mín %.2f)" % [main.office_view.world.scale.x, main.office_view.min_zoom()])
	main.office_view.set_zoom(0.5, Vector2(50, 50))
	print("  zoom mínimo respeitado: %s" % is_equal_approx(main.office_view.world.scale.x, main.office_view.min_zoom()))
	main.popups.show_people_picker(Game.agency_events.event_by_id("palestra"))
	await get_tree().process_frame
	print("  popup de escolha de pessoas: %s" % main.popups.is_open())
	main.popups.close()
	# cena de evento: a "câmera" troca o escritório pelo palco com o time
	# (esvazia a fila de popups antes: o que estiver enfileirado depende do estado aleatório da partida)
	await _drain_popups(main)
	var premio: Dictionary = Game.content.events.filter(func(e): return e.get("id", "") == "premio")[0]
	Game.events.trigger(premio)
	await get_tree().process_frame
	var scene_seen: bool = main.event_stage.visible and main.event_stage.actor_count() > 0
	print("  cena do evento '%s': visível=%s · atores=%d · cenário=%s" % [premio.get("id"), main.event_stage.visible, main.event_stage.actor_count(), main.event_stage.current_kind])
	main.popups.close()
	Game.resolve_event(0)
	await _drain_popups(main)
	var scene_hidden: bool = not main.event_stage.visible
	print("  cena fechou junto com o popup: %s" % scene_hidden)
	main.popups.show_agency_result(Game.agency_events.event_by_id("palco_principal"), [Game.state.employees[0].id], "+8 reputação")
	await get_tree().process_frame
	var agency_scene: bool = main.event_stage.visible and main.event_stage.current_kind == "stage"
	print("  resultado de evento da agência com cena: %s" % agency_scene)
	main.popups.close()
	await _drain_popups(main)
	# dezembro: o escritório ganha decoração de Natal; janeiro a tira de novo
	Game.state.day = GameState.DAYS_PER_MONTH * 11
	EventBus.state_changed.emit()
	await get_tree().process_frame
	var decor_seen: bool = main.office_view.season_nodes.size() > 1
	print("  decoração de dezembro: %d nós · janelas: %d" % [main.office_view.season_nodes.size(), main.office_view.window_positions.size()])
	Game.state.day = 0
	EventBus.state_changed.emit()
	await get_tree().process_frame
	var decor_gone: bool = main.office_view.season_nodes.is_empty()
	print("  decoração some em janeiro: %s" % decor_gone)
	main.show_screen("company")
	await get_tree().process_frame
	# avança o tempo pelo _process real (manual_time = false) e resolve eventos automaticamente
	Game.state.speed = 3
	var frames := 0
	while Game.state.day < 30 and frames < 8000:
		if main.popups.is_open():
			if not Game.state.pending_event.is_empty():
				Game.resolve_event(0)
			main.popups.close()
		await get_tree().process_frame
		frames += 1
	print("  dias simulados pela UI: %d (frames %d), projetos concluídos: %d" % [Game.state.day, frames, int(Game.state.stats.projects_done)])
	for key in main.SCREEN_ORDER:
		main.show_screen(key)
		await get_tree().process_frame
	main.show_title()
	await get_tree().process_frame
	print("  workers no escritório: %d" % main.office_view.workers.size())
	var ok: bool = Game.state.day >= 30 and main.office_view.workers.size() == Game.state.employees.size() and training_seen and scene_seen and scene_hidden and agency_scene and decor_seen and decor_gone and guide_ok
	print("[%s] UI smoke" % ("OK" if ok else "FALHA"))
	get_tree().quit(0 if ok else 1)


## Fecha o que estiver aberto e o que estiver na fila (eventos, ofertas, avisos), sem resolver nada.
func _drain_popups(main) -> void:
	var guard := 0
	while main.popups.is_open() and guard < 20:
		main.popups.close()
		if not Game.state.pending_event.is_empty():
			Game.resolve_event(0)
		await get_tree().process_frame
		guard += 1
