class_name Hud
extends PanelContainer
## Barra superior: caixa, reputação, data, fase da agência e controle de velocidade.

var money_label: Label
var rep_label: Label
var date_label: Label
var phase_label: Label
var speed_buttons: Array = []
var pause_button: Button


func _ready() -> void:
	var v := UIKit.vbox(4)
	add_child(v)
	var top := UIKit.hbox(10)
	v.add_child(top)
	money_label = UIKit.label("R$ 0", 20, UIKit.COLOR_GREEN)
	money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(money_label)
	rep_label = UIKit.label("Rep 0", 20, UIKit.COLOR_ACCENT)
	rep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rep_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(rep_label)
	date_label = UIKit.label("01 Jan 2010", 18)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(date_label)

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

	EventBus.state_changed.connect(refresh)
	EventBus.day_passed.connect(func(_d): refresh())
	EventBus.money_changed.connect(func(_v, _d): refresh())
	EventBus.reputation_changed.connect(func(_v, _d): refresh())


func refresh() -> void:
	if not Game.has_game():
		return
	var st: GameState = Game.state
	money_label.text = UIKit.money(st.money)
	money_label.add_theme_color_override("font_color", UIKit.COLOR_GREEN if st.money >= 0.0 else UIKit.COLOR_RED)
	rep_label.text = "Rep %d" % int(roundf(st.reputation))
	date_label.text = st.date_text()
	phase_label.text = "%s · %s" % [st.agency_name, Game.reputation.phase_name()]
	pause_button.text = ">" if st.paused else "II"
	for i in speed_buttons.size():
		var b: Button = speed_buttons[i]
		var active: bool = st.speed == i + 1 and not st.paused
		b.modulate = Color(1, 1, 1, 1) if active else Color(1, 1, 1, 0.55)
