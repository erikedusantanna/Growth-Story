class_name Pet
extends Node2D
## Pet do escritório (cachorro ou gato): passeia pelo piso, para, olha em volta e segue.
## A posição do nó é a pata do bicho (y-sort junto com os personagens).

const SPEED := {"dog": 18.0, "cat": 12.0}
const FRAME_TIME := 0.2

var kind := "dog"
var area := Rect2()
var sprite: Sprite2D
var rng := RandomNumberGenerator.new()
var target := Vector2.ZERO
var wait_time := 1.0
var moving := false
var frame_timer := 0.0


func setup(pet_kind: String, floor_area: Rect2, seed: int) -> void:
	kind = pet_kind
	area = floor_area
	rng.seed = seed
	position = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
	wait_time = rng.randf_range(1.0, 4.0)


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/art/furniture/%s.png" % kind)
	sprite.hframes = 2
	sprite.centered = false
	var frame_w: float = sprite.texture.get_width() / 2.0
	sprite.offset = Vector2(-frame_w * 0.5, -float(sprite.texture.get_height()))
	add_child(sprite)


func _process(delta: float) -> void:
	if moving:
		var dir := target - position
		if dir.length() < 1.0:
			position = target
			moving = false
			wait_time = rng.randf_range(2.0, 7.0)
			sprite.frame = 0
			return
		position += dir.normalized() * float(SPEED.get(kind, 14.0)) * delta
		sprite.flip_h = dir.x < 0.0
		frame_timer += delta
		if frame_timer >= FRAME_TIME:
			frame_timer = 0.0
			sprite.frame = 1 - sprite.frame
	else:
		wait_time -= delta
		if wait_time <= 0.0:
			target = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
			moving = true
