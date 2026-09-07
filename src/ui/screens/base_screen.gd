class_name BaseScreen
extends ScrollContainer
## Tela rolável que se reconstrói quando o estado muda. Subclasses implementam build().

var content: VBoxContainer
var refresh_daily := false


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content = UIKit.vbox(10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(content)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.day_passed.connect(func(_d): if refresh_daily: _on_state_changed())
	visibility_changed.connect(func(): if visible: refresh())


func _on_state_changed() -> void:
	if visible and is_inside_tree():
		refresh()


func refresh() -> void:
	if not Game.has_game():
		return
	var scroll := scroll_vertical
	UIKit.clear(content)
	build()
	set_deferred("scroll_vertical", scroll)


func build() -> void:
	pass


func popups() -> Popups:
	return get_tree().get_first_node_in_group("popups") as Popups


func header(text: String, right: String = "") -> HBoxContainer:
	var h := UIKit.hbox()
	var t := UIKit.title(text)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if right != "":
		var r := UIKit.muted(right)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(r)
	return h
