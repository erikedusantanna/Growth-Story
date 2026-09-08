class_name TimeSystem
extends RefCounted
## Converte tempo real em dias de jogo. Velocidades: 1x, 2x, 3x.

const SECONDS_PER_DAY := 1.4
const SPEEDS := [1.0, 2.0, 3.5]

var game
var accumulator := 0.0


func setup(g) -> void:
	game = g


func advance(delta: float) -> void:
	var st: GameState = game.state
	var mult: float = SPEEDS[clampi(st.speed - 1, 0, SPEEDS.size() - 1)]
	accumulator += delta * mult
	while accumulator >= SECONDS_PER_DAY:
		accumulator -= SECONDS_PER_DAY
		game.on_day()
		if not game.is_running():
			accumulator = 0.0
			break


func day_fraction() -> float:
	return accumulator / SECONDS_PER_DAY
