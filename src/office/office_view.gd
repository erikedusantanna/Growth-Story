class_name OfficeView
extends Control
## Escritório em visão 3/4: parede com janelas e quadro, piso de madeira, mobília e
## personagens ordenados por profundidade (y-sort). Mostra balões e números flutuantes.
## Dá para arrastar (um dedo) e dar zoom (pinça ou roda do mouse); toque no avatar abre a jornada.
## Mobília comprada troca sprites (cadeira, mesa, café) ou ocupa slots; o RH contratado ganha
## um anexo com divisória, mesa e analista fixa; pets adotados passeiam pelo piso.

const TILE := 16
const WALL_ROWS := 2
const MAX_ZOOM := 4.0
const DEFAULT_ZOOM_MIN := 2.0
const DEFAULT_ZOOM_MAX := 3.0
const TAP_SLOP := 8.0
const FURNITURE := {
	"desk": "res://assets/art/furniture/desk.png",
	"desk_wide": "res://assets/art/furniture/desk_wide.png",
	"chair": "res://assets/art/furniture/chair.png",
	"chair_ergo": "res://assets/art/furniture/chair_ergo.png",
	"sofa": "res://assets/art/furniture/sofa.png",
	"plant": "res://assets/art/furniture/plant.png",
	"coffee": "res://assets/art/furniture/coffee.png",
	"coffee_premium": "res://assets/art/furniture/coffee_premium.png",
	"cooler": "res://assets/art/furniture/cooler.png",
	"shelf": "res://assets/art/furniture/shelf.png",
	"window": "res://assets/art/furniture/window.png",
	"whiteboard": "res://assets/art/furniture/whiteboard.png",
	"goals_board": "res://assets/art/furniture/goals_board.png",
	"door": "res://assets/art/furniture/door.png",
	"pingpong": "res://assets/art/furniture/pingpong.png",
	"partition": "res://assets/art/furniture/partition.png",
	"partition_top": "res://assets/art/furniture/partition_top.png",
	"hr_sign": "res://assets/art/furniture/hr_sign.png",
}
## Deslocamento vertical dos objetos de parede (a partir do topo da parede).
const WALL_PROP_Y := {"window": 6, "whiteboard": 6, "shelf": 2, "door": 2, "goals_board": 6, "hr_sign": 9}

var world: Node2D
var wall_layer: Node2D
var scene_layer: Node2D      # y-sort: mobília + personagens + pets
var fx_layer: Node2D
var floor_tex := preload("res://assets/art/tiles/floor_wood.png")
var wall_tex := preload("res://assets/art/tiles/wall.png")
var layout: Dictionary = {}
var desk_positions: Array = []
var spot_positions: Array = []
var workers: Dictionary = {}
var pets: Dictionary = {}
var built_key := ""
var door_pos := Vector2.ZERO
var training_room: TrainingRoom
var hr_worker: Worker

# câmera
var zoom := 2.0
var fit_zoom := 1.0
var touches: Dictionary = {}     # índice do dedo -> posição
var press_pos := Vector2.ZERO
var dragging := false
var pinch_start_dist := 0.0
var pinch_start_zoom := 1.0
var pending_reset := false       # layout pedido antes de o painel ter tamanho

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
	training_room = TrainingRoom.new()
	training_room.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	training_room.position = Vector2(size.x - 12, 12)
	add_child(training_room)
	resized.connect(_place_training_room)
	EventBus.state_changed.connect(refresh)
	EventBus.day_passed.connect(func(_d): _sync_training())
	EventBus.game_started.connect(func(): built_key = ""; refresh())
	EventBus.office_feedback.connect(show_feedback)


func _place_training_room() -> void:
	if training_room == null:
		return
	training_room.reset_size()
	training_room.position = Vector2(size.x - training_room.size.x - 10, 10)


func refresh() -> void:
	if not Game.has_game():
		return
	var st: GameState = Game.state
	var key := "%d/%d/%s" % [st.office_level, st.furniture.size(), st.hr_hired]
	if key != built_key:
		built_key = key
		_build(Game.office.current())
	_sync_workers()
	_sync_pets()
	_sync_training()


func _sync_training() -> void:
	if not Game.has_game() or training_room == null:
		return
	var st: GameState = Game.state
	var trainees: Array = st.employees.filter(func(e): return e.busy_until >= st.day and e.busy_reason == "Em treinamento")
	training_room.sync(trainees)
	_place_training_room()


# --- Construção -------------------------------------------------------------------

func _has_hr_room() -> bool:
	return Game.has_game() and Game.state.hr_hired and layout.has("hr_room")


## Largura total em tiles (escritório + anexo do RH).
func _total_width() -> int:
	var w := int(layout.get("width", 10))
	if _has_hr_room():
		w += int(layout["hr_room"].get("width", 5))
	return w


## Sprites alternativos dados pela mobília comprada (cadeira ergonômica, mesa ultrawide, café premium).
func _visual_swaps() -> Dictionary:
	var swaps := {}
	for id in Game.state.furniture:
		var f: Dictionary = Game.office.furniture_by_id(id)
		for key in f.get("visual", {}):
			swaps[key] = f["visual"][key]
	return swaps


func _build(data: Dictionary) -> void:
	layout = data
	UIKit.clear(wall_layer)
	UIKit.clear(scene_layer)
	UIKit.clear(fx_layer)
	workers.clear()
	pets.clear()
	hr_worker = null
	desk_positions.clear()
	spot_positions.clear()
	var swaps := _visual_swaps()
	door_pos = Vector2(float(data.get("width", 10)) * TILE - 24, WALL_ROWS * TILE + 8)
	for p in data.get("wall", []):
		_add_wall_prop(String(p.type), float(p.x))
		if p.type == "door":
			door_pos = Vector2(float(p.x) * TILE + 10, WALL_ROWS * TILE + 6)
	# quadros comprados vão para os espaços livres da parede
	var wall_slots: Array = data.get("wall_slots", [])
	var wall_index := 0
	for id in Game.state.furniture:
		var f: Dictionary = Game.office.furniture_by_id(id)
		if f.has("wall_sprite") and wall_index < wall_slots.size():
			_add_wall_prop(String(f["wall_sprite"]), float(wall_slots[wall_index]))
			wall_index += 1
	for d in data.get("desks", []):
		var bottom := Vector2(float(d[0]) * TILE, (float(d[1]) + 1.0) * TILE)
		_add_furniture(swaps.get("chair", "chair"), bottom + Vector2(8, -20))
		_add_furniture(swaps.get("desk", "desk"), bottom)
		desk_positions.append(bottom + Vector2(16, -16))   # pés do personagem, atrás da mesa
	for p in data.get("props", []):
		_add_furniture(swaps.get(p.type, p.type), Vector2(float(p.pos[0]) * TILE, (float(p.pos[1]) + 1.0) * TILE))
	for sp in data.get("spots", []):
		spot_positions.append(Vector2((float(sp[0]) + 0.5) * TILE, (float(sp[1]) + 1.0) * TILE))
	_build_decor(data)
	if _has_hr_room():
		_build_hr_room(data)
	_layout_world(true)
	world.queue_redraw()


func _add_wall_prop(type: String, x_tile: float) -> void:
	var tex: Texture2D = load(FURNITURE.get(type, FURNITURE["whiteboard"]))
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = Vector2(x_tile * TILE, float(WALL_PROP_Y.get(type, 4)))
	wall_layer.add_child(s)


## Mobília comprada com sprite ocupa os slots de decoração do escritório.
func _build_decor(data: Dictionary) -> void:
	var slots: Array = data.get("decor_slots", [])
	var index := 0
	for id in Game.state.furniture:
		var f: Dictionary = Game.office.furniture_by_id(id)
		var sprite: String = String(f.get("sprite", ""))
		if sprite == "" or index >= slots.size():
			continue
		var slot: Array = slots[index]
		_add_furniture(sprite, Vector2(float(slot[0]) * TILE, (float(slot[1]) + 1.0) * TILE))
		index += 1


## Anexo do RH: divisória, placa, mesa com a analista sentada e uma planta.
func _build_hr_room(data: Dictionary) -> void:
	var room: Dictionary = data["hr_room"]
	var w := int(data.get("width", 10))
	var h := int(data.get("height", 7))
	var px := float(w) * TILE - 4.0
	var top := float(WALL_ROWS * TILE)
	var bottom := float(h * TILE) - 22.0    # passagem no fim da divisória
	var y := top
	while y + TILE <= bottom:
		var s := Sprite2D.new()
		s.texture = load(FURNITURE["partition"])
		s.centered = false
		s.offset = Vector2(0, -TILE)
		s.position = Vector2(px, y + TILE)
		scene_layer.add_child(s)
		y += TILE
	var cap := Sprite2D.new()
	cap.texture = load(FURNITURE["partition_top"])
	cap.centered = false
	cap.offset = Vector2(0, -6)
	cap.position = Vector2(px, top + 2.0)
	scene_layer.add_child(cap)
	_add_wall_prop("hr_sign", float(w) + float(room.get("sign_x", 1.5)))
	var d: Array = room.get("desk", [1, 4])
	var desk_bottom := Vector2(float(w + int(d[0])) * TILE, (float(d[1]) + 1.0) * TILE)
	_add_furniture("chair_ergo", desk_bottom + Vector2(8, -20))
	_add_furniture("desk", desk_bottom)
	var pl: Array = room.get("plant", [3, h - 2])
	_add_furniture("plant", Vector2(float(w + int(pl[0])) * TILE, (float(pl[1]) + 1.0) * TILE))
	hr_worker = Worker.new()
	var look := Employee.new()
	look.id = 9002
	look.name = "RH"
	look.skin = "#c8956c"
	look.hair_style = 1
	look.hair_color = "#4a2c1a"
	look.color = "#ff8f3d"
	hr_worker.setup(look, desk_bottom + Vector2(16, -16), [], 4242)
	hr_worker.static_pose = true
	hr_worker.sitting = true
	scene_layer.add_child(hr_worker)


func _add_furniture(type: String, bottom_left: Vector2) -> void:
	var tex: Texture2D = load(FURNITURE.get(type, FURNITURE["plant"]))
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(0, -tex.get_height())
	s.position = bottom_left
	scene_layer.add_child(s)


# --- Câmera -----------------------------------------------------------------------

func _layout_world(reset: bool = false) -> void:
	if layout.is_empty():
		return
	var w := float(_total_width()) * TILE
	var h := float(layout.get("height", 7)) * TILE
	if size.x <= 0.0 or size.y < 100.0:
		pending_reset = pending_reset or reset
		return
	if pending_reset:
		reset = true
		pending_reset = false
	fit_zoom = minf(size.x / w, size.y / h)
	if reset:
		zoom = clampf(fit_zoom, DEFAULT_ZOOM_MIN, DEFAULT_ZOOM_MAX)
		world.scale = Vector2(zoom, zoom)
		# começa mostrando o canto esquerdo (mesas) centralizado na vertical
		world.position = Vector2(maxf((size.x - w * zoom) * 0.5, 0.0), (size.y - h * zoom) * 0.5)
	_clamp_world()


func min_zoom() -> float:
	return minf(fit_zoom, DEFAULT_ZOOM_MIN)


func set_zoom(new_zoom: float, pivot: Vector2) -> void:
	new_zoom = clampf(new_zoom, min_zoom(), MAX_ZOOM)
	var old := world.scale.x
	if is_equal_approx(old, new_zoom):
		return
	world.position = pivot - (pivot - world.position) * (new_zoom / old)
	zoom = new_zoom
	world.scale = Vector2(zoom, zoom)
	_clamp_world()


## Mantém o escritório dentro da área visível (centralizado quando cabe inteiro).
func _clamp_world() -> void:
	if layout.is_empty():
		return
	var w := float(_total_width()) * TILE * world.scale.x
	var h := float(layout.get("height", 7)) * TILE * world.scale.y
	var pos := world.position
	if w <= size.x:
		pos.x = (size.x - w) * 0.5
	else:
		pos.x = clampf(pos.x, size.x - w, 0.0)
	if h <= size.y:
		pos.y = (size.y - h) * 0.5
	else:
		pos.y = clampf(pos.y, size.y - h, 0.0)
	world.position = pos.round()


func _draw_world() -> void:
	if layout.is_empty():
		return
	var w := _total_width()
	var h := int(layout.get("height", 7))
	for x in w:
		world.draw_texture(wall_tex, Vector2(x * TILE, 0))
		for y in range(WALL_ROWS, h):
			world.draw_texture(floor_tex, Vector2(x * TILE, y * TILE))


# --- Personagens e pets -----------------------------------------------------------

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
			worker.door_pos = door_pos
			scene_layer.add_child(worker)
			workers[e.id] = worker
			if e.busy_until >= st.day and (e.busy_reason == "Em treinamento" or e.busy_reason == "Em evento"):
				worker.training = true
				worker.state = Worker.State.AWAY
				worker.visible = false
		worker.sync(e, st.day)
		index += 1
	for id in workers.keys():
		if not seen.has(id):
			workers[id].queue_free()
			workers.erase(id)


func _sync_pets() -> void:
	var st: GameState = Game.state
	var w := float(layout.get("width", 10)) * TILE
	var h := float(layout.get("height", 7)) * TILE
	var area := Rect2(10.0, WALL_ROWS * TILE + 10.0, w - 20.0, h - WALL_ROWS * TILE - 14.0)
	for kind in st.pets:
		if pets.has(kind):
			continue
		var pet := Pet.new()
		pet.setup(String(kind), area, st.seed + kind.hash())
		scene_layer.add_child(pet)
		pets[kind] = pet


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
	var start := worker.head_position() - Vector2(label.size.x * 0.5, 6)
	label.position = start
	var tween := create_tween()
	tween.tween_property(label, "position", start + Vector2(0, -10), 1.4).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.4).set_delay(0.6)
	tween.tween_callback(label.queue_free)


# --- Entrada: toque, arrasto, pinça e roda ----------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() == 1:
				press_pos = event.position
				dragging = false
			elif touches.size() == 2:
				dragging = true
				var pts := touches.values()
				pinch_start_dist = maxf(pts[0].distance_to(pts[1]), 1.0)
				pinch_start_zoom = world.scale.x
		else:
			var was_single := touches.size() == 1
			touches.erase(event.index)
			if was_single and not dragging and event.position.distance_to(press_pos) <= TAP_SLOP:
				_tap(event.position)
			if touches.size() < 2:
				pinch_start_dist = 0.0
		accept_event()
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() >= 2 and pinch_start_dist > 0.0:
			var pts := touches.values()
			var dist: float = pts[0].distance_to(pts[1])
			set_zoom(pinch_start_zoom * dist / pinch_start_dist, (pts[0] + pts[1]) * 0.5)
		elif touches.size() == 1:
			if not dragging and event.position.distance_to(press_pos) > TAP_SLOP:
				dragging = true
			if dragging:
				world.position += event.relative
				_clamp_world()
		accept_event()
	elif event is InputEventMagnifyGesture:
		set_zoom(world.scale.x * event.factor, event.position)
		accept_event()
	elif event is InputEventPanGesture:
		world.position -= event.delta * 4.0
		_clamp_world()
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(world.scale.x * 1.15, event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(world.scale.x / 1.15, event.position)
			accept_event()


func _tap(screen_pos: Vector2) -> void:
	var local: Vector2 = (screen_pos - world.position) / world.scale.x
	var best_id := -1
	var best_dist := 26.0
	for id in workers:
		var w: Worker = workers[id]
		if not w.visible:
			continue
		# retângulo do sprite (24x32 acima dos pés), com folga para o dedo
		var rect := Rect2(w.position + Vector2(-14, -40), Vector2(28, 44))
		if rect.has_point(local):
			var d: float = (w.position + Vector2(0, -16)).distance_to(local)
			if d < best_dist:
				best_dist = d
				best_id = id
	if best_id != -1:
		worker_tapped.emit(best_id)
