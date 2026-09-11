extends Control
## Cena principal. Placeholder até o GDD definir as telas do jogo.

@onready var title_label: Label = $Title
@onready var start_button: Button = $Start


func _ready() -> void:
	start_button.pressed.connect(_on_start)
	EventBus.state_changed.connect(_refresh)
	_refresh()


func _on_start() -> void:
	Game.new_game()


func _refresh() -> void:
	title_label.text = "Tactics" if not Game.started else "Tactics — jogo iniciado"
	start_button.disabled = Game.started
