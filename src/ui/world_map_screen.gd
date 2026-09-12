class_name WorldMapScreen
extends Control
## World Map: a cidade isométrica em tela cheia com os marcos das 5 regiões. Tocar no marco da
## região atual amplia o escritório; tocar na próxima região muda a sede (custo alto, reputação
## mínima); regiões à frente ficam com cadeado. Concorrentes aparecem nas regiões 2–4 quando a
## agência chega lá (painel deles no bloco C). A camada viva (WorldMapLife) anima a cidade:
## carros, barcos, nuvens, avião, pássaros, luzes à noite e o caminhão da mudança de sede.

const MAP_SCALE := 2.0
const MARKER_W := 230.0

var scroll: ScrollContainer
var board: Control
var map: TextureRect
var life: WorldMapLife
var markers: Control
var header_title: Label
var marker_nodes: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var bg := ColorRect.new()
	bg.color = Color("#1b2438")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 64
	scroll.offset_bottom = -44
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	board = Control.new()
	var map_tex: Texture2D = preload("res://assets/art/map/world.png")
	board.custom_minimum_size = map_tex.get_size() * MAP_SCALE
	scroll.add_child(board)
	map = TextureRect.new()
	map.texture = map_tex
	map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.stretch_mode = TextureRect.STRETCH_SCALE
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.add_child(map)
	life = WorldMapLife.new()
	life.scale = Vector2(MAP_SCALE, MAP_SCALE)
	board.add_child(life)
	markers = Control.new()
	markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(markers)

	# cabeçalho fixo
	var head := PanelContainer.new()
	head.theme = UIKit.theme()
	head.set_anchors_preset(Control.PRESET_TOP_WIDE)
	head.offset_left = 8
	head.offset_right = -8
	head.offset_top = 8
	head.offset_bottom = 60
	add_child(head)
	var row := UIKit.hbox(8)
	head.add_child(row)
	header_title = UIKit.label("🌎 Mapa", 18, UIKit.COLOR_TEXT)
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(header_title)
	var close_btn := UIKit.button("✖️ Fechar", close, false, 40)
	close_btn.size_flags_horizontal = 0
	close_btn.custom_minimum_size.x = 110
	row.add_child(close_btn)
	# legenda fixa embaixo
	var legend := PanelContainer.new()
	legend.theme = UIKit.theme()
	legend.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	legend.anchor_top = 1.0
	legend.offset_left = 8
	legend.offset_right = -8
	legend.offset_top = -40
	legend.offset_bottom = -6
	add_child(legend)
	var lg := UIKit.label("📍 sua sede · 🏗️ ampliar · 🚚 mudar de sede · 🔒 bloqueada · ⚔️ concorrente", 12, UIKit.COLOR_MUTED)
	lg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lg.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	legend.add_child(lg)
	EventBus.state_changed.connect(func(): if visible: _build_markers())
	set_process(false)


func open() -> void:
	visible = true
	Game.ui_blocking = true
	set_process(true)
	_build_markers()
	await get_tree().process_frame
	var target := _scroll_for(_hq_map_pos())
	# começa um pouco acima e desce até a sede: a cidade "chega" em vez de aparecer pronta
	scroll.scroll_vertical = int(maxf(target - 140.0, 0.0))
	_scroll_to(target, 0.55)


func close() -> void:
	visible = false
	set_process(false)
	Game.ui_blocking = false


## Posição 1x do marco da região atual.
func _hq_map_pos() -> Vector2:
	if not Game.has_game():
		return Vector2.ZERO
	var pos: Array = Game.office.region_data(Game.office.region()).get("map_pos", [0, 0])
	return Vector2(float(pos[0]), float(pos[1]))


func _scroll_for(map_pos: Vector2) -> float:
	return clampf(map_pos.y * MAP_SCALE - size.y * 0.5, 0.0, maxf(board.custom_minimum_size.y - scroll.size.y, 0.0))


func _scroll_to(target: float, duration: float) -> void:
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float): scroll.scroll_vertical = int(v), float(scroll.scroll_vertical), target, duration)


func _process(_delta: float) -> void:
	if not visible or life == null:
		return
	map.modulate = life.tint
	if life.truck_active():
		# a câmera acompanha o caminhão da mudança
		scroll.scroll_vertical = int(_scroll_for(life.truck_position()))


func _build_markers() -> void:
	UIKit.clear(markers)
	marker_nodes.clear()
	if not Game.has_game():
		return
	var current: int = Game.office.region()
	var st: GameState = Game.state
	header_title.text = "🌎 %s · %s" % [st.agency_name, String(Game.office.region_data(current).get("name", ""))]
	var regions: Array = Game.office.regions()
	life.hq_pos = _hq_map_pos()
	life.parked_truck = Game.office.is_moving()
	life.flags = PackedVector2Array()
	life.rivals = PackedVector2Array()
	# concorrentes das regiões já alcançadas (sede desenhada ao lado do marco; toque abre o painel)
	for a in Game.competitors.active_rivals():
		var rd: Dictionary = Game.office.region_data(int(a.get("region", 1)))
		if not rd.is_empty():
			markers.add_child(_rival_sprite(rd, a))
	for rd in regions:
		var r := int(rd.get("region", 1))
		var card := _marker(rd, r, current)
		var pos: Array = rd.get("map_pos", [0, 0])
		card.position = Vector2(float(pos[0]) * MAP_SCALE - MARKER_W * 0.5, float(pos[1]) * MAP_SCALE + 14.0)
		card.position.x = clampf(card.position.x, 6.0, board.custom_minimum_size.x - MARKER_W - 6.0)
		markers.add_child(card)
		marker_nodes.append(card)
		if r == current:
			var pin := TextureRect.new()
			pin.texture = preload("res://assets/art/map/pin.png")
			pin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			pin.stretch_mode = TextureRect.STRETCH_SCALE
			pin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pin.size = Vector2(32, 44)
			pin.position = Vector2(float(pos[0]) * MAP_SCALE - 16.0, float(pos[1]) * MAP_SCALE - 46.0)
			pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			markers.add_child(pin)
			# o pino "flutua" sobre a sede
			var tw := pin.create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			tw.tween_property(pin, "position:y", pin.position.y - 6.0, 0.8)
			tw.tween_property(pin, "position:y", pin.position.y, 0.8)


func _rival_sprite(rd: Dictionary, a: Dictionary) -> Control:
	var holder := Control.new()
	var pos: Array = rd.get("map_pos", [0, 0])
	var tex := TextureRect.new()
	tex.texture = load("res://assets/art/map/rival_%s.png" % String(a.get("logo", "brick")))
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.size = Vector2(100, 140)
	tex.position = Vector2(float(pos[0]) * MAP_SCALE + 110.0, float(pos[1]) * MAP_SCALE - 124.0)
	tex.position.x = minf(tex.position.x, board.custom_minimum_size.x - 106.0)
	holder.add_child(tex)
	life.flags.append(tex.position / MAP_SCALE + Vector2(7.0, -5.0))
	life.rivals.append((tex.position + tex.size * 0.5) / MAP_SCALE + Vector2(0.0, 14.0))
	# rótulo com fundo escuro e badge ⚔️ acima do prédio: legível sobre qualquer parte da cidade
	var aggressive: bool = Game.competitors.is_aggressive(String(a.get("id", "")))
	var tag := PanelContainer.new()
	tag.theme = UIKit.theme()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#7a1f1a", 0.92) if aggressive else Color("#1f2633", 0.92)
	style.border_color = Color("#e04a3c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	tag.add_theme_stylebox_override("panel", style)
	tag.add_child(UIKit.label("⚔️ %s%s" % [String(a.get("name", "")), " 😠" if aggressive else ""], 13, Color.WHITE))
	tag.position = tex.position + Vector2(-30.0, -30.0)
	tag.position.x = clampf(tag.position.x, 4.0, board.custom_minimum_size.x - 170.0)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tag)
	var hint := UIKit.label("toque para ver", 11, Color("#ffd27a"))
	hint.add_theme_constant_override("outline_size", 3)
	hint.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.2))
	hint.position = tex.position + Vector2(8.0, 140.0)
	holder.add_child(hint)
	var btn := Button.new()
	btn.flat = true
	for st_name in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st_name, StyleBoxEmpty.new())
	btn.position = tag.position
	btn.size = Vector2(maxf(tex.position.x + 100.0 - tag.position.x, 150.0), 190.0)
	btn.tooltip_text = String(a.get("name", ""))
	btn.set_meta("rival_id", String(a.get("id", "")))
	btn.pressed.connect(func(): _popups().show_rival(String(a.get("id", ""))))
	holder.add_child(btn)
	return holder


func _marker(rd: Dictionary, r: int, current: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme = UIKit.theme()
	card.custom_minimum_size.x = MARKER_W
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1f2633", 0.92)
	style.border_color = UIKit.COLOR_ACCENT if r == current else (Color("#8fa3c8") if r == current + 1 else Color("#3a4358"))
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)
	var v := UIKit.vbox(3)
	card.add_child(v)
	var title := UIKit.label("TIER %d · %s" % [int(rd.get("tier", r)), String(rd.get("tier_name", "")).to_upper()], 13, Color.WHITE)
	v.add_child(title)
	v.add_child(UIKit.label(String(rd.get("name", "")), 15, UIKit.COLOR_ACCENT if r == current else Color("#dfe6f2")))
	v.add_child(UIKit.label(String(rd.get("desc", "")), 11, Color("#aab4c8"), true))
	if r < current:
		v.add_child(UIKit.label("✓ A agência já passou por aqui", 11, Color("#8fd19e")))
	elif r == current:
		var office: Dictionary = Game.office.current()
		v.add_child(UIKit.label("📍 Sua sede: %s · %d/%d lugares" % [String(office.get("name", "")), Game.state.employees.size(), Game.office.capacity()], 12, Color.WHITE, true))
		var nxt: Dictionary = Game.office.next_level()
		if nxt.is_empty():
			v.add_child(UIKit.label("Tamanho máximo nesta região.", 11, Color("#aab4c8")))
		else:
			var check: Dictionary = Game.office.can_upgrade()
			v.add_child(UIKit.label("Próximo: %s · %d lugares · %s" % [String(nxt.get("name", "")), int(nxt.get("capacity", 0)), UIKit.money(float(nxt.get("upgrade_cost", 0)))], 11, Color("#aab4c8"), true))
			var b := UIKit.button("🏗️ Ampliar", func(): _confirm_upgrade(nxt), true, 36)
			b.disabled = not check.ok
			b.tooltip_text = check.reason
			v.add_child(b)
	elif r == current + 1:
		var check: Dictionary = Game.office.can_move(r)
		v.add_child(UIKit.label("🔒 %s · reputação %d" % [UIKit.money(float(rd.get("move_cost", 0))), int(rd.get("rep_required", 0))], 12, Color.WHITE))
		var b := UIKit.button("🚚 Mudar a sede", func(): _confirm_move(rd, r), true, 36)
		b.disabled = not check.ok
		b.tooltip_text = check.reason
		v.add_child(b)
		if check.ok:
			# dá para mudar: o botão respira para chamar atenção
			var tw := b.create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			tw.tween_property(b, "modulate", Color(1.0, 1.0, 1.0, 0.72), 0.7)
			tw.tween_property(b, "modulate", Color.WHITE, 0.7)
		if not check.ok:
			v.add_child(UIKit.label(check.reason, 11, UIKit.COLOR_RED, true))
	else:
		v.add_child(UIKit.label("🔒 %s · reputação %d" % [UIKit.money(float(rd.get("move_cost", 0))), int(rd.get("rep_required", 0))], 12, Color("#aab4c8")))
	return card


func _popups() -> Popups:
	return get_tree().get_first_node_in_group("popups") as Popups


func _confirm_upgrade(nxt: Dictionary) -> void:
	var p := _popups()
	p.show_choice("🏗️ Ampliar o escritório?",
		"%s: %d lugares por %s. O aluguel passa a %s/mês." % [String(nxt.get("name", "")), int(nxt.get("capacity", 0)), UIKit.money(float(nxt.get("upgrade_cost", 0))), UIKit.money(float(nxt.get("rent", 0)) * Game.state.rent_modifier)],
		["🏗️ Ampliar", "✖️ Agora não"], func(i: int):
			if i == 0 and Game.office.upgrade():
				_build_markers())


func _confirm_move(rd: Dictionary, r: int) -> void:
	var p := _popups()
	var first: Dictionary = Game.office.level_data(int(rd.get("first_level", 1)))
	p.show_choice("🚚 Mudar a sede para %s?" % String(rd.get("name", "")),
		"Custa %s. O escritório novo (%s) tem %d lugares e aluguel de %s/mês. Clientes tier %d passam a aparecer. A mudança leva %d dias com produtividade reduzida." % [
			UIKit.money(float(rd.get("move_cost", 0))), String(first.get("name", "")), int(first.get("capacity", 0)),
			UIKit.money(float(first.get("rent", 0)) * Game.state.rent_modifier), int(rd.get("tier", r)), int(Game.content.regions.get("moving_days", 7))],
		["🚚 Mudar", "✖️ Agora não"], func(i: int):
			if i == 0:
				var from: int = Game.office.region()
				var res: Dictionary = Game.office.move_to(r)
				if res.ok:
					_build_markers()
					_play_move_and_announce(from, r, String(rd.get("name", "")))
				else:
					p.show_info("Mudança", res.reason))


## O caminhão atravessa a avenida até a região nova (a câmera acompanha); a mensagem vem depois.
func _play_move_and_announce(from: int, to: int, region_name: String) -> void:
	if life.play_move(from, to):
		await life.truck_arrived
	if not visible:
		return
	_scroll_to(_scroll_for(_hq_map_pos()), 0.4)
	_popups().show_info("Sede nova!", "Bem-vindos a %s. As caixas ficam no escritório por uma semana; depois disso é vida nova." % region_name)
