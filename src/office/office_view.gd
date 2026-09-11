class_name OfficeView
extends Control
## Escritório em visão 3/4: parede com janelas e quadro, piso de madeira, mobília e
## personagens ordenados por profundidade (y-sort). Mostra balões e números flutuantes.
## As mesas ficam agrupadas em ilhas; cada ilha tem um tapete (zona) e divisórias entre elas,
## além da área de convivência com sofá, café e mesa de reunião.
## Dá para arrastar (um dedo) e dar zoom (pinça ou roda do mouse); toque no avatar abre a jornada.
## Mobília comprada troca sprites (cadeira, mesa, café) ou ocupa slots; o RH contratado ganha
## um anexo com divisória, mesa e analista fixa; pets adotados passeiam pelo piso.

const TILE := 32
const WALL_ROWS := 2
const MAX_ZOOM := 2.0
const DEFAULT_ZOOM_MIN := 1.0
const DEFAULT_ZOOM_MAX := 1.5
const TAP_SLOP := 8.0
const FURNITURE := {
	"desk": "res://assets/art/furniture/desk.png",
	"desk_wide": "res://assets/art/furniture/desk_wide.png",
	"chair": "res://assets/art/furniture/chair.png",
	"chair_ergo": "res://assets/art/furniture/chair_ergo.png",
	"sofa": "res://assets/art/furniture/sofa.png",
	"reception": "res://assets/art/furniture/reception.png",
	"glass_room": "res://assets/art/furniture/glass_room.png",
	"studio": "res://assets/art/furniture/studio.png",
	"kitchen": "res://assets/art/furniture/kitchen.png",
	"gym": "res://assets/art/furniture/gym.png",
	"server_rack": "res://assets/art/furniture/server_rack.png",
	"terrace": "res://assets/art/furniture/terrace.png",
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
	"meeting_table": "res://assets/art/furniture/meeting_table.png",
	"partition": "res://assets/art/furniture/partition.png",
	"partition_top": "res://assets/art/furniture/partition_top.png",
	"hr_sign": "res://assets/art/furniture/hr_sign.png",
}
## Deslocamento vertical dos objetos de parede (a partir do topo da parede).
const WALL_PROP_Y := {"window": 10, "whiteboard": 10, "shelf": 0, "door": 4, "goals_board": 10, "hr_sign": 18}
## Tapetes que agrupam as ilhas de mesas: cor de preenchimento por tinta do layout.
## O dia de trabalho vai das 08:00 às 20:00; a fração do dia vem do TimeSystem.
const DAY_START_HOUR := 8.0
const DAY_HOURS := 12.0
## Luz por hora: [hora, céu em cima, céu embaixo, tinta sobre o escritório, luminárias 0..1]
## O entardecer começa às 16h (laranja), vira roxo às 18h30 e azul escuro às 20h. A transição
## desenhada é suavizada no tempo (LIGHT_FADE_RATE): a virada 20:00 → 08:00 vira um amanhecer lento.
const LIGHT_KEYS := [
	[8.0, Color("#9fc4e6"), Color("#f7c184"), Color(1.0, 0.72, 0.42, 0.10), 0.0],
	[9.5, Color("#dff1fb"), Color("#a9d8f0"), Color(1.0, 1.0, 1.0, 0.0), 0.0],
	[15.5, Color("#dff1fb"), Color("#a9d8f0"), Color(1.0, 1.0, 1.0, 0.0), 0.0],
	[17.0, Color("#ffd27a"), Color("#f28c4a"), Color(1.0, 0.6, 0.3, 0.16), 0.3],
	[18.5, Color("#6a4f8a"), Color("#d07a5a"), Color(0.5, 0.3, 0.4, 0.22), 0.8],
	[20.0, Color("#141c30"), Color("#243559"), Color(0.10, 0.14, 0.32, 0.32), 1.0],
]
const LIGHT_FADE_RATE := 1.1        # 1/s: ~63% do caminho em 0,9 s; o amanhecer leva ~2,5 s
const WALL_TINTS := {1: Color(1, 1, 1), 2: Color(0.86, 0.92, 1.0), 3: Color(1.0, 0.94, 0.86), 4: Color(0.78, 0.82, 0.96), 5: Color(0.82, 0.84, 0.9)}
const STARS := [Vector2(6, 5), Vector2(14, 9), Vector2(20, 4), Vector2(29, 11), Vector2(38, 6), Vector2(10, 15), Vector2(41, 15)]
## Balões de pensamento por situação do personagem
const BUBBLES_WORK := ["💡", "📊", "✍️", "📈", "🎯", "☕"]
const BUBBLES_IDLE := ["☕", "💬", "🎵", "📱", "🙂"]
const BUBBLES_REST := ["😴", "😮‍💨"]
const ZONE_TINTS := {
	"cool": Color(0.31, 0.49, 0.82, 0.11),
	"green": Color(0.26, 0.60, 0.37, 0.10),
	"purple": Color(0.58, 0.42, 0.85, 0.11),
	"warm": Color(0.96, 0.56, 0.26, 0.09),
	"lounge": Color(0.39, 0.41, 0.52, 0.10),
}

var world: Node2D
var sky_layer: Node2D        # céu atrás das janelas (muda com a hora)
var wall_layer: Node2D
var scene_layer: Node2D      # y-sort: mobília + personagens + pets
var tint_layer: Node2D       # luz do dia sobre o escritório
var glow_layer: Node2D       # luminárias das mesas à noite (aditivo)
var fx_layer: Node2D
var floor_tex := preload("res://assets/art/tiles/floor_wood.png")
var wall_tex := preload("res://assets/art/tiles/wall.png")
var pillar_tex := preload("res://assets/art/tiles/wall_pillar.png")
var layout: Dictionary = {}
var desk_positions: Array = []
var spot_positions: Array = []
var workers: Dictionary = {}
var pets: Dictionary = {}
var built_key := ""
var door_pos := Vector2.ZERO
var training_room: TrainingRoom
var hr_worker: Worker
var window_positions: Array = []   # canto superior esquerdo de cada janela, em px do mundo
var season_nodes: Array = []       # decoração da data comemorativa do mês
var cloud_t := 0.0                 # tempo acumulado para nuvens, estrelas e balões
var _light_now: Dictionary = {}    # luz desenhada, que persegue a luz da hora com um fade
var bubble_timer := 3.0            # próximo balão de "pensamento" de alguém
var _drawn_hour := -1.0

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
	sky_layer = Node2D.new()
	world.add_child(sky_layer)
	sky_layer.draw.connect(_draw_sky)
	wall_layer = Node2D.new()
	world.add_child(wall_layer)
	scene_layer = Node2D.new()
	scene_layer.y_sort_enabled = true
	world.add_child(scene_layer)
	tint_layer = Node2D.new()
	world.add_child(tint_layer)
	tint_layer.draw.connect(_draw_tint)
	glow_layer = Node2D.new()
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = add_mat
	world.add_child(glow_layer)
	glow_layer.draw.connect(_draw_glow)
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
	EventBus.employee_left.connect(_on_employee_left)


func _place_training_room() -> void:
	if training_room == null:
		return
	training_room.reset_size()
	training_room.position = Vector2(size.x - training_room.size.x - 10, 10)


func refresh() -> void:
	if not Game.has_game():
		return
	var st: GameState = Game.state
	var key := "%d/%d/%s/%s" % [st.office_level, st.furniture.size(), st.hr_hired, String(Game.seasons.current().get("id", ""))]
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
	window_positions.clear()
	season_nodes.clear()
	var swaps := _visual_swaps()
	door_pos = Vector2(float(data.get("width", 10)) * TILE - 48, WALL_ROWS * TILE + 16)
	for p in data.get("wall", []):
		_add_wall_prop(String(p.type), float(p.x))
		if p.type == "door":
			door_pos = Vector2(float(p.x) * TILE + 20, WALL_ROWS * TILE + 12)
		elif p.type == "window":
			window_positions.append(Vector2(float(p.x) * TILE, float(WALL_PROP_Y["window"])))
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
		_add_furniture(swaps.get("chair", "chair"), bottom + Vector2(2, -26))
		_add_furniture(swaps.get("desk", "desk"), bottom)
		desk_positions.append(bottom + Vector2(18, -22))   # pés do personagem, sentado à esquerda do monitor
	for p in data.get("props", []):
		_add_furniture(swaps.get(p.type, p.type), Vector2(float(p.pos[0]) * TILE, (float(p.pos[1]) + 1.0) * TILE))
	for sp in data.get("spots", []):
		spot_positions.append(Vector2((float(sp[0]) + 0.5) * TILE, (float(sp[1]) + 1.0) * TILE))
	for dv in data.get("dividers", []):
		_add_divider(float(dv.get("x", 0)) * TILE, float(dv.get("y0", WALL_ROWS)) * TILE, float(dv.get("y1", 6)) * TILE)
	_build_decor(data)
	if _has_hr_room():
		_build_hr_room(data)
	var theme: Dictionary = Game.seasons.current()
	if not theme.is_empty():
		_build_season(theme, data)
	_layout_world(true)
	world.queue_redraw()
	_drawn_hour = -1.0


func _add_wall_prop(type: String, x_tile: float) -> void:
	var tex: Texture2D = load(FURNITURE.get(type, FURNITURE["whiteboard"]))
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = Vector2(x_tile * TILE, float(WALL_PROP_Y.get(type, 4)))
	wall_layer.add_child(s)


## Divisória vertical: empilha painéis entre dois pontos e fecha com a peça de topo.
func _add_divider(px: float, top: float, bottom: float) -> void:
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
	cap.offset = Vector2(0, -12)
	cap.position = Vector2(px, top + 4.0)
	scene_layer.add_child(cap)


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
	var px := float(w) * TILE - 8.0
	var top := float(WALL_ROWS * TILE)
	var bottom := float(h * TILE) - 44.0    # passagem no fim da divisória
	_add_divider(px, top, bottom)
	_add_wall_prop("hr_sign", float(w) + float(room.get("sign_x", 1.5)))
	var d: Array = room.get("desk", [1, 4])
	var desk_bottom := Vector2(float(w + int(d[0])) * TILE, (float(d[1]) + 1.0) * TILE)
	_add_furniture("chair_ergo", desk_bottom + Vector2(2, -26))
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
	hr_worker.setup(look, desk_bottom + Vector2(18, -22), [], 4242)
	hr_worker.static_pose = true
	hr_worker.sitting = true
	scene_layer.add_child(hr_worker)


func _add_furniture(type: String, bottom_left: Vector2) -> void:
	_add_floor_sprite(load(FURNITURE.get(type, FURNITURE["plant"])), bottom_left)


func _add_floor_sprite(tex: Texture2D, bottom_left: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(0, -tex.get_height())
	s.position = bottom_left
	scene_layer.add_child(s)
	return s


## Data comemorativa do mês: guirlanda repetida ao longo da parede e um objeto no chão.
func _build_season(theme: Dictionary, data: Dictionary) -> void:
	var garland := String(theme.get("garland", ""))
	if garland != "":
		var tex: Texture2D = load("res://assets/art/seasons/%s.png" % garland)
		for x in int(data.get("width", 10)):
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.position = Vector2(float(x) * TILE, 2.0)
			wall_layer.add_child(s)
			season_nodes.append(s)
	var prop := String(theme.get("prop", ""))
	if prop != "":
		var slot: Array = data.get("season_slot", [0, 2])
		var sprite := _add_floor_sprite(load("res://assets/art/seasons/%s.png" % prop),
			Vector2(float(slot[0]) * TILE, (float(slot[1]) + 1.0) * TILE))
		season_nodes.append(sprite)


# --- Hora do dia: céu nas janelas, luz e luminárias ------------------------------------

static func hour_of(fraction: float) -> float:
	return DAY_START_HOUR + DAY_HOURS * clampf(fraction, 0.0, 1.0)


static func current_hour() -> float:
	if not Game.has_game():
		return 10.0
	return hour_of(Game.time.day_fraction())


## Interpola as chaves de luz: {sky_top, sky_bottom, tint, lamp, night}.
static func daylight(hour: float) -> Dictionary:
	var a: Array = LIGHT_KEYS[0]
	var b: Array = LIGHT_KEYS[LIGHT_KEYS.size() - 1]
	for i in LIGHT_KEYS.size() - 1:
		if hour >= float(LIGHT_KEYS[i][0]) and hour <= float(LIGHT_KEYS[i + 1][0]):
			a = LIGHT_KEYS[i]
			b = LIGHT_KEYS[i + 1]
			break
	var span: float = maxf(float(b[0]) - float(a[0]), 0.001)
	var t := clampf((hour - float(a[0])) / span, 0.0, 1.0)
	return {
		"sky_top": (a[1] as Color).lerp(b[1], t),
		"sky_bottom": (a[2] as Color).lerp(b[2], t),
		"tint": (a[3] as Color).lerp(b[3], t),
		"lamp": lerpf(float(a[4]), float(b[4]), t),
		"night": clampf((hour - 18.0) / 2.0, 0.0, 1.0),
	}


func _process(delta: float) -> void:
	if layout.is_empty() or not is_visible_in_tree() or not Game.has_game():
		return
	var running: bool = Game.is_running()
	if running:
		cloud_t += delta
		_tick_bubbles(delta)
	var hour := current_hour()
	var target := daylight(hour)
	if _light_now.is_empty():
		_light_now = target.duplicate()
	var t := 1.0 - exp(-delta * LIGHT_FADE_RATE)
	var changed := false
	for key in ["sky_top", "sky_bottom", "tint"]:
		var from: Color = _light_now[key]
		var to: Color = target[key]
		if not from.is_equal_approx(to):
			_light_now[key] = from.lerp(to, t)
			changed = true
	for key in ["lamp", "night"]:
		var fv: float = _light_now[key]
		var tv: float = target[key]
		if absf(fv - tv) > 0.001:
			_light_now[key] = lerpf(fv, tv, t)
			changed = true
	if running or changed or absf(hour - _drawn_hour) > 0.01:
		_drawn_hour = hour
		sky_layer.queue_redraw()
		tint_layer.queue_redraw()
		glow_layer.queue_redraw()


## Luz efetivamente desenhada (suavizada); antes do primeiro quadro, a luz da hora.
func _light() -> Dictionary:
	return _light_now if not _light_now.is_empty() else daylight(current_hour())


func _draw_sky() -> void:
	var light := _light()
	var hour := current_hour()
	var night: float = light["night"]
	var hill := Color("#7bbf6a").lerp(Color("#1e2a3a"), night * 0.75)
	var hill_lo := Color("#4f9a4a").lerp(Color("#141c28"), night * 0.75)
	for wp in window_positions:
		var glass := Rect2(wp + Vector2(3, 3), Vector2(42, 34))
		var sky := Rect2(glass.position, Vector2(42, 21))
		sky_layer.draw_rect(glass, light["sky_bottom"])
		sky_layer.draw_rect(Rect2(glass.position, Vector2(42, 8)), light["sky_top"])
		sky_layer.draw_rect(Rect2(glass.position + Vector2(0, 8), Vector2(42, 6)), (light["sky_top"] as Color).lerp(light["sky_bottom"], 0.5))
		# sol de manhã até o fim da tarde; lua e estrelas à noite
		if hour < 18.5:
			var p := (hour - DAY_START_HOUR) / 10.5
			var sun := Rect2(glass.position + Vector2(5.0 + 32.0 * p, 22.0 - 15.0 * sin(PI * clampf(p, 0.0, 1.0))), Vector2(4, 4))
			var sun_alpha := 1.0 - night
			_draw_clipped(sun, Color(1.0, 0.88, 0.4, sun_alpha), sky)
			_draw_clipped(Rect2(sun.position, Vector2(2, 1)), Color(1.0, 0.96, 0.75, sun_alpha), sky)
		if night > 0.0:
			_draw_clipped(Rect2(glass.position + Vector2(33, 6), Vector2(4, 4)), Color(0.95, 0.95, 0.9, night), sky)
			_draw_clipped(Rect2(glass.position + Vector2(33, 6), Vector2(2, 2)), Color(1, 1, 1, night), sky)
			for i in STARS.size():
				var twinkle := 0.6 if int(cloud_t * 2.0 + i) % 2 == 0 else 1.0
				_draw_clipped(Rect2(glass.position + STARS[i], Vector2(1, 1)), Color(1, 1, 1, night * twinkle), sky)
		# nuvens passando
		var cloud_col := Color(1, 1, 1, 0.9).lerp(Color("#6c7594"), night)
		for i in 2:
			var cx := fmod(float(i) * 31.0 + cloud_t * 3.0, 62.0) - 14.0
			var cy := 5.0 + float(i) * 8.0
			_draw_clipped(Rect2(glass.position + Vector2(cx, cy + 2), Vector2(11, 3)), cloud_col, sky)
			_draw_clipped(Rect2(glass.position + Vector2(cx + 3, cy), Vector2(6, 2)), cloud_col, sky)
		# ao fundo: morros no bairro, prédios cada vez mais altos nas outras regiões, mar no hub global
		var region: int = Game.office.region() if Game.has_game() else 1
		var far := Color("#9dbfda").lerp(Color("#1e2a3a"), night * 0.75)
		var far_lo := Color("#86a9c6").lerp(Color("#141c28"), night * 0.75)
		match region:
			1:
				for r in [Rect2(0, 21, 12, 4), Rect2(14, 19, 16, 4), Rect2(32, 22, 10, 4), Rect2(0, 24, 42, 10)]:
					sky_layer.draw_rect(Rect2(glass.position + r.position, r.size), hill)
				sky_layer.draw_rect(Rect2(glass.position + Vector2(0, 30), Vector2(42, 4)), hill_lo)
			2:
				for r in [Rect2(0, 22, 8, 12), Rect2(10, 18, 7, 16), Rect2(19, 24, 9, 10), Rect2(30, 20, 6, 14), Rect2(37, 25, 5, 9)]:
					sky_layer.draw_rect(Rect2(glass.position + r.position, r.size), far)
				sky_layer.draw_rect(Rect2(glass.position + Vector2(0, 30), Vector2(42, 4)), hill_lo)
			3:
				for r in [Rect2(0, 14, 6, 20), Rect2(7, 8, 8, 26), Rect2(17, 16, 6, 18), Rect2(25, 4, 7, 30), Rect2(34, 12, 8, 22)]:
					sky_layer.draw_rect(Rect2(glass.position + r.position, r.size), far)
					sky_layer.draw_rect(Rect2(glass.position + r.position + Vector2(r.size.x - 2, 0), Vector2(2, r.size.y)), far_lo)
			4:
				for r in [Rect2(0, 6, 7, 28), Rect2(9, 2, 9, 32), Rect2(20, 10, 6, 24), Rect2(28, 0, 8, 34), Rect2(37, 8, 5, 26)]:
					sky_layer.draw_rect(Rect2(glass.position + r.position, r.size), far)
					sky_layer.draw_rect(Rect2(glass.position + r.position + Vector2(r.size.x - 2, 0), Vector2(2, r.size.y)), far_lo)
			_:
				sky_layer.draw_rect(Rect2(glass.position + Vector2(0, 24), Vector2(42, 10)), Color("#3f8fd0").lerp(Color("#142a44"), night * 0.7))
				for r in [Rect2(2, 4, 7, 20), Rect2(12, 0, 8, 24), Rect2(24, 8, 6, 16), Rect2(33, 2, 8, 22)]:
					sky_layer.draw_rect(Rect2(glass.position + r.position, r.size), far)
					sky_layer.draw_rect(Rect2(glass.position + r.position + Vector2(r.size.x - 2, 0), Vector2(2, r.size.y)), far_lo)


func _draw_clipped(r: Rect2, color: Color, clip: Rect2) -> void:
	var c := r.intersection(clip)
	if c.size.x > 0.0 and c.size.y > 0.0:
		sky_layer.draw_rect(c, color)


## Tinta da hora do dia sobre todo o escritório (nada no meio do dia).
func _draw_tint() -> void:
	var light := _light()
	var tint: Color = light["tint"]
	if tint.a <= 0.001:
		return
	tint_layer.draw_rect(Rect2(0, 0, float(_total_width()) * TILE, float(layout.get("height", 7)) * TILE), tint)


## Luminárias das mesas acendem no fim da tarde (círculos aditivos sobre os monitores).
func _draw_glow() -> void:
	var lamp: float = _light()["lamp"]
	if lamp <= 0.01:
		return
	var centers: Array = desk_positions.duplicate()
	if hr_worker != null:
		centers.append(hr_worker.position)
	for d in centers:
		var c: Vector2 = d + Vector2(30, -24)
		# três anéis com alfa decrescente: halo suave em vez de um disco chapado
		glow_layer.draw_circle(c, 34.0, Color(1.0, 0.8, 0.5, 0.045 * lamp))
		glow_layer.draw_circle(c, 24.0, Color(1.0, 0.82, 0.55, 0.06 * lamp))
		glow_layer.draw_circle(c, 14.0, Color(1.0, 0.86, 0.6, 0.08 * lamp))


## De vez em quando alguém "pensa" alguma coisa: balão com emoji conforme o que está fazendo.
func _tick_bubbles(delta: float) -> void:
	bubble_timer -= delta
	if bubble_timer > 0.0:
		return
	bubble_timer = randf_range(4.0, 9.0)
	var candidates: Array = []
	for w in workers.values():
		if w.visible and (w.state == Worker.State.AT_DESK or w.state == Worker.State.AT_SPOT):
			candidates.append(w)
	if candidates.is_empty():
		return
	var w: Worker = candidates[randi() % candidates.size()]
	var pool: Array = BUBBLES_IDLE
	if Game.office.is_moving():
		pool = ["📦", "🚚", "📦"]
	elif w.resting:
		pool = BUBBLES_REST
	elif w.state == Worker.State.AT_DESK and w.on_project:
		pool = BUBBLES_WORK
	show_feedback(w.employee_id, pool[randi() % pool.size()], "bubble")


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
	var wall_tint: Color = WALL_TINTS.get(Game.office.region() if Game.has_game() else 1, Color.WHITE)
	for x in w:
		world.draw_texture(wall_tex, Vector2(x * TILE, 0), wall_tint)
		for y in range(WALL_ROWS, h):
			world.draw_texture(floor_tex, Vector2(x * TILE, y * TILE))
	world.draw_texture(pillar_tex, Vector2(0, 0))
	world.draw_texture(pillar_tex, Vector2(w * TILE - pillar_tex.get_width(), 0))
	for z in layout.get("zones", []):
		var r: Array = z.get("rect", [])
		if r.size() < 4:
			continue
		var fill: Color = ZONE_TINTS.get(String(z.get("tint", "lounge")), ZONE_TINTS["lounge"])
		var rect := Rect2(float(r[0]) * TILE, float(r[1]) * TILE, float(r[2]) * TILE, float(r[3]) * TILE)
		world.draw_rect(rect, fill)
		world.draw_rect(rect, Color(fill, minf(fill.a * 3.2, 0.85)).darkened(0.3), false, 1.0)


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
		worker.set_carrying_box(Game.office.is_moving())
		index += 1
	for id in workers.keys():
		if not seen.has(id):
			workers[id].queue_free()
			workers.erase(id)
	Audio.set_ambience_people(st.employees.size())


func _sync_pets() -> void:
	var st: GameState = Game.state
	var w := float(layout.get("width", 10)) * TILE
	var h := float(layout.get("height", 7)) * TILE
	var area := Rect2(20.0, WALL_ROWS * TILE + 20.0, w - 40.0, h - WALL_ROWS * TILE - 28.0)
	for kind in st.pets:
		if pets.has(kind):
			continue
		var pet := Pet.new()
		pet.setup(String(kind), area, st.seed + kind.hash())
		scene_layer.add_child(pet)
		pets[kind] = pet


## Quem sai da agência atravessa o escritório com a caixa e some na porta (o nó se libera sozinho).
func _on_employee_left(e: Employee, _reason: String) -> void:
	var worker: Worker = workers.get(e.id)
	if worker == null:
		return
	workers.erase(e.id)
	if not is_visible_in_tree():
		worker.queue_free()
		return
	worker.leave_for_good()


## Balão ("Café!") ou número flutuante ("+12 XP") sobre a cabeça do personagem.
func show_feedback(employee_id: int, text: String, kind: String) -> void:
	var worker: Worker = workers.get(employee_id)
	if worker == null or not is_visible_in_tree():
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
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
	var start := worker.head_position() - Vector2(label.size.x * 0.5, 10)
	label.position = start
	var tween := create_tween()
	tween.tween_property(label, "position", start + Vector2(0, -18), 1.4).set_ease(Tween.EASE_OUT)
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
	var best_dist := 44.0
	for id in workers:
		var w: Worker = workers[id]
		if not w.visible:
			continue
		# retângulo do sprite (32x48 acima dos pés), com folga para o dedo
		var rect := Rect2(w.position + Vector2(-20, -56), Vector2(40, 60))
		if rect.has_point(local):
			var d: float = (w.position + Vector2(0, -24)).distance_to(local)
			if d < best_dist:
				best_dist = d
				best_id = id
	if best_id != -1:
		worker_tapped.emit(best_id)
