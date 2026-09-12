class_name Hud
extends PanelContainer
## Barra superior: caixa, reputação, data, fase da agência e controle de velocidade.

var money_label: Label
var rep_label: Label
var date_label: Label
var phase_label: Label
var speed_buttons: Array = []
var pause_button: Button
var music_button: Button


func _ready() -> void:
	var v := UIKit.vbox(4)
	add_child(v)
	var top := UIKit.hbox(10)
	v.add_child(top)
	var money_box := UIKit.hbox(6)
	money_box.add_child(UIKit.icon("coin"))
	money_label = UIKit.number("R$ 0", 20)
	money_box.add_child(money_label)
	top.add_child(money_box)
	var rep_box := UIKit.hbox(6)
	rep_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rep_box.alignment = BoxContainer.ALIGNMENT_CENTER
	rep_box.add_child(UIKit.icon("rep"))
	rep_label = UIKit.number("0", 20)
	rep_box.add_child(rep_label)
	top.add_child(rep_box)
	var date_box := UIKit.hbox(6)
	date_box.size_flags_horizontal = 0
	date_box.add_child(UIKit.icon("calendar"))
	date_label = UIKit.number("01 Jan 2010 08:00", 17, UIKit.COLOR_TEXT)
	date_box.add_child(date_label)
	top.add_child(date_box)

	var bottom := UIKit.hbox(4)
	v.add_child(bottom)
	phase_label = UIKit.label("Freelancer", 15, UIKit.COLOR_MUTED)
	phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	phase_label.clip_text = true
	phase_label.custom_minimum_size.x = 0
	bottom.add_child(phase_label)
	var agenda_button := _icon_button("agenda", func(): get_tree().call_group("main", "show_calendar"), 40)
	agenda_button.tooltip_text = "Calendário: o que vem pela frente, missões e foco do mês"
	agenda_button.set_meta("tutorial", "calendar")
	bottom.add_child(agenda_button)
	var map_button := _icon_button("map", func(): get_tree().call_group("main", "show_world_map"), 40)
	map_button.tooltip_text = "Mapa: regiões, mudança de sede e concorrentes"
	map_button.set_meta("tutorial", "map")
	bottom.add_child(map_button)
	pause_button = _icon_button("pause", func(): Game.toggle_pause(), 42)
	pause_button.tooltip_text = "Pausar / continuar"
	bottom.add_child(pause_button)
	for i in 3:
		var speed := i + 1
		var b := UIKit.button("%dx" % speed, func(): Game.set_speed(speed), false, 36)
		b.size_flags_horizontal = 0
		b.custom_minimum_size.x = 46
		if speed == 2:
			b.set_meta("tutorial", "speed2")
		bottom.add_child(b)
		speed_buttons.append(b)
	music_button = _icon_button("sound_on", func():
		Audio.toggle_music()
		refresh(), 40)
	music_button.tooltip_text = "Música ligada/desligada"
	bottom.add_child(music_button)

	EventBus.state_changed.connect(refresh)
	EventBus.day_passed.connect(func(_d): refresh())
	EventBus.money_changed.connect(func(_v, _d): refresh())
	EventBus.reputation_changed.connect(func(_v, _d): refresh())


## Botão só com ícone pixel art (os emojis não renderizam em todas as plataformas).
static func _icon_button(icon_name: String, callback: Callable, width: int) -> Button:
	var b := UIKit.button("", callback, false, 36)
	b.size_flags_horizontal = 0
	b.custom_minimum_size.x = width
	b.icon = UIKit.icon_texture(icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


## Hora do dia de trabalho (08:00–20:00), em passos de 10 minutos, a partir da fração do dia.
static func clock_text() -> String:
	var hour := OfficeView.current_hour()
	var h := int(floor(hour))
	var m := int(floor((hour - float(h)) * 6.0)) * 10
	return "%02d:%02d" % [h, m]


func _process(_delta: float) -> void:
	if not Game.has_game():
		return
	var text := "%s %s" % [Game.state.date_text(), clock_text()]
	if text != date_label.text:
		date_label.text = text


func refresh() -> void:
	if not Game.has_game():
		return
	var st: GameState = Game.state
	money_label.text = UIKit.money(st.money)
	money_label.add_theme_color_override("font_color", UIKit.COLOR_NUMBER if st.money >= 0.0 else UIKit.COLOR_RED)
	rep_label.text = "%d" % int(roundf(st.reputation))
	date_label.text = "%s %s" % [st.date_text(), clock_text()]
	phase_label.text = "%s · %s" % [st.agency_name, Game.reputation.phase_name()]
	pause_button.icon = UIKit.icon_texture("play" if st.paused else "pause")
	music_button.icon = UIKit.icon_texture("sound_on" if Audio.music_enabled else "sound_off")
	for i in speed_buttons.size():
		var b: Button = speed_buttons[i]
		var active: bool = st.speed == i + 1 and not st.paused
		b.modulate = Color(1, 1, 1, 1) if active else Color(1, 1, 1, 0.6)
		b.button_pressed = false
		if active:
			b.add_theme_stylebox_override("normal", b.get_theme_stylebox("pressed"))
		else:
			b.remove_theme_stylebox_override("normal")
