extends Node
## Teste de fumaça da interface: abre cada tela e cada popup sem erros.
## Uso: godot --headless --path . res://tests/ui_smoke_test.tscn

var main: Control


func _ready() -> void:
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
	var ok: bool = Game.state.day >= 30 and main.office_view.workers.size() == Game.state.employees.size()
	print("[%s] UI smoke" % ("OK" if ok else "FALHA"))
	get_tree().quit(0 if ok else 1)
