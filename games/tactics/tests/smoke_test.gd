extends Node
## Teste de fumaça: abre a cena principal, inicia um jogo e confere o estado.
## Uso: godot --headless --path . res://tests/smoke_test.tscn

func _ready() -> void:
	print("== Tactics smoke ==")
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var ok := not Game.started
	main._on_start()
	await get_tree().process_frame
	ok = ok and Game.started and main.start_button.disabled
	print("  jogo iniciado: %s" % Game.started)
	print("== %s ==" % ("OK" if ok else "FALHOU"))
	get_tree().quit(0 if ok else 1)
