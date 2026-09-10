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
	date_label = UIKit.number("01 Jan 2010", 17, UIKit.COLOR_TEXT)
	date_box.add_child(date_label)
	top.add_child(date_box)

	var bottom := UIKit.hbox(6)
	v.add_child(bottom)
	phase_label = UIKit.label("Freelancer", 15, UIKit.COLOR_MUTED)
	phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bottom.add_child(phase_label)
	pause_button = UIKit.button("II", func(): Game.toggle_pause(), false, 36)
	pause_button.size_flags_horizontal = 0
	pause_button.custom_minimum_size.x = 48
	bottom.add_child(pause_button)
	for i in 3:
		var speed := i + 1
		var b := UIKit.button("%dx" % speed, func(): Game.set_speed(speed), false, 36)
		b.size_flags_horizontal = 0
		b.custom_minimum_size.x = 48
		bottom.add_child(b)
		speed_buttons.append(b)
	music_button = UIKit.button("🔊", func():
		Audio.toggle_music()
		refresh(), false, 36)
	music_button.size_flags_horizontal = 0
	music_button.custom_minimum_size.x = 44
	music_button.tooltip_text = "Música ligada/desligada"
	bottom.add_child(music_button)

	EventBus.state_changed.connect(refresh)
	EventBus.day_passed.connect(func(_d): refresh())
	EventBus.money_changed.connect(func(_v, _d): refresh())
	EventBus.reputation_changed.connect(func(_v, _d): refresh())


func refresh() -> void:
	if not Game.has_game():
		return
	var st: GameState = Game.state
	money_label.text = UIKit.money(st.money)
	money_label.add_theme_color_override("font_color", UIKit.COLOR_NUMBER if st.money >= 0.0 else UIKit.COLOR_RED)
	rep_label.text = "%d" % int(roundf(st.reputation))
	date_label.text = st.date_text()
	phase_label.text = "%s · %s" % [st.agency_name, Game.reputation.phase_name()]
	pause_button.text = ">" if st.paused else "II"
	music_button.text = "🔊" if Audio.music_enabled else "🔇"
	for i in speed_buttons.size():
		var b: Button = speed_buttons[i]
		var active: bool = st.speed == i + 1 and not st.paused
		b.modulate = Color(1, 1, 1, 1) if active else Color(1, 1, 1, 0.6)
		b.button_pressed = false
		if active:
			b.add_theme_stylebox_override("normal", b.get_theme_stylebox("pressed"))
		else:
			b.remove_theme_stylebox_override("normal")
