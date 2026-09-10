class_name TitleScreen
extends Control
## Tela inicial: a cidade da agência ao fundo, o logo, "Novo Jogo" / "Continuar" e um passo
## seguinte para nomear a agência e o fundador. Pessoas do jogo passeiam na calçada e o
## fundador observa de cima do logo. O botão de som liga/desliga a música desde aqui.

signal start_requested()

const WORLD_SCALE := 2.0
const SIDEWALK_Y := 828.0            # pés dos pedestres, em px de tela (as pessoas ficam em 1x, menores que o cenário)
const WALK_SPEED := 32.0
const FRAME_TIME := 0.2

var agency_input: LineEdit
var founder_input: LineEdit
var continue_button: Button
var message: Label
var music_button: Button
var menu: VBoxContainer
var form: PanelContainer
var world: Node2D
var people: Node2D                   # pessoas em escala 1, para ficarem pequenas diante dos prédios
var walkers: Array = []              # {node, dir}
var _frame_timer := 0.0
var _walk_frame := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/art/title/background.png")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	world = Node2D.new()
	world.scale = Vector2(WORLD_SCALE, WORLD_SCALE)
	add_child(world)
	var logo := Sprite2D.new()
	logo.texture = preload("res://assets/art/title/logo.png")
	logo.centered = false
	logo.position = Vector2(15, 36)
	world.add_child(logo)
	people = Node2D.new()
	add_child(people)
	_add_founder()
	_add_walkers()

	# menu principal
	menu = UIKit.vbox(10)
	menu.set_anchors_preset(Control.PRESET_CENTER_TOP)
	menu.anchor_left = 0.5
	menu.anchor_right = 0.5
	menu.offset_left = -160
	menu.offset_right = 160
	menu.offset_top = 590
	add_child(menu)
	continue_button = UIKit.button("▶️ Continuar", _on_continue, true, 56)
	menu.add_child(continue_button)
	var new_button := UIKit.button("🚀 Novo Jogo", _show_form, false, 56)
	menu.add_child(new_button)

	# passo dos nomes (aparece ao clicar em Novo Jogo)
	form = PanelContainer.new()
	form.set_anchors_preset(Control.PRESET_CENTER_TOP)
	form.anchor_left = 0.5
	form.anchor_right = 0.5
	form.offset_left = -190
	form.offset_right = 190
	form.offset_top = 470
	form.visible = false
	add_child(form)
	var fv := UIKit.vbox(8)
	form.add_child(fv)
	fv.add_child(UIKit.label("Sua agência começa hoje", 18, UIKit.COLOR_ACCENT))
	fv.add_child(UIKit.muted("🏢 Nome da agência"))
	agency_input = LineEdit.new()
	agency_input.placeholder_text = "Minha Agência"
	agency_input.custom_minimum_size.y = 44
	fv.add_child(agency_input)
	fv.add_child(UIKit.muted("🙋 Seu nome"))
	founder_input = LineEdit.new()
	founder_input.placeholder_text = "Você"
	founder_input.custom_minimum_size.y = 44
	fv.add_child(founder_input)
	fv.add_child(UIKit.button("🚀 Começar", _on_new_game, true, 52))
	fv.add_child(UIKit.button("↩️ Voltar", _show_menu, false, 44))
	message = UIKit.muted("")
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fv.add_child(message)

	# som e versão
	music_button = UIKit.button("🔊", _toggle_music, false, 40)
	music_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	music_button.anchor_left = 1.0
	music_button.anchor_right = 1.0
	music_button.offset_left = -60
	music_button.offset_right = -12
	music_button.offset_top = 12
	music_button.offset_bottom = 52
	music_button.tooltip_text = "Música ligada/desligada"
	add_child(music_button)
	var version := UIKit.label("Protótipo de mecânicas · v0.2", 12, Color(1, 1, 1, 0.85))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	version.anchor_top = 1.0
	version.offset_top = -26
	version.offset_bottom = -8
	version.add_theme_constant_override("outline_size", 3)
	version.add_theme_color_override("font_outline_color", Color(0.12, 0.15, 0.2))
	add_child(version)


## O fundador em cima do logo, como na referência.
func _add_founder() -> void:
	var look := Employee.new()
	look.id = 9101
	look.skin = "#f0c49c"
	look.hair_style = 0
	look.hair_color = "#5b3a22"
	look.color = "#f4f4f6"
	var w := Worker.new()
	w.setup(look, Vector2(452, 88), [], 1)   # em pé sobre a barra mais alta do gráfico
	w.static_pose = true
	people.add_child(w)


## Pedestres na calçada: aparências variadas, andando de um lado para o outro.
func _add_walkers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 4:
		var look := Employee.new()
		look.id = 9200 + i
		look.skin = Employee.SKIN_TONES[rng.randi_range(0, Employee.SKIN_TONES.size() - 1)]
		look.hair_style = rng.randi_range(0, Employee.HAIR_STYLES - 1)
		look.hair_color = Employee.HAIR_COLORS[rng.randi_range(0, Employee.HAIR_COLORS.size() - 1)]
		look.color = ["#f4f4f6", "#4b8fd8", "#d94a3d", "#3cb371", "#f2a851"][i % 5]
		look.glasses = i == 2
		var w := Worker.new()
		var dir := 1 if i % 2 == 0 else -1
		w.setup(look, Vector2(rng.randf_range(40, 500), SIDEWALK_Y - rng.randf_range(0, 8)), [], 77 + i)
		w.static_pose = true
		w.set_process(false)          # o Worker não anima sozinho: a tela controla os quadros
		w.facing = Worker.Dir.RIGHT if dir > 0 else Worker.Dir.LEFT
		people.add_child(w)
		walkers.append({"node": w, "dir": dir, "speed": WALK_SPEED * rng.randf_range(0.8, 1.2)})


func _process(delta: float) -> void:
	if not visible:
		return
	_frame_timer += delta
	if _frame_timer >= FRAME_TIME:
		_frame_timer = 0.0
		_walk_frame = 1 - _walk_frame
	for wk in walkers:
		var w: Worker = wk.node
		w.position.x += wk.dir * wk.speed * delta
		if w.position.x > 580.0:
			wk.dir = -1
			w.facing = Worker.Dir.LEFT
		elif w.position.x < -40.0:
			wk.dir = 1
			w.facing = Worker.Dir.RIGHT
		w._apply_frame(Worker.Frame.WALK_A if _walk_frame == 0 else Worker.Frame.WALK_B)


func open() -> void:
	visible = true
	_show_menu()
	continue_button.visible = Game.save.has_save()
	message.text = ""
	_refresh_music_button()


func _show_menu() -> void:
	menu.visible = true
	form.visible = false


func _show_form() -> void:
	menu.visible = false
	form.visible = true
	agency_input.grab_focus()


func _toggle_music() -> void:
	Audio.toggle_music()
	_refresh_music_button()


func _refresh_music_button() -> void:
	music_button.text = "🔊" if Audio.music_enabled else "🔇"


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
