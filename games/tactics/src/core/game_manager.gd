extends Node
## Dono do estado do jogo e dos sistemas. Autoload `Game`.
## Por enquanto só marca que o jogo foi iniciado; as mecânicas entram com o GDD.

var started: bool = false


func new_game() -> void:
	started = true
	EventBus.state_changed.emit()
