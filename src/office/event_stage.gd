class_name EventStage
extends Control
## "Corte de câmera": cobre o painel do escritório com um cenário (palco, auditório, estande,
## estúdio, sala de reunião, coletiva) e monta a cena com os personagens da própria agência.
## Os cenários e as marcas de posição vêm de data/scenes.json (270×168, exibidos em 2×).

const SCALE := 2.0
const SCENE_SIZE := Vector2(270, 168)
const CUT_TIME := 0.3

var world: Node2D
var backdrop: Sprite2D
var actors: Node2D
var front: Node2D
var fade: ColorRect
var current_kind := ""


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.14, 0.22)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	world = Node2D.new()
	world.scale = Vector2(SCALE, SCALE)
	add_child(world)
	backdrop = Sprite2D.new()
	backdrop.centered = false
	world.add_child(backdrop)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	world.add_child(actors)
	front = Node2D.new()
	world.add_child(front)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	add_child(fade)
	resized.connect(_center)


func _center() -> void:
	world.position = Vector2(floorf((size.x - SCENE_SIZE.x * SCALE) * 0.5), floorf((size.y - SCENE_SIZE.y * SCALE) * 0.5))


## Mostra o cenário `kind` com as pessoas dadas (a primeira é a protagonista: recebe o troféu, se houver).
func show_scene(kind: String, employees: Array) -> void:
	var def: Dictionary = Game.content.scenes.get(kind, {})
	if def.is_empty():
		return
	current_kind = kind
	_build(def, employees)
	_center()
	visible = true
	fade.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, CUT_TIME).set_ease(Tween.EASE_OUT)


func hide_scene() -> void:
	if not visible:
		return
	visible = false
	current_kind = ""
	UIKit.clear(actors)
	UIKit.clear(front)


func actor_count() -> int:
	return actors.get_child_count()


func _build(def: Dictionary, employees: Array) -> void:
	UIKit.clear(actors)
	UIKit.clear(front)
	backdrop.texture = load("res://assets/art/scenes/%s.png" % String(def.get("backdrop", "stage")))
	var marks: Array = def.get("marks", [])
	var count: int = mini(marks.size(), employees.size())
	for i in count:
		var mark: Array = marks[i]
		var e: Employee = employees[i]
		var w := Worker.new()
		w.setup(e, Vector2(float(mark[0]), float(mark[1])), [], e.id * 31 + 7)
		w.static_pose = true
		w.sitting = mark.size() > 3 and String(mark[3]) == "sit"
		w.facing = _facing(String(mark[2]) if mark.size() > 2 else "front")
		actors.add_child(w)
		if i == 0 and def.has("hold"):
			var prop := Sprite2D.new()
			prop.texture = load("res://assets/art/scenes/%s.png" % String(def["hold"]))
			prop.centered = false
			var off: Array = def.get("hold_offset", [4, -30])
			prop.position = Vector2(float(off[0]), float(off[1]))
			w.add_child(prop)
	for p in def.get("front", []):
		var s := Sprite2D.new()
		s.texture = load("res://assets/art/scenes/%s.png" % String(p.get("sprite", "")))
		s.centered = false
		s.position = Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
		front.add_child(s)


func _facing(name: String) -> int:
	match name:
		"back":
			return Worker.Dir.BACK
		"left":
			return Worker.Dir.LEFT
		"right":
			return Worker.Dir.RIGHT
		_:
			return Worker.Dir.FRONT
