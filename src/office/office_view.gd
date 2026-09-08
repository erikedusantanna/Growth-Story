class_name OfficeView
extends Control
## Escritório em visão 3/4: parede com janelas e quadro, piso de madeira, mobília e
## personagens ordenados por profundidade (y-sort). Mostra balões e números flutuantes.

const TILE := 16
const WALL_ROWS := 2
const MAX_SCALE := 3.0
const FURNITURE := {
	"desk": "res://assets/art/furniture/desk.png",
	"chair": "res://assets/art/furniture/chair.png",
	"sofa": "res://assets/art/furniture/sofa.png",
	"plant": "res://assets/art/furniture/plant.png",
	"coffee": "res://assets/art/furniture/coffee.png",
	"cooler": "res://assets/art/furniture/cooler.png",
	"shelf": "res://assets/art/furniture/shelf.png",
	"window": "res://assets/art/furniture/window.png",
	"whiteboard": "res://assets/art/furniture/whiteboard.png",
	"door": "res://assets/art/furniture/door.png",
}
## Deslocamento vertical dos objetos de parede (a partir do topo da parede).
const WALL_PROP_Y := {"window": 6, "whiteboard": 6, "shelf": 2, "door": 2}

var world: Node2D
var wall_layer: Node2D
var scene_layer: Node2D      # y-sort: mobília + personagens
var fx_layer: Node2D
var floor_tex := preload("res://assets/art/tiles/floor_wood.png")
var wall_tex := preload("res://assets/art/tiles/wall.png")
var layout: Dictionary = {}
var desk_positions: Array = []
var spot_positions: Array = []
var workers: Dictionary = {}
var built_level := -1

signal worker_tapped(employee_id: int)


func _ready() -> void:
	clip_contents = true
	world = Node2D.new()
	add_child(world)
	wall_layer = Node2D.new()
	world.add_child(wall_layer)
	scene_layer = Node2D.new()
	scene_layer.y_sort_enabled = true
	world.add_child(scene_layer)
	fx_layer = Node2D.new()
	world.add_child(fx_layer)
	world.draw.connect(_draw_world)
	resized.connect(_layout_world)
	EventBus.state_changed.connect(refresh)
	EventBus.game_started.connect(func(): built_level = -1; refresh())
	EventBus.office_feedback.connect(show_feedback)


func refresh() -> void:
	if not Game.has_game():
		return
	if Game.state.office_level != built_level:
		_build(Game.office.current())
	_sync_workers()


func _build(data: Dictionary) -> void:
	layout = data
	built_level = int(data.get("level", 1))
	UIKit.clear(wall_layer)
	UIKit.clear(scene_layer)
	UIKit.clear(fx_layer)
	workers.clear()
	desk_positions.clear()
	spot_positions.clear()
	for p in data.get("wall", []):
		var tex: Texture2D = load(FURNITURE[p.type])
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.position = Vector2(float(p.x) * TILE, float(WALL_PROP_Y.get(p.type, 4)))
		wall_layer.add_child(s)
	for d in data.get("desks", []):
		var bottom := Vector2(float(d[0]) * TILE, (float(d[1]) + 1.0) * TILE)
		_add_furniture("chair", bottom + Vector2(8, -20))
		_add_furniture("desk", bottom)
		desk_positions.append(bottom + Vector2(16, -16))   # pés do personagem, atrás da mesa
	for p in data.get("props", []):
		_add_furniture(p.type, Vector2(float(p.pos[0]) * TILE, (float(p.pos[1]) + 1.0) * TILE))
	for sp in data.get("spots", []):
		spot_positions.append(Vector2((float(sp[0]) + 0.5) * TILE, (float(sp[1]) + 1.0) * TILE))
	_layout_world()
	world.queue_redraw()


func _add_furniture(type: String, bottom_left: Vector2) -> void:
	var tex: Texture2D = load(FURNITURE.get(type, FURNITURE["plant"]))
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(0, -tex.get_height())
	s.position = bottom_left
	scene_layer.add_child(s)


func _layout_world() -> void:
	if layout.is_empty():
		return
	var w := float(layout.get("width", 10)) * TILE
	var h := float(layout.get("height", 7)) * TILE
	var scale_factor: float = minf(MAX_SCALE, minf(size.x / w, size.y / h))
	scale_factor = maxf(scale_factor, 1.0)
	world.scale = Vector2(scale_factor, scale_factor)
	world.position = Vector2((size.x - w * scale_factor) * 0.5, (size.y - h * scale_factor) * 0.5)


func _draw_world() -> void:
	if layout.is_empty():
		return
	var w := int(layout.get("width", 10))
	var h := int(layout.get("height", 7))
	for x in w:
		world.draw_texture(wall_tex, Vector2(x * TILE, 0))
		for y in range(WALL_ROWS, h):
			world.draw_texture(floor_tex, Vector2(x * TILE, y * TILE))


func _sync_workers() -> void:
	var st: GameState = Game.state
	var seen := {}
	var index := 0
	for e in st.employees:
		seen[e.id] = true
		var worker: Worker = workers.get(e.id)
		if worker == null:
			worker = Worker.new()
			var desk: Vector2 = desk_positions[index % maxi(desk_positions.size(), 1)] if not desk_positions.is_empty() else Vector2(TILE * 3, TILE * 5)
			worker.setup(e, desk, spot_positions, e.id * 7919 + st.seed)
			scene_layer.add_child(worker)
			workers[e.id] = worker
		worker.sync(e, st.day)
		index += 1
	for id in workers.keys():
		if not seen.has(id):
			workers[id].queue_free()
			workers.erase(id)


## Balão ("Café!") ou número flutuante ("+12 XP") sobre a cabeça do personagem.
func show_feedback(employee_id: int, text: String, kind: String) -> void:
	var worker: Worker = workers.get(employee_id)
	if worker == null or not is_visible_in_tree():
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 7)
	label.z_index = 10
	var color := UIKit.COLOR_TEXT
	if kind == "good":
		color = UIKit.COLOR_GREEN
	elif kind == "bad":
		color = UIKit.COLOR_RED
	label.add_theme_color_override("font_color", color)
	if kind == "bubble":
		var style := StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.border_color = UIKit.COLOR_TEXT
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		style.content_margin_left = 3
		style.content_margin_right = 3
		style.content_margin_top = 1
		style.content_margin_bottom = 1
		label.add_theme_stylebox_override("normal", style)
	else:
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color.WHITE)
	fx_layer.add_child(label)
	label.reset_size()
	var start := worker.head_position() - Vector2(label.size.x * 0.5, 0)
	label.position = start
	var tween := create_tween()
	tween.tween_property(label, "position", start + Vector2(0, -10), 1.4).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.4).set_delay(0.6)
	tween.tween_callback(label.queue_free)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed:
		var local: Vector2 = (event.position - world.position) / world.scale.x
		var best_id := -1
		var best_dist := 18.0
		for id in workers:
			var d: float = workers[id].position.distance_to(local + Vector2(0, 16))
			if d < best_dist:
				best_dist = d
				best_id = id
		if best_id != -1:
			worker_tapped.emit(best_id)
