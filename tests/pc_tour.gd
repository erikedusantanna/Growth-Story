extends Node
## Tour de screenshots do layout de PC: abre a cena principal na janela larga e fotografa as telas.
## O tour normal (screenshot_tour) cobre o celular; este cobre as três colunas.
## Uso: xvfb-run godot --path . --rendering-driver opengl3 res://tests/pc_tour.tscn
## (sem --resolution: a janela vem de project.godot, 1620x960). Saída em user://pc/.
var main: Control
var out_dir := "user://pc"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://src/ui/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	print("VIEWPORT %.0fx%.0f" % [vp.x, vp.y])
	await _shot("00_titulo")
	main.title_screen.agency_input.text = "Growth Lab"
	main.title_screen.founder_input.text = "Erik"
	main.title_screen._on_new_game()
	await _frames(3)
	await _settle()
	# alguns dias para haver conteúdo nas abas
	Game.state.money = 240000.0
	Game.state.reputation = 45.0
	for i in 3:
		Game.clients.spawn_prospect()
	Game.employees.add_candidate("high")
	await _frames(2)
	await _settle()
	for key in main.SCREEN_ORDER:
		main.show_screen(key)
		await _frames(4)
		main.screens[key].scroll_vertical = 0
		await _frames(2)
		await _shot("01_%s" % key)
	main.popups.show_notifications()
	await _frames(3)
	await _shot("02_notificacoes")
	await _settle()
	var c: Client = Game.state.prospects()[0]
	main.popups.show_proposal(c)
	await _frames(3)
	await _shot("03_proposta")
	await _settle()
	main.show_world_map()
	await get_tree().create_timer(0.6).timeout
	await _shot("04_mapa")
	main.world_map.close()
	await _frames(2)
	print("shots em %s" % ProjectSettings.globalize_path(out_dir))
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _settle() -> void:
	var guard := 0
	while main.popups.is_open() and guard < 20:
		main.popups.close()
		if not Game.state.pending_event.is_empty():
			Game.resolve_event(0)
		await get_tree().process_frame
		guard += 1


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("shot %s" % name)
