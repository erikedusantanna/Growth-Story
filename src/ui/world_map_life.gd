class_name WorldMapLife
extends Node2D
## Camada viva do World Map, desenhada entre a imagem da cidade e os cartões das regiões, em
## coordenadas 1x (o pai aplica a escala do mapa). Carros na avenida e nas ruas, barcos no mar,
## nuvens com sombra, avião com rastro, bandos de pássaros, espuma em movimento; à noite (hora do
## escritório) as janelas acendem e o farol gira. O pino da sede pulsa e, na mudança de sede, um
## caminhão atravessa a avenida até a região nova. Rotas e pontos vêm de data/map_life.json
## (gerado por tools/gen_art.py).

const CAR_COLORS := [Color("#f4f6f8"), Color("#f2c744"), Color("#e04a3c"), Color("#3e8fd0"), Color("#5aa64f"), Color("#4a5566"), Color("#e8a0b8")]
const CAR_SPEED := Vector2(12.0, 24.0)        # px/s (1x)
const ROAD_CARS_PER_LANE := 7
const STREET_CAR_EVERY := 48.0                # 1 carro a cada N px de rua
const ROAD_LANE := 3.0
const STREET_LANE := 1.5
const BOAT_SPEED := Vector2(4.0, 7.0)
const CLOUD_COUNT := 5
const CLOUD_SPEED := Vector2(2.0, 4.5)
const PLANE_INTERVAL := Vector2(14.0, 26.0)
const PLANE_SPEED := 38.0
const BIRDS_INTERVAL := Vector2(8.0, 16.0)
const BIRD_SPEED := 16.0
const TRUCK_SPEED := 42.0
const MAX_LIT_WINDOWS := 320
const LIT_FRACTION := 0.6
const RING_PERIOD := 1.6

var paths: Dictionary = {}
var map_size := Vector2(270, 640)
var vehicles: Array = []       # carros e barcos: {sprite, line, cum, total, d, speed, kind}
var clouds: Array = []         # {sprite, shadow, speed, drift}
var birds: Array = []          # {sprite, vel, phase}
var plane: Dictionary = {}     # {sprite, vel, trail: PackedVector2Array, trail_t}
var truck: Dictionary = {}     # {sprite, line, cum, total, d}
var flags: PackedVector2Array = []   # bandeiras no telhado das rivais (1x)
var hq_pos := Vector2.ZERO
var parked_truck := false      # semana de mudança: caminhão estacionado ao lado da sede
var tint := Color.WHITE        # luz da hora (o mapa e os veículos usam)
var night := 0.0
var t := 0.0
var plane_timer := 6.0
var birds_timer := 3.0
var rng := RandomNumberGenerator.new()
var lit: PackedVector2Array = []
var lit_phase: PackedFloat32Array = []
var foam: PackedVector2Array = []
var road: PackedVector2Array = []
var lighthouse := Vector2(232, 30)

var ground: Node2D     # veículos, caminhão, barcos (recebem a luz da hora)
var cover: Sprite2D    # só os prédios/árvores da cidade: os carros passam por trás deles
var sky: Node2D        # pássaros, sombras, nuvens, avião
var rivals: PackedVector2Array = []   # centro da sede de cada rival (1x): anel vermelho pulsando
var tex_car: Texture2D
var tex_truck: Texture2D
var tex_boat: Texture2D
var tex_plane: Texture2D
var tex_bird: Texture2D
var tex_flag: Texture2D
var tex_clouds: Array = []

signal truck_arrived


func _ready() -> void:
	rng.seed = 20260911
	ground = Node2D.new()
	add_child(ground)
	cover = Sprite2D.new()
	cover.texture = load("res://assets/art/map/world_cover.png")
	cover.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cover.centered = false
	add_child(cover)
	sky = Node2D.new()
	add_child(sky)
	tex_car = load("res://assets/art/map/car.png")
	tex_truck = load("res://assets/art/map/truck.png")
	tex_boat = load("res://assets/art/map/boat.png")
	tex_plane = load("res://assets/art/map/plane.png")
	tex_bird = load("res://assets/art/map/bird.png")
	tex_flag = load("res://assets/art/map/flag.png")
	tex_clouds = [load("res://assets/art/map/cloud_a.png"), load("res://assets/art/map/cloud_b.png")]
	var txt := FileAccess.get_file_as_string("res://data/map_life.json")
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		setup(parsed)


func setup(p: Dictionary) -> void:
	paths = p
	var sz: Array = p.get("size", [270, 640])
	map_size = Vector2(float(sz[0]), float(sz[1]))
	road = _to_points(p.get("road", []))
	foam = _to_points(p.get("foam", []))
	var lh: Array = p.get("lighthouse", [232, 30])
	lighthouse = Vector2(float(lh[0]), float(lh[1]))
	# janelas acesas à noite: subconjunto fixo das janelas dos prédios
	var all_windows: Array = []
	all_windows.append_array(p.get("windows", []))
	all_windows.append_array(p.get("dark_windows", []))
	lit.clear()
	lit_phase.clear()
	for w in all_windows:
		if rng.randf() < LIT_FRACTION and lit.size() < MAX_LIT_WINDOWS:
			lit.append(Vector2(float(w[0]), float(w[1])))
			lit_phase.append(rng.randf() * TAU)
	_spawn_vehicles()
	_spawn_clouds()


static func _to_points(arr: Array) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for a in arr:
		out.append(Vector2(float(a[0]), float(a[1])))
	return out


# --- Rotas ------------------------------------------------------------------------------

## Polilinha deslocada para a faixa da direita (no sentido de quem anda): carros andam pela direita.
static func _lane(line: PackedVector2Array, offset: float) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for i in line.size():
		var d := Vector2.ZERO
		if i > 0:
			d += (line[i] - line[i - 1]).normalized()
		if i < line.size() - 1:
			d += (line[i + 1] - line[i]).normalized()
		d = d.normalized()
		out.append(line[i] + Vector2(-d.y, d.x) * offset)
	return out


static func _reversed(line: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for i in range(line.size() - 1, -1, -1):
		out.append(line[i])
	return out


static func _cumulative(line: PackedVector2Array) -> PackedFloat32Array:
	var cum: PackedFloat32Array = [0.0]
	for i in range(1, line.size()):
		cum.append(cum[i - 1] + line[i].distance_to(line[i - 1]))
	return cum


## Posição e ângulo a uma distância d ao longo da polilinha.
static func _along(line: PackedVector2Array, cum: PackedFloat32Array, d: float) -> Array:
	for i in range(1, line.size()):
		if d <= cum[i] or i == line.size() - 1:
			var seg_len: float = maxf(cum[i] - cum[i - 1], 0.001)
			var f := clampf((d - cum[i - 1]) / seg_len, 0.0, 1.0)
			return [line[i - 1].lerp(line[i], f), (line[i] - line[i - 1]).angle()]
	return [line[0], 0.0]


func _make_vehicle(tex: Texture2D, line: PackedVector2Array, kind: String, speed: float, color: Color = Color.WHITE) -> Dictionary:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.modulate = color
	ground.add_child(s)
	var cum := _cumulative(line)
	var v := {"sprite": s, "line": line, "cum": cum, "total": cum[cum.size() - 1], "d": rng.randf() * cum[cum.size() - 1], "speed": speed, "kind": kind}
	_place_vehicle(v)
	return v


func _place_vehicle(v: Dictionary) -> void:
	var line: PackedVector2Array = v["line"]
	var pa := _along(line, v["cum"], v["d"])
	var s: Sprite2D = v["sprite"]
	s.position = pa[0]
	var angle: float = pa[1]
	if v["kind"] == "boat":
		s.rotation = 0.0
		s.flip_h = cos(angle) < 0.0
	else:
		s.rotation = angle
		s.flip_v = absf(wrapf(angle, -PI, PI)) > PI * 0.5
	# entra e sai suavemente nas pontas da rota
	var edge: float = minf(v["d"], float(v["total"]) - v["d"])
	s.modulate.a = clampf(edge / 8.0, 0.0, 1.0)


func _spawn_vehicles() -> void:
	for v in vehicles:
		v["sprite"].queue_free()
	vehicles.clear()
	if road.size() >= 2:
		for lane_line in [_lane(road, ROAD_LANE), _lane(_reversed(road), ROAD_LANE)]:
			for k in ROAD_CARS_PER_LANE:
				vehicles.append(_make_vehicle(tex_car, lane_line, "car", rng.randf_range(CAR_SPEED.x, CAR_SPEED.y) * 1.2, CAR_COLORS[rng.randi() % CAR_COLORS.size()]))
	for st in paths.get("streets", []):
		var line := _to_points(st)
		if line.size() < 2:
			continue
		var cum := _cumulative(line)
		var n: int = maxi(1, int(cum[cum.size() - 1] / STREET_CAR_EVERY))
		for k in n:
			var forward: bool = rng.randf() < 0.5
			var lane_line := _lane(line if forward else _reversed(line), STREET_LANE)
			vehicles.append(_make_vehicle(tex_car, lane_line, "car", rng.randf_range(CAR_SPEED.x, CAR_SPEED.y), CAR_COLORS[rng.randi() % CAR_COLORS.size()]))
	var lanes: Array = paths.get("sea_lanes", [])
	for li in lanes.size():
		var line := _to_points(lanes[li])
		if line.size() < 2:
			continue
		for k in 2:
			var boat_line := line if k == 0 else _reversed(line)
			vehicles.append(_make_vehicle(tex_boat, _lane(boat_line, 4.0), "boat", rng.randf_range(BOAT_SPEED.x, BOAT_SPEED.y)))


func _spawn_clouds() -> void:
	for c in clouds:
		c["sprite"].queue_free()
		c["shadow"].queue_free()
	clouds.clear()
	for i in CLOUD_COUNT:
		var tex: Texture2D = tex_clouds[i % tex_clouds.size()]
		var shadow := Sprite2D.new()
		shadow.texture = tex
		shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shadow.modulate = Color(0, 0, 0, 0.16)
		sky.add_child(shadow)
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(rng.randf_range(0.0, map_size.x), rng.randf_range(20.0, map_size.y - 20.0))
		sky.add_child(s)
		clouds.append({"sprite": s, "shadow": shadow, "speed": rng.randf_range(CLOUD_SPEED.x, CLOUD_SPEED.y), "drift": rng.randf_range(-0.4, 0.4)})


func _spawn_plane() -> void:
	var s := Sprite2D.new()
	s.texture = tex_plane
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var to_right: bool = rng.randf() < 0.5
	s.flip_h = not to_right
	s.position = Vector2(-16.0 if to_right else map_size.x + 16.0, rng.randf_range(30.0, map_size.y * 0.7))
	sky.add_child(s)
	plane = {"sprite": s, "vel": Vector2(PLANE_SPEED if to_right else -PLANE_SPEED, rng.randf_range(-6.0, 6.0)), "trail": PackedVector2Array(), "trail_t": 0.0}


func _spawn_birds() -> void:
	var to_right: bool = rng.randf() < 0.5
	var y0 := rng.randf_range(40.0, map_size.y - 40.0)
	var n := rng.randi_range(3, 5)
	for i in n:
		var s := Sprite2D.new()
		s.texture = tex_bird
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.hframes = 2
		s.modulate = Color(0.16, 0.19, 0.25)
		var x0 := (-10.0 - i * 6.0) if to_right else (map_size.x + 10.0 + i * 6.0)
		s.position = Vector2(x0, y0 + (i % 2) * 4.0 + i * 1.5)
		sky.add_child(s)
		birds.append({"sprite": s, "vel": Vector2(BIRD_SPEED if to_right else -BIRD_SPEED, 0.0), "phase": rng.randf() * TAU})


# --- Mudança de sede ---------------------------------------------------------------------

## Caminhão de mudança sai do marco da região `from` e vai pela avenida até `to` (1..5).
## Emite truck_arrived ao chegar. Retorna false se não há rota.
func play_move(from_region: int, to_region: int) -> bool:
	if road.size() < 2:
		return false
	var a: int = clampi(from_region - 1, 0, road.size() - 1)
	var b: int = clampi(to_region - 1, 0, road.size() - 1)
	if a == b:
		return false
	var line: PackedVector2Array = []
	var step: int = 1 if b > a else -1
	var i := a
	while true:
		line.append(road[i])
		if i == b:
			break
		i += step
	_clear_truck()
	var s := Sprite2D.new()
	s.texture = tex_truck
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.add_child(s)
	var lane_line := _lane(line, ROAD_LANE)
	var cum := _cumulative(lane_line)
	truck = {"sprite": s, "line": lane_line, "cum": cum, "total": cum[cum.size() - 1], "d": 0.0, "speed": TRUCK_SPEED, "kind": "truck"}
	_place_vehicle(truck)
	s.modulate.a = 1.0
	return true


func truck_active() -> bool:
	return not truck.is_empty()


func truck_position() -> Vector2:
	return truck["sprite"].position if truck_active() else hq_pos


func _clear_truck() -> void:
	if truck_active():
		truck["sprite"].queue_free()
	truck = {}


# --- Tick ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	t += delta
	# luz da hora do escritório, um pouco mais clara que lá dentro para o mapa seguir legível
	var light := OfficeView.daylight(OfficeView.current_hour())
	tint = (light["tint"] as Color).lerp(Color.WHITE, 0.3)
	night = float(light["night"])
	ground.modulate = tint
	cover.modulate = tint
	sky.modulate = tint.lerp(Color.WHITE, 0.3)
	for v in vehicles:
		v["d"] = fmod(float(v["d"]) + float(v["speed"]) * delta, float(v["total"]))
		_place_vehicle(v)
	if truck_active():
		truck["d"] = float(truck["d"]) + TRUCK_SPEED * delta
		if float(truck["d"]) >= float(truck["total"]):
			_clear_truck()
			truck_arrived.emit()
		else:
			_place_vehicle(truck)
			truck["sprite"].modulate.a = 1.0
	for c in clouds:
		var s: Sprite2D = c["sprite"]
		s.position += Vector2(float(c["speed"]), float(c["drift"])) * delta
		if s.position.x > map_size.x + 16.0:
			s.position = Vector2(-16.0, rng.randf_range(20.0, map_size.y - 20.0))
		var sh: Sprite2D = c["shadow"]
		sh.position = s.position + Vector2(5, 9)
	plane_timer -= delta
	if plane.is_empty() and plane_timer <= 0.0:
		_spawn_plane()
	if not plane.is_empty():
		var s: Sprite2D = plane["sprite"]
		s.position += (plane["vel"] as Vector2) * delta
		plane["trail_t"] = float(plane["trail_t"]) + delta
		if float(plane["trail_t"]) > 0.12:
			plane["trail_t"] = 0.0
			var trail: PackedVector2Array = plane["trail"]
			trail.append(s.position - (plane["vel"] as Vector2).normalized() * 7.0)
			if trail.size() > 18:
				trail.remove_at(0)
			plane["trail"] = trail
		if s.position.x < -30.0 or s.position.x > map_size.x + 30.0:
			s.queue_free()
			plane = {}
			plane_timer = rng.randf_range(PLANE_INTERVAL.x, PLANE_INTERVAL.y)
	birds_timer -= delta
	if birds.is_empty() and birds_timer <= 0.0:
		_spawn_birds()
	var gone: Array = []
	for b in birds:
		var s: Sprite2D = b["sprite"]
		s.position += (b["vel"] as Vector2) * delta + Vector2(0.0, sin(t * 2.0 + float(b["phase"])) * 6.0 * delta)
		s.frame = 0 if fmod(t * 5.0 + float(b["phase"]), 2.0) < 1.0 else 1
		if s.position.x < -20.0 or s.position.x > map_size.x + 20.0:
			gone.append(b)
	for b in gone:
		b["sprite"].queue_free()
		birds.erase(b)
	if birds.is_empty() and gone.size() > 0:
		birds_timer = rng.randf_range(BIRDS_INTERVAL.x, BIRDS_INTERVAL.y)
	queue_redraw()


func _draw() -> void:
	# espuma que anda (por cima da espuma fixa da imagem)
	for i in foam.size():
		var p := foam[i]
		var ph := t * 1.4 + p.x * 0.21 + p.y * 0.07
		draw_rect(Rect2(p.x - 2.0 + 2.0 * sin(ph), p.y, 3.0, 1.0), Color(0.9, 0.96, 1.0, 0.35 + 0.35 * sin(ph * 1.3)))
	# rastro do avião
	if not plane.is_empty():
		var trail: PackedVector2Array = plane["trail"]
		for i in trail.size():
			var a := float(i + 1) / float(trail.size() + 1)
			draw_rect(Rect2(trail[i].x - 1.0, trail[i].y, 2.0, 1.0), Color(1, 1, 1, 0.55 * a))
	# esteira dos barcos
	for v in vehicles:
		if v["kind"] == "boat":
			var s: Sprite2D = v["sprite"]
			var dir := -1.0 if s.flip_h else 1.0
			for k in 3:
				draw_rect(Rect2(s.position.x - dir * (6.0 + k * 3.0) - 1.0, s.position.y + 2.0 + (k % 2), 2.0, 1.0), Color(0.9, 0.96, 1.0, (0.5 - k * 0.14) * s.modulate.a))
	# janelas acesas e farol à noite
	if night > 0.02:
		for i in lit.size():
			var w := lit[i]
			var flicker := 0.75 + 0.25 * sin(t * 2.3 + lit_phase[i])
			if fmod(t * 0.7 + lit_phase[i], 9.0) < 0.25:
				continue   # de vez em quando uma apaga por um instante
			draw_rect(Rect2(w.x, w.y, 2.0, 3.0), Color(1.0, 0.9, 0.55, night * flicker * 0.9))
		var beam_angle := t * 0.9
		var beam := PackedVector2Array([lighthouse, lighthouse + Vector2.from_angle(beam_angle - 0.12) * 64.0, lighthouse + Vector2.from_angle(beam_angle + 0.12) * 64.0])
		draw_colored_polygon(beam, Color(1.0, 0.98, 0.8, 0.2 * night))
		draw_circle(lighthouse, 2.5, Color(1.0, 0.95, 0.7, 0.9 * night))
	# lâmpada vermelha do farol pisca dia e noite
	if fmod(t, 1.2) < 0.6:
		draw_rect(Rect2(lighthouse.x - 1.0, lighthouse.y - 4.0, 2.0, 2.0), Color(1.0, 0.35, 0.3, 0.9))
	# anel pulsando na sede
	if hq_pos != Vector2.ZERO:
		for k in 2:
			var ph := fmod(t / RING_PERIOD + k * 0.5, 1.0)
			draw_arc(hq_pos, 5.0 + 11.0 * ph, 0.0, TAU, 28, Color(0.24, 0.76, 0.42, (1.0 - ph) * 0.8), 1.5)
	# rivais: anel vermelho pulsando em volta da sede (para a concorrente saltar aos olhos)
	for r in rivals:
		var ph := fmod(t / 1.3, 1.0)
		draw_arc(r, 22.0 + 10.0 * ph, 0.0, TAU, 32, Color(0.9, 0.25, 0.2, (1.0 - ph) * 0.9), 2.0)
		draw_arc(r, 22.0, 0.0, TAU, 32, Color(0.9, 0.25, 0.2, 0.55 + 0.25 * sin(t * 4.0)), 1.5)
	# bandeiras das rivais (2 quadros)
	if tex_flag != null:
		var frame := 0 if fmod(t * 3.0, 2.0) < 1.0 else 1
		for f in flags:
			draw_texture_rect_region(tex_flag, Rect2(f, Vector2(7, 6)), Rect2(Vector2(7 * frame, 0), Vector2(7, 6)))
	# caminhão estacionado na semana de mudança
	if parked_truck and not truck_active() and tex_truck != null and hq_pos != Vector2.ZERO:
		draw_texture(tex_truck, hq_pos + Vector2(10.0, 2.0), tint)
