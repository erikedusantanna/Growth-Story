class_name TitleScreen
extends Control
## Tela inicial: continuar partida salva ou começar um novo jogo.

signal start_requested()

var agency_input: LineEdit
var founder_input: LineEdit
var continue_button: Button
var message: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UIKit.COLOR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)
	var v := UIKit.vbox(12)
	panel.add_child(v)

	var logo := TextureRect.new()
	logo.texture = preload("res://icon.png")
	logo.custom_minimum_size = Vector2(96, 96)
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.add_child(logo)
	var t := UIKit.label("A Growth Story", 34, UIKit.COLOR_ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UIKit.muted("Comece pequeno. Conquiste clientes. Monte seu time. Escale sua agência.")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(UIKit.spacer(6))

	continue_button = UIKit.button("Continuar", _on_continue, true)
	v.add_child(continue_button)
	v.add_child(UIKit.separator())

	v.add_child(UIKit.muted("Nome da agência"))
	agency_input = LineEdit.new()
	agency_input.placeholder_text = "Minha Agência"
	agency_input.custom_minimum_size.y = 44
	v.add_child(agency_input)
	v.add_child(UIKit.muted("Seu nome"))
	founder_input = LineEdit.new()
	founder_input.placeholder_text = "Você"
	founder_input.custom_minimum_size.y = 44
	v.add_child(founder_input)
	v.add_child(UIKit.button("Novo jogo", _on_new_game))
	message = UIKit.muted("")
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(message)
	v.add_child(UIKit.spacer(4))
	var version := UIKit.muted("Protótipo de mecânicas · v0.1", 13)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(version)


func open() -> void:
	visible = true
	continue_button.visible = Game.save.has_save()
	message.text = ""


func _on_continue() -> void:
	if Game.load_game():
		visible = false
		start_requested.emit()
	else:
		message.text = "Não foi possível carregar o save."


func _on_new_game() -> void:
	Game.new_game(agency_input.text, founder_input.text)
	Game.save_game()  # "Continuar" passa a apontar para a nova partida
	visible = false
	start_requested.emit()
