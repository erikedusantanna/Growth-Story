class_name Worker
extends Node2D
## Personagem pixel art chibi (32x48, visão 3/4) montado em camadas: contorno (+ rosto e óculos), pele,
## pernas, camisa e cabelo. A folha tem 4 poses por linha e 4 direções (frente, costas, esquerda, direita).
## A posição do nó é o pé do personagem (usada pelo y-sort do escritório).

enum State { AT_DESK, WALKING, AT_SPOT, LEAVING, AWAY, RETURNING }
enum Frame { IDLE, WALK_A, WALK_B, SIT }
enum Dir { FRONT, BACK, LEFT, RIGHT }

const WALK_SPEED := 26.0
const FRAME_TIME := 0.18
const SPRITE_OFFSET := Vector2(-16, -48)

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
var door_pos := Vector2.ZERO
var static_pose := false   # sala de treinamento: fica parado na pose escolhida
var sitting := false
var morale := -1.0         # barra de moral sobre a cabeça (-1 = não mostra)
var facing: int = Dir.FRONT
var mood := ""             # humor visível (EmployeeSystem.mood_of): ícone animado sobre a cabeça
var mood_sprite: Sprite2D
var box_sprite: Sprite2D   # caixa carregada (saindo da agência / mudança de sede)
var carrying_box := false
var leaving_for_good := false
var speed_mult := 1.0
var _mood_timer := 0.0
var _burst_left := 0.0     # estouro de burnout (1 s)
var _bounce_t := 0.0
var _skin_color := Color.WHITE

const MOOD_OFFSET := Vector2(-8, -78)
const SLOW_MOODS := ["exhausted", "sad", "burnout"]


func _ready() -> void:
	for name in ["outline", "skin", "legs", "shirt", "hair"]:
		var s := Sprite2D.new()
		s.centered = false
		s.hframes = 4
		s.vframes = 4
		s.offset = SPRITE_OFFSET
		add_child(s)
		layers[name] = s
	box_sprite = Sprite2D.new()
	box_sprite.texture = preload("res://assets/art/moods/box.png")
	box_sprite.centered = false
	box_sprite.position = Vector2(-7, -30)
	box_sprite.visible = false
	add_child(box_sprite)
	mood_sprite = Sprite2D.new()
	mood_sprite.centered = false
	mood_sprite.hframes = 2
	mood_sprite.position = MOOD_OFFSET
	mood_sprite.visible = false
	add_child(mood_sprite)
	position = desk_pos
	wait_time = rng.randf_range(3.0, 8.0)


## Troca o humor visível: ícone animado, pele vermelha no burnout, ritmo mais lento quando cansado.
func set_mood(new_mood: String) -> void:
	if new_mood == mood:
		return
	if new_mood == "burnout" and mood != "burnout":
		_burst_left = 1.0
	mood = new_mood
	speed_mult = 0.7 if mood in SLOW_MOODS else 1.0
	if mood != "" and mood != "leaving" and ResourceLoader.exists("res://assets/art/moods/%s.png" % mood):
		mood_sprite.texture = load("res://assets/art/moods/%s.png" % mood)
		mood_sprite.visible = true
	else:
		mood_sprite.visible = false
	_apply_skin()


func _apply_skin() -> void:
	if layers.is_empty():
		return
	layers["skin"].modulate = _skin_color.lerp(Color("#e05d5d"), 0.65) if mood == "burnout" else _skin_color


func set_carrying_box(on: bool) -> void:
	carrying_box = on
	box_sprite.visible = on


## Pediu demissão ou foi levado por um concorrente: vai até a porta com a caixa e some de vez.
func leave_for_good() -> void:
	if static_pose:
		queue_free()
		return
	leaving_for_good = true
	set_mood("leaving")
	set_carrying_box(true)
	visible = true
	training = false
	target = door_pos
	state = State.LEAVING


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
	var tag := "%d%s" % [style, "g" if e.glasses else ""]
	layers["outline"].texture = load("res://assets/art/characters/outline_%s.png" % tag)
	layers["hair"].texture = load("res://assets/art/characters/hair_%s.png" % tag)
	layers["skin"].texture = load("res://assets/art/characters/skin.png")
	layers["legs"].texture = load("res://assets/art/characters/legs.png")
	layers["shirt"].texture = load("res://assets/art/characters/shirt.png")
	_skin_color = Color(e.skin)
	_apply_skin()
	layers["hair"].modulate = Color(e.hair_color)
	layers["shirt"].modulate = Color(e.color)


func sync(e: Employee, day: int) -> void:
	on_project = e.project_id != -1
	resting = e.busy_until >= day and e.busy_reason == "Burnout"
	var was_training := training
	training = e.busy_until >= day and (e.busy_reason == "Em treinamento" or e.busy_reason == "Em evento")
	apply_look(e)
	if not static_pose:
		morale = e.motivation
		set_mood(Game.employees.mood_of(e, day))
		queue_redraw()
	if static_pose or leaving_for_good:
		return
	if training and not was_training and state != State.AWAY and state != State.LEAVING:
		# vai até a porta e sai do escritório
		target = door_pos
		state = State.LEAVING
	elif not training and (state == State.AWAY or state == State.LEAVING):
		visible = true
		position = door_pos
		target = desk_pos
		state = State.RETURNING


func _process(delta: float) -> void:
	var frame := Frame.IDLE
	_animate_mood(delta)
	if static_pose:
		_apply_frame(Frame.SIT if sitting else Frame.IDLE)
		return
	match state:
		State.AWAY:
			return
		State.LEAVING, State.RETURNING:
			var dir := target - position
			if dir.length() < 1.5:
				position = target
				if state == State.LEAVING:
					if leaving_for_good:
						queue_free()
						return
					visible = false
					state = State.AWAY
				else:
					state = State.AT_DESK
					wait_time = rng.randf_range(8.0, 20.0)
			else:
				position += dir.normalized() * WALK_SPEED * speed_mult * delta
				_face(dir)
				frame_timer += delta
				if frame_timer >= FRAME_TIME:
					frame_timer = 0.0
					walk_frame = 1 - walk_frame
				frame = Frame.WALK_A if walk_frame == 0 else Frame.WALK_B
		State.AT_DESK:
			wait_time -= delta
			frame = Frame.SIT
			facing = Dir.FRONT
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
				position += dir.normalized() * WALK_SPEED * speed_mult * delta
				_face(dir)
				frame_timer += delta
				if frame_timer >= FRAME_TIME:
					frame_timer = 0.0
					walk_frame = 1 - walk_frame
				frame = Frame.WALK_A if walk_frame == 0 else Frame.WALK_B
	_apply_frame(frame)


## Ícone do humor alterna entre 2 quadros; feliz dá pulinhos; estouro do burnout dura 1 s.
func _animate_mood(delta: float) -> void:
	_mood_timer += delta
	if _burst_left > 0.0:
		_burst_left -= delta
		if mood_sprite.texture == null or not mood_sprite.visible or _burst_left > 0.0:
			var burst: Texture2D = load("res://assets/art/moods/burst.png")
			mood_sprite.texture = burst
			mood_sprite.visible = true
		if _burst_left <= 0.0 and mood == "burnout":
			mood_sprite.texture = load("res://assets/art/moods/burnout.png")
	if mood_sprite.visible:
		mood_sprite.frame = int(_mood_timer / 0.35) % 2
	var bounce := 0.0
	if mood == "happy" or mood == "celebrating":
		_bounce_t += delta
		bounce = absf(sin(_bounce_t * 6.0)) * 3.0
	for s in layers.values():
		s.offset.y = SPRITE_OFFSET.y - bounce
	box_sprite.position.y = -30.0 - bounce


## Escolhe a direção pela componente dominante do movimento.
func _face(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		facing = Dir.LEFT if dir.x < 0.0 else Dir.RIGHT
	else:
		facing = Dir.BACK if dir.y < 0.0 else Dir.FRONT


func _apply_frame(frame: int) -> void:
	for s in layers.values():
		s.frame = facing * 4 + frame


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
	state = State.WALKING


func head_position() -> Vector2:
	return position + Vector2(0, -50)


## Barra de moral (verde, amarela ou vermelha) flutuando sobre a cabeça.
func _draw() -> void:
	if static_pose or morale < 0.0:
		return
	var width := 20.0
	var origin := Vector2(-10, -56)
	var color := UIKit.COLOR_GREEN
	if morale < 35.0:
		color = UIKit.COLOR_RED
	elif morale < 60.0:
		color = UIKit.COLOR_GOLD
	draw_rect(Rect2(origin - Vector2(1, 1), Vector2(width + 2, 5)), Color(0.16, 0.14, 0.2, 0.9))
	draw_rect(Rect2(origin, Vector2(width, 3)), Color(1, 1, 1, 0.45))
	draw_rect(Rect2(origin, Vector2(width * clampf(morale / 100.0, 0.0, 1.0), 3)), color)
