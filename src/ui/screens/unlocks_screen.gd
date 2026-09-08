class_name UnlocksScreen
extends BaseScreen
## Desbloqueios: árvore de serviços.

const TIER_NAMES := {"inicio": "Início", "intermediario": "Intermediário", "avancado": "Avançado", "endgame": "Endgame"}


func build() -> void:
	content.add_child(header("Serviços", "%d/%d" % [Game.state.unlocked_services.size(), Game.content.service_order.size()]))
	content.add_child(UIKit.muted("Cada segmento de cliente combina melhor com certos serviços. Descubra as combinações perfeitas."))
	var last_tier := ""
	for id in Game.content.service_order:
		var svc: Dictionary = Game.content.services[id]
		if svc.get("tier", "") != last_tier:
			last_tier = svc.get("tier", "")
			content.add_child(UIKit.label(TIER_NAMES.get(last_tier, last_tier), 17, UIKit.COLOR_ACCENT))
		content.add_child(_service_card(svc))
	content.add_child(UIKit.spacer(4))
	content.add_child(header("Combinações por segmento"))
	for seg in Game.content.match_table:
		var best: Array = Game.content.match_table[seg].get("best", [])
		var poor: Array = Game.content.match_table[seg].get("poor", [])
		var card := UIKit.card()
		var v := UIKit.card_content(card)
		v.add_child(UIKit.label(Game.content.segment_names.get(seg, seg), 17))
		v.add_child(UIKit.label("Funciona: %s" % ", ".join(best.map(func(s): return Game.content.service_name(s))), 14, UIKit.COLOR_GREEN, true))
		v.add_child(UIKit.label("Evite: %s" % ", ".join(poor.map(func(s): return Game.content.service_name(s))), 14, UIKit.COLOR_RED, true))
		content.add_child(card)


func _service_card(svc: Dictionary) -> PanelContainer:
	var id: String = svc["id"]
	var unlocked := Game.services.is_unlocked(id)
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	var top := UIKit.hbox()
	var name := UIKit.label(svc["name"], 19, UIKit.COLOR_TEXT if unlocked else UIKit.COLOR_MUTED)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	top.add_child(UIKit.label("ativo" if unlocked else "bloqueado", 13, UIKit.COLOR_GREEN if unlocked else UIKit.COLOR_MUTED))
	v.add_child(top)
	var weights: Dictionary = svc.get("weights", {})
	var parts: Array = []
	for key in weights:
		parts.append("%s %d%%" % [Employee.ATTR_NAMES[key], int(float(weights[key]) * 100)])
	v.add_child(UIKit.muted("Usa: %s" % ", ".join(parts), 13))
	if not unlocked:
		var check := Game.services.can_unlock(id)
		var b := UIKit.button("Desbloquear (%s · rep %d)" % [UIKit.money(float(svc.get("unlock_cost", 0))), int(svc.get("rep_required", 0))],
			func(): Game.services.unlock(id), true)
		b.disabled = not check.ok
		v.add_child(b)
		if not check.ok:
			v.add_child(UIKit.label(check.reason, 13, UIKit.COLOR_RED))
	return card
