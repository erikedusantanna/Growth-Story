class_name TrainingRoom
extends PanelContainer
## Mini sala de aula que aparece sobre o escritório enquanto alguém está em treinamento.
## Instrutor ao telão, alunos (os funcionários em curso) sentados nas mesas.

const TILE := 32
const ROOM_W := 8
const ROOM_H := 6
const SCALE := 1.0
const DESK_SLOTS := [Vector2(16, 120), Vector2(96, 120), Vector2(176, 120), Vector2(56, 176)]

var world: Node2D
var scene_layer: Node2D
var title_label: Label
var students: Dictionary = {}    # employee_id -> Worker
var instructor: Worker
var floor_tex := preload("res://assets/art/tiles/floor_wood.png")
var wall_tex := preload("res://assets/art/tiles/wall.png")


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UIKit.COLOR_PANEL
	style.border_color = UIKit.COLOR_ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(2)
	add_child(v)
	title_label = UIKit.label("Treinamento", 12, UIKit.COLOR_ACCENT)
	title_label.add_theme_font_override("font", UIKit.bold_font())
	v.add_child(title_label)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(ROOM_W * TILE * SCALE, ROOM_H * TILE * SCALE)
	holder.clip_contents = true
	v.add_child(holder)
	world = Node2D.new()
	world.scale = Vector2(SCALE, SCALE)
	holder.add_child(world)
	world.draw.connect(_draw_room)
	var projector := Sprite2D.new()
	projector.texture = load("res://assets/art/furniture/projector.png")
	projector.centered = false
	projector.position = Vector2(16, 4)
	world.add_child(projector)
	var plant := Sprite2D.new()
	plant.texture = load("res://assets/art/furniture/plant.png")
	plant.centered = false
	plant.position = Vector2(ROOM_W * TILE - 36, ROOM_H * TILE - 52)
	world.add_child(plant)
	scene_layer = Node2D.new()
	scene_layer.y_sort_enabled = true
	world.add_child(scene_layer)
	instructor = Worker.new()
	var look := Employee.new()
	look.id = 9001
	look.skin = "#e0b48c"
	look.hair_style = 3
	look.hair_color = "#2a2432"
	look.color = "#2b2a33"
	instructor.setup(look, Vector2(ROOM_W * TILE - 60, 96), [], 1)
	instructor.static_pose = true
	scene_layer.add_child(instructor)
	visible = false


func _draw_room() -> void:
	for x in ROOM_W:
		world.draw_texture(wall_tex, Vector2(x * TILE, 0))
		for y in range(2, ROOM_H):
			world.draw_texture(floor_tex, Vector2(x * TILE, y * TILE))


## Sincroniza com quem está em treinamento; esconde a sala quando não há ninguém.
func sync(trainees: Array) -> void:
	var seen := {}
	var index := 0
	for e in trainees:
		seen[e.id] = true
		var w: Worker = students.get(e.id)
		if w == null:
			w = Worker.new()
			var slot: Vector2 = DESK_SLOTS[index % DESK_SLOTS.size()]
			w.setup(e, slot + Vector2(18, -22), [], e.id)
			w.static_pose = true
			w.sitting = true
			scene_layer.add_child(w)
			var desk := Sprite2D.new()
			desk.texture = load("res://assets/art/furniture/desk.png")
			desk.centered = false
			desk.offset = Vector2(0, -56)
			desk.position = slot
			desk.name = "desk_%d" % e.id
			scene_layer.add_child(desk)
			students[e.id] = w
		w.sync(e, Game.state.day)
		index += 1
	for id in students.keys():
		if not seen.has(id):
			students[id].queue_free()
			var desk := scene_layer.get_node_or_null("desk_%d" % id)
			if desk != null:
				desk.queue_free()
			students.erase(id)
	visible = not trainees.is_empty()
	if visible:
		var names: Array = trainees.map(func(e): return e.name.split(" ")[0])
		var course_name := ""
		var days_left := 0
		for e in trainees:
			var course := Game.employees.course_by_id(e.training_id)
			course_name = String(course.get("name", "Curso"))
			days_left = maxi(days_left, e.busy_until - Game.state.day + 1)
		title_label.text = "%s · %s · %d dia%s" % [course_name, ", ".join(names), days_left, "" if days_left == 1 else "s"]
