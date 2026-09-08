class_name Worker
extends Node2D
## Personagem pixel art (24x32, visão 3/4) montado em camadas: contorno, pele, pernas, camisa, cabelo.
## A posição do nó é o pé do personagem (usada pelo y-sort do escritório).

enum State { AT_DESK, WALKING, AT_SPOT }
enum Frame { IDLE, WALK_A, WALK_B, SIT }

const WALK_SPEED := 26.0
const FRAME_TIME := 0.18
const SPRITE_OFFSET := Vector2(-12, -32)

var employee_id: int = -1
var employee_name: String = ""
var desk_pos := Vector2.ZERO
var spots: Array = []
var state: int = State.AT_DESK
var target := Vector2.ZERO
var wait_time := 0.0
var frame_timer := 0.0
var walk_frame := 0
var rng := RandomNumberGenerator.new()
var layers: Dictionary = {}
var on_project := false
var resting := false
var training := false


func _ready() -> void:
	for name in ["outline", "skin", "legs", "shirt", "hair"]:
		var s := Sprite2D.new()
		s.centered = false
		s.hframes = 4
		s.offset = SPRITE_OFFSET
		add_child(s)
		layers[name] = s
	position = desk_pos
	wait_time = rng.randf_range(3.0, 8.0)


func setup(e: Employee, desk: Vector2, spot_list: Array, seed: int) -> void:
	employee_id = e.id
	employee_name = e.name
	desk_pos = desk
	spots = spot_list
	rng.seed = seed
	position = desk
	call_deferred("apply_look", e)


func apply_look(e: Employee) -> void:
	if layers.is_empty():
		return
	var style: int = clampi(e.hair_style, 0, Employee.HAIR_STYLES - 1)
	layers["outline"].texture = load("res://assets/art/characters/outline_%d.png" % style)
	layers["hair"].texture = load("res://assets/art/characters/hair_%d.png" % style)
	layers["skin"].texture = load("res://assets/art/characters/skin.png")
	layers["legs"].texture = load("res://assets/art/characters/legs.png")
	layers["shirt"].texture = load("res://assets/art/characters/shirt.png")
	layers["skin"].modulate = Color(e.skin)
	layers["hair"].modulate = Color(e.hair_color)
	layers["shirt"].modulate = Color(e.color)


func sync(e: Employee, day: int) -> void:
	on_project = e.project_id != -1
	resting = e.busy_until >= day and e.busy_reason == "Burnout"
	training = e.busy_until >= day and e.busy_reason == "Em treinamento"
	apply_look(e)


func _process(delta: float) -> void:
	var frame := Frame.IDLE
	match state:
		State.AT_DESK:
			wait_time -= delta
			frame = Frame.SIT
			if wait_time <= 0.0:
				_pick_next()
		State.AT_SPOT:
			wait_time -= delta
			if wait_time <= 0.0:
				_pick_next()
		State.WALKING:
			var dir := target - position
			if dir.length() < 1.5:
				position = target
				state = State.AT_DESK if target == desk_pos else State.AT_SPOT
				wait_time = rng.randf_range(3.0, 7.0) if state == State.AT_SPOT else rng.randf_range(8.0, 20.0)
			else:
				position += dir.normalized() * WALK_SPEED * delta
				_set_flip(dir.x < 0.0)
				frame_timer += delta
				if frame_timer >= FRAME_TIME:
					frame_timer = 0.0
					walk_frame = 1 - walk_frame
				frame = Frame.WALK_A if walk_frame == 0 else Frame.WALK_B
	for s in layers.values():
		s.frame = frame


func _set_flip(flip: bool) -> void:
	for s in layers.values():
		s.flip_h = flip
		s.offset = Vector2(-12, -32)


func _pick_next() -> void:
	var go_out: bool
	if resting:
		go_out = true
	elif on_project:
		go_out = rng.randf() < 0.25
	else:
		go_out = rng.randf() < 0.55
	if go_out and not spots.is_empty() and state == State.AT_DESK:
		target = spots[rng.randi_range(0, spots.size() - 1)] + Vector2(rng.randf_range(-8, 8), rng.randf_range(0, 6))
	else:
		target = desk_pos
	_set_flip(false)
	state = State.WALKING


## Sai da mesa por um instante (usado ao receber feedback) sem trocar o estado.
func head_position() -> Vector2:
	return position + Vector2(0, -34)
