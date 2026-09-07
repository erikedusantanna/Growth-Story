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
	Game.manual_time = true
	# prepara um estado interessante: 3 pessoas, cliente ativo, projeto rodando
	var st: GameState = Game.state
	for i in 2:
		Game.employees.hire(Game.employees.generate_candidate("high"))
	st.office_level = 2
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
	main.show_screen("team")
	await _frames(2)
	await _shot("04_team")
	main.show_screen("projects")
	await _frames(2)
	await _shot("05_projects")
	main.show_screen("company")
	await _frames(2)
	await _shot("06_company")
	main.show_screen("unlocks")
	await _frames(2)
	await _shot("07_unlocks")
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
