class_name Worker
extends Node2D
## Personagem pixel art que anda pelo escritório. Estado visual do funcionário.

enum State { AT_DESK, WALKING, AT_SPOT }

const WALK_SPEED := 22.0        # px/s no espaço do mundo (antes da escala)
const FRAME_TIME := 0.18

var employee_id: int = -1
var employee_name: String = ""
var desk_pos := Vector2.ZERO
var spots: Array = []            # posições de café/sofá
var state: int = State.AT_DESK
var target := Vector2.ZERO
var wait_time := 0.0
var frame_timer := 0.0
var frame := 0
var rng := RandomNumberGenerator.new()

var body: Sprite2D
var shirt: Sprite2D
var bubble: Label
var busy_text := ""
var on_project := false
var resting := false


func _ready() -> void:
	body = Sprite2D.new()
	body.texture = preload("res://assets/sprites/body.png")
	body.hframes = 2
	body.centered = false
	body.position = Vector2(-8, -16)
	add_child(body)
	shirt = Sprite2D.new()
	shirt.texture = preload("res://assets/sprites/shirt.png")
	shirt.hframes = 2
	shirt.centered = false
	shirt.position = Vector2(-8, -16)
	add_child(shirt)
	bubble = Label.new()
	bubble.add_theme_font_size_override("font_size", 6)
	bubble.add_theme_color_override("font_color", Color("#22203a"))
	bubble.position = Vector2(-10, -26)
	bubble.size = Vector2(20, 8)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(bubble)
	position = desk_pos
	wait_time = rng.randf_range(2.0, 6.0)


func setup(e: Employee, desk: Vector2, spot_list: Array, seed: int) -> void:
	employee_id = e.id
	employee_name = e.name
	desk_pos = desk
	spots = spot_list
	rng.seed = seed
	position = desk
	if shirt != null:
		shirt.modulate = Color(e.color)
	else:
		call_deferred("_apply_color", e.color)


func _apply_color(color: String) -> void:
	shirt.modulate = Color(color)


func sync(e: Employee, day: int) -> void:
	on_project = e.project_id != -1
	resting = e.busy_until >= day and e.busy_reason == "Burnout"
	if e.busy_until >= day and e.busy_reason == "Em treinamento":
		busy_text = "aula"
	elif resting:
		busy_text = "zz"
	elif on_project:
		busy_text = "$"
	else:
		busy_text = ""
	if shirt != null:
		shirt.modulate = Color(e.color)


func _process(delta: float) -> void:
	match state:
		State.AT_DESK, State.AT_SPOT:
			wait_time -= delta
			frame = 0
			if wait_time <= 0.0:
				_pick_next()
		State.WALKING:
			var dir := target - position
			if dir.length() < 1.0:
				position = target
				state = State.AT_DESK if target == desk_pos else State.AT_SPOT
				wait_time = rng.randf_range(2.0, 7.0) if state == State.AT_SPOT else rng.randf_range(6.0, 16.0)
				frame = 0
			else:
				position += dir.normalized() * WALK_SPEED * delta
				body.flip_h = dir.x < 0.0
				shirt.flip_h = body.flip_h
				frame_timer += delta
				if frame_timer >= FRAME_TIME:
					frame_timer = 0.0
					frame = 1 - frame
	body.frame = frame
	shirt.frame = frame
	bubble.text = busy_text if state != State.WALKING else ""
	bubble.visible = bubble.text != ""


func _pick_next() -> void:
	# Quem está em projeto passa mais tempo na mesa; quem está em burnout fica no sofá/café.
	var go_out: bool
	if resting:
		go_out = true
	elif on_project:
		go_out = rng.randf() < 0.35
	else:
		go_out = rng.randf() < 0.6
	if go_out and not spots.is_empty() and state == State.AT_DESK:
		target = spots[rng.randi_range(0, spots.size() - 1)] + Vector2(rng.randf_range(-6, 6), 0)
	else:
		target = desk_pos
	state = State.WALKING
