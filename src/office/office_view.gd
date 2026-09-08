class_name OfficeView
extends Control
## Renderiza o escritório atual (piso, parede, mobília) e os funcionários andando.

const TILE := 16
const MAX_SCALE := 3.0

var world: Node2D
var furniture: Node2D
var workers_root: Node2D
var floor_tex := preload("res://assets/sprites/floor.png")
var wall_tex := preload("res://assets/sprites/wall.png")
var props := {
	"desk": preload("res://assets/sprites/desk.png"),
	"coffee": preload("res://assets/sprites/coffee.png"),
	"sofa": preload("res://assets/sprites/sofa.png"),
	"plant": preload("res://assets/sprites/plant.png"),
	"door": preload("res://assets/sprites/door.png"),
}
var layout: Dictionary = {}
var desk_positions: Array = []
var spot_positions: Array = []
var workers: Dictionary = {}    # employee_id -> Worker
var built_level := -1

signal worker_tapped(employee_id: int)


func _ready() -> void:
	clip_contents = true
	world = Node2D.new()
	add_child(world)
	furniture = Node2D.new()
	world.add_child(furniture)
	workers_root = Node2D.new()
	world.add_child(workers_root)
	world.draw.connect(_draw_world)
	resized.connect(_layout_world)
	EventBus.state_changed.connect(refresh)
	EventBus.game_started.connect(func(): built_level = -1; refresh())


func refresh() -> void:
	if not Game.has_game():
		return
	if Game.state.office_level != built_level:
		_build(Game.office.current())
	_sync_workers()


func _build(data: Dictionary) -> void:
	layout = data
	built_level = int(data.get("level", 1))
	UIKit.clear(furniture)
	UIKit.clear(workers_root)
	workers.clear()
	desk_positions.clear()
	spot_positions.clear()
	for d in data.get("desks", []):
		var pos := Vector2(float(d[0]) * TILE, float(d[1]) * TILE)
		_add_prop("desk", pos)
		desk_positions.append(pos + Vector2(TILE, TILE + 4))   # cadeira: frente da mesa
	for p in data.get("props", []):
		var pos := Vector2(float(p.pos[0]) * TILE, float(p.pos[1]) * TILE)
		_add_prop(p.type, pos)
		if p.type == "coffee":
			spot_positions.append(pos + Vector2(TILE * 0.5, TILE + 6))
		elif p.type == "sofa":
			spot_positions.append(pos + Vector2(TILE, TILE + 2))
	_layout_world()
	world.queue_redraw()


func _add_prop(type: String, pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = props.get(type, props["plant"])
	s.centered = false
	s.position = pos
	furniture.add_child(s)


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
		for y in range(1, h):
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
			var desk: Vector2 = desk_positions[index % maxi(desk_positions.size(), 1)] if not desk_positions.is_empty() else Vector2(TILE * 2, TILE * 3)
			worker.setup(e, desk, spot_positions, e.id * 7919 + st.seed)
			workers_root.add_child(worker)
			workers[e.id] = worker
		worker.sync(e, st.day)
		index += 1
	for id in workers.keys():
		if not seen.has(id):
			workers[id].queue_free()
			workers.erase(id)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed:
		var local: Vector2 = (event.position - world.position) / world.scale.x
		var best_id := -1
		var best_dist := 14.0
		for id in workers:
			var d: float = workers[id].position.distance_to(local + Vector2(0, 8))
			if d < best_dist:
				best_dist = d
				best_id = id
		if best_id != -1:
			worker_tapped.emit(best_id)
