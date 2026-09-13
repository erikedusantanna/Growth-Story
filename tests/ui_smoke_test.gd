extends Node
## Teste de fumaça da interface: abre cada tela e cada popup sem erros.
## Uso: godot --headless --path . res://tests/ui_smoke_test.tscn

var main: Control


func _ready() -> void:
	var training_seen := false
	Game.save.delete_save()  # o teste sempre começa com os espaços de save vazios
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
	Game.state.office_level = 4
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
	Game.state.office_level = 7
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
	# humores: estresse alto vira ícone no personagem; quem sai atravessa o escritório com a caixa
	var founder: Employee = Game.state.employees[0]
	founder.stress = 90.0
	EventBus.state_changed.emit()
	await get_tree().process_frame
	var w0: Worker = main.office_view.workers.get(founder.id)
	var mood_ok: bool = w0 != null and w0.mood == "exhausted" and w0.mood_sprite.visible
	founder.stress = 0.0
	var extra: Employee = Game.employees.generate_candidate("normal")
	Game.state.candidates.append(extra)
	Game.employees.hire(extra)
	await get_tree().process_frame
	var w1: Worker = main.office_view.workers.get(extra.id)
	Game.employees.quit(extra, "teste")
	await get_tree().process_frame
	var leaving_ok: bool = w1 != null and is_instance_valid(w1) and w1.leaving_for_good and w1.carrying_box and not main.office_view.workers.has(extra.id)
	print("  humor exausto no personagem: %s · saída pela porta com caixa: %s" % [mood_ok, leaving_ok])
	# mapa: abre em tela cheia com os 5 marcos e fecha
	main.show_world_map()
	await get_tree().process_frame
	await get_tree().process_frame
	var map_ok: bool = main.world_map.visible and main.world_map.marker_nodes.size() == 5 and Game.ui_blocking
	# camada viva: veículos e nuvens existem, e o caminhão da mudança anda pela avenida
	var life: WorldMapLife = main.world_map.life
	var life_ok: bool = life.vehicles.size() > 20 and life.clouds.size() == WorldMapLife.CLOUD_COUNT and life.play_move(1, 2) and life.truck_active()
	# os carros passam ATRÁS dos prédios: a camada de cobertura fica depois dos veículos
	life_ok = life_ok and life.cover != null and life.cover.texture != null and life.cover.get_index() > life.ground.get_index()
	var car0: Vector2 = life.vehicles[0]["sprite"].position
	await get_tree().create_timer(0.4).timeout
	life_ok = life_ok and float(life.truck["d"]) > 0.0 and life.vehicles[0]["sprite"].position != car0
	print("  camada viva do mapa (veículos, nuvens, caminhão): %s (%d veículos)" % [life_ok, life.vehicles.size()])
	map_ok = map_ok and life_ok
	main.world_map.close()
	await get_tree().process_frame
	map_ok = map_ok and not main.world_map.visible and not Game.ui_blocking
	print("  mapa abre com 5 regiões e fecha: %s" % map_ok)
	# rival: na Região 2 a sede aparece no mapa e o painel abre
	Game.state.money = 500000.0
	Game.state.reputation = 60.0
	var region_before: int = Game.state.office_level
	Game.office.move_to(2)
	main.show_world_map()
	await get_tree().process_frame
	var rival_buttons: int = 0
	for n in main.world_map.markers.get_children():
		for ch in n.get_children():
			if ch is Button and ch.has_meta("rival_id"):
				rival_buttons += 1
	main.world_map.close()
	main.popups.show_rival("vertice")
	await get_tree().process_frame
	var rival_ok: bool = rival_buttons >= 1 and rival_buttons == Game.competitors.active_rivals().size() and main.popups.is_open()
	print("  rival no mapa e painel: %s (%d sede)" % [rival_ok, rival_buttons])
	# a sede da rival ganhou anel vermelho e rótulo com fundo (ficar visível era o pedido)
	main.show_world_map()
	await get_tree().process_frame
	var rival_marks: int = main.world_map.life.rivals.size()
	main.world_map.close()
	await get_tree().process_frame
	print("  destaque da rival no mapa: %s (%d anel)" % [rival_marks >= 1, rival_marks])
	rival_ok = rival_ok and rival_marks >= 1
	# calendário: abre com os 12 meses, agenda e foco do mês
	main.show_calendar()
	await get_tree().process_frame
	await get_tree().process_frame
	var cal_ok: bool = main.calendar_screen.visible and Game.ui_blocking and main.calendar_screen.body.get_child_count() > 4
	main.calendar_screen.close()
	await get_tree().process_frame
	cal_ok = cal_ok and not main.calendar_screen.visible and not Game.ui_blocking
	print("  calendário abre e fecha: %s" % cal_ok)
	# missão nova e notícia abrem o popup com a arte
	Game.state.day = 300
	Game.quests.start("dois_projetos")
	await get_tree().process_frame
	var quest_ok: bool = main.popups.is_open()
	main.popups.close()
	await get_tree().process_frame
	Game.news.publish("b4_pivot")
	await get_tree().process_frame
	var news_ok: bool = main.popups.is_open()
	main.popups.close()
	await get_tree().process_frame
	print("  popup de missão: %s · popup de notícia: %s" % [quest_ok, news_ok])
	# talento raro, crise e decisão de projeto abrem os popups novos
	Game.state.money = 300000.0
	var talent: Employee = Game.talent.spawn()
	await get_tree().process_frame
	var talent_ok: bool = talent != null and main.popups.is_open()
	main.popups.close()
	await get_tree().process_frame
	main.show_screen("team")
	await get_tree().process_frame
	talent_ok = talent_ok and main.screens["team"].content.get_child_count() > 0 and Game.talent.can_hire(talent).ok
	Game.crisis.start("apagao")
	await get_tree().process_frame
	var crisis_ok: bool = main.popups.is_open() and Game.crisis.is_active()
	main.popups.close()
	await get_tree().process_frame
	main._refresh_objective()
	await get_tree().process_frame
	crisis_ok = crisis_ok and main.quest_label.visible and main.quest_label.text.contains("Apagão")
	print("  popup de talento raro: %s · aviso de crise no topo: %s" % [talent_ok, crisis_ok])
	# decisão no meio de um projeto em andamento
	var dec_ok := false
	if Game.state.running_projects().is_empty():
		var dc: Client = Game.clients.spawn_prospect()
		dc.status = Client.Status.ACTIVE
		var free_ids: Array = Game.state.employees.filter(func(e): return e.is_available(Game.state.day)).map(func(e): return e.id)
		if not free_ids.is_empty():
			Game.projects.create_project(dc, [String(Game.state.unlocked_services[0])], [free_ids[0]])
		await get_tree().process_frame
		await _drain_popups(main)
	var running: Array = Game.state.running_projects()
	if not running.is_empty():
		var proj: Project = running[0]
		proj.decision_done = false
		var dec: Dictionary = Game.projects.trigger_decision(proj, "pedido_ultima_hora")
		await get_tree().process_frame
		dec_ok = not dec.is_empty() and main.popups.is_open() and (dec.get("choices", []) as Array).size() >= 2
		await _drain_popups(main)
		dec_ok = dec_ok and not main.popups.is_open() and not Game.ui_blocking
	print("  popup de decisão de projeto: %s" % dec_ok)
	# especialização de carreira pela aba Equipe
	var spec_ok := false
	for e in Game.state.employees:
		if e.is_founder:
			continue
		for key in Employee.ATTRS:
			e.attrs[key] = 90.0
		e.busy_until = -1
		var options: Array = Game.employees.spec_options(e)
		if options.is_empty():
			break
		main.popups.show_specialize(e)
		await get_tree().process_frame
		spec_ok = main.popups.is_open()
		main.popups.close()
		await get_tree().process_frame
		spec_ok = spec_ok and Game.employees.can_specialize(e, String(options[0])).ok
		break
	print("  popup de especialização: %s" % spec_ok)
	# pets novos andam pelo escritório
	for kind in ["rabbit", "parrot", "capybara"]:
		if not Game.state.pets.has(kind):
			Game.state.pets.append(kind)
	main.office_view.refresh()
	await get_tree().process_frame
	var pets_ok: bool = main.office_view.pets.size() >= 3
	print("  pets no escritório: %s (%d)" % [pets_ok, main.office_view.pets.size()])
	# aba Clientes avisa quando há prospect esperando
	Game.clients.spawn_prospect()
	main.show_screen("team")
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	var nav: Button = main.nav_buttons["clients"]
	var alert_ok: bool = nav.text.contains(str(Game.state.prospects().size())) and nav.modulate != Color.WHITE
	print("  aba Clientes avisa prospect: %s (\"%s\")" % [alert_ok, nav.text.replace("\n", " ")])
	main.popups.close()
	await _drain_popups(main)
	Game.state.office_level = region_before
	Game.state.moving_until_day = -1
	main.popups.show_awards(Game.awards.evaluate_year(GameState.START_YEAR))
	await get_tree().process_frame
	var awards_scene: bool = main.popups.is_open() and main.event_stage.visible
	print("  cerimônia de prêmios com cena: %s (%s)" % [awards_scene, main.event_stage.current_kind])
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
	# nada pode ser mais largo que a tela: HUD ou tela larga demais empurra o layout e corta a interface
	var vp_w: float = 540.0 - 16.0
	var widest := 0.0
	var layout_ok := true
	for key in main.SCREEN_ORDER:
		main.show_screen(key)
		await get_tree().process_frame
		await get_tree().process_frame
		var w: float = main.screens[key].get_combined_minimum_size().x
		widest = maxf(widest, w)
		if w > vp_w:
			layout_ok = false
			print("  LARGURA: tela %s pede %.0f px (limite %.0f)" % [key, w, vp_w])
	var hud_w: float = main.hud.get_combined_minimum_size().x
	widest = maxf(widest, hud_w)
	if hud_w > vp_w:
		layout_ok = false
		print("  LARGURA: HUD pede %.0f px (limite %.0f)" % [hud_w, vp_w])
	print("  layout cabe na tela: %s (mais largo: %.0f de %.0f px)" % [layout_ok, widest, vp_w])
	# evento salvo em aberto: ao carregar precisa reaparecer, senão o tempo fica travado
	await _drain_popups(main)   # começa sem nada na fila para o teste medir só o evento salvo
	Game.events.trigger(Game.content.events[0])
	await get_tree().process_frame
	main.popups.close()   # fecha o popup sem resolver: o evento continua pendente e vai para o save
	Game.save_game()
	var pending_id: String = String(Game.state.pending_event.get("id", ""))
	Game.state = null
	var reload_ok: bool = Game.load_game()
	await get_tree().process_frame
	reload_ok = reload_ok and main.popups.is_open() and String(Game.state.pending_event.get("id", "")) == pending_id
	Game.state.paused = false
	Game.resolve_event(0)
	await _drain_popups(main)   # o desfecho pode abrir outro popup; o tempo só volta com a fila vazia
	reload_ok = reload_ok and Game.state.pending_event.is_empty() and Game.is_running()
	print("  save com evento em aberto volta a rodar: %s" % reload_ok)
	# tela inicial: escolher de qual espaço continuar
	var workers_count: int = main.office_view.workers.size()
	Game.save.delete_save()
	Game.save.save(Game.state, 2)
	var slots_ok: bool = Game.save.has_slot(2)
	main.show_title()
	await get_tree().process_frame
	main.title_screen._on_continue()
	await get_tree().process_frame
	slots_ok = slots_ok and main.title_screen.slots_panel.visible and main.title_screen.slots_box.get_child_count() == SaveSystem.MAX_SLOTS
	main.title_screen._pick_slot(2, true)
	await get_tree().process_frame
	slots_ok = slots_ok and Game.state != null and not main.title_screen.visible and Game.is_running()
	print("  escolher espaço de save ao continuar: %s (%d espaços)" % [slots_ok, SaveSystem.MAX_SLOTS])
	Game.save.delete_save()
	print("  workers no escritório: %d" % workers_count)
	var ok: bool = Game.state.day >= 30 and main.office_view.workers.size() == Game.state.employees.size() and training_seen and scene_seen and scene_hidden and agency_scene and decor_seen and decor_gone and guide_ok and awards_scene and mood_ok and leaving_ok and map_ok and rival_ok and cal_ok and quest_ok and news_ok and pets_ok and alert_ok and layout_ok and reload_ok and talent_ok and crisis_ok and dec_ok and spec_ok and slots_ok
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
